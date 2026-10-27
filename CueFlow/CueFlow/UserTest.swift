//
//  UserTest.swift
//  CueFlow
//
//  유저테스트(TestFlight) 빌드 설정.
//  아직 동작이 정해지지 않은 버튼은 숨기고, 진행자용 메뉴(예시 공연 넣기 · 모든 데이터 지우기)를 둔다.
//  유저테스트가 끝나면 hidesUnfinished를 false로 바꾸면 숨긴 버튼이 다시 보이고 진행자 메뉴도 사라진다.
//

import Foundation
import SwiftData

enum UserTest {
    // true면 미정 기능 숨김: 사이드바 공지사항 · 도움말, 홈 알림 · 설정, 큐시트 씬 단위 화면
    // + 메뉴 막대에 "UT 진행" 메뉴가 보인다
    static let hidesUnfinished = true

    // true면 처음 실행할 때 예시 공연을 한 번 넣는다. 10/19 UT는 빈 화면에서 시작하므로 끔
    static let insertsSampleOnFirstLaunch = false

    // 진행자 메뉴로 데이터를 넣거나 지웠을 때 → ContentView가 홈 화면으로 돌아간다
    static let didResetNotification = Notification.Name("UserTestDidReset")

    // 처음 실행했을 때 한 번만 예시 공연을 넣는다. 지워도 다시 생기지 않게 기록해 둔다.
    @MainActor
    static func insertSampleIfNeeded(into context: ModelContext, isEmpty: Bool) {
        guard insertsSampleOnFirstLaunch else { return }
        let key = "didInsertSampleProduction"
        guard isEmpty, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        context.insert(makeSampleProduction())
    }

    // 진행자 메뉴 "예시 공연 넣기": 참가자가 공연 만들기에서 막히면 큐가 채워진 공연으로 이어서 진행
    @MainActor
    static func insertSample(into context: ModelContext) {
        NotificationCenter.default.post(name: didResetNotification, object: nil)
        context.insert(makeSampleProduction())
        try? context.save()
    }

    // 진행자 메뉴 "모든 데이터 지우기": 참가자가 바뀔 때 빈 화면으로 되돌린다
    @MainActor
    static func deleteAll(in context: ModelContext) {
        // 열려 있는 큐시트 · 리허설 화면을 먼저 닫고 지운다 (지워진 공연을 화면이 붙잡고 있지 않게)
        NotificationCenter.default.post(name: didResetNotification, object: nil)
        let productions = (try? context.fetch(FetchDescriptor<Production>())) ?? []
        productions.forEach(context.delete)
        try? context.save()
        UserDefaults.standard.removeObject(forKey: "didInsertSampleProduction")
    }
}

