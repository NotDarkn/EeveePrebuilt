import Foundation
import Orion

// Bearer token captured from premium-relevant requests; reused by lyrics fetch etc.
public var spotifyAccessToken: String?

// Spotify's primary URLSession delegate (wg-spclient: bootstrap, customize, PAM).
// Patching lives in SpotifyResponsePatcher so HttpClientURLSessionHook can share it.

class SPTDataLoaderServiceHook: ClassHook<NSObject>, SpotifySessionDelegate {
    typealias Group = PremiumBootstrapGroup
    static let targetName = "SPTDataLoaderService"

    func URLSession(
        _ session: URLSession,
        task: URLSessionDataTask,
        didCompleteWithError error: Error?
    ) {
        if let request = task.currentRequest,
           let headers = request.allHTTPHeaderFields,
           let auth = headers["Authorization"] ?? headers["authorization"],
           auth.hasPrefix("Bearer ") {
            let token = String(auth.dropFirst(7))
            spotifyAccessToken = token
            // TEMP DEBUG: log token shape + source URL, never the token itself.
            let dotCount = token.filter { $0 == "." }.count
            let shape = "len=\(token.count) dots=\(dotCount) prefix=\(token.prefix(6))"
            writeDebugLog("[TokenCapture] \(shape) from \(task.currentRequest?.url?.absoluteString ?? "<no url>")")
        }

        guard let url = task.currentRequest?.url else {
            orig.URLSession(session, task: task, didCompleteWithError: error)
            return
        }

        if CasitaResponseProbe.shouldProbe(url) {
            CasitaResponseProbe.flush(task, url: url)
        }

        if SpotifyResponsePatcher.shouldBlock(url) {
            orig.URLSession(session, dataTask: task, didReceiveData: SpotifyResponsePatcher.blockedResponseData(for: url))
            orig.URLSession(session, task: task, didCompleteWithError: nil)
            return
        }

        // 304 already served — suppress the second completion.
        if SpotifyResponsePatcher.consumeCustomizeTask(task.taskIdentifier) {
            orig.URLSession(session, task: task, didCompleteWithError: nil)
            return
        }

        guard error == nil, SpotifyResponsePatcher.shouldModify(url) else {
            orig.URLSession(session, task: task, didCompleteWithError: error)
            return
        }

        guard let buffer = URLSessionHelper.shared.obtainData(for: task) else {
            // Customize 304 fallback — wg-spclient returned 304, no buffer
            // to patch, but we have a cached body from a prior 200.
            if url.isCustomize, let cached = SpotifyResponsePatcher.cachedCustomizeData {
                orig.URLSession(session, dataTask: task, didReceiveData: cached)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
            } else {
                // Some Spotify builds complete "modified" tasks with 0 body bytes.
                // Forwarding completion only can crash consumers that assume at least
                // one didReceiveData callback before completion.
                writeDebugLog("[DL] Missing buffered body for \(url.absoluteString) (taskId=\(task.taskIdentifier))")
                orig.URLSession(session, dataTask: task, didReceiveData: Data())
                // Always forward completion; otherwise Spotify may hang and get watchdog-killed.
                orig.URLSession(session, task: task, didCompleteWithError: error)
            }
            return
        }

        do {
            // Lyrics — async fetch with 18s budget, falls back to Spotify's own response on failure.
            //
            // iOS 27 / Spotify 9.1.60 fix: Spotify's URLSession delegate handler for
            // didReceiveData now accesses @MainActor-isolated state. When we call orig.*
            // from the SPTDataLoaderService delegate queue (a background serial queue),
            // Swift's strict concurrency runtime trips _swift_task_checkIsolatedSwift and
            // kills the process with EXC_BREAKPOINT / SIGTRAP.
            //
            // Fix: dispatch the two orig.URLSession calls onto the main queue.
            // This matches the execution context Spotify's renderer expects and eliminates
            // the @MainActor isolation violation entirely.
            if url.isLyrics {
                let originalLyrics = try? Lyrics(serializedBytes: buffer)

                // Fast path: if lyrics are already cached for this track, skip the
                // async dispatch + semaphore entirely and deliver inline. This makes
                // the full lyrics panel open instantly on first and subsequent views.
                if let trackId = extractTrackId(from: url.path),
                   let cached = cachedLyricsData(for: trackId) {
                    DispatchQueue.main.async { [self] in
                        orig.URLSession(session, dataTask: task, didReceiveData: cached)
                        orig.URLSession(session, task: task, didCompleteWithError: nil)
                    }
                    return
                }

                let semaphore = DispatchSemaphore(value: 0)
                var customLyricsData: Data?

                DispatchQueue.global(qos: .userInitiated).async {
                    customLyricsData = try? getLyricsDataForCurrentTrack(url.path, originalLyrics: originalLyrics)
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: .now() + .milliseconds(18000))
                let lyricsPayload = customLyricsData ?? buffer
                DispatchQueue.main.async { [self] in
                    orig.URLSession(session, dataTask: task, didReceiveData: lyricsPayload)
                    orig.URLSession(session, task: task, didCompleteWithError: nil)
                }
                return
            }

            if let result = try SpotifyResponsePatcher.patch(url: url, buffer: buffer) {
                writeDebugLog("[DL] Patched \(result.tag.rawValue)")
                orig.URLSession(session, dataTask: task, didReceiveData: result.data)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }
            // patch() returned nil but didReceiveData already suppressed the original —
            // replay the buffer or the consumer hangs (casita/browsita with no ad sections).
            orig.URLSession(session, dataTask: task, didReceiveData: buffer)
            orig.URLSession(session, task: task, didCompleteWithError: nil)
        } catch {
            orig.URLSession(session, task: task, didCompleteWithError: error)
        }
    }

