//
//  AppButtonStyle.swift
//  CueFlow
//
//  자주 쓰는 버튼 모양 4가지 (primary · secondary · softPrimary · tertiary/tertiaryFilled). 크기는 쓰는 곳에서 .frame으로 정한다.
//  사용법: Button("새 프로젝트") { }.buttonStyle(.primary).frame(width: 200, height: 40)
//

import SwiftUI

// 보라 배경 + 흰 글자 (예: 새 프로젝트, 작성하기). 못 누를 때는 연보라 바탕 + 보라 글자 (예: 대본 입력 "다음")
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration)
    }

    // 못 누르는 상태(.disabled)는 View 안에서만 읽을 수 있어서 따로 뺀다
    private struct PrimaryButton: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.body.weight(.semibold))
                .foregroundStyle(isEnabled ? Color.white : Color.buttonDisabledText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }

        private var background: Color {
            if !isEnabled { return .buttonDisabledBackground }
            return configuration.isPressed ? .brandPrimaryPressed : .brandPrimary
        }
    }
}

// 흰 배경 + 보라 테두리 + 보라 글자 (예: 홈으로 가기)
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(Color.brandPrimaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                configuration.isPressed ? Color.brandPrimarySubtle : (colorScheme == .dark ? Color.neutral25 : Color.windowBackground),   // 다크 Dark/Button #2C2C2E
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.brandPrimary, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

// 연한 보라 배경 + 흰 글자 (예: 최근 프로젝트 카드의 리허설 모드)
struct SoftPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(Color.softActionText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                configuration.isPressed ? Color.brandPrimary : Color.brandPrimarySoft,   // 피그마 #9188FF
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

// 흰 배경 + 연보라 테두리 + 진한 글자 (예: 최근 프로젝트 카드의 이어서 작업하기)
// isFilled = true: 리허설 "다음 큐"
//   라이트 = 아주 연한 보라 바탕 #E4E2FF + 보라 테두리 + 진한 글자
//   다크 = 연보라 바탕 #C1BCFF + 검은 글자 #141414, 테두리 없음 (피그마 2426:24472)
struct TertiaryButtonStyle: ButtonStyle {
    var isFilled = false
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkFilled: Bool { isFilled && colorScheme == .dark }

    private func background(isPressed: Bool) -> Color {
        if isDarkFilled {
            return isPressed ? Color.brandPrimary : Color.brandPrimarySoft   // 다크 #C1BCFF
        }
        if isFilled {
            return isPressed ? Color.brandPrimarySoft.opacity(0.4) : Color.brandPrimarySubtle   // 라이트 #E4E2FF
        }
        return isPressed ? Color.neutral100 : (colorScheme == .dark ? Color.neutral25 : Color.windowBackground)   // 다크 Dark/Button #2C2C2E
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(isDarkFilled ? Color.softActionText : Color.neutral900)   // 다크 #141414
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isDarkFilled ? Color.clear : Color.brandPrimaryHover, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

// .buttonStyle(.primary), .buttonStyle(.secondary)로 짧게 쓰기 위한 것
extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == SoftPrimaryButtonStyle {
    static var softPrimary: SoftPrimaryButtonStyle { SoftPrimaryButtonStyle() }
}

extension ButtonStyle where Self == TertiaryButtonStyle {
    static var tertiary: TertiaryButtonStyle { TertiaryButtonStyle() }
    static var tertiaryFilled: TertiaryButtonStyle { TertiaryButtonStyle(isFilled: true) }
}
