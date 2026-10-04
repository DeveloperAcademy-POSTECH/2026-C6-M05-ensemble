//
//  ContentView.swift
//  CueFlow
//
//  Created by yunseo on 10/4/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainCueView()
    }
}

#Preview {
    ContentView()
        .environment(CueStore.sample())
}
