//
//  NoticeDetailView.swift
//  CueFlow
//
//  받은 공지 상세 화면 (피그마 공지사항_03).
//  TODO: 카드 아래 다른 공지 접힌 목록 — 동작 방식 팀 확인 후
//

import SwiftUI

struct NoticeDetailView: View {
    let notice: Notice

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("받은 공지")
                    .font(.largeTitle.bold())

                card
            }
            .frame(maxWidth: 1000, alignment: .leading)
            .padding(40)
        }
    }

    // 공지 내용이 들어가는 큰 카드
    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 보낼 대상 태그: 전체공지 / 조명 공지 / 개인 공지
            Text(notice.targetTag)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandPrimaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.brandPrimarySubtle, in: Capsule())

            Text(notice.title)
                .font(.title.bold())

            infoRow(label: "프로젝트", value: notice.productionTitle)
            infoRow(label: "보낸사람", value: notice.senderName)

            Text(notice.sentDateDetailText)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 8)

            Text(notice.body)
                .lineSpacing(6)
                .textSelection(.enabled)   // 본문 글자를 드래그해서 복사할 수 있게
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    // "프로젝트  별마루" 처럼 이름표 + 값
    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.body.weight(.semibold))
                .frame(width: 60, alignment: .leading)
            Text(value)
        }
    }
}

#Preview {
    NoticeDetailView(notice: NoticePreviewData.samples[0])
        .frame(width: 1290, height: 930)
}
