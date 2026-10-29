//
//  NoticeListView.swift
//  CueFlow
//
//  Created by yunseo on 10/10/26.
//

import SwiftData
import SwiftUI

// 목록 위 필터 버튼 종류
enum NoticeFilter: String, CaseIterable {
    case all = "전체"
    case unread = "안읽음"
    case important = "중요"
}

struct NoticeListView: View {
    let notices: [Notice]   // 최근에 보낸 순서로 들어온다
    var openRequest: Binding<Notice?> = .constant(nil)   // 알림 카드 [공지 자세히 보기] → 이 공지 상세로 (#82)

    @Environment(\.modelContext) private var modelContext
    @State private var filter: NoticeFilter = .all
    @State private var isComposing = false   // true가 되면 쓰기 화면으로 이동
    @State private var openedNotice: Notice?  // 누른 공지 (상세로 이동)
    @State private var checkedIDs: Set<UUID> = []   // 체크박스로 고른 공지 (삭제용)

    // 고른 필터에 맞는 공지
    private var filteredNotices: [Notice] {
        switch filter {
        case .all:
            notices
        case .unread:
            notices.filter { $0.isUnread(byUserID: ICloudAccount.currentUserRecordName) }
        case .important:
            notices.filter { $0.isImportant }
        }
    }

    // 필터 버튼 옆 숫자
    private func count(of item: NoticeFilter) -> Int {
        switch item {
        case .all: notices.count
        case .unread: notices.filter { $0.isUnread(byUserID: ICloudAccount.currentUserRecordName) }.count
        case .important: notices.filter { $0.isImportant }.count
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                HStack {
                    filterBar
                    Spacer()
                    deleteButton
                }
                .padding(.bottom, 7)

                ForEach(filteredNotices) { notice in
                    NoticeRow(
                        title: notice.title,
                        preview: notice.body,           // 공지 "내용" 칸
                        sentDate: notice.sentDateText,
                        sender: notice.senderName,            // Notice+List에서 만든 것
                        isStarred: notice.isImportant,
                        isChecked: checkedIDs.contains(notice.id),
                        onToggleStar: { notice.isImportant.toggle() },
                        onToggleCheck: { toggleCheck(notice) },
                        onOpen: { openedNotice = notice }
                    )
                    .padding(.vertical, 16)
                    Divider()
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 42)
            .padding(.bottom, 40)
        }
        // openedNotice에 공지가 들어오면 상세 화면으로 이동
        .navigationDestination(item: $openedNotice) { notice in
            NoticeDetailView(notice: notice, notices: filteredNotices)
        }
        .navigationDestination(isPresented: $isComposing) {
            NoticeComposeView()
        }
        .onChange(of: openRequest.wrappedValue, initial: true) { _, notice in
            guard let notice else { return }
            openedNotice = notice
            openRequest.wrappedValue = nil
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
                isComposing = true
            } label: {
                Label("작성하기", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.primary)
            .frame(width: 126, height: 34)
        }
        .padding(.bottom, 33)
    }

    // 체크한 공지 지우기. 체크한 게 없으면 흐리게
    // TODO: 남이 쓴 공지도 지울 수 있게 할지 (작성자만? 감독만?) 정하기
    private var deleteButton: some View {
        Button("삭제") {
            for notice in notices where checkedIDs.contains(notice.id) {
                modelContext.delete(notice)
            }
            checkedIDs.removeAll()
        }
        .buttonStyle(.plain)
        .font(.title3)
        .foregroundStyle(Color.neutral500)
        .disabled(checkedIDs.isEmpty)
    }

    private func toggleCheck(_ notice: Notice) {
        if checkedIDs.contains(notice.id) {
            checkedIDs.remove(notice.id)
        } else {
            checkedIDs.insert(notice.id)
        }
    }

    // 전체 / 안읽음 / 중요 알약 버튼. 선택된 것은 보라 배경.
    private var filterBar: some View {
        HStack(spacing: 5) {
            ForEach(NoticeFilter.allCases, id: \.self) { item in
                let isSelected = (filter == item)

                Button {
                    filter = item
                } label: {
                    HStack(spacing: 8) {
                        Text(item.rawValue)
                        Text("\(count(of: item))")
                            .foregroundStyle(Color.brandPrimaryText)   // .primary는 바깥 흰 글자를 따라가서 안 보였음
                            .frame(width: 22, height: 22)
                            .background(isSelected ? Color.neutral25 : Color.brandPrimarySubtle, in: Circle())
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.neutral25 : Color.brandPrimaryText)
                    .padding(.leading, 14)
                    .padding(.trailing, 10)
                    .frame(height: 36)
                    .background(isSelected ? Color.brandPrimaryHover : Color.neutral25, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(isSelected ? Color.clear : Color.brandPrimaryHover, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NoticeListView(notices: NoticePreviewData.samples)
    }
    .frame(width: 1290, height: 930)
}
