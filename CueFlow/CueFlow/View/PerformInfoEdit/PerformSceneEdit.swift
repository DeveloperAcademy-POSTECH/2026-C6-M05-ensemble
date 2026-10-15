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

    private static let steps = ["기본 정보", "파트 구성", "씬 구성", "생성 확인"]
    private static let currentStep = 3

    var body: some View {
        ScrollView {
            content
        }
        .overlay(alignment: .bottom) { footer }
        .frame(minWidth: 850)
        .background(.white)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            pageHeader
            stepBar
                .padding(.top, 20)
            sceneCard
                .padding(.top, 43)
        }
        .frame(width: 799)
        .padding(.top, 163)
        .padding(.bottom, 209)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        footerButtons
            .background(Color.neutral25)
            .frame(maxWidth: 1214, alignment: .trailing)
            .padding(.horizontal, 24)
            .padding(.bottom, 124)
    }
}

// 위쪽(제목 · 단계)

extension PerformSceneEdit {
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("씬/넘버 구성해주세요")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.neutral900)
            Text("공연의 흐름을 워드처럼 입력하되, 각 줄을 씬 넘버 및 전환으로 구분합니다.")
                .font(.system(size: 17))
                .foregroundStyle(Color.neutral500)
        }
    }

    private var stepBar: some View {
        HStack(spacing: 8) {
            ForEach(Self.steps.indices, id: \.self) { index in
                stepItem(number: index + 1, title: Self.steps[index])
                if index < Self.steps.count - 1 { stepLine }
            }
        }
    }

    private func stepItem(number: Int, title: String) -> some View {
        let isCurrent = number == Self.currentStep
        return HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isCurrent ? Color.neutral25 : Color.neutral500)
                .frame(width: 24, height: 24)
                .background(isCurrent ? Color.neutral400 : Color.neutral200, in: .circle)
            Text(title)
                .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? Color.neutral900 : Color.neutral400)
        }
    }

    private var stepLine: some View {
        Color.neutral300
            .frame(width: 50, height: 1)
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

// 아래 버튼

extension PerformSceneEdit {
    private var footerButtons: some View {
        HStack(spacing: 15) {
            Button("이전으로", action: onPrevious)
                .buttonStyle(.secondary)
                .frame(width: 175, height: 45)
            Button("다음으로", action: onNext)
                .buttonStyle(.primary)
                .frame(width: 175, height: 45)
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
