//
//  ClipboardInviteCheck.swift
//  CueFlow
//
//  아이패드: 카톡에서 초대 링크를 복사하고 앱을 열면 "참여할까요?"를 묻는다 (#166).
//  카톡 안 브라우저에선 iCloud 초대 링크를 눌러도 앱이 안 열려서, 복사만 하면 되게.
//
//  - 복사한 내용을 바로 읽지 않는다. 읽으면 iOS가 "붙여넣기 허용?" 창을 매번 띄워서.
//    링크처럼 보이는 게 있는지만 확인하고(창 안 뜸) → 사람이 [참여]를 누를 때 읽는다.
//  - 같은 복사에는 한 번만 묻는다 (changeCount로 구분).
//  - 맥은 안 쓴다: 공유하기 창에서 [링크 복사]한 주인에게도 물어보게 돼서.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    func clipboardInviteCheck() -> some View {
        #if os(iOS)
        modifier(ClipboardInviteCheck())
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct ClipboardInviteCheck: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAsking = false
    @State private var errorText: String?

    // 이미 물어본 복사 (앱을 다시 열어도 같은 복사엔 다시 안 묻게)
    @AppStorage("clipboardInvite.handledChangeCount") private var handledChangeCount = -1

    func body(content: Content) -> some View {
        content
            .onAppear { check() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { check() }
            }
            .alert("복사한 초대 링크로 참여할까요?", isPresented: $isAsking) {
                Button("나중에", role: .cancel) {}
                Button("참여") { join() }
            } message: {
                Text("방금 복사한 링크가 Cuedit 공연 초대 링크라면 바로 참여할 수 있어요.")
            }
            .alert(
                "참여하지 못했어요",
                isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
    }

    private func check() {
        let pasteboard = UIPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != handledChangeCount,
              ShareInvites.shared.pending == nil else { return }

        // 링크처럼 보이는 게 있는지만 확인 (내용은 안 읽어서 "붙여넣기 허용?" 창이 안 뜬다)
        pasteboard.detectPatterns(for: [.probableWebURL]) { result in
            guard case .success(let patterns) = result, patterns.contains(.probableWebURL) else { return }
            Task { @MainActor in
                handledChangeCount = changeCount
                isAsking = true
            }
        }
    }

    private func join() {
        // 여기서 처음 읽는다 → iOS가 "붙여넣기 허용?"을 물을 수 있다
        let pasteboard = UIPasteboard.general
        let text = pasteboard.url?.absoluteString ?? pasteboard.string ?? ""
        Task {
            errorText = await ShareInvites.shared.join(link: text)
        }
    }
}
#endif
