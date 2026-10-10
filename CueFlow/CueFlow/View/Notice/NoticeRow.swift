//
//  NoticeRow.swift
//  CueFlow
//
//  Created by yunseo on 10/10/26.
//

import SwiftUI

struct NoticeRow: View {
    let title: String        // 예: "오늘 리허설 콜타임 변경 안내"
    let preview: String      // 내용 앞부분
    let sentDate: String     // 예: "9월 28일"
    let sender: String       // 예: "Rami"
    let isImportant: Bool

    var body: some View {
        HStack(spacing: 20) {
            // 체크박스 (아직 기능 없음, 팀 결정 전)
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(.secondary, lineWidth: 1.5)
                .frame(width: 26, height: 26)

            Divider()
                .frame(height: 54)

            // 보낸 사람 첫 글자 동그라미
            Text(String(sender.prefix(1)))
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Color(nsColor: .quaternarySystemFill), in: Circle())

            // 제목 + 미리보기 (위아래로 쌓기)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.body.weight(.semibold))

                    if isImportant {
                        Text("중요")
                            .font(.caption.weight(.semibold))      // 작은 글씨
                            .foregroundStyle(.white)               // 흰 글자
                            .padding(.horizontal, 8)               // 좌우 여백
                            .padding(.vertical, 3)                 // 위아래 여백
                            .background(Color.brandPrimary, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(preview)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 0) {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                Text(sentDate)
                    .frame(width: 140, alignment: .leading)
                Text(sender)
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.body)
            .padding(.trailing, 20)
        }
        .lineLimit(1)
    }
}

#Preview {
    NoticeRow(
        title: "오늘 리허설 콜타임 변경 안내",
        preview: "오늘 19:00 예정이던 리허설 콜타임이 18:40으로 변경되었습니다",
        sentDate: "9월 28일",
        sender: "Rami",
        isImportant: true
    )
    .frame(width: 1200)
    .padding()
}
