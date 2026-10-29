//
//  HomePreviewData.swift
//  CueFlow
//
//  미리보기(Preview) 전용 예시 데이터. 실제 앱 데이터에는 들어가지 않는다.
//

import Foundation
import SwiftData

enum HomePreviewData {
    // 메모리에만 있는 저장소에 예시 공연 4개를 넣어서 돌려준다.
    @MainActor
    static var container: ModelContainer {
        let container = try! ModelContainer(
            for: Production.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        for production in samples {
            container.mainContext.insert(production)
        }
        return container
    }

    static var samples: [Production] {
        let names = ["레미제라블", "캣츠", "영웅", "별이 빛나는 밤에"]
        return names.enumerated().map { index, name in
            let production = Production(
                title: name,
                genre: "뮤지컬",
                firstShowDate: Date().addingTimeInterval(Double(30 + index * 20) * 86_400)
            )
            production.lastShowDate = production.firstShowDate.addingTimeInterval(86_400)   // 이틀 공연
            production.venue = "아트스페이스 A홀"
            production.seatCount = 1200
            production.runningTime = index == 0 ? 170 : nil   // 첫 카드만 러닝타임 (없을 때 줄이 숨는지 확인)
            production.lastOpenedAt = Date().addingTimeInterval(Double(-index) * 86_400)
            production.updatedAt = Date().addingTimeInterval(Double(-index) * 3_600)
            return production
        }
    }
}
