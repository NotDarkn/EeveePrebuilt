import SwiftUI
import Combine

extension EeveeLyricsSettingsViewModel {
    func setupBindings() {
        $lyricsOptions
            .map(\.musixmatchLanguage)
            .sink { [weak self] language in
                guard let self = self else { return }
                
                let isValidLanguage = language.isEmpty || language ~= "^[\\w\\d]{2}$"
                
                if isValidLanguage {
                    self.showMusixmatchInvalidLanguageWarning = false
                    MusixmatchLyricsRepository.shared.selectedLanguage = language
                    return
                }
                
                self.showMusixmatchInvalidLanguageWarning = true
            }
            .store(in: &cancellables)
        
        $lyricsOptions
            .map(\.lrclibUrl)
            .map { urlString -> AnyPublisher<LrclibURLState, Never> in
                guard let url = URL(string: urlString) else {
                    return Just(.invalidURL).eraseToAnyPublisher()
                }
                
                if url.host == "lrclib.net" {
                    return Just(.originalURL).eraseToAnyPublisher()
                }
                
                return URLSession.shared.dataTaskPublisher(for: url)
                    .map { _ in
                        LrclibLyricsRepository.shared.apiUrl = urlString
                        return LrclibURLState.ok
                    }
                    .catch { _ in Just(LrclibURLState.unreachableURL) }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .assign(to: &$lrclibURLState)
        
        $musixmatchToken
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tokenString in
                guard let self = self else { return }
                
                if let token = self.getMusixmatchTokenFromDebugInfo(tokenString) {
                    self.musixmatchToken = token
                    return
                }
                
                if let token = self.getMusixmatchToken(tokenString) {
                    UserDefaults.musixmatchToken = token
                }
            }
            .store(in: &cancellables)
        
        $lyricsSource
            .dropFirst()
            .sink { [weak self] newSource in
                guard let self = self else { return }
                
                if newSource == .musixmatch && self.musixmatchToken.isEmpty {
                    // Token field is always visible in UI - no alert needed
                }
                
                if newSource == .lrclib {
                    self.lyricsOptions.lrclibUrl = LrclibLyricsRepository.originalApiUrl
                }
                
                UserDefaults.lyricsSource = newSource

                // Everything cached for the old provider (prefetch, custom lyrics
                // view data, Musixmatch cache) must go, or revisiting a song
                // would keep serving the old provider's lyrics.
                invalidateLyricsForSourceChange()

                // Spotify keeps its own copy of lyrics it already loaded, which the tweak
                // can't clear, so the new source is only used everywhere after a restart.
                if newSource != LyricsLaunchSource.value {
                    PopUpHelper.showPopUp(
                        message: "lyrics_source_restart_popup".localized,
                        buttonText: "restart_now".localized,
                        secondButtonText: "restart_later".localized,
                        onPrimaryClick: { exitApplication() }
                    )
                }
            }
            .store(in: &cancellables)
    }
}
