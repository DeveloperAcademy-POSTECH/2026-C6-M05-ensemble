//
//  AppPopover.swift
//  CueFlow
//
//  Created by 김나현 on 10/29/26.
//

import SwiftUI

// (애플 .popover 대신) 겉모양 값은 PopoverStyle.swift
//
// 사용법
// ① 팝오버를 여는 뷰에 붙임
//      .appPopover(isPresented: $isAddingPart) { AddPart(onSave: addPart) }
//      .appPopover(isPresented: $isEditing, edge: .trailing, width: nil, background: .display) { … }
//      - edge: 연 뷰의 아래(.bottom, 기본) / 오른쪽(.trailing)에 띄움
//      - width: 피그마 폭 (기본 240, nil이면 내용만큼)
//      - background: .input = Neutral/25 (기본, 입력 팝오버) / .display = 흰색 70% (보기 팝오버)
// ② 그 화면 맨 바깥 뷰에 한 번 붙임 (팝오버가 여기에 그려져서 표 · 스크롤에 안 잘림)
//      .appPopoverHost()
// ③ 팝오버 안에서 닫을 때 (Enter로 저장한 뒤 등)
//      @Environment(\.closeAppPopover) private var closePopover   →   closePopover()
//
// 바깥을 클릭하거나 Esc를 누르면 저절로 닫힌다
// 팝오버 안 내용 뷰에는 패딩 · 폭 · 배경을 넣지 않는다 (겉모양이 다 넣어줌)

extension View {
    func appPopover<Content: View>(
        isPresented: Binding<Bool>,
        edge: Edge = .bottom,                    // 연 뷰의 아래(.bottom) / 오른쪽(.trailing)에 띄움
        width: CGFloat? = 240,
        background: PopoverBackground = .input,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let popover = content().popoverStyle(width: width, background: background)
        return anchorPreference(key: AppPopoverKey.self, value: .bounds) { anchor in
            guard isPresented.wrappedValue else { return [] }
            let close = { isPresented.wrappedValue = false }
            return [AppPopoverItem(anchor: anchor, edge: edge, content: AnyView(popover.environment(\.closeAppPopover, CloseAppPopoverAction(close: close))), close: close)]
        }
    }

    func appPopoverHost() -> some View {
        overlayPreferenceValue(AppPopoverKey.self) { AppPopoverLayer(items: $0) }
            .transformPreference(AppPopoverKey.self) { $0 = [] }   // 여기서 그린 팝오버는 더 바깥으로 안 올려보냄 (두 번 그려지지 않게)
    }
}

// 팝오버 안에서 스스로 닫을 때 쓰는 값 (appPopover가 넣어줌). 쓰는 법: closePopover()
struct CloseAppPopoverAction {
    let close: () -> Void
    func callAsFunction() { close() }   // closePopover() 처럼 함수처럼 부를 수 있게
}

extension EnvironmentValues {
    @Entry var closeAppPopover = CloseAppPopoverAction(close: {})
}

// 열린 팝오버 하나
struct AppPopoverItem {
    let anchor: Anchor<CGRect>   // 팝오버를 연 뷰의 자리
    let edge: Edge
    let content: AnyView
    let close: () -> Void
}

// 열린 팝오버들을 화면 맨 바깥(appPopoverHost)까지 올려 보내는 키
struct AppPopoverKey: PreferenceKey {
    static let defaultValue: [AppPopoverItem] = []
    static func reduce(value: inout [AppPopoverItem], nextValue: () -> [AppPopoverItem]) {
        value.append(contentsOf: nextValue())
    }
}

// 열린 팝오버를 연 뷰 옆에 그림 + 바깥을 누르면 닫힘
// 화면 끝에 닿으면 안쪽으로 당겨서 잘리지 않게 함
struct AppPopoverLayer: View {
    let items: [AppPopoverItem]
    @State private var sizes: [Int: CGSize] = [:]   // 팝오버마다 실제 크기 (화면 끝 계산용)

    var body: some View {
        GeometryReader { proxy in
            ForEach(items.indices, id: \.self) { popover(at: $0, in: proxy) }
        }
    }

    private func popover(at index: Int, in proxy: GeometryProxy) -> some View {
        let item = items[index]
        return ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(.rect)
                .onTapGesture(perform: item.close)    // 바깥 클릭하면 닫힘
            item.content.appPopoverHost()            // 팝오버 안에서 여는 팝오버(위치 · 종류 고르기)는 이 팝오버 위에 그려짐
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { sizes[index] = $0 }
                .offset(position(of: item, size: sizes[index] ?? .zero, in: proxy))
                .onExitCommand(perform: item.close)   // Esc 누르면 닫힘
        }
    }

    // 원래 자리에 놓되, 화면 밖으로 나가면 안쪽으로 당김
    private func position(of item: AppPopoverItem, size: CGSize, in proxy: GeometryProxy) -> CGSize {
        let start = startPoint(of: item, in: proxy)
        let maxX = proxy.size.width - size.width - 8     // 이보다 오른쪽이면 화면 밖으로 나감
        let maxY = proxy.size.height - size.height - 8   // 이보다 아래면 화면 밖으로 나감
        return CGSize(width: min(start.x, maxX), height: min(start.y, maxY))
    }

    // 원래 자리: .bottom이면 버튼 바로 아래, .trailing이면 버튼 바로 오른쪽 (8 띄움)
    private func startPoint(of item: AppPopoverItem, in proxy: GeometryProxy) -> CGPoint {
        let rect = proxy[item.anchor]
        if item.edge == .trailing { return CGPoint(x: rect.maxX + 8, y: rect.minY) }
        return CGPoint(x: rect.minX, y: rect.maxY + 8)
    }
}
