//
//  Notice+List.swift
//  CueFlow
//
//  Created by yunseo on 10/10/26.
//

import Foundation
import SwiftData

extension Notice {
    // 목록의 "9월 28일"
    var sentDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: sentAt)
    }

    // 목록의 "Rami". 보낸 사람이 나가서 비어 있으면 "알 수 없음"
    var senderName: String {
        author?.name ?? "알 수 없음"
    }

    // 상세 아래 이전/다음 글의 "무대연출 이진환". 맡은 일이 없으면 이름만
    var senderRoleAndName: String {
        guard let author else { return "알 수 없음" }
        return author.role.isEmpty ? author.name : "\(author.role) \(author.name)"
    }

    // 상세의 "2026.10.02(금) 18:32"
    var sentDateDetailText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd(E) HH:mm"   // E = 요일 한 글자 (금)
        return formatter.string(from: sentAt)
    }

    // 상세의 "프로젝트 별마루". 공연이 없으면 빈칸
    var productionTitle: String {
        production?.title ?? ""
    }

    // 목록 한 줄 제목 "[레미제라블] 오늘 리허설 콜타임 변경 안내" (피그마 공지사항_01, #182)
    // 공연을 여러 개 하면 어느 공연 공지인지 바로 보이게. 공연이 없으면 제목만
    var listTitle: String {
        productionTitle.isEmpty ? title : "[\(productionTitle)] \(title)"
    }

    // 상세·알림 카드의 대상 태그: "전체공지" / "조명 공지" / "조명 · 음향 공지" / "개인 공지" / "조명 외 공지"
    var targetTag: String {
        let parts = recipientParts
        let members = recipientMembers
        if parts.isEmpty && members.isEmpty { return "전체공지" }
        if parts.isEmpty { return "개인 공지" }
        let names = parts.map(\.name).joined(separator: " · ")
        return members.isEmpty ? "\(names) 공지" : "\(names) 외 공지"
    }
}

// 받는 대상 여러 개 (파트 · 사람)
extension Notice {
    // 받을 파트들. 옛 앱이 보낸 공지는 targetPart 하나만 있다
    var recipientParts: [Part] {
        let all = production?.parts ?? []
        var parts = targetPartIDs.compactMap { id in all.first { $0.id == id } }
        if let targetPart, !parts.contains(targetPart) { parts.insert(targetPart, at: 0) }
        return parts
    }

    var recipientMembers: [Member] {
        let all = production?.members ?? []
        var members = targetMemberIDs.compactMap { id in all.first { $0.id == id } }
        if let targetMember, !members.contains(targetMember) { members.insert(targetMember, at: 0) }
        return members
    }

    // 쓰기 화면 · 답장에서 쓰는 모양 (비어 있으면 전체)
    var recipients: [NoticeRecipient] {
        recipientParts.map { .part($0) } + recipientMembers.map { .member($0) }
    }

    // 보낼 대상 정하기. 하나뿐이면 옛 앱도 읽는 targetPart · targetMember에도 적는다
    func setRecipients(_ recipients: [NoticeRecipient]) {
        var parts: [Part] = []
        var members: [Member] = []
        for recipient in recipients {
            switch recipient {
            case .all: break
            case .part(let part): if !parts.contains(part) { parts.append(part) }
            case .member(let member): if !members.contains(member) { members.append(member) }
            }
        }
        targetPartIDs = parts.map(\.id)
        targetMemberIDs = members.map(\.id)
        let isSingle = parts.count + members.count == 1
        targetPart = isSingle ? parts.first : nil
        targetMember = isSingle ? members.first : nil
    }
}

// 읽음 · 받는 사람 (#82). userID = 내 iCloud 계정 ID (Member.iCloudUserID와 비교)
extension Notice {
    // 내가 읽었는지 (내 읽음 기록이 있는지)
    func isRead(byUserID userID: String?) -> Bool {
        guard let userID else { return false }
        return (reads ?? []).contains { $0.member?.iCloudUserID == userID }
    }

    // 내가 보낸 공지인지
    func isSent(byUserID userID: String?) -> Bool {
        userID != nil && author?.iCloudUserID == userID
    }

    // 나한테 온 공지인지: 전체 공지 · 내 파트가 들어간 공지 · 나를 고른 공지
    // 맡은 파트가 없는 사람(감독 · 총연출처럼 역할을 안 고른 사람)은 전부 담당 → 파트 공지도 다 받는다
    // (큐 수정 알림과 같은 규칙, ContentView.notifyCueChanges · #179)
    func isForMe(userID: String?) -> Bool {
        let parts = recipientParts
        let members = recipientMembers
        if parts.isEmpty && members.isEmpty { return true }
        guard let userID else { return false }
        if members.contains(where: { $0.iCloudUserID == userID }) { return true }
        guard let me = production?.member(withUserID: userID) else { return false }
        let myParts = me.parts ?? []
        return myParts.isEmpty ? !parts.isEmpty : myParts.contains { parts.contains($0) }
    }

    // 안 읽은 공지 (내가 보낸 건 읽은 것으로 친다)
    func isUnread(byUserID userID: String?) -> Bool {
        !isRead(byUserID: userID) && !isSent(byUserID: userID)
    }

    // 목록 · 상세의 삭제: 내가 보낸 공지는 정말 지운다 (iCloud에서도 → 모두에게서 사라짐)
    // 남이 보낸 공지는 내 목록에서만 숨긴다 (메일 앱처럼. 다른 사람 목록에는 그대로)
    func removeFromMyList(in context: ModelContext) {
        let myID = ICloudAccount.currentUserRecordName
        if myID == nil || isSent(byUserID: myID) {
            context.delete(self)
        } else {
            isHiddenByMe = true
        }
    }

    // 상세를 열면 내 읽음 기록을 남긴다 → iCloud로 다른 사람에게도 간다
    func markRead(in context: ModelContext) {
        guard let userID = ICloudAccount.currentUserRecordName, let production, !isRead(byUserID: userID) else { return }
        let read = NoticeRead()
        context.insert(read)
        read.notice = self
        read.member = context.me(in: production, userID: userID)
    }
}
