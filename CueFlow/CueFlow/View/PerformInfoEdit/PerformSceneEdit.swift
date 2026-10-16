//
//  PerformSceneEdit.swift
//  CueFlow
//
//  Created by 김나현 on 10/16/26.
//

import SwiftUI
import SwiftData

struct PerformSceneEdit: View {
    @Binding var scenes: [ShowScene]   // 공연 흐름 순서대로. 생성 확인에서 공연에 붙인다
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}

    @State private var dropTargetID: UUID?   // 드래그 중 놓일 줄

    var body: some View {
        CreateStepLayout(
            title: "씬/넘버 구성해주세요",
            subtitle: "공연의 흐름을 워드처럼 입력하되, 각 줄을 씬 넘버 및 전환으로 구분합니다.",
            currentStep: 3,
            onPrevious: onPrevious,
            onNext: onNext
        ) {
            sceneCard
                .padding(.top, 43)
        }
    }
}

extension PerformSceneEdit {
    private var sceneCard: some View {
        VStack(spacing: 0) {
            cardHeader
            ForEach(scenes) { scene in
                divider
                row(scene)
            }
            divider
            SceneInputRow(scenes: scenes, onAdd: addScene)
        }
        .frame(width: 799)
        .background(.white, in: .rect(cornerRadius: 10))
        .overlay(cardBorder)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color.neutral200, lineWidth: 1)
    }

    // 공연 흐름                    씬3 넘버2 전환1
    private var cardHeader: some View {
        HStack {
            Text("공연 흐름")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.neutral900)
            Spacer()
            Text(countSummary)
                .font(.system(size: 15))
                .foregroundStyle(Color.neutral400)
        }
        .padding(.leading, 26)
        .padding(.trailing, 46)
        .frame(height: 80)
    }

    private var countSummary: String {
        "씬\(count(of: .scene)) 넘버\(count(of: .number)) 전환\(count(of: .transition))"
    }

    private var divider: some View {
        Color.neutral200
            .frame(height: 1)
    }

    private func row(_ scene: ShowScene) -> some View {
        SceneRow(scene: scene, code: scene.code(in: scenes)) { delete(scene) }
            .background(dropHighlight(for: scene))
            .dropDestination(for: String.self) { items, _ in
                moveScene(id: items.first, to: scene)
            } isTargeted: { isTargeted in
                updateDropTarget(scene, isTargeted: isTargeted)
            }
    }

    private func dropHighlight(for scene: ShowScene) -> Color {
        dropTargetID == scene.id ? Color.brandPrimarySubtle.opacity(0.3) : .clear
    }
}

// 추가 · 삭제 · 순서 바꾸기

extension PerformSceneEdit {
    private func count(of kind: SceneKind) -> Int {
        scenes.filter { $0.kind == kind }.count
    }

    private func addScene(title: String, kind: SceneKind) {
        scenes.append(ShowScene(title: title, kind: kind, order: scenes.count))
    }

    private func delete(_ scene: ShowScene) {
        scenes.removeAll { $0.id == scene.id }
        renumberOrder()
    }

    // 끌어온 줄을 놓은 줄 자리로 옮기기
    private func moveScene(id: String?, to target: ShowScene) -> Bool {
        guard let id,
              let from = scenes.firstIndex(where: { $0.id.uuidString == id }),
              let to = scenes.firstIndex(where: { $0.id == target.id }),
              from != to else { return false }
        let offset = to > from ? to + 1 : to
        withAnimation(.snappy) {
            scenes.move(fromOffsets: IndexSet(integer: from), toOffset: offset)
        }
        renumberOrder()
        return true
    }

    private func updateDropTarget(_ scene: ShowScene, isTargeted: Bool) {
        if isTargeted {
            dropTargetID = scene.id
        } else if dropTargetID == scene.id {
            dropTargetID = nil
        }
    }

    // 화면 순서대로 order를 0, 1, 2 … 로 다시 매김
    private func renumberOrder() {
        for (index, scene) in scenes.enumerated() {
            scene.order = index
        }
    }
}

#Preview {
    @Previewable @State var scenes: [ShowScene] = []
    PerformSceneEdit(scenes: $scenes)
        .frame(width: 1512, height: 982)
        .modelContainer(for: Production.self, inMemory: true)
        .onAppear {
            guard scenes.isEmpty else { return }
            scenes = [
                ShowScene(title: "프롤로그 : 툴롱 노역장", kind: .scene, order: 0),
                ShowScene(title: "Look Down", kind: .number, order: 1),
                ShowScene(title: "장면 전환 : 디뉴로 가는 길", kind: .transition, order: 2),
                ShowScene(title: "What Have I Done?", kind: .number, order: 3),
            ]
        }
}
