//
//  HomeView.swift
//  CueFlow
//
//  프로젝트가 있을 때 홈 화면. 헤더 + 최근 프로젝트 카드 + 생성한 프로젝트 목록.
//

import SwiftUI

// "최근 ⌄" 메뉴에서 고르는 목록 종류
enum ProjectFilter: String, CaseIterable {
    case recent = "최근"
    case shared = "공유됨"
    case favorite = "즐겨찾기"
}

struct HomeView: View {
    let productions: [Production]   // 최근에 수정한 순서로 들어온다

    @State private var filter: ProjectFilter = .recent

    // 최근에 열어본 프로젝트 3개
    private var recentlyOpened: [Production] {
        Array(productions.sorted { $0.lastOpenedAt > $1.lastOpenedAt }.prefix(3))
    }

    // 메뉴에서 고른 종류에 맞는 프로젝트
    private var filteredProductions: [Production] {
        switch filter {
        case .recent:
            productions
        case .shared:
            productions   // TODO: 공유 기능이 생기면 공유받은 프로젝트만
        case .favorite:
            productions.filter { $0.isFavorite }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                recentProjects
                    .padding(.top, 117)

                projectList
                    .padding(.top, 92)
            }
            .padding(.horizontal, 40)
            .padding(.top, 37)
            .padding(.bottom, 40)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            PageHeader(
                title: "프로젝트",
                subtitle: "새 공연을 만들거나 기존 프로젝트를 이어서 편집할 수 있습니다."
            )

            Spacer()

            HStack(spacing: 10) {
                // TODO: 다크모드 스위치 — 디자인 수정 중이라 확정되면 추가

                NotificationBellButton(hasUnread: true) {
                    // TODO: 알림 목록 열기
                }

                Button {
                    // TODO: 설정 화면 (동작 미정)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brandPrimary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("설정")

                Button {
                    // TODO: 프로젝트 생성 화면으로 이동 (다른 팀원 담당 화면)
                } label: {
                    Label("새 프로젝트", systemImage: "plus")
                }
                .buttonStyle(.primary)
                .frame(width: 125, height: 40)
            }
            .padding(.top, 5)
        }
    }

    private var recentProjects: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("최근에 열어본 프로젝트")
                .font(.system(size: 20, weight: .semibold))   // 피그마 20pt (macOS 기본 스타일에 없음)

            HStack(spacing: 21) {
                ForEach(recentlyOpened) { production in
                    RecentProjectCard(
                        lastWorked: production.lastWorkedText,
                        title: production.cardTitle,
                        summary: "",   // TODO: 공연장 규모·회차 (모델에 아직 없음)
                        members: production.memberCountText,
                        schedule: production.scheduleText,
                        onRehearsal: {
                            production.lastOpenedAt = .now
                            // TODO: 리허설 모드로 이동
                        },
                        onContinue: {
                            production.lastOpenedAt = .now
                            // TODO: 큐시트 화면으로 이동 (다른 팀원 담당 화면)
                        }
                    )
                }

                // 카드가 3장보다 적으면 빈자리를 채워서 카드 폭이 일정하게
                ForEach(recentlyOpened.count..<3, id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
            }
        }
    }

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("생성한 프로젝트")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                filterMenu
            }

            // 열 제목
            HStack(spacing: 0) {
                Spacer()
                Text("수정한 날짜")
                    .frame(width: ProjectListColumn.dateWidth, alignment: .leading)
                Text("소유자")
                    .frame(width: ProjectListColumn.ownerWidth, alignment: .trailing)
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.trailing, ProjectListColumn.trailingPadding)
            .padding(.top, 20)

            ForEach(filteredProductions) { production in
                ProjectListRow(
                    name: production.listName,
                    modifiedDate: production.updatedDateText,
                    owner: ""   // TODO: 소유자 (모델에 아직 없음)
                )
                    .padding(.top, 18)
                    .padding(.bottom, 21)
                Divider()
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            ForEach(ProjectFilter.allCases, id: \.self) { item in
                Button(item.rawValue) {
                    filter = item
                }
            }
        } label: {
            HStack(spacing: 11) {
                Text(filter.rawValue)
                    .font(.title2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
            .padding(.leading, 20)
            .padding(.trailing, 15)
            .frame(height: 36)
            .background(Color(nsColor: .quaternarySystemFill), in: Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// 알림 벨 버튼. 안 읽은 알림이 있으면 빨간 점을 보여준다.
struct NotificationBellButton: View {
    let hasUnread: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "bell")
                .font(.system(size: 18))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 40, height: 40)
                .overlay {
                    if hasUnread {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                            .offset(x: 6, y: -6)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(productions: HomePreviewData.samples)
        .frame(width: 1290, height: 930)
}
