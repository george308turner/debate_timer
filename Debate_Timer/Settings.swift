//
//  Settings.swift
//  Debate_Timer
//
//  Created by George Turner on 5/19/26.
//

import SwiftUI

struct Settings: View {
    @Bindable var debateTimer: DebateTimer
    var body: some View {
        VStack {
            HStack {
                Text("Settings").font(.largeTitle)
                    .foregroundStyle(.white)
                Spacer()
            }
            
            Picker("Length", selection: $debateTimer.length) {
                Text("5 minutes").tag(5)
                Text("7 minutes").tag(7)
            }.pickerStyle(.palette)
                .colorMultiply(.white)
                .padding(.all)
                .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(.white.opacity(0.8)))
                
            
            ForEach(settings, id: \.title) { setting in
                
                Toggle(setting.title, isOn: setting.binding)
                    .padding(.all)
                    .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(.white.opacity(0.8)))
            }
            
            Spacer()
        }
        .safeAreaPadding(.all)
        .background()
        .backgroundStyle(.black)
        .foregroundStyle(.black)
    }
    
    private var settings: [(title: String, binding: Binding<Bool>)] {
            [
                ("Flash", $debateTimer.flashEnabled),
                ("Vibration", $debateTimer.vibrationEnabled),
                ("Sound", $debateTimer.soundEnabled)
            ]
        }
}

#Preview {
    Settings(debateTimer: DebateTimer())
}
