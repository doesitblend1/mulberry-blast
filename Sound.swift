import AVFoundation

final class Sound {
    static let shared = Sound()
    private var players: [String: AVAudioPlayer] = [:]
    private let muteKey = "mulberryblast.muted"
    var muted: Bool {
        get { UserDefaults.standard.bool(forKey: muteKey) }
        set { UserDefaults.standard.set(newValue, forKey: muteKey) }
    }

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for n in ["place", "clear", "combo", "perfect", "gameover", "tap"] {
            if let url = Bundle.main.url(forResource: n, withExtension: "wav"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay(); players[n] = p
            }
        }
    }

    func play(_ name: String) {
        guard !muted, let p = players[name] else { return }
        p.currentTime = 0
        p.play()
    }
}
