//
//  CuePrioritySidebar.swift
//  CueFlow
//
//  Created by 김나현 on 10/29/26.
//

import SwiftUI
import SwiftData

// 씬 열의 ⓝ → 오른쪽 우선순위 사이드바 (피그마 순서박스지정사이드바, 폭 329)
// 번호 칸(1, 2, 3 …)에 큐 카드를 끌어다 놓으면 그 칸 번호가 큐 번호가 된다. 같은 칸 = 같은 번호
struct CuePrioritySidebar: View {
    let scene: ShowScene
    @State private var slotCount = 5   // 번호 칸 수 (+ 로 늘림)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                header
                slotList
            }
            .padding(.leading, 15)
            .padding(.trailing, 9)
            .padding(.vertical, 13)
        }
        .frame(width: 329)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.neutral25, in: .rect(cornerRadius: 10))
        .onAppear(perform: numberNewCues)
    }
}

// 위쪽: S#1 Scene ⌄ / 씬 이름

extension CuePrioritySidebar {
    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            sceneChip
            Text(scene.title)
                .font(.body)
                .foregroundStyle(Color.neutral700)
        }
    }

    private var sceneChip: some View {
        HStack(spacing: 4) {
            Text("\(sceneCode) Scene")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.neutral900)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.neutral500)
        }
        .padding(.horizontal, 13)
        .frame(height: 24)
        .background(Color.neutral200, in: .capsule)
    }

    // "S#1", "N#1" …
    private var sceneCode: String {
        let scenes = (scene.production?.scenes ?? []).sorted { $0.order < $1.order }
        return scene.code(in: scenes)
    }
}

// 번호 칸들 + 칸 추가

extension CuePrioritySidebar {
    private var slotList: some View {
        VStack(spacing: 10) {
            ForEach(1...slotCount, id: \.self) { slot($0) }
            addSlotButton
        }
    }

    // 번호 칸: 왼쪽 회색 띠(20)에 번호, 오른쪽에 그 번호의 큐 카드들. 카드를 끌어다 놓으면 이 번호가 됨
    private func slot(_ number: Int) -> some View {
        VStack(spacing: 5) {
            ForEach(cues(numbered: number)) { PriorityCueCard(cue: $0) }
        }
        .padding(.leading, 30)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 89, alignment: .top)
        .background(alignment: .leading) { slotNumber(number) }
        .background(Color.neutral100)
        .clipShape(.rect(cornerRadius: 4.5))
        .dropDestination(for: String.self) { ids, _ in moveCue(id: ids.first, to: number) }
    }

    private func slotNumber(_ number: Int) -> some View {
        Text("\(number)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.neutral600)
            .frame(width: 20)
            .frame(maxHeight: .infinity)
            .background(Color.neutral200)
    }

    // + 칸: 누르면 번호 칸이 하나 늘어남
    private var addSlotButton: some View {
        Button { slotCount += 1 } label: { addSlotLabel }
            .buttonStyle(.plain)
    }

    private var addSlotLabel: some View {
        Text("+")
            .font(.system(size: 16))
            .foregroundStyle(Color.neutral500)
            .frame(maxWidth: .infinity, minHeight: 89)
            .background(alignment: .leading) { Color.neutral200.frame(width: 20) }
            .background(Color.neutral100)
            .clipShape(.rect(cornerRadius: 4.5))
            .contentShape(.rect)
    }
}

// 데이터

extension CuePrioritySidebar {
    // 이 씬의 큐 전부 (모든 파트)
    private var sceneCues: [Cue] {
        (scene.triggers ?? []).flatMap { $0.cues ?? [] }
    }

    // 이 번호 칸에 들어갈 큐 (만든 순서)
    private func cues(numbered number: Int) -> [Cue] {
        sceneCues.filter { $0.order == number }.sorted { $0.createdAt < $1.createdAt }
    }

    // 처음 열 때: 번호가 없는(00) 큐에 1번부터 차례로 번호를 붙이고, 칸 수를 맞춤 (최소 5칸)
    private func numberNewCues() {
        closeGaps()   // 처음 열 때도 빈 번호부터 정리
        var next = (sceneCues.map(\.order).max() ?? 0) + 1
        for cue in sceneCues.filter({ $0.order == 0 }).sorted(by: { $0.createdAt < $1.createdAt }) {
            cue.order = next
            next += 1
        }
        slotCount = max(5, next - 1)
    }

    // 끌어다 놓은 카드를 이 번호로
    private func moveCue(id: String?, to number: Int) -> Bool {
        guard let cue = sceneCues.first(where: { $0.id.uuidString == id }), cue.order != number else { return false }
        cue.addHistory("순서 변경", detail: "\(CurrentEditor.name)님이 \(cue.order)번 → \(number)번으로 변경")
        cue.order = number
        closeGaps()   // 옮기고 나서 비는 번호가 생기면 당김
        return true
    }

    // 빈 번호를 없애고 1번부터 차례로 당김 (예: 1, 3, 4 → 1, 2, 3)
    private func closeGaps() {
        let usedNumbers = Set(sceneCues.map(\.order)).filter { $0 > 0 }.sorted()
        for (index, number) in usedNumbers.enumerated() where number != index + 1 {
            for cue in sceneCues where cue.order == number { cue.order = index + 1 }
        }
    }
}

// 사이드바 안의 큐 카드: ≡ 손잡이 + 번호 · 트리거 · 제목 · 위치 (아래 버튼 없는 버전, 265 × 69)

private struct PriorityCueCard: View {
    let cue: Cue

    var body: some View {
        cardContent
            .padding(.leading, 37)
            .padding(.trailing, 13)
            .padding(.top, 11)
            .frame(maxWidth: .infinity, minHeight: 69, alignment: .topLeading)
            .background(.white, in: .rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(partColor.background, lineWidth: 1))
            .overlay(alignment: .leading) { dragHandle }
            .draggable(cue.id.uuidString)
    }
}

extension PriorityCueCard {
    private var cardContent: some View {
        HStack(alignment: .top, spacing: 5) {
            numberCircle
            VStack(alignment: .leading, spacing: 5) {
                Text(cue.trigger?.text ?? "")
                    .font(.body)
                    .foregroundStyle(Color.neutral800)
                    .lineLimit(1)
                Text(cue.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.neutral900)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            positionTag
        }
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12))
            .foregroundStyle(Color.neutral800)
            .padding(.leading, 13)
    }

    private var numberCircle: some View {
        Text(String(format: "%02d", cue.order))
            .font(.callout.weight(.medium))
            .foregroundStyle(partColor.number)
            .frame(width: 23, height: 23)
            .background(partColor.background, in: .circle)
    }

    private var positionTag: some View {
        Text(cue.position.rawValue)
            .font(.callout.weight(.medium))
            .foregroundStyle(partColor.number)
            .padding(.horizontal, 5)
            .frame(height: 23)
            .background(partColor.background, in: .capsule)
    }

    private var partColor: PartColor {
        cue.part?.color ?? PartColor.at(0)
    }
}
