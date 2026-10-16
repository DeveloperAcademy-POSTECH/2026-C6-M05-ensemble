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
    @State private var selectedPart: Part?     // 파트 칩에서 고른 파트 (nil = 전체)
    
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
    }
}

// 위쪽 두 줄

extension MainCueSheetView {
    // 공연 제목 + 오른쪽 멤버 캡슐
    private var titleRow: some View {
        HStack {
            Text(production.title)
                .font(.title2.weight(.semibold))
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
        Button("리허설 모드") {
            // TODO: 리허설 모드로 이동
        }
        .buttonStyle(.primary)
        .frame(width: 90, height: 30)
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
