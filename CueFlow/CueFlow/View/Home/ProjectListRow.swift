//
//  ProjectListRow.swift
//  CueFlow
//
//  홈 화면 "생성한 프로젝트" 목록의 한 줄.
//

import SwiftUI

struct ProjectListRow: View {
    let name: String        // 예: "뮤지컬_레미제라블"
    let modifiedDate: String // 예: "9월 28일"
    let owner: String       // 예: "Rami"

    var body: some View {
        HStack(spacing: 31) {
            // 썸네일 자리 (이미지는 아직 없음)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .quaternarySystemFill))
                .frame(width: 50, height: 50)

            Text(name)
                .font(.body)

            Spacer()

            HStack(spacing: 0) {
                Text(modifiedDate)
                    .frame(width: ProjectListColumn.dateWidth, alignment: .leading)
                Text(owner)
                    .frame(width: ProjectListColumn.ownerWidth, alignment: .trailing)
            }
            .font(.body.weight(.semibold))
            .padding(.trailing, ProjectListColumn.trailingPadding)
        }
        .lineLimit(1)
    }
}

// 열 제목과 각 줄의 날짜·소유자 위치를 맞추기 위한 값
enum ProjectListColumn {
    static let dateWidth: CGFloat = 140
    static let ownerWidth: CGFloat = 60
    static let trailingPadding: CGFloat = 50
}

#Preview {
    ProjectListRow(name: "뮤지컬_레미제라블", modifiedDate: "9월 28일", owner: "Rami")
        .frame(width: 1200)
        .padding()
}
