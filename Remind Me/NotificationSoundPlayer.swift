import Foundation
import AVFoundation
import AudioToolbox

final class NotificationSoundPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = NotificationSoundPlayer()

    private var player: AVAudioPlayer?
    private var lastPlayDate: Date?
    private let throttleInterval: TimeInterval = 0.8

    private let userDefaults = UserDefaults.standard

    private override init() {
        super.init()
    }

    private func currentInAppSoundKey() -> String {
        return userDefaults.string(forKey: "settings.inAppSound") ?? "default"
    }

    func playReminderSound() {
        let now = Date()
        if let last = lastPlayDate, now.timeIntervalSince(last) < throttleInterval {
            return
        }

        let key = currentInAppSoundKey()

        if key == "none" {
            // Do not play any sound and do not update lastPlayDate
            return
        }

        // Prefer a bundled file for any non-none selection so it plays in silent mode
        if let url = bundledSoundURL(forKey: key) {
            lastPlayDate = now
            playSound(at: url) // Uses AVAudioSession .playback to ignore silent switch
            return
        }

        // If no bundled file is present, fall back to system sounds (these obey silent mode)
        switch key {
        case "triTone":
            lastPlayDate = now
            AudioServicesPlaySystemSound(1002) // Tri-tone
            return
        case "bell":
            lastPlayDate = now
            AudioServicesPlaySystemSound(1013) // Bell
            return
        case "default":
            lastPlayDate = now
            AudioServicesPlaySystemSound(1013) // Bell
            return
        default:
            // No bundled sound and no matching key, fallback to default system sound
            lastPlayDate = now
            AudioServicesPlaySystemSound(1007) // SMS received
            return
        }
    }

    private func bundledSoundURL(forKey key: String) -> URL? {
        let candidates: [String]
        switch key {
        case "default":
            candidates = ["bell", "default"]
        case "triTone":
            candidates = ["tritone", "tri_tone", "tri-tone"]
        case "bell":
            candidates = ["bell"]
        default:
            candidates = []
        }
        let exts = ["caf", "wav", "mp3"]
        for name in candidates {
            for ext in exts {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }
        return nil
    }

    private func playSound(at url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [])

            let player = try AVAudioPlayer(contentsOf: url)
            self.player = player
            player.delegate = self
            player.prepareToPlay()
            player.play()
        } catch {
            // If anything fails, fall back to a system sound
            AudioServicesPlaySystemSound(1007)
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignore deactivation errors
        }
    }
}

