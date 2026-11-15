//
//  PopoverConfirm.swift
//  CueFlow
//
//  Created by 김나현 on 11/15/26.
//
// 기존
//  삭제처럼 되돌릴 수 없는 일을 하기 전에 묻는 팝오버 (시스템 알림창 대신 앱 팝오버 모양)
//  쓰는 법: .appPopover(isPresented: …) { PopoverConfirm(title: "…", message: "…") { 지우기 } }
// 바꿀 코드
//  삭제처럼 되돌릴 수 없는 일을 하기 전에 묻는 확인 창 (시스템 알림창 대신 앱 팝오버 모양)
//  화면 가운데에 뒤를 어둡게 하고 띄운다. 쓰는 법: showConfirm(ConfirmRequest(title:message:onConfirm:))

import SwiftUI

struct PopoverConfirm: View {
    let title: String
    let message: String
    var confirmTitle = "삭제"
    var onCancel: () -> Void = {}
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appBody.weight(.semibold))
                .foregroundStyle(Color.neutral900)
            Text(message)
                .font(.appCallout)
                .foregroundStyle(Color.neutral500)
                .fixedSize(horizontal: false, vertical: true)   // 길면 줄바꿈
            buttons
                .padding(.top, 8)
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button("취소", action: onCancel)
                .buttonStyle(CancelButtonStyle())
            Button(confirmTitle, action: onConfirm)
            .buttonStyle(DestructiveButtonStyle())
        }
        .frame(height: 32)
    }
}

// 빨간 글자 + 연빨강 배경 + 빨간 테두리 (프로젝트 설정 "프로젝트 삭제하기"와 같은 색)
private struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appBody.weight(.semibold))
            .foregroundStyle(Color.error)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.errorSubtle.opacity(configuration.isPressed ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.error, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

// 확인 창 취소 버튼: tertiary와 같은 바탕 + 회색 테두리 neutral300
private struct CancelButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appBody)
            .foregroundStyle(Color.neutral900)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.neutral300, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }

    private func background(isPressed: Bool) -> Color {
        if isPressed { return .neutral100 }
        return colorScheme == .dark ? .neutral25 : .windowBackground   // tertiary와 같음
    }
}

extension String {
    // 목적격 조사: 받침 있으면 "을", 없으면 "를" (한글로 안 끝나면 "을(를)")
    var objectParticle: String {
        guard let last = unicodeScalars.last, (0xAC00...0xD7A3).contains(last.value) else { return "을(를)" }
        return (last.value - 0xAC00) % 28 == 0 ? "를" : "을"
    }
}

// 화면 가운데 확인 창 (뒤를 어둡게). 어디서든 showConfirm(…)으로 띄움
// 맨 바깥(ContentView)에 .confirmHost($confirmRequest)를 한 번 붙여 둔다
struct ConfirmRequest {
    let title: String
    let message: String
    var confirmTitle = "삭제"
    let onConfirm: () -> Void
}

// 쓰는 법: @Environment(\.showConfirm) private var showConfirm → showConfirm(ConfirmRequest(…))
struct ShowConfirmAction {
    let show: (ConfirmRequest) -> Void
    func callAsFunction(_ request: ConfirmRequest) { show(request) }
}

extension EnvironmentValues {
    @Entry var showConfirm = ShowConfirmAction(show: { _ in })
}

extension View {
    func confirmHost(_ request: Binding<ConfirmRequest?>) -> some View {
        environment(\.showConfirm, ShowConfirmAction { request.wrappedValue = $0 })
            .overlay {
                if let current = request.wrappedValue {
                    ConfirmOverlay(request: current) { request.wrappedValue = nil }
                }
            }
    }
}

// 뒤를 어둡게 + 가운데 확인 창. 바깥을 누르면 닫힘
private struct ConfirmOverlay: View {
    let request: ConfirmRequest
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)   // 단축키 안내창과 같은 어둡기
                .ignoresSafeArea()
                .onTapGesture { close() }
            PopoverConfirm(title: request.title, message: request.message,
                           confirmTitle: request.confirmTitle, onCancel: close) {
                close()
                request.onConfirm()
            }
            .popoverStyle()
        }
        .ignoresSafeArea()   // 툴바까지 포함한 창 전체 기준으로 정중앙
    }
}

#Preview {
    PopoverConfirm(title: "무대를 삭제하시겠습니까?", message: "이 파트의 큐도 함께 지워져요. 되돌릴 수 없어요.") {}
        .popoverStyle()
        .padding(60)
}
