//
//  HomeView.swift
//  CueFlow
//
//  프로젝트가 있을 때 홈 화면. 헤더 + 최근 프로젝트 카드 + 생성한 프로젝트 목록.
//

import SwiftData
import SwiftUI

// "최근 ⌄" 메뉴에서 고르는 목록 종류
enum ProjectFilter: String, CaseIterable {
    case recent = "최근"
    case favorite = "즐겨찾기"
}

struct HomeView: View {
    let productions: [Production]   // 최근에 수정한 순서로 들어온다
    var onRehearsal: (Production) -> Void = { _ in }   // 카드의 "리허설 모드"
    var onOpen: (Production) -> Void = { _ in }        // 카드의 "이어서 작업하기" · 목록 줄 → 메인 큐시트
    var onNewProject: () -> Void = {}                  // "새 프로젝트" → 새 공연 만들기 흐름

    // 안 읽은 알림이 있을 때만 종 옆에 빨간 점
    // TODO: 알림 기능이 생기면 실제 안 읽은 알림 여부로 바꾸기 (지금은 알림이 없어서 항상 false)
    var hasUnreadNotification = false

    @State private var filter: ProjectFilter = .recent
    @State private var deletingProduction: Production?   // 삭제 확인 창에 띄울 공연
    @Environment(\.modelContext) private var modelContext

    // 최근에 열어본 프로젝트 3개
    private var recentlyOpened: [Production] {
        Array(productions.sorted { $0.lastOpenedAt > $1.lastOpenedAt }.prefix(3))
    }

    // 메뉴에서 고른 종류에 맞는 프로젝트
    private var filteredProductions: [Production] {
        switch filter {
        case .recent:
            productions
        case .favorite:
            productions.filter { $0.isFavorite }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                recentProjects
                    .padding(.top, 45)

                projectList
                    .padding(.top, 73)
            }
            .padding(.horizontal, 40)
            .padding(.top, 37)
            .padding(.bottom, 40)
        }
        .alert(
            "\(deletingProduction?.title ?? "")을(를) 삭제할까요?",
            isPresented: Binding(get: { deletingProduction != nil }, set: { if !$0 { deletingProduction = nil } })
        ) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) { deleteProduction() }
        } message: {
            Text("큐시트 · 대본 · 공지가 모두 지워지고, 함께 쓰는 사람들에게서도 사라져요. 되돌릴 수 없어요.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            PageHeader(
                title: "프로젝트",
                subtitle: "새 공연을 만들거나 기존 프로젝트를 이어서 편집할 수 있습니다."
            )

            Spacer()

            // 아이콘 버튼은 40pt 틀 안에 있어서 간격 0이어도 그림 사이가 피그마 22pt
            HStack(spacing: 0) {
                if !UserTest.hidesUnfinished {
                    NotificationBellButton(hasUnread: hasUnreadNotification) {
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
                }

                Button {
                    onNewProject()
                } label: {
                    Label("새 프로젝트", systemImage: "plus")
                }
                .buttonStyle(.primary)
                .frame(width: 125, height: 40)
                .padding(.leading, 11)
            }
            .padding(.top, 3)
        }
    }

    private var recentProjects: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text("최근에 열어본 프로젝트")
                .font(.system(size: 20, weight: .semibold))   // 피그마 20pt (macOS 기본 스타일에 없음)
                .foregroundStyle(Color.neutral900)

            HStack(spacing: 22) {
                ForEach(recentlyOpened) { production in
                    RecentProjectCard(
                        lastWorked: production.lastWorkedText,
                        title: production.title,
                        tags: [production.genre],
                        runningTime: production.runningTimeText,
                        schedule: production.scheduleText,
                        seats: production.summaryText,
                        onRehearsal: {
                            production.lastOpenedAt = .now
                            onRehearsal(production)
                        },
                        onContinue: {
                            production.lastOpenedAt = .now
                            onOpen(production)
                        }
                    )
                    .contextMenu { deleteMenu(for: production) }
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
                    .foregroundStyle(Color.neutral900)
                Spacer()
                filterMenu
            }

            // 열 제목
            HStack(spacing: 0) {
                Text("프로젝트 이름")
                Spacer()
                Text("수정한 날짜")
                    .frame(width: ProjectListColumn.dateWidth, alignment: .leading)
                Text("소유자")
                    .frame(width: ProjectListColumn.ownerWidth)
            }
            .font(.body)
            .foregroundStyle(Color.neutral500)
            .padding(.trailing, ProjectListColumn.trailingPadding)
            .padding(.top, 21)

            ForEach(filteredProductions) { production in
                ProjectListRow(
                    name: production.listName,
                    modifiedDate: production.updatedDateText,
                    owner: production.ownerText,
                    isFavorite: production.isFavorite,
                    onToggleFavorite: { production.isFavorite.toggle() }
                )
                    .padding(.top, 19)
                    .padding(.bottom, 17)
                    .contentShape(Rectangle())
                    .onTapGesture {   // 줄을 누르면 그 공연의 큐시트 (별표 버튼은 따로 눌림)
                        production.lastOpenedAt = .now
                        onOpen(production)
                    }
                    .contextMenu { deleteMenu(for: production) }
                Divider()
            }
        }
    }

    // 우클릭 메뉴: 내가 만든 공연만 삭제할 수 있다
    // 공유받은 공연은 메뉴를 보이지 않는다 (지우면 만든 사람의 iCloud 폴더를 건드리게 된다)
    @ViewBuilder
    private func deleteMenu(for production: Production) -> some View {
        if !production.isSharedWithMe {
            Button("삭제하기", role: .destructive) { deletingProduction = production }
        }
    }

    // 지우고 저장하면 CloudSync가 iCloud 폴더째 지운다 → 함께 쓰는 사람에게서도 사라진다
    private func deleteProduction() {
        guard let deletingProduction else { return }
        modelContext.delete(deletingProduction)
        try? modelContext.save()
        self.deletingProduction = nil
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
            .foregroundStyle(Color.neutral500)
            .padding(.leading, 20)
            .padding(.trailing, 15)
            .frame(height: 36)
            .background(Color.homeSortBackground, in: Capsule())   // 피그마 #F6F6F6 → 색상 표에서 가장 가까운 neutral50
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
