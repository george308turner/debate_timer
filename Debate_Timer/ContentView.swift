//
//  ContentView.swift
//  Debate_Timer
//
//  Created by George Turner on 1/28/25.
//

import SwiftUI
import AVFoundation
import AudioToolbox

struct ContentView: View {
    @State private var start_time: Date? = nil
    @State private var displayed_time: String = "00:00"
    
    @State private var timer: Timer?
    
    @State private var first_flash: Bool = false
    @State private var second_flash: Bool = false
    @State private var third_flash: Bool = false
    
    @State private var screenColor: Color = .black
    
    @AppStorage("end") private var end = 5
    @AppStorage("signal") private var signal: Signal = .flash
    
    var body: some View {
        VStack {
            Spacer()
            if start_time != nil {
                Text("\(displayed_time)")
                    .font(.largeTitle)
                    .foregroundStyle(screenColor == .white ? .black : .white)
            } else {
                Text("Stopped")
                    .font(.largeTitle)
            }
            Spacer()
            Button {
                if start_time != nil {
                    start_time = nil
                    timer = nil
                    first_flash = false
                    second_flash = false
                } else {
                    start_time = Date()
                    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { _ in
                        updateTimer()
                    })
                }
            } label: {
                Text(start_time == nil ? "Start" : "Stop")
                    .padding(.all)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .foregroundStyle(start_time == nil ? Color.blue : Color.red)
                    )
            }
            Spacer()
            HStack {
                Text("Length: ")
                Picker("Length", selection: $end) {
                    Text("5").tag(5)
                    Text("7").tag(7)
                }.tint(Color.white)
            }
            Spacer()
            HStack {
                Spacer()
                Picker("Alert Type", selection: $signal) {
                    ForEach(Signal.allCases) { signalHolder in
                        Text("\(signalHolder.name)").tag(signalHolder)
                    }
                }.tint(Color.white)
                Spacer()
                Button {
                    flash()
                    vibrate_sound()
                } label: {
                    Text("Test Alert").foregroundStyle(timer == nil ? .white : .gray)
                }.disabled(timer != nil)
                Spacer()

            }

            Spacer()
        }
        .padding()
        .foregroundStyle(Color.white)
        .background(
            screenColor
                .ignoresSafeArea()
                .scaledToFill()
        )
        .onAppear(perform: {
            UIApplication.shared.isIdleTimerDisabled = true
        })
    }
    func updateTimer() {
        if let start_time {
            let time_interval = start_time.timeIntervalSinceNow
            let mins = Int(abs(time_interval) / 60)
            let secs = Int(abs(time_interval.truncatingRemainder(dividingBy: 60)))
            displayed_time = "\(mins):\(secs < 10 ? "0" : "")\(secs)"
            
            if mins == 1 && !first_flash {
                flash()
                vibrate_sound()
                first_flash = true
            }
            if mins == (end-1) && !second_flash {
                flash()
                vibrate_sound()
                second_flash = true
            }
            if mins >= end {
                if secs > 0 && !third_flash {
                    flash()
                    vibrate_sound()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                        flash()
                    })
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
                        flash()
                    })
                    third_flash = true
                } else if secs > 15 {
                    flash()
                    vibrate_sound()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: {
                        flash()
                    })
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
                        flash()
                    })
                    timer = nil
                    first_flash = false
                    second_flash = false
                    self.start_time = nil
                }
            }
        }
    }
    func flash() {
        // Do flash
        toggleTorch(on: true)
        screenColor = .white
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
            // Stop flash
            toggleTorch(on: false)
            screenColor = .black
        })
    }
    
    func vibrate_sound() {
        if signal == .vibrate || signal == .sound {
            Vibration.error.vibrate()
        }
        
        if signal == .sound {
            AudioServicesPlaySystemSound(1009)
        }
    }
    
    func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("Torch is not available on this device")
            return
        }

        if device.hasTorch {
            do {
                try device.lockForConfiguration() // Lock the device for configuration
                device.torchMode = on ? .on : .off // Turn torch on or off
                device.unlockForConfiguration()   // Unlock the device
            } catch {
                print("Torch could not be used: \(error)")
            }
        } else {
            print("Torch is not supported on this device")
        }
    }
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
}

enum Vibration {
        case error
        case success
        case warning
        case light
        case medium
        case heavy
        @available(iOS 13.0, *)
        case soft
        @available(iOS 13.0, *)
        case rigid
        case selection
        case oldSchool

        public func vibrate() {
            switch self {
            case .error:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .warning:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .light:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .medium:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .heavy:
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case .soft:
                if #available(iOS 13.0, *) {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            case .rigid:
                if #available(iOS 13.0, *) {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
            case .selection:
                UISelectionFeedbackGenerator().selectionChanged()
            case .oldSchool:
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }

#Preview {
    ContentView()
}
