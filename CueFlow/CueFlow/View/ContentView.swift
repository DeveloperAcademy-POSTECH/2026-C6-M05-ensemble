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
    @Environment(ICloudAccount.self) private var iCloudAccount

    // 받은 초대. 있으면 사이드바 없이 초대 수락 화면만 보인다.
    // 초대 링크로 앱이 열리면 ShareInvites.shared.pending에 들어온다 (이 값은 미리보기용)
    @State private var pendingInvite: PendingInvite?
    private var shareInvites = ShareInvites.shared

    private var invite: PendingInvite? { shareInvites.pending ?? pendingInvite }

    // 초대를 수락한 공연. 있으면 사이드바 없이 역할 선택 화면만 보인다
    @State private var roleProductionID: UUID?

    // 저장된 공연 전부. 최근에 수정한 순서.
    @Query(sort: \Production.updatedAt, order: .reverse)
    private var productions: [Production]

    init(pendingInvite: PendingInvite? = nil) {
        _pendingInvite = State(initialValue: pendingInvite)
    }

    var body: some View {
        Group {
            if let invite {
                InviteAcceptView(invite: invite) {
                    // 수락 → 나도 공연 참여자가 된다. 공연은 CloudSync가 받아 와서 홈에 뜨고, 나는 멤버로 들어간다
                    if let metadata = invite.metadata {
                        Task {
                            do {
                                try await CloudShare.accept(metadata)
                            } catch {
                                print("초대 수락 실패: \(error)")
                            }
                        }
                    }
                    shareInvites.pending = nil
                    pendingInvite = nil
                    // 수락하면 열려 있던 화면을 닫고 → 역할 선택 (공연 id를 모르면 바로 홈으로)
                    rehearsingProduction = nil
                    openedProduction = nil
                    isCreatingProduction = false
                    selectedMenu = .project
                    roleProductionID = invite.productionID
                }
            } else if let roleProductionID {
                InviteRoleView(
                    productionID: roleProductionID,
                    onPrevious: { self.roleProductionID = nil },   // 역할을 안 고르고 홈으로
                    onDone: {
                        self.roleProductionID = nil
                        openedProduction = $0   // 고르면 그 공연 큐시트 열기
                    }
                )
            } else if let rehearsingProduction {
                RehearsalView(production: rehearsingProduction) {
                    self.rehearsingProduction = nil   // 종료하면 들어오기 전 화면(홈 또는 큐시트)으로
                }
            } else {
                mainView
                    // iCloud 로그인 안 된 맥이면 화면 맨 위에 안내 띠
                    .safeAreaInset(edge: .top, spacing: 0) {
                        ICloudStatusBanner(status: iCloudAccount.status)
                    }
                    .task {
                        UserTest.insertSampleIfNeeded(into: modelContext, isEmpty: productions.isEmpty)
                    }
            }
        }
        // UT 진행자 메뉴로 예시 공연을 넣거나 전부 지우면 → 열린 화면을 닫고 홈으로
        .onReceive(NotificationCenter.default.publisher(for: UserTest.didResetNotification)) { _ in
            rehearsingProduction = nil
            openedProduction = nil
            isCreatingProduction = false
            selectedMenu = .project
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: InviteRoleView.fakeAcceptNotification)) { _ in
            startFakeInvite()
        }
        #endif
    }

    #if DEBUG
    // 개발용 "가짜 초대 수락": 역할 선택 화면을 띄우고, 2초 뒤 테스트용 공연이 "도착"한다
    // (진짜 초대처럼 "받아 오는 중" → 역할 선택 순서로 보이게). 진짜 공연은 건드리지 않는다
    private func startFakeInvite() {
        let production = Production(title: "초대 테스트 공연", genre: "뮤지컬", firstShowDate: .now)
        rehearsingProduction = nil
        openedProduction = nil
        isCreatingProduction = false
        selectedMenu = .project
        roleProductionID = production.id

        Task {
            try? await Task.sleep(for: .seconds(2))
            modelContext.insert(production)
            for part in Part.makeDefaultParts() {
                part.production = production
            }
            // 초대받은 사람 = 나 (진짜 초대에선 CloudShare가 넣어 준다)
            let me = Member(name: "나 (테스트)", role: "")
            me.iCloudUserID = iCloudAccount.userRecordName
            me.production = production
            try? modelContext.save()
        }
    }
    #endif

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
            SidebarView(
                selectedMenu: menuSelection,
                productions: productions,
                isInProduction: selectedMenu == .project && openedProduction != nil,
                onOpenProduction: { production in
                    // 사이드바 큐시트 목록에서 공연을 고르면 어느 화면에 있든 그 공연 큐시트로
                    selectedMenu = .project
                    isCreatingProduction = false
                    openedProduction = production
                }
            )
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
                    .id(openedProduction.id)   // 사이드바에서 다른 공연으로 바로 옮기면 화면 상태(파트 필터 등)를 새로
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
        .environment(ICloudAccount())
}

#Preview("프로젝트 있음") {
    ContentView()
        .modelContainer(HomePreviewData.container)
        .environment(ICloudAccount())
}

#Preview("초대 받음") {
    ContentView(pendingInvite: PendingInvite(productionTitle: "별이 빛나는 밤 뮤지컬"))
        .modelContainer(HomePreviewData.container)
        .environment(ICloudAccount())
}
