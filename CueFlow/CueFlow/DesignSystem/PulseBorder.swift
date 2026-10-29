//
//  SwiftUIView.swift
//  CueFlow
//
//  Created by 김나현 on 10/29/26.
//

import SwiftUI

struct PulseBorder: View {
    var cornerRadius: CGFloat = 10

    var body: some View {
        // 매 화면마다 다시 그려서 계속 일렁이게 한다
        TimelineView(.animation) { context in
            glow(breath: breath(at: context.date))
        }
    }
}

extension PulseBorder {
    // 흰 사각형 + 바깥 그림자를 '곱하기'로 겹치면 흰색은 안 보이고 연보라 빛만 남는다
    private func glow(breath: Double) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.white)
            .padding(-3)                                                      // 스프레드 3
            .shadow(color: Self.glowColor, radius: (10 + 8 * breath) / 2)     // 흐림 10 ~ 18 (피그마 흐림의 절반이 SwiftUI 값)
            .blendMode(.multiply)                                             // 피그마 블렌드 모드: 곱하기
    }

    // 0 ~ 1 사이를 오감 (약 2.5초에 한 번)
    private func breath(at date: Date) -> Double {
        (sin(date.timeIntervalSinceReferenceDate * 2.5) + 1) / 2
    }

    private static let glowColor = Color(red: 225 / 255, green: 211 / 255, blue: 255 / 255)   // #E1D3FF. 에셋 컬러에 없는 색이라 숫자로 직접 넣음
}
