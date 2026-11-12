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
    @State private var showsHomeWhenEmpty = false   // 빈 화면의 "홈으로 가기"를 눌렀으면 공연이 없어도 홈 화면
    @State private var startsLeadingRehearsal = false   // Spotlight me로 들어왔으면 리허설을 열자마자 내가 진행

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

    // iCloud 안내 띠를 ✕로 닫았는지. 앱을 다시 켜거나 iCloud 상태가 바뀌면 다시 보인다
    @State private var isICloudBannerClosed = false

    // 저장된 공연 전부. 최근에 수정한 순서.
    @Query(sort: \Production.updatedAt, order: .reverse)
    private var productions: [Production]

    // 저장된 공지 전부. 최근에 보낸 순서.
    @Query(sort: \Notice.sentAt, order: .reverse)
    private var notices: [Notice]

    // 내 목록에서 숨긴 공지(남이 보낸 공지를 삭제한 것)는 목록 · 안 읽은 숫자에서 뺀다
    // 총 연출자(공연을 만든 사람)는 그 공연의 공지를 모두 본다. 나머지는 개인 · 파트 공지를 받는 사람과 보낸 사람만 본다
    private var visibleNotices: [Notice] {
        let myID = iCloudAccount.userRecordName
        return notices.filter {
            !$0.isHiddenByMe && ($0.production?.isSharedWithMe == false || $0.isSent(byUserID: myID) || $0.isForMe(userID: myID))
        }
    }

    // 시스템 알림을 눌러 연 공지 → 공지사항 상세로 (#103)
    @State private var noticeToOpen: Notice?
    // 공지 목록 위에 열어 둔 상세 · 쓰기 화면. 메뉴를 바꿀 때 먼저 닫으려고 여기서 가진다 (#144)
    @State private var openedNotice: Notice?
    @State private var isComposingNotice = false
    @State private var cueFocus: SystemNotifications.CueFocus?   // 큐 수정 알림을 눌렀을 때 큐시트가 찾아갈 큐들

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
                    switchMenu(to: .project)
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
                RehearsalView(production: rehearsingProduction, startsLeading: startsLeadingRehearsal) {
                    self.rehearsingProduction = nil   // 종료하면 들어오기 전 화면(홈 또는 큐시트)으로
                }
                .onDisappear { startsLeadingRehearsal = false }
            } else {
                mainView
                    .onChange(of: iCloudAccount.status) {
                        isICloudBannerClosed = false
                    }
                    .task {
                        UserTest.insertSampleIfNeeded(into: modelContext, isEmpty: productions.isEmpty)
                    }
            }
        }
        // 다른 사람이 보낸 새 공지 · 내 파트 큐 수정이 iCloud로 오면 맥 시스템 알림 (#103)
        .onReceive(NotificationCenter.default.publisher(for: CloudSync.didReceiveNoticesNotification)) { notification in
            notifyNotices(notification.object as? [UUID] ?? [])
        }
        .onReceive(NotificationCenter.default.publisher(for: CloudSync.didReceiveCueChangesNotification)) { notification in
            notifyCueChanges(notification.object as? [UUID] ?? [])
        }
        // 알림을 누르면 그 공지 / 그 공연 큐시트로
        .onReceive(NotificationCenter.default.publisher(for: SystemNotifications.openNotification)) { notification in
            open(notification.object as? SystemNotifications.Target)
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: SystemNotifications.fakeNoticeNotification)) { _ in
            showFakeNotice()
        }
        .onReceive(NotificationCenter.default.publisher(for: SystemNotifications.fakeCueChangeNotification)) { _ in
            showFakeCueChange()
        }
        #endif
        // UT 진행자 메뉴로 예시 공연을 넣거나 전부 지우면 → 열린 화면을 닫고 홈으로
        .onReceive(NotificationCenter.default.publisher(for: UserTest.didResetNotification)) { _ in
            rehearsingProduction = nil
            openedProduction = nil
            isCreatingProduction = false
            switchMenu(to: .project)
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
        switchMenu(to: .project)
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

    // 공지 상세 · 쓰기가 위에 쌓인 채로 메뉴를 바꾸면 오른쪽 화면이 안 바뀐다 (#144)
    // → 쌓인 화면을 먼저 닫고, 잠깐 뒤에 메뉴를 바꾼다
    private func switchMenu(to menu: SidebarMenu) {
        let hadNoticeOnTop = openedNotice != nil || isComposingNotice
        openedNotice = nil
        isComposingNotice = false
        guard hadNoticeOnTop, menu != selectedMenu else {
            selectedMenu = menu
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            selectedMenu = menu
        }
    }

    // 사이드바에서 메뉴를 누르면(같은 메뉴여도) 열어 둔 큐시트를 닫는다
    private var menuSelection: Binding<SidebarMenu> {
        Binding(
            get: { selectedMenu },
            set: {
                switchMenu(to: $0)
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
                    switchMenu(to: .project)
                    isCreatingProduction = false
                    openedProduction = production
                },
                // 공지 목록 "안읽음" 숫자와 같은 기준 (내가 보낸 건 읽은 것으로)
                unreadNoticeCount: visibleNotices.filter { $0.isUnread(byUserID: iCloudAccount.userRecordName) }.count
            )
                .navigationSplitViewColumnWidth(220)
        } detail: {
            detailView
                // iCloud 로그인 안 된 맥 · 아이패드면 오른쪽 내용 영역 맨 위에 안내 카드 (✕로 닫을 수 있음)
                // 사이드바까지 덮으면 어색해서 내용 영역에만
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !isICloudBannerClosed {
                        ICloudStatusBanner(status: iCloudAccount.status) {
                            isICloudBannerClosed = true
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
        }
    }

    // 오른쪽: 선택된 메뉴에 따라 다른 화면
    @ViewBuilder
    private var detailView: some View {
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
                    MainCueSheetView(
                        production: openedProduction,
                        cueFocus: $cueFocus,
                        onRehearsal: { rehearsingProduction = openedProduction },
                        onSpotlight: {
                            startsLeadingRehearsal = true
                            rehearsingProduction = openedProduction
                        }
                    )
                    .id(openedProduction.id)   // 사이드바에서 다른 공연으로 바로 옮기면 화면 상태(파트 필터 등)를 새로
                } else if productions.isEmpty && !showsHomeWhenEmpty {
                    HomeEmptyView(
                        onGoHome: { showsHomeWhenEmpty = true },
                        onNewProject: { isCreatingProduction = true }
                    )
                } else {
                    HomeView(
                        productions: productions,
                        onRehearsal: { rehearsingProduction = $0 },
                        onOpen: { openedProduction = $0 },
                        onNewProject: { isCreatingProduction = true }
                    )
                }
            case .notice:
                // NavigationStack: 목록 → 상세로 들어갔다가 뒤로 돌아올 수 있게
                NavigationStack {
                    NoticeListView(
                        notices: visibleNotices,
                        openRequest: $noticeToOpen,
                        openedNotice: $openedNotice,
                        isComposing: $isComposingNotice
                    )
                }
            case .help:
                Text("도움말 화면")
            }
    }
}

