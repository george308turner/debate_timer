//
//  MenuView.swift
//  Debate_Timer
//
//  Created by George Turner on 5/18/26.
//

import SwiftUI

struct MenuView: View {
    @State private var debateTimer = DebateTimer()
    var body: some View {
        TabView {
            Tab {
                TimerView(debateTimer: debateTimer)
            } label: {
                Label("Timer", systemImage: "clock")
            }
            
            Tab {
                Settings(debateTimer: debateTimer)
            } label: {
                Label("Settings", systemImage: "gear")
            }
        }.tint(.customPurple)
    }
}

#Preview {
    MenuView()
}
