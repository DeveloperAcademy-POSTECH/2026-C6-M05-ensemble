//
//  Platform.swift
//  CueFlow
//
//  맥 · 아이패드에서 이름이 다른 것들을 한 이름으로 (#156).
//  화면 코드에서는 #if 없이 이것만 쓴다.
//

import SwiftUI

extension Color {
    // 창 배경 (맥 windowBackgroundColor · 아이패드 systemBackground)
    static var windowBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    // 구분선 · 테두리 회색 (맥 separatorColor · 아이패드 separator)
    static var separatorLine: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }

    // 아주 옅은 회색 채우기 (스위치 바탕 등)
    static var quaternaryFill: Color {
        #if os(macOS)
        Color(nsColor: .quaternarySystemFill)
        #else
        Color(uiColor: .quaternarySystemFill)
        #endif
    }
}

extension View {
    // Esc로 닫기 · 취소. 아이패드는 키보드를 붙였을 때만
    func onEscape(perform action: @escaping () -> Void) -> some View {
        #if os(macOS)
        onExitCommand(perform: action)
        #else
        onKeyPress(.escape) {
            action()
            return .handled
        }
        #endif
    }

    // 글자만 있는 링크 모양 버튼 (맥 .link)
    func linkButtonStyle() -> some View {
        #if os(macOS)
        buttonStyle(.link)
        #else
        buttonStyle(.borderless)
        #endif
    }
}

// 아이패드는 보기 전용 (#156): 공연 만들기 · 삭제, 큐 · 파트 · 씬 추가와 편집은 맥에서만.
// 댓글 달기 · 큐 확인은 아이패드에서도 된다.
enum Platform {
    #if os(macOS)
    static let canEditCueSheet = true
    static let hasHover = true    // 마우스를 올려야 보이는 버튼은 아이패드에서 항상 보이게
    #else
    static let canEditCueSheet = false
    static let hasHover = false
    #endif
}

