//
//  MainCueSheetView.swift
//  CueFlow
//
//  Created by 김나현 on 10/11/26.
//

import SwiftUI
import SwiftData

struct MainCueSheetView: View {
    let production: Production                 // 어느 공연의 큐시트인지
    var cueFocus: Binding<SystemNotifications.CueFocus?> = .constant(nil)   // 큐 수정 알림을 누르면 들어옴 → 표에 넘기고 비운다
    var onRehearsal: () -> Void = {}           // "리허설 모드" 버튼
    @State private var selectedPart: Part?     // 파트 칩에서 고른 파트 (nil = 전체)
    @State private var historyCue: Cue?        // History 사이드바에 보여줄 큐 (nil = 닫힘)
    @State private var priorityScene: ShowScene?  // 우선순위 사이드바에 보여줄 씬 (nil = 닫힘)
    @State private var isShowingParticipants = false   // 멤버 버튼 → 참여자 현황
    @State private var isShowingUnread = false
    @State private var isShowingShare = false          // 임시 초대하기 버튼 → 공유하기 창
    @State private var remoteRevision = 0              // 다른 사람이 고친 걸 받으면 +1 → 표 다시 그리기
    @State private var gridFocus: SystemNotifications.CueFocus?   // 표가 스크롤 · 선택할 큐들
    @Environment(ICloudAccount.self) private var iCloudAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
            filterRow
            CueGrid(production: production, selectedPart: selectedPart, remoteRevision: remoteRevision, onShowHistory: { historyCue = $0 }, onEscape: { isShowingUnread = false }, priorityScene: $priorityScene, focus: gridFocus)
                .padding(.top, -12)   // 위 여유(12)만큼 올려서 표 위치는 피그마 그대로
                .padding(.trailing, -35)   // 표는 바깥 여백(35)을 무시하고 창 오른쪽 끝까지
                .overlay(alignment: .trailing) { sidebar.padding(.bottom, 20).padding(.trailing, -15) }   // 사이드바는 창 오른쪽 · 아래에서 20씩 (기준이 바깥 여백 35 안쪽이라 -15)
        }
        .padding(.horizontal, 35)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appBackground)
        .appPopoverHost()   // 표 안 팝오버(파트 추가 · 수정)가 그려지는 곳
        .environment(\.myUserID, iCloudAccount.userRecordName)
        .environment(\.canEditCues, production.canEdit(userID: iCloudAccount.userRecordName))
        .onReceive(NotificationCenter.default.publisher(for: CloudSync.didApplyRemoteNotification)) { _ in
            remoteRevision += 1
        }
        // 큐시트를 보고 있는 동안 1분마다 "나 지금 보고 있음"을 남긴다 → 다른 사람 참여자 현황에 보인다
        .task(id: production.id) {
            while !Task.isCancelled {
                production.markSeen(byUserID: iCloudAccount.userRecordName)
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .onChange(of: cueFocus.wrappedValue, initial: true) { _, focus in showFocusedCues(focus) }
        .onChange(of: historyCue) { if $1 != nil { priorityScene = nil; isShowingUnread = false } }     // 사이드바는 하나만
        .onChange(of: priorityScene) { if $1 != nil { historyCue = nil; isShowingUnread = false } }
        .onChange(of: isShowingUnread) { if $1 { historyCue = nil; priorityScene = nil } }
    }
}

// 오른쪽 사이드바: History (큐 카드 우클릭) · 우선순위 (씬 열 ⓝ) · 미확인 수정사항

extension MainCueSheetView {
    @ViewBuilder
    private var sidebarContent: some View {
        if let historyCue {
            CueHistorySidebar(cue: historyCue, onClose: closeSidebar)
        } else if let priorityScene {
            CuePrioritySidebar(scene: priorityScene, onSelectScene: { self.priorityScene = $0 })
                .id(priorityScene)   // 다른 열로 바뀌면 새로 그림 (00 카드 번호 다시 매기기)
        } else if isShowingUnread {
            CueUnreadSidebar(production: production, onClose: closeSidebar)
        }
    }

    private var sidebar: some View {
        sidebarContent
            .overlay(alignment: .leading) { sidebarEdge }
            .overlay(alignment: .topLeading) {
                if historyCue != nil || priorityScene != nil || isShowingUnread { closeButton }   // 사이드바가 열려 있을 때만
            }
    }

    // « 닫기 버튼: 세 사이드바 모두 같은 자리에 고정 (왼쪽 16, 위 21)
    private var closeButton: some View {
        SidebarCloseButton(action: closeSidebar)
            .padding(.leading, 16)
            .padding(.top, 21)
    }

    // 왼쪽 구분선 손잡이 (마우스를 올리면 ↔ 커서)
    private var sidebarEdge: some View {
        Color.clear
            .frame(width: 8)
            .contentShape(.rect)
            .pointerStyle(.columnResize)
            .gesture(DragGesture().onEnded { if $0.translation.width > 100 { closeSidebar() } })   // 오른쪽으로 100 넘게 밀면 닫힘
    }

    // 큐 수정 알림을 눌러서 왔을 때: 다른 파트만 보고 있었으면 "전체"로 풀고, 표에 그 큐들을 넘긴다
    private func showFocusedCues(_ focus: SystemNotifications.CueFocus?) {
        guard let focus, focus.productionID == production.id else { return }
        if let selectedPart, !(selectedPart.cues ?? []).contains(where: { focus.cueIDs.contains($0.id) }) {
            self.selectedPart = nil
        }
        gridFocus = focus
        cueFocus.wrappedValue = nil   // 한 번 썼으면 비운다 (다시 열 때 또 움직이지 않게)
    }

