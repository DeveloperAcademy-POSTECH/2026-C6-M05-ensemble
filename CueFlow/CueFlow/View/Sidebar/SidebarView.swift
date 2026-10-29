//
//  SidebarView.swift
//  CueFlow
//
//  왼쪽 사이드바. Q-Sheet 제목, 메뉴 목록(홈 · 큐시트 · 공지사항 · 도움말), 다크모드 버튼.
//  큐시트는 화면이 아니라 펼치기 목록 — 공연 이름을 누르면 그 공연 통합 큐시트로 간다.
//  공연 안(큐시트)에 들어가 있으면 어느 메뉴도 선택 표시를 하지 않는다 (피그마 · 팀 결정).
//

import SwiftUI

struct SidebarView: View {
    // ContentView가 가진 선택값을 같이 쓴다. 여기서 바꾸면 ContentView에도 반영된다.
    @Binding var selectedMenu: SidebarMenu
    var productions: [Production] = []          // 큐시트 펼치기 목록에 보일 공연
    var isInProduction = false                  // 공연 큐시트를 보고 있으면 true → 선택 표시 없음
    var onOpenProduction: (Production) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Cuedit")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brandPrimaryText)
                .padding(.leading, 24)
                .padding(.top, 23)

            VStack(spacing: 10) {
                ForEach(SidebarMenu.visibleCases, id: \.self) { menu in
                    SidebarMenuRow(
                        menu: menu,
                        isSelected: !isInProduction && selectedMenu == menu,
                        badgeCount: 0   // TODO: #33 공지사항 머지 후 공지사항 메뉴에 안 읽은 개수
                    ) {
                        selectedMenu = menu
                    }
                    // 홈 바로 아래에 큐시트 펼치기 목록
                    if menu == .project {
                        SidebarCueSheetGroup(productions: productions, onOpen: onOpenProduction)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 15)

            Spacer()

            DarkModeToggle()
                .padding(.leading, 28)
                .padding(.bottom, 37)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
    }
}

// 메뉴 한 줄
struct SidebarMenuRow: View {
    let menu: SidebarMenu
    let isSelected: Bool
    var badgeCount: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: menu.icon)
                Text(menu.title)
                Spacer()
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(width: 24, height: 24)
                        .background(Color.brandPrimarySubtle, in: Circle())
                }
            }
            // 피그마: 글자 13 semibold neutral900, 선택된 메뉴는 연보라 바탕
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.neutral900)
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .frame(height: 35)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.brandPrimarySubtle)
                }
            }
            .contentShape(Rectangle())   // 글자 말고 빈 곳을 눌러도 선택되게
        }
        .buttonStyle(.plain)
    }
}

// 큐시트 펼치기 목록: [큐시트 ⌄] 줄을 누르면 접고 펴고, 아래 공연 이름을 누르면 그 공연 큐시트로
struct SidebarCueSheetGroup: View {
    let productions: [Production]
    let onOpen: (Production) -> Void

    @State private var isExpanded = true   // 피그마: 펼친 상태

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "rectangle.grid.2x2")
                    Text("큐시트")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .padding(.trailing, 10)
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.neutral900)
                .padding(.leading, 14)
                .frame(height: 35)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(productions) { production in
                    Button {
                        onOpen(production)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                            Text(production.title.isEmpty ? "제목 없는 공연" : production.title)
                                .lineLimit(1)
                            Spacer()
                        }
                        .font(.body)
                        .foregroundStyle(Color.neutral900)
                        .padding(.leading, 16)
                        .frame(height: 29)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// 사이드바 왼쪽 아래 다크모드 스위치. 라이트면 손잡이 왼쪽 + 달, 다크면 손잡이 오른쪽 + 해.
// 값은 앱 전체가 같이 쓰도록 AppStorage에 저장한다 (CueFlowApp에서 화면 모드에 적용).
// TODO: 셀리나 색상 표에 Neutral 회색이 추가되면 바탕색 교체
struct DarkModeToggle: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDarkMode.toggle()
            }
        } label: {
            ZStack(alignment: isDarkMode ? .trailing : .leading) {
                // 아이콘: 손잡이 반대쪽에 보인다
                Image(systemName: isDarkMode ? "sun.min" : "moon")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .frame(width: 30)
                    .frame(maxWidth: .infinity, alignment: isDarkMode ? .leading : .trailing)
                    .padding(.horizontal, 6)

                // 손잡이
                Capsule()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 44, height: 28)
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                    .padding(.horizontal, 6)
            }
            .frame(width: 94, height: 40)
            .background(Color(nsColor: .quaternarySystemFill), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(isDarkMode ? "라이트 모드로 바꾸기" : "다크 모드로 바꾸기")
    }
}

#Preview {
    SidebarView(selectedMenu: .constant(.project))
        .frame(width: 220, height: 700)
}
