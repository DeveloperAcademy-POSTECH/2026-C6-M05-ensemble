//
//  PageHeader.swift
//  CueFlow
//
//  화면 맨 위 제목 + 설명. 홈, 공지사항 등에서 같이 쓴다.
//

import SwiftUI

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PageHeader(title: "프로젝트", subtitle: "새 공연을 만들거나 기존 프로젝트를 이어서 편집할 수 있습니다.")
        .padding()
}
