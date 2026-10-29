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
}

extension Production {
    func member(withUserID userID: String?) -> Member? {
        guard let userID else { return nil }
        return (members ?? []).first { $0.iCloudUserID == userID }
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
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(letterColor)
            .frame(width: size, height: size)
            .background(background, in: .circle)
    }
}
