//
//  NewProjectFlow.swift
//  CueFlow
//
//  Created by 김나현 on 10/16/26.
//

import SwiftUI
import SwiftData

// 새 공연 만들기 흐름: 기본정보 → 파트구성 → 씬구성 → 생성확인 → 완료 → 통합 큐시트
// 화면끼리 주고받는 값을 여기서 들고 있다가, 생성확인에서 "다음으로"를 누르면 공연을 저장한다
struct NewProjectFlow: View {
    var onGoHome: () -> Void = {}   // 홈으로 돌아가기
    // "큐시트 편집 시작하기": 있으면 바깥(ContentView)의 큐시트로 연다 → 리허설 버튼도 동작. 없으면 이 흐름 안에서 연다
    var onOpenCueSheet: ((Production) -> Void)?

    @Environment(\.modelContext) private var modelContext

    @State private var step: Step = .info
    @State private var draft = ProductionDraft()               // 기본정보
    @State private var selectedParts = Set(Part.defaultNames)  // 파트구성: 고른 파트
    @State private var customParts: [String] = []              // 파트구성: 직접 추가한 파트
    @State private var scenes: [ShowScene] = []                // 씬구성
    @State private var createdProduction: Production?          // 생성확인에서 저장한 공연

    private enum Step {
        case info, part, scene, check, complete, cueSheet
    }

    var body: some View {
        switch step {
        case .info:
            PerformInfo(
                draft: $draft,
                onPrevious: onGoHome,
                onNext: { step = .part }
            )
        case .part:
            PerformPart(
                selectedParts: $selectedParts,
                customParts: $customParts,
                onPrevious: { step = .info },
                onNext: { step = .scene }
            )
        case .scene:
            PerformSceneEdit(
                scenes: $scenes,
                onPrevious: { step = .part },
                onNext: { step = .check }
            )
        case .check:
            InfoCheck(
                draft: draft,
                onPrevious: { step = .scene },
                onNext: createProduction
            )
        case .complete:
            InfoComplete(
                onGoHome: onGoHome,
                onStartEditing: {
                    if let onOpenCueSheet, let createdProduction {
                        onOpenCueSheet(createdProduction)
                    } else {
                        step = .cueSheet
                    }
                }
            )
        case .cueSheet:
            cueSheet
        }
    }
}

extension NewProjectFlow {
    // 생성확인 "다음으로": 입력한 값으로 공연을 만들어 저장하고 완료 화면으로
    private func createProduction() {
        let production = Production(
            title: draft.title,
            genre: draft.genre,
            firstShowDate: draft.firstShowDate
        )
        production.lastShowDate = draft.lastShowDate
        production.venue = draft.venue
        production.seatCount = draft.seatCount
        production.organizer = draft.organizer
        production.runningTime = draft.runningTime
        production.parts = Part.makeParts(named: selectedParts, customNames: customParts)
        production.scenes = scenes
        modelContext.insert(production)
        createdProduction = production
        step = .complete
    }

    // 완료 "큐시트 편집 시작하기": 방금 만든 공연의 통합 큐시트
    @ViewBuilder
    private var cueSheet: some View {
        if let createdProduction {
            MainCueSheetView(production: createdProduction)
        }
    }
}

#Preview {
    NewProjectFlow()
        .frame(width: 1512, height: 982)
        .modelContainer(for: Production.self, inMemory: true)
}
