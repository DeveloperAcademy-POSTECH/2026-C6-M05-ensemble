//
//  NoticeListView.swift
//  CueFlow
//
//  Created by yunseo on 10/10/26.
//

import SwiftUI

// 목록 위 필터 버튼 종류
enum NoticeFilter: String, CaseIterable {
    case all = "전체"
    case unread = "안읽음"
    case important = "중요"
}

struct NoticeListView: View {
    let notices: [Notice]   // 최근에 보낸 순서로 들어온다

    @State private var filter: NoticeFilter = .all

    // 고른 필터에 맞는 공지
    private var filteredNotices: [Notice] {
        switch filter {
        case .all:
            notices
        case .unread:
            notices   // TODO: "나"를 알게 되면 내 읽음 기록이 없는 공지만
        case .important:
            notices.filter { $0.isImportant }
        }
    }

    // 필터 버튼 옆 숫자
    private func count(of item: NoticeFilter) -> Int {
        switch item {
        case .all: notices.count
        case .unread: 0   // TODO: 위와 같이
        case .important: notices.filter { $0.isImportant }.count
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                filterBar
                    .padding(.bottom, 20)

                ForEach(filteredNotices) { notice in
                    NoticeRow(
                        title: notice.title,
                        preview: notice.body,           // 공지 "내용" 칸
                        sentDate: notice.sentDateText,
                        sender: notice.senderName,            // Notice+List에서 만든 것
                        isImportant: notice.isImportant
                    )
                    .padding(.vertical, 14)
                    Divider()
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 37)
            .padding(.bottom, 40)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            PageHeader(
                title: "공지사항",
                subtitle: "프로젝트의 공지사항과 멤버 간의 중요한 메시지를 확인할 수 있습니다."
            )

            Spacer()

            Button {
                // TODO: 공지 쓰기 화면으로 이동
            } label: {
                Label("작성하기", systemImage: "plus")
            }
            .buttonStyle(.primary)
            .frame(width: 125, height: 40)
        }
        .padding(.bottom, 30)
    }

    // 전체 / 안읽음 / 중요 알약 버튼. 선택된 것은 보라 배경.
    private var filterBar: some View {
        HStack(spacing: 5) {
            ForEach(NoticeFilter.allCases, id: \.self) { item in
                let isSelected = (filter == item)

                Button {
                    filter = item
                } label: {
                    HStack(spacing: 10) {
                        Text(item.rawValue)
                            .font(.body.weight(.semibold))
                        Text("\(count(of: item))")
                            .font(.caption2.bold())
                            .foregroundStyle(isSelected ? Color.brandPrimary : .white)
                            .frame(width: 24, height: 24)
                            .background(isSelected ? Color.white.opacity(0.6) : Color.brandPrimary, in: Circle())
                    }
                    .foregroundStyle(isSelected ? .white : Color.brandPrimaryText)
                    .padding(.leading, 10)
                    .padding(.trailing, 6)
                    .frame(height: 36)
                    .background(isSelected ? Color.brandPrimary : Color.clear, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.brandPrimary, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NoticeListView(notices: NoticePreviewData.samples)
        .frame(width: 1290, height: 930)
}
