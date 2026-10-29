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

    // 상세·알림 카드의 대상 태그: "전체공지" / "조명 공지" / "개인 공지"
    var targetTag: String {
        if let part = targetPart { return "\(part.name) 공지" }
        if targetMember != nil { return "개인 공지" }
        return "전체공지"
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

    // 나한테 온 공지인지: 전체 공지 · 내 파트 공지 · 나한테 보낸 공지
    func isForMe(userID: String?) -> Bool {
        if let targetMember { return userID != nil && targetMember.iCloudUserID == userID }
        if let targetPart {
            guard let me = production?.member(withUserID: userID) else { return false }
            return (me.parts ?? []).contains(targetPart)
        }
        return true
    }

    // 안 읽은 공지 (내가 보낸 건 읽은 것으로 친다)
    func isUnread(byUserID userID: String?) -> Bool {
        !isRead(byUserID: userID) && !isSent(byUserID: userID)
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
