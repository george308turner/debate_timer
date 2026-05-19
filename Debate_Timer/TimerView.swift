//
//  TimerView.swift
//  Debate_Timer
//
//  Created by George Turner on 5/18/26.
//

import SwiftUI
import AVFoundation

struct TimerView: View {
    @Bindable var debateTimer = DebateTimer()

    var body: some View {
        VStack(alignment: .center) {
            Text("\(debateTimer.length) min Timer")
                .font(.largeTitle)
            Spacer()
            ZStack(alignment: .bottomTrailing) {
                RingProgressView(
                    progress: debateTimer.timeElapsed / debateTimer.end,
                    timeText: debateTimer.formattedTime,
                    dot1Progress: debateTimer.poiOpen / debateTimer.end,
                    dot2Progress: debateTimer.poiClose / debateTimer.end
                )
                
                Button {
                    debateTimer.testAlert()
                } label: {
                    VStack {
                        Image(systemName: "bell.circle")
                            .font(.title)
                        Text("Test").font(.caption2)
                    }
                }
                .padding(.all)
            }
            Spacer()
            
            ControlsView(debateTimer: debateTimer)
                .frame(height: 100)
        }   .safeAreaPadding(.all)
            .background()
            .foregroundStyle(.white)
            .backgroundStyle(debateTimer.whiteScreen ? .white : .black)
            .onChange(of: debateTimer.isRunning) { _, isRunning in
                UIApplication.shared.isIdleTimerDisabled = isRunning
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }
}

struct ControlsView: View {
    @Bindable var debateTimer: DebateTimer
    var body: some View {
        HStack(spacing: 5) {
            ControlButton(debateTimer: debateTimer, type: debateTimer.isRunning ? .stop : .start)
            ControlButton(debateTimer: debateTimer, type: .reset)
        }
    }
}

struct ControlButton: View {
    @Bindable var debateTimer: DebateTimer
    var type: ControlType
    
    var body: some View {
        Button {
            switch (type) {
            case .start:
                debateTimer.start()
            case .stop:
                debateTimer.stop()
            case .reset:
                debateTimer.reset()
            }
        } label: {
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    switch (type) {
                    case .start:
                        Image(systemName: "play.fill").font(.title)
                        Text("Start").font(.caption2)
                    case .stop:
                        Image(systemName: "stop.fill").font(.title)
                        Text("Stop").font(.caption2)
                    case .reset:
                        Image(systemName: "arrow.counterclockwise").font(.title)
                        Text("Reset").font(.caption2)
                    }
                    Spacer()
                }
                Spacer()
            }
            .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(.customPurple))
        }
    }
}

struct RingProgressView: View {
    let progress: Double
    let timeText: String
    
    let dot1Progress: Double // 0.0 to 1.0
    let dot2Progress: Double // 0.0 to 1.0

    var body: some View {
        ZStack {
            // Background ring basic
            Circle()
                .stroke(
                    .white.opacity(0.2),
                    style: StrokeStyle(lineWidth: 30, lineCap: .round)
                )
            // Background ring poi
            Circle()
                .trim(from: dot1Progress, to: dot2Progress)
                .stroke(
                    .white.opacity(0.3),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    .customPurple,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center time
            Text(timeText)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(20)
    }
}
@MainActor
@Observable
class DebateTimer {
    var timeStarted: Date?
    var timeBeforePause: TimeInterval = TimeInterval(0)
    var signalStatus: SignalStatus = .none
    
    private var codeTimer: Timer?
        
    // Length in mins (either 5 or 7)
    var length: Int = UserDefaults.standard.object(forKey: "debatelength") as? Int ?? 5 {
        didSet {
            UserDefaults.standard.set(length, forKey: "debatelength")
        }
    }
    
    var poiOpen: TimeInterval {
        // POI Opens 1 min after start
        return TimeInterval(60)
    }
    
    var poiClose: TimeInterval {
        // POI Closes 1 min before end
        return TimeInterval((length-1) * 60)
    }
    
    var end: TimeInterval {
        return TimeInterval(length * 60)
    }
    
    var isRunning: Bool {
        timeStarted != nil
    }
    
    private var privateTimeElapsed: TimeInterval {
        guard let timeStarted else {
            return timeBeforePause
        }
        return Date().timeIntervalSince(timeStarted) + timeBeforePause
    }
    
    var timeElapsed: TimeInterval = 0
    
    private var privateFormattedTime: String {
        let totalSeconds = Int(privateTimeElapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(format: "%01d:%02d", minutes, seconds)
    }
    
    // Updates every second
    var formattedTime: String = ""
    
    // When set to true background of screen goes white
    var whiteScreen: Bool = false
    
    var flashEnabled: Bool = UserDefaults.standard.object(forKey: "flashEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(flashEnabled, forKey: "flashEnabled")
        }
    }
    
    var vibrationEnabled: Bool = UserDefaults.standard.object(forKey: "vibrationEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(vibrationEnabled, forKey: "vibrationEnabled")
        }
    }
    
    var soundEnabled: Bool = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }
    
