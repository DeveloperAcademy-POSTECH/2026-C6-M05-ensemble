//
//  NoticePreviewData.swift
//  CueFlow
//
//  Created by yunseo on 10/10/26.
//

import Foundation
import SwiftData

// 미리보기(Preview) 전용 예시 공지. 실제 앱 데이터에는 들어가지 않는다.
enum NoticePreviewData {
    @MainActor
    static var container: ModelContainer {
        let container = try! ModelContainer(
            for: Notice.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        for notice in samples {
            container.mainContext.insert(notice)
        }
        return container
    }

    static var samples: [Notice] {
        let sender = Member(name: "Rami", role: "무대감독")
        return (0..<8).map { index in
            let notice = Notice(
                title: "오늘 리허설 콜타임 변경 안내",
                body: "오늘 19:00 예정이던 리허설 콜타임이 18:40으로 변경되었습니다. 18:30까지 무대 뒤 대기 구역에 도착해 주세요."
            )
            notice.sentAt = Date().addingTimeInterval(Double(-index) * 86_400)
            notice.isImportant = (index == 0 || index == 3)   // 피그마처럼 1번, 4번만 중요
            notice.author = sender
            return notice
        }
    }
}
