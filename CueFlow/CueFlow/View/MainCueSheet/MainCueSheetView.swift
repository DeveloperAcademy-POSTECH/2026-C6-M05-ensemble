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
    var onRehearsal: () -> Void = {}           // "리허설 모드" 버튼
    @State private var selectedPart: Part?     // 파트 칩에서 고른 파트 (nil = 전체)
    @State private var isShowingParticipants = false   // 멤버 버튼 → 참여자 현황
    @State private var isShowingShare = false          // 임시 초대하기 버튼 → 공유하기 창
    @Environment(ICloudAccount.self) private var iCloudAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
            filterRow
            CueGrid(production: production, selectedPart: selectedPart)
        }
        .padding(.horizontal, 35)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white)
        // 큐시트를 보고 있는 동안 1분마다 "나 지금 보고 있음"을 남긴다 → 다른 사람 참여자 현황에 보인다
        .task(id: production.id) {
            while !Task.isCancelled {
                production.markSeen(byUserID: iCloudAccount.userRecordName)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}

// 위쪽 두 줄

extension MainCueSheetView {
    // 공연 제목 + 오른쪽 멤버 캡슐
    private var titleRow: some View {
        HStack {
            Text(production.title)
                .font(.title2.weight(.semibold))
            Spacer()
            #if DEBUG
            shareButton
            memberButton
        }
    }
    
    // 파트 칩 + 오른쪽 "씬 단위 화면" 버튼
    private var filterRow: some View {
        HStack {
            PartFilterTabBar(production: production, selectedPart: $selectedPart)
            Spacer()
                rehearsalModeButton
        }
        .padding(.top, 18)
        .padding(.bottom, 15)
    }
}

// 버튼 · 멤버

extension MainCueSheetView {
    private var rehearsalModeButton: some View {
        Button("리허설 모드", action: onRehearsal)
        .buttonStyle(.primary)
        .frame(width: 90, height: 30)
    }

    #if DEBUG
    // 임시: 사이드바 공유하기가 붙기 전까지 초대 테스트용 (TestFlight에는 안 보임)
    private var shareButton: some View {
        Button("초대하기") { isShowingShare = true }
            .buttonStyle(.bordered)
            .popover(isPresented: $isShowingShare, arrowEdge: .bottom) {
                SharePopover(production: production)
            }
    }
    #endif

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
        .popover(isPresented: $isShowingParticipants, arrowEdge: .bottom) {
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