// 새 공지 · 내 파트 큐 수정 → 맥 시스템 알림 (#103 · 피그마 951:11334 · 951:11335)

extension ContentView {
    // 막 들어온 공지 중 다른 사람이 보낸 · 나한테 온 · 안 읽은 · 10분 안에 보낸 것
    // (10분: 새 맥에서 처음 받을 때 예전 공지가 줄줄이 뜨지 않게)
    private func notifyNotices(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let myID = iCloudAccount.userRecordName
        let received = (try? modelContext.fetch(FetchDescriptor<Notice>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        received
            .filter {
                Date.now.timeIntervalSince($0.sentAt) < 10 * 60
                    && !$0.isSent(byUserID: myID) && $0.isForMe(userID: myID) && !$0.isRead(byUserID: myID)
            }
            .forEach(SystemNotifications.shared.notifyNotice)
    }

    // 다른 사람이 고친 큐 중 내 파트 것만 (CloudSync가 다른 사람 · 10분 안 것만 골라 보냄)
    // 파트가 없는 사람(공연 만든 사람 · 감독 등)은 모든 파트의 큐 수정을 받는다
    private func notifyCueChanges(_ ids: [UUID]) {
        guard !ids.isEmpty, let myID = iCloudAccount.userRecordName else { return }
        let cues = (try? modelContext.fetch(FetchDescriptor<Cue>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        let mine = cues.filter { cue in
            guard let part = cue.part, let production = cue.trigger?.scene?.production else { return false }
            let myParts = production.member(withUserID: myID)?.parts ?? []
            return myParts.isEmpty || myParts.contains(part)
        }
        SystemNotifications.shared.notifyCueChanges(mine)
    }

    #if DEBUG
    // 가장 최근에 연 공연에 "다른 사람(테스트)"이 보낸 전체 공지를 하나 넣고 알림을 띄운다.
    // iCloud에서 온 것처럼 조건(다른 사람 · 나한테 옴 · 안 읽음)을 그대로 거친다 — 실제로 공지 목록에도 남고 iCloud에도 올라간다
    private func showFakeNotice() {
        guard let production = productions.max(by: { $0.lastOpenedAt < $1.lastOpenedAt }) else { return }
        let sender = (production.members ?? []).first { $0.iCloudUserID == "fake-sender" } ?? {
            let member = Member(name: "테스트", role: "무대감독")
            modelContext.insert(member)
            member.iCloudUserID = "fake-sender"
            member.production = production
            return member
        }()
        let notice = Notice(title: "오늘 리허설 콜타임 변경 안내", body: "18:40으로 변경되었습니다. 지금 확인하고 큐시트 변경 사항을 놓치지 마세요.")
        modelContext.insert(notice)
        notice.production = production
        notice.author = sender
        try? modelContext.save()
        notifyNotices([notice.id])
    }

    // 지금 연 공연(없으면 가장 최근에 연 공연)에서 앞 장면 4개의 큐를 누가 고친 척 (내 파트인지는 안 따짐). 3초 뒤에 파트마다 알림이 뜬다
    // 한 번 누르면 "여러 장면" 문구, 장면이 하나뿐인 공연이면 "지금 수정되었습니다" 문구. 앞 장면 4개에 큐가 없으면 알림 없음
    private func showFakeCueChange() {
        guard let production = openedProduction ?? productions.max(by: { $0.lastOpenedAt < $1.lastOpenedAt }) else { return }
        let cues = (production.scenes ?? [])
            .sorted { $0.order < $1.order }
            .prefix(4)
            .flatMap { ($0.triggers ?? []).flatMap { $0.cues ?? [] } }
            .filter { $0.part != nil }
        SystemNotifications.shared.notifyCueChanges(cues)
    }
    #endif

    // 알림을 누르면 → 공지면 공지사항 상세, 큐 수정이면 그 공연 큐시트에서 수정된 큐로
    private func open(_ target: SystemNotifications.Target?) {
        switch target {
        case .notice(let id):
            if let notice = notices.first(where: { $0.id == id }) { openNotice(notice) }
        case .cues(let focus):
            guard let production = productions.first(where: { $0.id == focus.productionID }) else { return }
            rehearsingProduction = nil
            isCreatingProduction = false
            switchMenu(to: .project)
            openedProduction = production
            cueFocus = focus
        case nil:
            break
        }
    }

    // 리허설 · 큐시트에 있어도 공지사항으로 가서 그 공지를 연다
    private func openNotice(_ notice: Notice) {
        rehearsingProduction = nil
        openedProduction = nil
        isCreatingProduction = false
        selectedMenu = .notice
        noticeToOpen = notice
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
