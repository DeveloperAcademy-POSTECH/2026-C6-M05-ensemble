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

    // 리허설 중인 공연. 있으면 사이드바 없이 리허설 모드 화면만 보인다.
    @State private var rehearsingProduction: Production?

    // 큐시트를 열어 둔 공연. 있으면 홈 대신 메인 큐시트가 보인다. 사이드바 메뉴를 누르면 홈으로.
    @State private var openedProduction: Production?

    // 새 공연 만들기 중이면 홈 대신 셀리나의 생성 흐름(기본정보 → 파트 → 씬 → 확인 → 완료)이 보인다
    @State private var isCreatingProduction = false

    @Environment(\.modelContext) private var modelContext

    // 저장된 공연 전부. 최근에 수정한 순서.
    @Query(sort: \Production.updatedAt, order: .reverse)
    private var productions: [Production]

    var body: some View {
        if let rehearsingProduction {
            RehearsalView(production: rehearsingProduction) {
                self.rehearsingProduction = nil   // 종료하면 들어오기 전 화면(홈 또는 큐시트)으로
            }
        } else {
            mainView
                .task {
                    UserTest.insertSampleIfNeeded(into: modelContext, isEmpty: productions.isEmpty)
                }
        }
    }

    // 사이드바에서 메뉴를 누르면(같은 메뉴여도) 열어 둔 큐시트를 닫는다
    private var menuSelection: Binding<SidebarMenu> {
        Binding(
            get: { selectedMenu },
            set: {
                selectedMenu = $0
                openedProduction = nil
                isCreatingProduction = false
            }
        )
    }

    // 사이드바 + 내용 영역
    private var mainView: some View {
        NavigationSplitView {
            // 왼쪽: 사이드바
            SidebarView(selectedMenu: menuSelection)
                .navigationSplitViewColumnWidth(220)
        } detail: {
            // 오른쪽: 선택된 메뉴에 따라 다른 화면
            switch selectedMenu {
            case .project:
                if isCreatingProduction {
                    NewProjectFlow(
                        onGoHome: { isCreatingProduction = false },
                        onOpenCueSheet: {
                            isCreatingProduction = false
                            openedProduction = $0
                        }
                    )
                } else if let openedProduction {
                    MainCueSheetView(production: openedProduction) {
                        rehearsingProduction = openedProduction
                    }
                } else if productions.isEmpty {
                    HomeEmptyView(onNewProject: { isCreatingProduction = true })
                } else {
                    HomeView(
                        productions: productions,
                        onRehearsal: { rehearsingProduction = $0 },
                        onOpen: { openedProduction = $0 },
                        onNewProject: { isCreatingProduction = true }
                    )
                }
            case .notice:
                Text("공지사항 화면")
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
