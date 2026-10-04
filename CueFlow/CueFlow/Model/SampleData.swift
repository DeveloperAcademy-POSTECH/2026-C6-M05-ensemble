//
//  SampleData.swift
//  CueFlow
//
//  유저테스트용 샘플 데이터. 앱을 켜면 이 상태로 시작한다.
//  Preview에서도 CueStore.sample() 로 쓸 수 있다.
//

import Foundation

extension CueStore {
    static func sample() -> CueStore {
        let store = CueStore()

        let stage = store.addPart(name: "무대")
        let light = store.addPart(name: "조명")
        let sound = store.addPart(name: "음향")
        let props = store.addPart(name: "소품")

        let haneul = Member(name: "김하늘", partID: light.id)
        let junho  = Member(name: "이준호", partID: sound.id)
        let seoyeon = Member(name: "박서연", partID: stage.id)
        let minji  = Member(name: "최민지", partID: props.id)
        let daeun  = Member(name: "정다은", partID: stage.id)
        store.members = [haneul, junho, seoyeon, minji, daeun]
        let everyone = store.members

        // 큐 하나 추가 + 확인한 사람 + 댓글
        func cue(_ scene: ShowScene, _ trigger: String, _ part: Part, _ action: String,
                 checked: [Member] = [], comments: [(Member, String)] = []) {
            let c = store.addCue(sceneID: scene.id, triggerText: trigger, partID: part.id, action: action)
            for m in checked { store.toggleCheck(cueID: c.id, memberID: m.id) }
            for (i, (author, text)) in comments.enumerated() {
                store.addComment(cueID: c.id, authorID: author.id, text: text,
                                 at: .now.addingTimeInterval(Double(i - comments.count) * 600))
            }
        }

        // S1 — 오프닝
        let s1 = store.addScene(name: "S1 오프닝")
        cue(s1, "하우스 오픈", light, "객석등 50%", checked: everyone)
        cue(s1, "하우스 오픈", sound, "프리쇼 음악 재생", checked: everyone)
        cue(s1, "공연 시작 안내 멘트 끝", light, "객석등 FADE OUT 5초", checked: [haneul, junho, seoyeon, minji])
        cue(s1, "공연 시작 안내 멘트 끝", sound, "프리쇼 음악 FADE OUT", checked: [haneul, junho, seoyeon, minji])
        cue(s1, "암전", stage, "소파·테이블 세팅", checked: [seoyeon, daeun])
        cue(s1, "암전", props, "테이블 위 찻잔 2개", checked: [minji],
            comments: [(seoyeon, "찻잔 깨질 수 있으니 플라스틱으로 바꿀까요?"),
                       (minji, "네 내일 리허설부터 플라스틱으로 할게요")])
        cue(s1, "배우 A 등장", light, "무대 전체 조명 IN 3초", checked: [haneul])
        cue(s1, "배우 A 등장", sound, "새소리 효과음", checked: [junho])
        cue(s1, "\"오늘따라 조용하네\" 대사", sound, "초인종 효과음",
            comments: [(junho, "대사 끝나고 바로인가요, 1초 쉬고인가요?")])

        // S2 — 갈등
        let s2 = store.addScene(name: "S2 갈등")
        cue(s2, "전환 암전", stage, "소파 무대 왼쪽으로 이동", checked: [seoyeon])
        cue(s2, "전환 암전", props, "편지 봉투 소파 위에", checked: [minji, daeun])
        cue(s2, "전환 암전", sound, "전환 음악 재생", checked: [junho])
        cue(s2, "배우 B 등장", light, "왼쪽 스팟 IN", checked: [haneul, seoyeon])
        cue(s2, "배우 B 등장", sound, "전환 음악 FADE OUT")
        cue(s2, "편지를 읽는 순간", light, "스팟만 남기고 전체 DIM",
            comments: [(haneul, "DIM 정도는 30%로 생각 중이에요"),
                       (daeun, "배우 표정 보이게 40%는 어떨까요")])
        cue(s2, "편지를 읽는 순간", sound, "피아노 테마 IN")
        cue(s2, "배우 B 퇴장", light, "스팟 OUT", checked: [haneul])
        cue(s2, "배우 B 퇴장", stage, "문 닫기", checked: [daeun])

        // S3 — 화해
        let s3 = store.addScene(name: "S3 화해")
        cue(s3, "전환 암전", stage, "소파 원위치", checked: [seoyeon, daeun])
        cue(s3, "전환 암전", props, "편지 회수, 꽃다발 준비")
        cue(s3, "두 배우 마주 섬", light, "무대 중앙 따뜻한 색 조명 IN", checked: [haneul])
        cue(s3, "두 배우 마주 섬", sound, "피아노 테마 다시 IN")
        cue(s3, "꽃다발 건넴", props, "꽃다발 무대 오른쪽에서 전달", checked: [minji],
            comments: [(minji, "꽃다발 위치 확인 부탁드려요")])
        cue(s3, "\"고마워\" 대사", light, "전체 FADE OUT 5초")
        cue(s3, "\"고마워\" 대사", sound, "엔딩 음악 IN")
        cue(s3, "커튼콜", light, "전체 조명 FULL", checked: everyone)
        cue(s3, "커튼콜", sound, "커튼콜 음악", checked: everyone)

        return store
    }
}
