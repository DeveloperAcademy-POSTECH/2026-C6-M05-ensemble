//
//  PopoverMenu.swift
//  CueFlow
//
//  Created by 김나현 on 10/29/26.
//

import SwiftUI

// 팝오버 안에 넣는 메뉴 부품 (애플 Menu · Picker 대신 사용 → 리퀴드 글래스 X)
//
// 사용법
// ① 하나 고르기 (피그마 무대위치: ✓ + 글자)
// ② 메뉴 (피그마 큐카드우클릭: 글자 줄 + 구분선)
//      .appPopover(isPresented: $isShowingMenu, edge: .trailing, width: nil) {
//          PopoverMenu {
//              PopoverMenuItem("큐 수정하기") { isEditingCue = true }
//              PopoverMenuDivider()
//              PopoverMenuItem("큐 삭제하기") { modelContext.deleteCue(cue) }
//          }
//      }
// 고르거나 누르면 팝오버는 저절로 닫힌다

struct PopoverCheckList<Item: Hashable>: View {
    let items: [Item]
    let selected: Item?
    let title: (Item) -> String
    let onSelect: (Item) -> Void
    @Environment(\.closeAppPopover) private var closePopover

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(items, id: \.self) { row($0) }
        }
    }

    private func row(_ item: Item) -> some View {
        Button {
            onSelect(item)
            closePopover()
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 12)
                    .opacity(item == selected ? 1 : 0)
                Text(title(item))
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// ② 메뉴 묶음
struct PopoverMenu<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) { content }
            .frame(width: 91, alignment: .leading)
    }
}

// 메뉴 한 줄. 누르면 팝오버 닫고 할 일
struct PopoverMenuItem: View {
    let title: String
    let action: () -> Void
    @Environment(\.closeAppPopover) private var closePopover

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            closePopover()
            action()
        } label: {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// 메뉴 묶음 사이 구분선
struct PopoverMenuDivider: View {
    var body: some View {
        Color.neutral300
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

// 우클릭했을 때 할 일
// SwiftUI는 우클릭이 시스템 메뉴(contextMenu)뿐이라, 우클릭만 AppKit으로 받음
extension View {
    func onRightClick(perform action: @escaping () -> Void) -> some View {
        overlay { RightClickCatcher(action: action) }
    }
}

// 우클릭만 받고, 왼쪽 클릭 · 드래그 · 마우스 올리기는 아래 뷰로 그대로 통과시키는 투명 판
struct RightClickCatcher: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> CatcherView { CatcherView() }
    func updateNSView(_ view: CatcherView, context: Context) { view.action = action }

    final class CatcherView: NSView {
        var action: () -> Void = {}

        override func hitTest(_ point: NSPoint) -> NSView? {
            NSApp.currentEvent?.type == .rightMouseDown ? super.hitTest(point) : nil
        }

        override func rightMouseDown(with event: NSEvent) { action() }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 40) {
        PopoverCheckList(items: CuePosition.allCases, selected: .sangsu, title: \.rawValue) { _ in }
            .popoverStyle(width: nil)
        PopoverMenu {
            PopoverMenuItem("큐 수정하기") {}
            PopoverMenuItem("History") {}
            PopoverMenuDivider()
            PopoverMenuItem("큐 삭제하기") {}
        }
        .popoverStyle(width: nil)
    }
    .padding(60)
}
