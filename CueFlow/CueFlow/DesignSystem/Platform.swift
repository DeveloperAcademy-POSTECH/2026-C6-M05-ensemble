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

// 글자 크기 (#157). 맥은 시스템 크기 그대로, 아이패드는 피그마 iPad처럼 "맥 크기 × 0.9365".
// 피그마 iPad 화면(1194 × 834)은 맥 디자인을 93.65%로 줄인 것 (26→24.35, 13→12.18, 20→18.73).
// .body · .title3 같은 이름은 아이패드에서 훨씬 커져서(본문 13 → 17) 대신 .appBody · .appTitle3을 쓴다.
// 숫자로 정한 크기도 .system(size:) 대신 .app(size:)를 쓴다.
extension Font {
    #if os(macOS)
    static let iPadScale: CGFloat = 1
    #else
    static let iPadScale: CGFloat = 0.9365
    #endif

    static func app(size: CGFloat, weight: Font.Weight? = nil, design: Font.Design? = nil) -> Font {
        .system(size: size * iPadScale, weight: weight, design: design)
    }

    // 맥 기본 크기(포인트): largeTitle 26 · title 22 · title2 17 · title3 15 · headline 13 굵게
    // subheadline 11 · body 13 · callout 12 · footnote 10 · caption 10 · caption2 10
    #if os(macOS)
    static var appLargeTitle: Font { .largeTitle }
    static var appTitle: Font { .title }
    static var appTitle2: Font { .title2 }
    static var appTitle3: Font { .title3 }
    static var appHeadline: Font { .headline }
    static var appSubheadline: Font { .subheadline }
    static var appBody: Font { .body }
    static var appCallout: Font { .callout }
    static var appFootnote: Font { .footnote }
    static var appCaption: Font { .caption }
    static var appCaption2: Font { .caption2 }
    #else
    static var appLargeTitle: Font { .app(size: 26) }
    static var appTitle: Font { .app(size: 22) }
    static var appTitle2: Font { .app(size: 17) }
    static var appTitle3: Font { .app(size: 15) }
    static var appHeadline: Font { .app(size: 13, weight: .bold) }
    static var appSubheadline: Font { .app(size: 11) }
    static var appBody: Font { .app(size: 13) }
    static var appCallout: Font { .app(size: 12) }
    static var appFootnote: Font { .app(size: 10) }
    static var appCaption: Font { .app(size: 10) }
    static var appCaption2: Font { .app(size: 10) }
    #endif
}
