//
//  CueMembers.swift
//  CueFlow
//
//  Created by 김나현 on 10/30/26.
//
//  댓글 · 확인 현황에서 같이 쓰는 것: "나" 찾기, 이름 동그라미, 날짜
//

import SwiftUI
import SwiftData

extension EnvironmentValues {
    // 내 iCloud 계정 ID (Member.iCloudUserID와 비교해서 "나"를 찾음)
    @Entry var myUserID: String? = nil
    // 지금 공연을 고칠 수 있는지. 큐시트 · 리허설 화면이 넣어 준다. 읽기 권한이어도 댓글 · 큐 확인은 된다 (#120)
    @Entry var canEditCues: Bool = true
}

extension Production {
    func member(withUserID userID: String?) -> Member? {
        guard let userID else { return nil }
        return (members ?? []).first { $0.iCloudUserID == userID }
    }

    // 이 사람이 큐를 고칠 수 있는지. 공연을 만든 사람(총 연출자)은 항상, 나머지는 총 연출자가 켜 줬을 때만 (#120)
    func canEdit(userID: String?) -> Bool {
        !isSharedWithMe || member(withUserID: userID)?.canEdit == true
    }

    // 리허설을 진행(동기화 모드 · Spotlight me)할 수 있는지. 총 연출자 + 편집 권한을 받은 멤버만 (#132)
    func canLeadRehearsal(userID: String?) -> Bool {
        canEdit(userID: userID)
    }
}

extension ModelContext {
    // "나" 멤버. 없으면 내 이름으로 만들어 공연에 넣음
    func me(in production: Production, userID: String) -> Member {
        if let me = production.member(withUserID: userID) { return me }
        let me = Member(name: CurrentEditor.name, role: "")
        insert(me)
        me.iCloudUserID = userID
        me.production = production
        return me
    }
}

extension Member {
    // 대표 파트 (색 · 이름 표시용)
    var mainPart: Part? { (parts ?? []).min { $0.order < $1.order } }
}

extension Cue {
    func check(byUserID userID: String?) -> CueCheck? {
        guard let userID else { return nil }
        return (checks ?? []).first { $0.member?.iCloudUserID == userID }
    }
}

extension Date {
    // 2026.10.01(금) 17:29
    var commentText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd(E) HH:mm"
        return formatter.string(from: self)
    }
}

// 이름 첫 글자 동그라미
struct MemberAvatar: View {
    let name: String
    var size: CGFloat = 40
    var background: Color = .neutral300
    var letterColor: Color = .white
    var fontSize: CGFloat = 17

    var body: some View {
        Text(String(name.prefix(1)))
            .font(.app(size: fontSize, weight: .semibold))
            .foregroundStyle(letterColor)
            .frame(width: size, height: size)
            .background(background, in: .circle)
    }
}
