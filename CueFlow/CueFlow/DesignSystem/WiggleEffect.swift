//
//  WiggleEffect.swift
//  CueFlow
//
//  Created by 김나현 on 10/29/26.
//

import SwiftUI

struct WiggleEffect: ViewModifier {
    func body(content: Content) -> some View {
        // 매 화면마다 다시 그려서 계속 흔들리게 한다
        TimelineView(.animation) { context in
            content
                .rotationEffect(angle(at: context.date))
        }
    }

    // 왼쪽 6도 ↔ 오른쪽 6도를 0.3초에 한 번씩 오간다
    private func angle(at date: Date) -> Angle {
        .degrees(sin(date.timeIntervalSinceReferenceDate * 21) * 6)
    }
}

extension View {
    func wiggle() -> some View {
        modifier(WiggleEffect())
    }
}
