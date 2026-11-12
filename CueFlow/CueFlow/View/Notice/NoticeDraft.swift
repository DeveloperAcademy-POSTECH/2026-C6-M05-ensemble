//
//  NoticeDraft.swift
//  CueFlow
//
//  공지 상세의 답장 · 전체 답장 · 전달 → 쓰기 화면에 미리 채울 내용 (피그마 951:7518).
//  보낼 대상은 한 곳(전체 / 파트 하나 / 사람 한 명)만 고를 수 있어서 그 안에서 정한다.
//

import Foundation

struct NoticeDraft: Identifiable, Hashable {
    let id = UUID()
    var production: Production?
    var recipient: NoticeRecipient
    var title: String
    var body: String

    // 답장: 보낸 사람 한 명에게
    static func reply(to notice: Notice) -> NoticeDraft {
        NoticeDraft(
            production: notice.production,
            recipient: notice.author.map { .member($0) } ?? .all,
            title: prefixed("RE: ", notice.title),
            body: quoted(notice)
        )
    }

    // 전체 답장: 원래 받은 대상(전체 · 그 파트)에게. 개인 공지였으면 보낸 사람에게
    static func replyAll(to notice: Notice) -> NoticeDraft {
        let recipient: NoticeRecipient
        if let part = notice.targetPart {
            recipient = .part(part)
        } else if notice.targetMember != nil, let author = notice.author,
                  !notice.isSent(byUserID: ICloudAccount.currentUserRecordName) {
            recipient = .member(author)
        } else if let member = notice.targetMember {
            recipient = .member(member)   // 내가 보낸 개인 공지 → 받았던 사람에게 다시
        } else {
            recipient = .all
        }
        return NoticeDraft(
            production: notice.production,
            recipient: recipient,
            title: prefixed("RE: ", notice.title),
            body: quoted(notice)
        )
    }

    // 전달: 같은 공연에서 받는 사람은 새로 고른다 (처음엔 전체)
    static func forward(_ notice: Notice) -> NoticeDraft {
        NoticeDraft(
            production: notice.production,
            recipient: .all,
            title: prefixed("FW: ", notice.title),
            body: quoted(notice)
        )
    }

    // "RE: RE: 제목"처럼 쌓이지 않게
    private static func prefixed(_ prefix: String, _ title: String) -> String {
        title.hasPrefix(prefix) ? title : prefix + title
    }

    // 맨 위는 비워 두고(내가 쓸 자리) 아래에 원본 공지를 붙인다
    private static func quoted(_ notice: Notice) -> String {
        """


        ----- 원본 공지 -----
        보낸사람: \(notice.senderName)
        보낸 날짜: \(notice.sentDateDetailText)
        제목: \(notice.title)

        \(notice.body)
        """
    }
}
