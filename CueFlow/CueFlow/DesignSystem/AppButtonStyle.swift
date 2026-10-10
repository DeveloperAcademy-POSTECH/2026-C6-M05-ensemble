//
//  AppButtonStyle.swift
//  CueFlow
//
//  자주 쓰는 버튼 모양 2가지. 크기는 쓰는 곳에서 .frame으로 정한다.
//  사용법: Button("새 프로젝트") { }.buttonStyle(.primary).frame(width: 200, height: 40)
//

import SwiftUI

// 보라 배경 + 흰 글자 (예: 새 프로젝트, 리허설 모드)
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                configuration.isPressed ? Color.brandPrimaryPressed : Color.brandPrimary,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

// 흰 배경 + 보라 테두리 + 보라 글자 (예: 홈으로 가기, 이어서 작업하기)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(Color.brandPrimaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                configuration.isPressed ? Color.brandPrimarySubtle : Color(nsColor: .windowBackgroundColor),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.brandPrimary, lineWidth: 1)
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
