//
//  ContentView.swift
//  CueFlow
//
//  앱의 가장 바깥 틀. 왼쪽 사이드바 + 오른쪽 내용 영역.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // 지금 선택된 메뉴. 앱을 켜면 "프로젝트"가 선택된 상태로 시작한다.
    @State private var selectedMenu: SidebarMenu = .project

    // 저장된 공연 전부. 최근에 수정한 순서.
    @Query(sort: \Production.updatedAt, order: .reverse)
    private var productions: [Production]

    // 저장된 공지 전부. 최근에 보낸 순서.
    @Query(sort: \Notice.sentAt, order: .reverse)
    private var notices: [Notice]

    var body: some View {
        NavigationSplitView {
            // 왼쪽: 사이드바
            SidebarView(selectedMenu: $selectedMenu)
                .navigationSplitViewColumnWidth(220)
        } detail: {
            // 오른쪽: 선택된 메뉴에 따라 다른 화면
            switch selectedMenu {
            case .project:
                if productions.isEmpty {
                    HomeEmptyView()
                } else {
                    HomeView(productions: productions)
                }
            case .notice:
                // NavigationStack: 목록 → 상세로 들어갔다가 뒤로 돌아올 수 있게
                NavigationStack {
                    NoticeListView(notices: notices)
                }
            case .help:
                Text("도움말 화면")
            }
        }
    }
}

#Preview("프로젝트 없음") {
    ContentView()
        .modelContainer(for: Production.self, inMemory: true)
}

#Preview("프로젝트 있음") {
    ContentView()
        .modelContainer(HomePreviewData.container)
}
