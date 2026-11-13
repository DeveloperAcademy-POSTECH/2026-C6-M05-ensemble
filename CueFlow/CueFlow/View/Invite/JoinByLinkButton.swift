//
//  JoinByLinkButton.swift
//  CueFlow
//
//  [링크로 참여] — 카톡 등으로 받은 초대 링크를 붙여 넣어 공연에 참여한다.
//  카톡 안 브라우저에서 링크를 누르면 앱이 아니라 iCloud 웹페이지로 가서 만듦.
//  붙여 넣으면 ShareInvites가 초대를 받아 오고 → ContentView가 초대 수락 화면을 띄운다 (링크로 열렸을 때와 같은 흐름).
//  TODO: 피그마에 아직 없는 버튼 → 디자인 나오면 모양 맞추기
//

import SwiftUI

struct JoinByLinkButton: View {
    @State private var isAsking = false
    @State private var link = ""
    @State private var isChecking = false
    @State private var errorText: String?

    var body: some View {
        Button {
            link = ""
            isAsking = true
        } label: {
            if isChecking {
                ProgressView()
            } else {
                Label("링크로 참여", systemImage: "link")
            }
        }
        .buttonStyle(.secondary)
        .disabled(isChecking)
        .alert("초대 링크로 참여", isPresented: $isAsking) {
            TextField("https://www.icloud.com/share/…", text: $link)
                .autocorrectionDisabled()
            Button("취소", role: .cancel) {}
            Button("참여") { join() }
        } message: {
            Text("카카오톡 등에서 받은 초대 링크를 복사해서 붙여 넣어 주세요.")
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

    private func join() {
        isChecking = true
        Task {
            errorText = await ShareInvites.shared.join(link: link)
            isChecking = false
        }
    }
}

#Preview {
    JoinByLinkButton()
        .frame(width: 200, height: 40)
        .padding()
}
