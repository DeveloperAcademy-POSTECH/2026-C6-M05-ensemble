//
//  Notice+List.swift
//  CueFlow
//
//  Created by yunseo on 10/10/26.
//

import Foundation

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
}
