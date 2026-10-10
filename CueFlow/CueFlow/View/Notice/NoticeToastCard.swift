//
//  NoticeToastCard.swift
//  CueFlow
//
//  새 공지가 왔을 때 띄우는 작은 알림 카드 (피그마 리허설공지).
//  TODO: 팀원 공유가 생기면 다른 사람이 보낸 새 공지가 올 때 띄우기 (지금은 모양만)
//

import SwiftUI

struct NoticeToastCard: View {
    let title: String       // 예: "오늘 리허설 콜타임 변경 안내"
    let preview: String     // 내용 앞부분 (두 줄까지)
    let onDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("전체 공지")
                    .font(.caption)
                    .foregroundStyle(Color.brandPrimaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandPrimarySubtle, in: Capsule())

                Text(title)
                    .font(.title3.bold())
                    .lineLimit(1)
            }

            Text(preview)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("공지 자세히 보기", action: onDetail)
                    .buttonStyle(.primary)
                    .frame(width: 118, height: 34)
            }
        }
        .padding(20)
        .frame(width: 381)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

#Preview {
    NoticeToastCard(
        title: "오늘 리허설 콜타임 변경 안내",
        preview: "18:40으로 변경되었습니다. 지금 확인하고 큐시트 변경 사항을 놓치지 마세요.",
        onDetail: {}
    )
    .padding(40)
}
