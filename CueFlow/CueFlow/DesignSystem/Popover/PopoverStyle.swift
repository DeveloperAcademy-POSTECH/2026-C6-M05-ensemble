//
//  PopoverStyle.swift
//  CueFlow
//
//  Created by 김나현 on 10/29/26.
//

import SwiftUI

// 팝오버 배경 두 종류 (피그마 Popover 섹션)
enum PopoverBackground {
    case input     // 입력 팝오버: Neutral/25 (큐카드 입력 · 씬 · 파트 추가 · 우클릭 메뉴 · 댓글)
    case display   // 보기 팝오버: 흰색 70% (확인현황 · 참여자현황 · 파트 입력)

    var color: Color {
        switch self {
        case .input: Color.neutral25
        case .display: Color.white.opacity(0.7)
        }
    }
}

extension View {
    // 팝오버 겉모양: 패딩 20 · 모서리 10 · 회색 테두리 0.5 · 아래로 퍼지는 그림자 (피그마 Y 18, 흐림 48, 검정 25%)
    // width: 피그마 폭 (240이 가장 많음). nil이면 내용만큼
    func popoverStyle(width: CGFloat? = 240, background: PopoverBackground = .input) -> some View {
        self
            .padding(20)
            .frame(width: width, alignment: .leading)
            .background(background.color.shadow(.drop(color: .black.opacity(0.25), radius: 24, y: 18)), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.popoverBorder, lineWidth: 0.5))   // 테두리 DBDBDB (에셋 popoverBorder)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        Text("트리거")
        TextField("", text: .constant("")).popoverInputStyle()
    }
    .popoverStyle()
    .padding(60)
}