    func URLSession(
        _ session: URLSession,
        dataTask task: URLSessionDataTask,
        didReceiveResponse response: HTTPURLResponse,
        completionHandler handler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let url = task.currentRequest?.url, url.isCustomize, response.statusCode == 304,
           let cached = SpotifyResponsePatcher.cachedCustomizeData {
            // 304, but our cache holds the already-patched body; force 200 so the
            // consumer accepts the cached data we replay next.
            guard let synthetic = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: [:]) else {
                orig.URLSession(session, dataTask: task, didReceiveResponse: response, completionHandler: handler)
                return
            }
            orig.URLSession(session, dataTask: task, didReceiveResponse: synthetic, completionHandler: handler)
            orig.URLSession(session, dataTask: task, didReceiveData: cached)
            SpotifyResponsePatcher.markCustomizeTaskHandled(task.taskIdentifier)
            return
        }

        // Lyrics 4xx/5xx — replace with our custom fetch result so the
        // consumer doesn't show "no lyrics available".
        //
        // IMPORTANT: getLyricsDataForCurrentTrack is a blocking network call.
        // Calling it synchronously here deadlocks because this delegate queue is
        // also needed to deliver subsequent delegate callbacks (didReceiveData,
        // didCompleteWithError). The fix is to fetch on a background queue while
        // holding the URLSession completion handler open — URLSession won't
        // proceed until we call handler(.allow/.cancel), so we have time to fetch
        // and then deliver everything ourselves.
        guard let url = task.currentRequest?.url, url.isLyrics, response.statusCode != 200 else {
            orig.URLSession(session, dataTask: task, didReceiveResponse: response, completionHandler: handler)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Fast path: serve from cache without a new fetch.
            let data: Data?
            if let trackId = extractTrackId(from: url.path),
               let cached = cachedLyricsData(for: trackId) {
                data = cached
            } else {
                data = try? getLyricsDataForCurrentTrack(url.path)
            }

            guard let lyricsData = data,
                  let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: [:]) else {
                // Fetch failed — let Spotify handle the original non-200 response.
                handler(.allow)
                orig.URLSession(session, dataTask: task, didReceiveResponse: response, completionHandler: { _ in })
                return
            }

            DispatchQueue.main.async { [self] in
                orig.URLSession(session, dataTask: task, didReceiveResponse: ok, completionHandler: handler)
                orig.URLSession(session, dataTask: task, didReceiveData: lyricsData)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
            }
        }
    }

    func URLSession(
        _ session: URLSession,
        dataTask task: URLSessionDataTask,
        didReceiveData data: Data
    ) {
        guard let url = task.currentRequest?.url else { return }

        // Suppress original data for endpoints we'll replace in
        // didCompleteWithError — otherwise the consumer sees both.
        if SpotifyResponsePatcher.shouldBlock(url) { return }
        if CasitaResponseProbe.shouldProbe(url) {
            CasitaResponseProbe.append(data, for: task)
        }
        if SpotifyResponsePatcher.shouldModify(url) {
            URLSessionHelper.shared.setOrAppend(data, for: task)
            return
        }
        orig.URLSession(session, dataTask: task, didReceiveData: data)
    }
}