// UT용 예시 공연 (레미제라블): 장면 3개 · 트리거 10개 · 큐 17개. 대본은 채우고 무대 배치는 비워 둔다.
// 참가자용 "공연 정보 종이"와 같은 내용이라 공연 만들기 → 예시 공연으로 바꿔도 흐름이 이어진다
extension UserTest {
    static func makeSampleProduction() -> Production {
        let production = Production(title: "레미제라블", genre: "뮤지컬", firstShowDate: Date())
        production.castNames = ["판틴", "공장장", "시장", "노동자들"]
        production.propNames = ["로켓", "편지", "작업대"]

        let partList = Part.makeDefaultParts()   // 무대 · 소품 · 의상 · 조명 · 음향
        production.parts = partList
        let parts = Dictionary(uniqueKeysWithValues: partList.map { ($0.name, $0) })

        var cueOrder = 0   // 트리거 안 순서가 섞이지 않게 차례로 번호
        func cue(_ title: String, _ position: CuePosition, _ part: String, cell: Int? = nil) -> Cue {
            cueOrder += 1
            let cue = Cue(title: title, position: position, order: cueOrder)
            cue.part = parts[part]
            cue.stageCell = cell
            return cue
        }
        func trigger(_ text: String, _ order: Int, _ cues: [Cue]) -> Trigger {
            let trigger = Trigger(text: text, order: order)
            trigger.cues = cues
            return trigger
        }

        let factory = ShowScene(title: "공장 안", kind: .scene, order: 0)
        factory.triggers = [
            trigger("공장 넘버 전주", 0, [
                cue("공장 전체조명 ON", .stage, "조명"),
                cue("공장 기계음 효과음 시작", .console, "음향"),
                cue("판틴 공장복 착용 확인", .sangsu, "의상"),
                cue("공장 노동자 입장", .sangsu, "무대"),
            ]),
            trigger("노동자들 - 후렴 직후", 1, [
                cue("시장 공장 등장", .stage, "무대", cell: 1),
            ]),
            trigger("판틴 - 공장 다툼 중", 2, [
                cue("판틴 로켓, 편지", .stage, "소품", cell: 4),
            ]),
            trigger("공장장 - \"오늘까지만 일하고 나가\"", 3, [
                cue("판틴 핀 조명", .stage, "조명"),
                cue("기계음 효과음 끄기", .console, "음향"),
            ]),
        ]

        let endOfDay = ShowScene(title: "At the End of the Day", kind: .number, order: 1)
        endOfDay.triggers = [
            trigger("합창 첫 소절", 0, [
                cue("M1 반주 재생", .console, "음향"),
                cue("거리 조명으로 전환", .stage, "조명"),
            ]),
            trigger("노동자들 앞으로 걸어 나올 때", 1, [
                cue("작업대 하수 퇴장", .hasu, "무대"),
            ]),
            trigger("넘버 끝 - 마지막 화음", 2, [
                cue("암전", .stage, "조명"),
                cue("반주 페이드아웃", .console, "음향"),
            ]),
        ]

        let dream = ShowScene(title: "I Dreamed a Dream", kind: .number, order: 2)
        dream.triggers = [
            trigger("판틴 혼자 남음", 0, [
                cue("판틴 숄 착용", .hasu, "의상"),
                cue("M2 반주 재생", .console, "음향"),
            ]),
            trigger("판틴 - 첫 소절", 1, [
                cue("판틴 스포트라이트", .stage, "조명"),
            ]),
            trigger("판틴 - 마지막 소절", 2, [
                cue("편지 바닥에 떨어뜨리기", .stage, "소품", cell: 7),
            ]),
        ]

        let scenes = [factory, endOfDay, dream]
        production.scenes = scenes

        // 대본: 장면 순서대로 채운다
        let parsed = ScriptParser.parse(sampleScriptText, cast: Set(production.castNames))
        for (scene, section) in zip(scenes, parsed) {
            scene.scriptLines = section.lines.enumerated().map { index, line in
                ScriptLine(order: index, speaker: line.speaker, text: line.text)
            }
        }

        production.initialPlacements = []   // 무대 배치는 "배치하기"부터 직접 해 보게 비워 둔다
        return production
    }

    private static let sampleScriptText = """
    S1 공장 안
    판틴 (편지를 품에 급히 숨기며 작게) …아무것도 아니에요. 그냥 집에서 온 편지예요.
    공장장 (작업대를 탕 치며, 노동자들을 둘러보고) 일하는 시간에 편지라니! 다들 손 멈추지 말고 계속해! 판틴, 너는 이리 와.
    판틴 죄송해요… 금방 다시 일할게요. 제발 한 번만 봐주세요.
    공장장 딸이 있다는 소문이 사실이었군. 오늘까지만 일하고 나가.
    판틴 (로켓을 꼭 움켜쥔다) …제가 일을 못 하면 그 아이는 어떻게 되나요.

    N1 At the End of the Day
    노동자들 하루가 또 끝나고 (주먹을 쥐고 앞으로 한 걸음씩 걸어 나온다)
    노동자들 내일은 또 어떻게 버티나
    공장장 다들 자리로 돌아가!

    N2 I Dreamed a Dream
    판틴 (혼자 남아 숄을 두른다) 꿈을 꾸었지, 지난날에
    판틴 희망은 높고 삶은 살 만했지
    판틴 (편지를 떨어뜨리며) 이젠 꿈도 다 사라졌어
    """
}
