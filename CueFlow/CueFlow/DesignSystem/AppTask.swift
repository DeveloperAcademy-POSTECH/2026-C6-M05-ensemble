//
//  AppTask.swift
//  CueFlow
//
//  .task 대신 쓴다 (#215). Xcode 27로 빌드하면 .task가 macOS 27에만 있는 부품(_TaskModifier2)으로 바뀌어서
//  macOS 26에서는 앱이 켜지자마자 죽는다 (App Store 1.0 (102) 충돌).
//  예전부터 있던 onAppear · onDisappear · onChange만 써서 .task와 같은 일을 한다:
//  화면이 뜨면 작업 시작 → 사라지면 취소 → id가 바뀌면 다시 시작.
//  ⚠️ 새 코드에서도 .task 말고 .appTask를 쓴다.
//

import SwiftUI

extension View {
    func appTask(_ action: @escaping @MainActor () async -> Void) -> some View {
        modifier(AppTaskModifier(id: 0, action: action))
    }

    func appTask<ID: Equatable>(id: ID, _ action: @escaping @MainActor () async -> Void) -> some View {
        modifier(AppTaskModifier(id: id, action: action))
    }
}

private struct AppTaskModifier<ID: Equatable>: ViewModifier {
    let id: ID
    let action: @MainActor () async -> Void
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear { start() }
            .onDisappear {
                task?.cancel()
                task = nil
            }
            .onChange(of: id) { start() }
    }

    private func start() {
        task?.cancel()
        task = Task { await action() }
    }
}
