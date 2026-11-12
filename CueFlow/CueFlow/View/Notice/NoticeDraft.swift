//
//  NoticeDraft.swift
//  CueFlow
//
//  공지 상세의 답장 · 전체 답장 · 전달 → 쓰기 화면에 미리 채울 내용 (피그마 951:7518).
//  보낼 대상은 여러 파트 · 여러 사람을 고를 수 있다 (비어 있으면 전체).
//

import Foundation

struct NoticeDraft: Identifiable, Hashable {
    let id = UUID()
    var production: Production?
    var recipients: [NoticeRecipient]   // 비어 있으면 전체
    var title: String
    var body: String

    // 답장: 보낸 사람 한 명에게
    static func reply(to notice: Notice) -> NoticeDraft {
        NoticeDraft(
            production: notice.production,
            recipients: notice.author.map { [.member($0)] } ?? [],
            title: prefixed("RE: ", notice.title),
            body: quoted(notice)
        )
    }

    // 전체 답장: 원래 받은 대상 + 보낸 사람. 전체 공지였으면 다시 전체
    static func replyAll(to notice: Notice) -> NoticeDraft {
        var recipients = notice.recipients
        let iSentIt = notice.isSent(byUserID: ICloudAccount.currentUserRecordName)
        if !recipients.isEmpty, !iSentIt, let author = notice.author, !recipients.contains(.member(author)) {
            recipients.append(.member(author))
        }
        return NoticeDraft(
            production: notice.production,
            recipients: recipients,
            title: prefixed("RE: ", notice.title),
            body: quoted(notice)
        )
    }

    // 전달: 같은 공연에서 받는 사람은 새로 고른다 (처음엔 전체)
    static func forward(_ notice: Notice) -> NoticeDraft {
        NoticeDraft(
            production: notice.production,
            recipients: [],
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
