//
//  NoticeToastCard.swift
//  CueFlow
//
//  새 공지가 왔을 때 띄우는 작은 알림 카드 (피그마 951:7387 리허설공지).
//  다른 사람이 보낸, 나한테 온, 아직 안 읽은 공지가 iCloud로 오면 창 오른쪽 위에 뜬다 (#82 · ContentView).
//

import SwiftUI

struct NoticeToastCard: View {
    #if DEBUG
    // 메뉴 막대 "개발용 → 가짜 새 공지" → ContentView가 공지를 하나 넣고 카드를 띄운다
    static let fakeNoticeNotification = Notification.Name("NoticeToastCard.fakeNotice")
    #endif

    var tag = "전체 공지"   // 예: "전체 공지" / "조명 공지" / "개인 공지"
    let title: String       // 예: "오늘 리허설 콜타임 변경 안내"
    let preview: String     // 내용 앞부분 (두 줄까지)
    let onDetail: () -> Void

    var body: some View {
        // 피그마: 흰 바탕 · 모서리 8 · 안쪽 25 · 폭 381. 태그 11 / 제목 17 굵게 / 내용 13 / 버튼 13
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text(tag)
                    .font(.subheadline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .frame(height: 24)
                    .background(Color.brandPrimarySubtle, in: Capsule())

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.black)
                    .lineLimit(1)
            }

            Text(preview)
                .font(.body)
                .lineSpacing(2)   // 피그마 줄 높이 18
                .foregroundStyle(Color.neutral800)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(action: onDetail) {
                    Text("공지 자세히 보기")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 118, height: 30)
                        .background(Color.brandPrimary, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(25)
        .frame(width: 381, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        // 화면 위에 떠 있어서 그림자 (팀 팝오버와 같은 값)
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.popoverBorder, lineWidth: 0.5))
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