    private func closeSidebar() {
        historyCue = nil
        priorityScene = nil
        isShowingUnread = false
    }
}

// 위쪽 두 줄

extension MainCueSheetView {
    // 공연 제목 + 오른쪽 멤버 캡슐
    private var titleRow: some View {
        HStack {
            Text(production.title)
                .font(.title)
                .foregroundStyle(Color.neutral900)
            Spacer()
            // 피그마 1349:3639: 멤버 · 공유하기 · 내보내기 아이콘
            HStack(spacing: 20) {
                memberButton
                HStack(spacing: 4) {   // 피그마: 공유하기 · 내보내기 아이콘 간격 4
                    shareButton
                    exportButton
                }
            }
        }
    }
    
    // 파트 칩 + 오른쪽 미확인 · 리허설 모드 버튼
    private var filterRow: some View {
        HStack {
            PartFilterTabBar(parts: production.parts ?? [], selectedPart: $selectedPart)
            Spacer()
            HStack(spacing: 10) {   // 피그마: 미확인 · 리허설 모드 간격 10
                unreadButton
                rehearsalModeButton
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 18)
    }
}

// 버튼 · 멤버

extension MainCueSheetView {
    private var rehearsalModeButton: some View {
        Button("리허설 모드", action: onRehearsal)
        .buttonStyle(.primary)
        .frame(width: 100, height: 36)
    }
    
    // 미확인 N건 → 누르면 미확인 사이드바 (피그마: 100 × 36, neutral25 배경 + 보라 테두리, Title 3/Emphasized)
    private var unreadButton: some View {
        Button { isShowingUnread.toggle() } label: {
            Text("미확인 \(unreadCount)건")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brandPrimaryText)
                .frame(width: 100, height: 36)
                .background(Color.neutral25, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.brandPrimary, lineWidth: 1))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // 내가 아직 확인 안 한 큐 수 (미확인 사이드바의 N건과 같은 기준)
    private var unreadCount: Int {
        let cues = (production.parts ?? []).flatMap { $0.cues ?? [] }
        return cues.filter { $0.check(byUserID: iCloudAccount.userRecordName) == nil }.count
    }

    // 공유하기 (셀리나 #90 모양) → 공유하기 창 (초대 링크 · 메일, #68)
    private var shareButton: some View {
        Button { isShowingShare = true } label: {
            Text("공유하기")
                .font(.body)                                   // Body/Regular 13
                .foregroundStyle(Color.softActionText)
                .frame(width: 79, height: 28)
                .background(Color.softAction, in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // 팀 팝오버 (셀리나 #90) — 피그마 951:10223 폭 420
        // 바탕은 셀리나 댓글 · 확인 팝오버처럼 불투명 Neutral/25 (흰색 70%는 뒤의 큐시트가 비쳐 보여서)
        .appPopover(isPresented: $isShowingShare, width: 420) {
            SharePopover(production: production)
        }
    }
    
    // 공유하기 옆 내보내기 버튼 (피그마: 26 × 26 네모 · 모서리 5 · neutral25 · 테두리 purple/300, 가운데 square.and.arrow.up 14 purple/700)
    private var exportButton: some View {
        Button {
            // TODO: 누르면 할 일 정해지면 넣기
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14))
                .offset(y: -1)   // SF Symbol은 아래 여백 때문에 눈으로는 아래로 쏠려 보여서 1pt 올림 (피그마: 위 5 · 아래 4)
                .foregroundStyle(Color.brandPrimaryPressed)
                .frame(width: 16, height: 17)
                .frame(width: 26, height: 26)   // 피그마 네모 26 × 26 (아이콘은 가운데)
                .background(Color.neutral25, in: .rect(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.brandPrimaryDisabled, lineWidth: 1))   // purple/300 #C1BCFF
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // 멤버 이니셜 동그라미(겹쳐서) + ∨ → 누르면 참여자 현황
    private var memberButton: some View {
        Button { isShowingParticipants = true } label: {
            HStack(spacing: 4) {
                HStack(spacing: -6) {
                    let initials = (production.members ?? []).prefix(2).map { String($0.name.prefix(1)).uppercased() }
                    if initials.isEmpty {
                        memberCircle(Image(systemName: "person.fill"))
                    } else {
                        ForEach(Array(initials.enumerated()), id: \.offset) { _, initial in
                            memberCircle(Text(initial))
                        }
                    }
                }
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.neutral500)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // 피그마 1618:7175 폭 426
        .appPopover(isPresented: $isShowingParticipants, width: 426) {
            ParticipantsPopover(production: production, myUserID: iCloudAccount.userRecordName)
        }
    }

    private func memberCircle(_ content: some View) -> some View {
        content
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brandPrimary)
            .frame(width: 25, height: 25)
            .background(Color.brandPrimarySubtle, in: .circle)
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
    }
}


#Preview {
    let container = try! ModelContainer(for: Production.self, configurations: .init(isStoredInMemoryOnly: true))
    let production = Production(title: "레미제라블", genre: "뮤지컬", firstShowDate: .now)
    let scenes = (0..<3).map { ShowScene(title: "", kind: .scene, order: $0) }
    let trigger = Trigger(text: "오프닝 \"Look Down\" 전주", order: 0)
    let cue = Cue(title: "죄수들 노역 위치 입장", position: .sangsu, order: 1)
    container.mainContext.insert(production)
    production.parts = Part.makeDefaultParts()
    production.scenes = scenes
    scenes[0].triggers = [trigger]
    cue.trigger = trigger
    cue.part = production.parts?.first { $0.order == 0 }
    
    return MainCueSheetView(production: production)
        .frame(width: 1300, height: 800)
        .modelContainer(container)
        .environment(ICloudAccount())
}
