import Foundation

/// Holds the most recently parsed karaoke (per-syllable) lyrics, keyed by
/// Spotify track ID. SpicyLyricsRepository populates this as a side effect
/// whenever it parses a Type=="Syllable" response — it's the bridge between
/// the existing LyricsRepository protocol (which only returns flattened
/// LyricsDto, matching Spotify's native line-only protobuf schema) and the
/// custom karaoke overlay view, which needs the richer per-syllable timing
/// that LyricsDto has nowhere to carry.
///
/// Not persisted, not thread-safety-hardened beyond a simple lock — this is
/// just a same-process handoff between "lyrics were fetched" and "the
/// overlay wants to render them," both of which happen on the main app
/// process during normal playback.
/// Holds the most recently parsed karaoke (per-syllable) lyrics, keyed by
/// Spotify track ID. SpicyLyricsRepository populates this as a side effect
/// whenever it parses a Type=="Syllable" response — it's the bridge between
/// the existing LyricsRepository protocol (which only returns flattened
/// LyricsDto, matching Spotify's native line-only protobuf schema) and the
/// custom karaoke overlay view, which needs the richer per-syllable timing
/// that LyricsDto has nowhere to carry.
///
/// Not persisted, not thread-safety-hardened beyond a simple lock — this is
/// just a same-process handoff between "lyrics were fetched" and "the
/// overlay wants to render them," both of which happen on the main app
/// process during normal playback.
final class KaraokeLyricsStore {
    static let shared = KaraokeLyricsStore()

    private let lock = NSLock()
    private var cache: [String: KaraokeLyricsDto] = [:]
    private var order: [String] = []
    private let capacity = 8

    private init() {}

    func set(trackId: String, lyrics: KaraokeLyricsDto) {
        guard !trackId.isEmpty else { return }
        lock.lock()
        cache[trackId] = lyrics
        order.removeAll { $0 == trackId }
        order.append(trackId)
        if order.count > capacity { cache[order.removeFirst()] = nil }
        lock.unlock()
        notify()
    }

    /// Drops a track's entry. Called before every fresh fetch so a result from an
    /// earlier source (or an earlier attempt) can never keep the button alive
    /// for a track whose current fetch found nothing.
    func remove(trackId: String) {
        guard !trackId.isEmpty else { return }
        lock.lock()
        let hadEntry = cache.removeValue(forKey: trackId) != nil
        order.removeAll { $0 == trackId }
        lock.unlock()
        if hadEntry { notify() }
    }

    func lyrics(forTrackId trackId: String) -> KaraokeLyricsDto? {
        lock.lock()
        defer { lock.unlock() }
        return cache[trackId]
    }

    func clear() {
        lock.lock()
        cache = [:]
        order = []
        lock.unlock()
        notify()
    }

    func notify() {
        DispatchQueue.main.async { NotificationCenter.default.post(name: .eeveeKaraokeLyricsChanged, object: nil) }
    }
}
