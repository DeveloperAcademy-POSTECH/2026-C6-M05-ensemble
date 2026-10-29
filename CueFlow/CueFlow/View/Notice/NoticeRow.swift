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
    let isChecked: Bool      // 삭제하려고 체크했는지
    let onToggleStar: () -> Void
    let onToggleCheck: () -> Void
    let onOpen: () -> Void   // 줄을 누르면 상세로

    var body: some View {
        HStack(spacing: 20) {
            // 체크박스: 체크한 공지를 위의 "삭제"로 지운다
            Button(action: onToggleCheck) {
                checkbox
            }
            .buttonStyle(.plain)

            // 보낸 사람 첫 글자 동그라미
            Text(String(sender.prefix(1)))
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.neutral500)
                .frame(width: 40, height: 40)
                .background(Color.neutral100, in: Circle())

            // 제목 + 미리보기 (위아래로 쌓기)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.neutral900)
                Text(preview)
                    .foregroundStyle(Color.neutral500)
            }
            .frame(maxWidth: 370, alignment: .leading)

            Spacer()

            HStack(spacing: 60) {
                // 별표: 누르면 중요 켜기/끄기
                Button(action: onToggleStar) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.system(size: isStarred ? 15 : 14))
                        .foregroundStyle(isStarred ? Color.brandPrimaryHover : Color.neutral400)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
                .help(isStarred ? "중요 해제" : "중요 표시")

                Text(sentDate)
                    .frame(width: 60, alignment: .leading)
                Text(sender)
                    .frame(width: 60, alignment: .leading)
            }
            .foregroundStyle(Color.neutral700)
        }
        .font(.body)
        .lineLimit(1)
        .contentShape(Rectangle())   // 체크박스·별표 말고 줄 어디를 눌러도 상세로
        .onTapGesture(perform: onOpen)
    }

    private var checkbox: some View {
        RoundedRectangle(cornerRadius: 3)
            .strokeBorder(isChecked ? Color.brandPrimary : Color.neutral400, lineWidth: 2)
            .background(isChecked ? Color.brandPrimary : Color.clear, in: RoundedRectangle(cornerRadius: 3))
            .overlay {
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 20, height: 20)
            // 안쪽이 투명하면 테두리 선에만 클릭이 잡혀서 줄(상세 열기)이 눌렸다 → 네모 전체 + 둘레 조금 더
            .padding(6)
            .contentShape(Rectangle())
            .padding(-6)
    }
}

#Preview {
    NoticeRow(
        title: "오늘 리허설 콜타임 변경 안내",
        preview: "오늘 19:00 예정이던 리허설 콜타임이 18:40으로 변경되었습니다",
        sentDate: "9월 28일",
        sender: "Rami",
        isStarred: true,
        isChecked: false,
        onToggleStar: {},
        onToggleCheck: {},
        onOpen: {}
    )
    .frame(width: 1200)
    .padding()
}
