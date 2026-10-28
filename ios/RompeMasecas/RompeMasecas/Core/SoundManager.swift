import AVFoundation
import Observation

/// Efectos de sonido (archivos en /Sounds, todos originales).
enum SFX: String, CaseIterable {
    case tap, pickup, start, tick, beep, go, wrong, win, record, timeout
    case tickUrgent = "tick_urgent"
}

/// Musica en loop.
enum Music: String, CaseIterable {
    case menu = "music_menu"
    case game = "music_game"
}

/// Reproduce musica y efectos. Ajustes guardados en UserDefaults (panel admin).
@Observable
final class SoundManager {
    static let shared = SoundManager()

    var sfxOn: Bool { didSet { save(); if !sfxOn { stopAllSFX() } } }
    var musicOn: Bool { didSet { save(); musicOn ? resumeMusic() : stopMusicNow() } }
    var sfxVolume: Float { didSet { save() } }
    var musicVolume: Float { didSet { save(); applyMusicVolume() } }

    @ObservationIgnored private var sfxPlayers: [String: AVAudioPlayer] = [:]
    @ObservationIgnored private var musicPlayers: [Music: AVAudioPlayer] = [:]
    @ObservationIgnored private var currentMusic: Music?
    @ObservationIgnored private var wantedMusic: Music?

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "snd.sfxOn": true, "snd.musicOn": true,
            "snd.sfxVolume": 0.9, "snd.musicVolume": 0.5
        ])
        sfxOn = d.bool(forKey: "snd.sfxOn")
        musicOn = d.bool(forKey: "snd.musicOn")
        sfxVolume = d.float(forKey: "snd.sfxVolume")
        musicVolume = d.float(forKey: "snd.musicVolume")

        // Todo el arranque de audio (sesion + carga de sonidos) va fuera del hilo
        // principal: activar la sesion o preparar reproductores puede trabar la UI.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // .playback: suena aunque el iPad este en silencio.
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)

            var sfx: [String: AVAudioPlayer] = [:]
            let names = SFX.allCases.map(\.rawValue) + (1...9).map { "correct_\($0)" }
            for name in names {
                guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                      let p = try? AVAudioPlayer(contentsOf: url) else { continue }
                p.prepareToPlay()
                sfx[name] = p
            }

            var music: [Music: AVAudioPlayer] = [:]
            for m in Music.allCases {
                guard let url = Bundle.main.url(forResource: m.rawValue, withExtension: "wav"),
                      let p = try? AVAudioPlayer(contentsOf: url) else { continue }
                p.numberOfLoops = -1
                p.enableRate = true
                p.prepareToPlay()
                music[m] = p
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.sfxPlayers = sfx
                self.musicPlayers = music
                // Si una pantalla pidio musica antes de terminar de cargar, arrancarla ya.
                if let pending = self.wantedMusic, self.currentMusic == nil {
                    self.playMusic(pending)
                }
            }
        }
    }

    // MARK: - Efectos

    func play(_ sfx: SFX) {
        play(name: sfx.rawValue)
    }

    /// Pieza correcta: sube de tono con cada pieza (1...9).
    func playCorrect(_ count: Int) {
        play(name: "correct_\(min(max(count, 1), 9))")
    }

    private func play(name: String) {
        guard sfxOn, let p = sfxPlayers[name] else { return }
        p.volume = sfxVolume
        p.currentTime = 0
        p.play()
    }

    private func stopAllSFX() {
        sfxPlayers.values.forEach { $0.stop() }
    }

    // MARK: - Musica

    /// Cambia la musica con fade. nil = silencio.
    func playMusic(_ music: Music?, fade: TimeInterval = 0.6) {
        wantedMusic = music
        guard music != currentMusic else { return }

        if let current = currentMusic, let p = musicPlayers[current] {
            p.setVolume(0, fadeDuration: fade)
            DispatchQueue.main.asyncAfter(deadline: .now() + fade) { [weak self] in
                if self?.currentMusic != current { p.stop() }
            }
        }
        currentMusic = nil

        guard musicOn, let music, let p = musicPlayers[music] else { return }
        p.rate = 1.0
        p.currentTime = 0
        p.volume = 0
        p.play()
        p.setVolume(musicVolume, fadeDuration: fade)
        currentMusic = music
    }

    /// Acelera la musica (ultimos segundos del juego).
    func setMusicRate(_ rate: Float) {
        guard let current = currentMusic, let p = musicPlayers[current] else { return }
        p.rate = rate
    }

    private func resumeMusic() {
        let m = wantedMusic
        wantedMusic = nil
        playMusic(m, fade: 0.3)
    }

    private func stopMusicNow() {
        musicPlayers.values.forEach { $0.stop() }
        currentMusic = nil
    }

    private func applyMusicVolume() {
        guard let current = currentMusic else { return }
        musicPlayers[current]?.volume = musicVolume
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(sfxOn, forKey: "snd.sfxOn")
        d.set(musicOn, forKey: "snd.musicOn")
        d.set(sfxVolume, forKey: "snd.sfxVolume")
        d.set(musicVolume, forKey: "snd.musicVolume")
    }
}
