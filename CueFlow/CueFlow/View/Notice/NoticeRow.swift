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
    let isStarred: Bool      // 별표(중요) 여부
    let onToggleStar: () -> Void
    let onOpen: () -> Void   // 줄을 누르면 상세로

    var body: some View {
        HStack(spacing: 20) {
            // 체크박스 (보류 — 삭제용이 될 가능성 높음)
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(.secondary, lineWidth: 1.5)
                .frame(width: 20, height: 20)

            // 별표: 누르면 중요 켜기/끄기
            Button(action: onToggleStar) {
                Image(systemName: isStarred ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(isStarred ? Color.brandPrimary : Color.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(isStarred ? "중요 해제" : "중요 표시")

            // 별표·체크박스를 뺀 나머지 부분을 누르면 상세로 이동
            Button(action: onOpen) {
                HStack(spacing: 20) {
                    // 보낸 사람 첫 글자 동그라미
                    Text(String(sender.prefix(1)))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color(nsColor: .quaternarySystemFill), in: Circle())

                    // 제목 + 미리보기 (위아래로 쌓기)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.body.weight(.semibold))
                        Text(preview)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 0) {
                        Text(sentDate)
                            .frame(width: 140, alignment: .leading)
                        Text(sender)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.body)
                    .padding(.trailing, 20)
                }
                .contentShape(Rectangle())   // 글자 없는 빈 곳을 눌러도 이동
            }
            .buttonStyle(.plain)
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
        isStarred: true,
        onToggleStar: {},
        onOpen: {}
    )
    .frame(width: 1200)
    .padding()
}
