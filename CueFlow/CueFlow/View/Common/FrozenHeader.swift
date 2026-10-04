//
//  FrozenHeader.swift
//  CueFlow
//
//  표의 윗줄(씬)과 왼쪽 열(파트)을 스크롤해도 제자리에 고정.
//  같은 Grid 안에서 헤더 칸만 스크롤한 만큼 반대로 밀어주는 방식이라 행 높이·열 폭이 항상 맞는다.
//

import SwiftUI

// 스크롤 위치. 고정 헤더 칸만 이 값을 읽어서, 스크롤할 때 헤더만 다시 그려짐 (본문 칸은 안 건드림)
@Observable
final class ScrollOffset {
    var x: CGFloat = 0
    var y: CGFloat = 0
}

// 가로·세로 스크롤 + 스크롤 위치를 헤더 칸에 전달
struct FrozenHeaderScrollView<Content: View>: View {
    @State private var offset = ScrollOffset()
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView([.horizontal, .vertical]) { content }
            .onScrollGeometryChange(for: CGPoint.self) { geo in
                CGPoint(x: geo.contentOffset.x + geo.contentInsets.leading,
                        y: geo.contentOffset.y + geo.contentInsets.top)
            } action: { _, new in
                offset.x = max(0, new.x)
                offset.y = max(0, new.y)
            }
            .environment(offset)
    }
}

// 스크롤한 만큼 반대로 밀어서 제자리에 고정. Grid 바로 아래 칸에 붙여야 함
private struct Pinned: ViewModifier {
    let x: Bool, y: Bool
    @Environment(ScrollOffset.self) private var offset

    func body(content: Content) -> some View {
        content
            .background(.white)       // 불투명 배경으로 아래로 지나가는 칸을 가림
            .offset(x: x ? offset.x : 0, y: y ? offset.y : 0)
            .zIndex(x && y ? 2 : 1)   // 모서리 칸이 맨 위
    }
}

extension View {
    // x: 왼쪽 열 고정, y: 윗줄 고정, 둘 다: 왼쪽 위 모서리
    func pinned(x: Bool = false, y: Bool = false) -> some View {
        modifier(Pinned(x: x, y: y))
    }
}
