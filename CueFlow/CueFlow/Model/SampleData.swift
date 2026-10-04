//
//  SampleData.swift
//  CueFlow
//
//  유저테스트용 샘플 데이터 (피그마 로우파이_4차 기준). 앱을 켜면 이 상태로 시작한다.
//  Preview에서도 CueStore.sample() 로 쓸 수 있다.
//

import Foundation

extension CueStore {
    static func sample() -> CueStore {
        let store = CueStore()
        store.showTitle = "별이 빛나는 밤에"

        let stage   = store.addPart(name: "무대")
        let props   = store.addPart(name: "소품")
        let costume = store.addPart(name: "의상")
        let light   = store.addPart(name: "조명")
        let sound   = store.addPart(name: "음향")
        let etc     = store.addPart(name: "기타")

        let rami   = Member(name: "라미", partID: stage.id)
        let selina = Member(name: "셀리나", partID: props.id)
        let sonu   = Member(name: "소누", partID: costume.id)
        let katt   = Member(name: "캇", partID: light.id)
        let kou    = Member(name: "코우", partID: sound.id)
        let minji  = Member(name: "민지", partID: etc.id)
        store.members = [rami, selina, sonu, katt, kou, minji]
        let everyone = store.members

        // 큐 하나 추가 + 확인한 사람 + 댓글
        // 같은 씬에서 트리거 글자가 같으면 같은 트리거 = 동시에 실행
        func cue(_ scene: ShowScene, _ part: Part, _ action: String, _ position: StageSide?,
                 trigger: String, checked: [Member] = [], comments: [(Member, String)] = []) {
            let c = store.addCue(sceneID: scene.id, triggerText: trigger, partID: part.id,
                                 action: action, position: position)
            for m in checked { store.toggleCheck(cueID: c.id, memberID: m.id) }
            for (i, (author, text)) in comments.enumerated() {
                store.addComment(cueID: c.id, authorID: author.id, text: text,
                                 at: .now.addingTimeInterval(Double(i - comments.count) * 600))
            }
        }

        let s1 = store.addScene(name: "#1 Scene", subtitle: "예종·본종·안내멘트")
        cue(s1, stage, "소프 기본퇴장", .sangsu, trigger: "스페셜게스트 포함", checked: everyone)
        cue(s1, props, "대도구: 침대", nil, trigger: "이불·베개·동화책", checked: [rami, selina, katt])
        cue(s1, light, "객석조명 OFF", nil, trigger: "안내멘트 직후", checked: everyone)
        cue(s1, sound, "예종·본종·안내멘트", nil, trigger: "객석조명 OUT", checked: [katt, kou, minji])

        let s2 = store.addScene(name: "#2 Scene", subtitle: "We're all adventurers")
        cue(s2, stage, "전체스텝 무대대기", nil, trigger: "전캐스트 준비", checked: everyone)
        cue(s2, costume, "파스텔 셔츠·청바지", nil, trigger: "배역의상", checked: [sonu])
        cue(s2, light, "전체조명 ON", nil, trigger: "노래 시작 · 끝나면 OFF", checked: [katt, kou])
        cue(s2, sound, "MR 시작", nil, trigger: "노래 시작 · 끝나면 OFF", checked: [katt, kou],
            comments: [(kou, "MR 음량 리허설 때보다 조금 줄일게요")])
        cue(s2, etc, "스페셜게스트 등장", .sangsu, trigger: "전체조명 이후", checked: [rami, minji])

        let s3 = store.addScene(name: "#3 Scene", subtitle: "마루·우현의 우주 이야기")
        cue(s3, stage, "혜원 바로 입장", .hasu, trigger: "조명 IN · 정원 제외", checked: [rami, katt],
            comments: [(rami, "혜원 입장 타이밍 조명이랑 맞춰야 해요"),
                       (katt, "조명 IN 신호 주시면 바로 들어오면 돼요"),
                       (rami, "넵 리허설 때 한 번 더 맞춰봐요")])
        cue(s3, stage, "정원 전화 받으며 퇴장", .sangsu, trigger: "코우 - \"너 나가!\" 대사 종료 후",
            checked: [rami, kou])
        cue(s3, props, "윤서 대표 큰기기 IN", .hasu, trigger: "윤서 입장하면서", checked: [selina])
        cue(s3, light, "하수 IN / 상수 OUT", .hasu, trigger: "거실 조명")
        cue(s3, sound, "대사 후 BGM", nil, trigger: "자전거 벨소리", checked: [kou],
            comments: [(selina, "벨소리 버전 바뀐 거 맞죠?")])
        cue(s3, etc, "암전", nil, trigger: "장면 전환", checked: everyone)

        let s4 = store.addScene(name: "#4 Scene", subtitle: "A million miles away")
        cue(s4, stage, "전주시작 캐스트 입장", .sangsu, trigger: "혜원 제외", checked: everyone)
        cue(s4, props, "장바구니 IN", .hasu, trigger: "은비 입장하면서", checked: [selina, rami])
        cue(s4, costume, "긴팔 셔츠·연청바지", nil, trigger: "배역의상 유지", checked: [sonu, rami])
        cue(s4, light, "전체조명 IN", nil, trigger: "조도는 낮게", checked: [katt])
        cue(s4, sound, "전주 시작", nil, trigger: "1절 끝나고 전환", checked: [kou, katt, rami])

        let s5 = store.addScene(name: "#5 Scene", subtitle: "수연 등장·침실 이동")
        cue(s5, stage, "은비·혜원 침대로 이동", .sangsu, trigger: "무대 뒤쪽 이동", checked: [rami, selina])
        cue(s5, props, "식탁·의자 OUT", .hasu, trigger: "장면 전환", checked: [selina, rami, minji])
        cue(s5, costume, "상의 니트로 환복", nil, trigger: "은비 퀵체인지",
            comments: [(sonu, "퀵체인지 시간 30초 안에 가능할까요?")])
        cue(s5, light, "혜원·정원 ON", .sangsu, trigger: "은비 입장 시 ON", checked: [katt])
        cue(s5, sound, "등장하면 BGM", nil, trigger: "유림·윤서 · Fadeout", checked: [kou])
        cue(s5, etc, "혜원·정원 퇴장", .hasu, trigger: "마루 퇴장 전", checked: [minji, rami])

        return store
    }
}
