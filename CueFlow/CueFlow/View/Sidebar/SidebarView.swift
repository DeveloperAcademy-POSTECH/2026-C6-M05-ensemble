//
//  SidebarView.swift
//  CueFlow
//
//  왼쪽 사이드바. Q-Sheet 제목, 메뉴 목록, 다크모드 버튼.
//

import SwiftUI

struct SidebarView: View {
    // ContentView가 가진 선택값을 같이 쓴다. 여기서 바꾸면 ContentView에도 반영된다.
    @Binding var selectedMenu: SidebarMenu
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Q-Sheet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brandPrimaryText)
                .padding(.leading, 24)
                .padding(.top, 23)

            VStack(spacing: 10) {
                ForEach(SidebarMenu.allCases, id: \.self) { menu in
                    SidebarMenuRow(
                        menu: menu,
                        isSelected: selectedMenu == menu,
                        badgeCount: menu == .notice ? 2 : 0   // TODO: 공지사항 작업 때 안 읽은 개수로 바꾸기
                    ) {
                        selectedMenu = menu
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 15)

            Spacer()

            Button {
                // TODO: 다크모드 전환
            } label: {
                Text("다크모드")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brandPrimaryText)
                    .frame(width: 150, height: 35)
                    .background(Color.brandPrimarySubtle, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 36)
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
            .font(.body.weight(isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? Color.white : Color.brandPrimaryText)
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .frame(height: 35)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.brandPrimary)
                        .shadow(color: Color.brandPrimary, radius: 0.5, x: 2, y: 2)
                }
            }
            .contentShape(Rectangle())   // 글자 말고 빈 곳을 눌러도 선택되게
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SidebarView(selectedMenu: .constant(.project))
        .frame(width: 220, height: 700)
}