    init() {
        codeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { _ in
            Task { @MainActor in
                self.update()
            }
        })
        
        do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Audio session error: \(error.localizedDescription)")
            }
    }
    
    func update() {
        if privateTimeElapsed >= poiOpen && signalStatus == .none {
            alert(.single)
            signalStatus = .alertPOIOpen
        }
        if privateTimeElapsed >= poiClose && signalStatus == .alertPOIOpen {
            alert(.single)
            signalStatus = .alertPOIClosed
            
        }
        if privateTimeElapsed >= end && signalStatus == .alertPOIClosed {
            alert(.double)
            signalStatus = .end
        }
        
        if privateTimeElapsed >= end.advanced(by: 15) && signalStatus == .end {
            alert(.quadruple)
            signalStatus = .overtimeEnd
        }
        
        if signalStatus == .overtimeEnd {
            timeStarted = nil
            timeElapsed = end
        } else {
            // Update the time shown
            timeElapsed = privateTimeElapsed
        }
        
        formattedTime = privateFormattedTime
    }
    
    func start() {
        if !isRunning {
            timeStarted = Date()
        }
    }
    
    func stop() {
        if isRunning {
            timeBeforePause = privateTimeElapsed
            timeStarted = nil
        }
    }
    
    func reset() {
        timeBeforePause = 0
        timeStarted = nil
        signalStatus = .none
    }
    
    private func alert(_ signalLength: SignalLength) {
        if flashEnabled {
            Signal.flash.play(signalLength, screenFlashFunction: self.flashScreen)
        }
        if vibrationEnabled {
            Signal.vibrate.play(signalLength)
        }
        if soundEnabled {
            Signal.sound.play(signalLength)
        }
    }
    
    func testAlert() {
        alert(.double)
    }
    
    func flashScreen() {
        whiteScreen = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
            Task { @MainActor in
                self.whiteScreen = false
            }
        })
    }
}

enum ControlType {
    case start
    case stop
    case reset
}

enum SignalStatus {
    case alertPOIOpen
    case alertPOIClosed
    case end
    case overtimeEnd
    case none
}

enum SignalLength {
    case single, double, quadruple
}

enum Signal: String, Codable, CaseIterable, Identifiable {
    case flash, vibrate, sound
    
    var name: String {
        switch self {
        case .flash: return "Flash"
        case .vibrate: return "Vibrate"
        case .sound: return "Sound"
        }
    }
    
    var id: Self { return self }
    
    public func play(_ level: SignalLength, screenFlashFunction: (() -> Void)? = nil) {
        switch (self) {
        case .flash:
            switch (level) {
            case .single:
                flashTorch()
                (screenFlashFunction ?? {})()
                
            case .double:
                flashTorch()
                (screenFlashFunction ?? {})()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                    flashTorch()
                    (screenFlashFunction ?? {})()
                })
            case .quadruple:
                flashTorch()
                (screenFlashFunction ?? {})()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                    flashTorch()
                    (screenFlashFunction ?? {})()
                })
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
                    flashTorch()
                    (screenFlashFunction ?? {})()
                })
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: {
                    flashTorch()
                    (screenFlashFunction ?? {})()
                })
            }
        case .vibrate:
            switch (level) {
            case .single:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .double:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                })
        case .quadruple:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            })
        }
        case .sound:
            switch (level) {
            case .single:
                playSoundFile("single")
            case .double:
                playSoundFile("double")
            case .quadruple:
                playSoundFile("quad")
            }
        }
    }
}

func flashTorch() {
    setTorch(true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
        setTorch(false)
    })
}

func setTorch(_ on: Bool) {
    guard let device = AVCaptureDevice.default(for: .video),
          device.hasTorch
    else {
        NSLog("Torch Not Available")
        return
    }

    do {
        try device.lockForConfiguration()
        
        device.torchMode = on ? .on : .off
        
        device.unlockForConfiguration()
    } catch {
        NSLog("Torch could not be used: \(error)")
    }
}

var audio_player: AVAudioPlayer?
func playSoundFile(_ filename: String) {
    if let soundURL = Bundle.main.url(forResource: filename, withExtension: "mp3") {
        do {
            audio_player = try AVAudioPlayer(contentsOf: soundURL)
            audio_player?.volume = 1.0  // Max volume
            audio_player?.prepareToPlay()
            audio_player?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    } else {
        print("Sound file not found")
    }
}

#Preview {
    TimerView()
}
