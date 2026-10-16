//
//  UserTest.swift
//  CueFlow
//
//  유저테스트(TestFlight) 빌드 설정.
//  아직 동작이 정해지지 않은 버튼은 숨기고, 처음 실행하면 예시 공연을 하나 넣어 둔다.
//  유저테스트가 끝나면 hidesUnfinished를 false로 바꾸면 숨긴 버튼이 다시 보인다.
//

import Foundation
import SwiftData

enum UserTest {
    // true면 미정 기능 숨김: 사이드바 공지사항 · 도움말, 홈 알림 · 설정, 큐시트 씬 단위 화면, 리허설 동기화 모드
    static let hidesUnfinished = true

    // 처음 실행했을 때 한 번만 예시 공연(레미제라블)을 넣는다. 지워도 다시 생기지 않게 기록해 둔다.
    @MainActor
    static func insertSampleIfNeeded(into context: ModelContext, isEmpty: Bool) {
        let key = "didInsertSampleProduction"
        guard isEmpty, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let production = RehearsalPreviewData.production
        production.initialPlacements = []   // 무대 배치는 테스터가 "배치하기"부터 직접 해 보게 비워 둔다
        context.insert(production)
    }
}
