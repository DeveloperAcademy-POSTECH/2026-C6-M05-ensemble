//
//  SplashView.swift
//  CueFlow
//
//  Created by 김나현 on 11/15/26.
//
//  앱을 켜고 iCloud 상태를 확인하는 동안 보여주는 화면 (#189)
//

import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 15) {
            Image("SplashIcon")
                .resizable()
                .frame(width: 42.946, height: 41.587)
            Image("SplashLogo")
                .resizable()
                .frame(width: 169.482, height: 41.547)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // 창 가운데
        .background(background.ignoresSafeArea())
    }

    // 라이트 neutral25 #FCFCFD / 다크 appBackground #1E1E1E (한 토큰으로 둘 다 맞는 게 없어서 나눔)
    private var background: Color {
        colorScheme == .dark ? .appBackground : .neutral25
    }
}

#Preview("라이트") {
    SplashView()
        .frame(width: 1512, height: 932)
        .preferredColorScheme(.light)
}

#Preview("다크") {
    SplashView()
        .frame(width: 1512, height: 932)
        .preferredColorScheme(.dark)
}
