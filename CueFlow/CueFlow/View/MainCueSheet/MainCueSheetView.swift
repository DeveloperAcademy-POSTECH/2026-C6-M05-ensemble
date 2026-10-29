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
    @State private var historyCue: Cue?        // History 사이드바에 보여줄 큐 (nil = 닫힘)
    @State private var priorityScene: ShowScene?  // 우선순위 사이드바에 보여줄 씬 (nil = 닫힘)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
            filterRow
            CueGrid(production: production, selectedPart: selectedPart, onShowHistory: { historyCue = $0 }, priorityScene: $priorityScene)
            .padding(.top, -12)   // 위 여유(12)만큼 올려서 표 위치는 피그마 그대로
            .overlay(alignment: .trailing) { sidebar.padding(.trailing, -35) }   // 표 높이만큼만 + 창 오른쪽 끝에 붙임 (바깥 여백 35만큼)
        }
        .padding(.horizontal, 35)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white)
        .appPopoverHost()   // 표 안 팝오버(파트 추가 · 수정)가 그려지는 곳
        .onChange(of: historyCue) { if $1 != nil { priorityScene = nil } }     // History 열면 우선순위 닫힘
        .onChange(of: priorityScene) { if $1 != nil { historyCue = nil } }     // 우선순위 열면 History 닫힘
    }
}

// 오른쪽 사이드바: History (큐 카드 우클릭) · 우선순위 (씬 열 ⓝ)

extension MainCueSheetView {
    @ViewBuilder
    private var sidebarContent: some View {
        if let historyCue {
            CueHistorySidebar(cue: historyCue, onClose: closeSidebar)
        } else if let priorityScene {
            CuePrioritySidebar(scene: priorityScene, onSelectScene: { self.priorityScene = $0 })
                .id(priorityScene)   // 다른 열로 바뀌면 새로 그림 (00 카드 번호 다시 매기기)
        }
    }

    // 오른쪽 사이드바 + 왼쪽 구분선 손잡이
    private var sidebar: some View {
        sidebarContent
            .overlay(alignment: .leading) { sidebarEdge }
    }

    // 왼쪽 구분선 손잡이 (마우스를 올리면 ↔ 커서)
    private var sidebarEdge: some View {
        Color.clear
            .frame(width: 8)
            .contentShape(.rect)
            .pointerStyle(.columnResize)
            .gesture(DragGesture().onEnded { if $0.translation.width > 100 { closeSidebar() } })   // 오른쪽으로 100 넘게 밀면 닫힘
    }

    private func closeSidebar() {
        historyCue = nil
        priorityScene = nil
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
            shareButton
        }
    }
    
    // 파트 칩 + 오른쪽 "씬 단위 화면" 버튼
    private var filterRow: some View {
        HStack {
            PartFilterTabBar(parts: production.parts ?? [], selectedPart: $selectedPart)
            Spacer()
            rehearsalModeButton
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
    
    private var shareButton: some View {
        Button { } label: {
            Text("공유하기")
                .font(.body)                                   // Body/Regular 13
                .foregroundStyle(Color.neutral25)
                .frame(width: 79, height: 28)
                .background(Color.brandPrimaryHover, in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
}
