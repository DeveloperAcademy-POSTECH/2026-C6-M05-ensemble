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
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 31) {
            // 썸네일 자리 (이미지는 아직 없음)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.neutral100)
                .frame(width: 50, height: 50)

            Text(name)
                .font(.body)
                .foregroundStyle(Color.neutral800)

            Spacer()

            HStack(spacing: 0) {
                favoriteButton
                    .frame(width: ProjectListColumn.starWidth, alignment: .leading)
                Text(modifiedDate)
                    .frame(width: ProjectListColumn.dateWidth, alignment: .leading)
                Text(owner)
                    .frame(width: ProjectListColumn.ownerWidth)
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.neutral700)
            .padding(.trailing, ProjectListColumn.trailingPadding)
        }
        .lineLimit(1)
        .contentShape(Rectangle())   // 빈 곳에 올려도 호버로 친다
        .onHover { isHovering = $0 }
    }

    // 별표: 마우스를 올렸을 때만 보인다. 즐겨찾기한 줄은 항상 채운 별로 보인다.
    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            // 피그마: 빈 별 14 neutral400, 채운 별 15 연보라
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: isFavorite ? 15 : 14))
                .foregroundStyle(isFavorite ? Color.brandPrimaryDisabled : Color.neutral400)
        }
        .buttonStyle(.plain)
        .opacity(isFavorite || isHovering ? 1 : 0)
        .help(isFavorite ? "즐겨찾기 해제" : "즐겨찾기")
    }
}

// 열 제목과 각 줄의 날짜·소유자 위치를 맞추기 위한 값
enum ProjectListColumn {
    static let starWidth: CGFloat = 78
    static let dateWidth: CGFloat = 108
    static let ownerWidth: CGFloat = 50   // 소유자는 열 제목 가운데에 맞춘다
    static let trailingPadding: CGFloat = 18
}

#Preview {
    ProjectListRow(name: "뮤지컬_레미제라블", modifiedDate: "9월 28일", owner: "Rami", isFavorite: false, onToggleFavorite: {})
        .frame(width: 1200)
        .padding()
}
