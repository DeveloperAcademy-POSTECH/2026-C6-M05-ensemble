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
    @State private var slots: [UUID: Int] = [:]   // 사이드바에서 옮긴 큐의 칸 번호 (빈칸 유지). 사이드바를 닫으면 사라짐
    var onSelectScene: (ShowScene) -> Void = { _ in }   // 위 씬 칩 목록에서 다른 씬을 골랐을 때
    @State private var isPickingScene = false   // 씬 고르는 팝오버가 열려 있는지

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
        .background(Color.neutral25.shadow(.drop(color: .black.opacity(0.25), radius: 2, y: 4)), in: .rect(cornerRadius: 10))   // 피그마 바깥쪽 그림자 (Y 4, 흐림 4, 검정 25%)
        .onAppear(perform: numberNewCues)
    }
}

// 위쪽: S#1 ⌄ / 씬 이름
extension CuePrioritySidebar {
    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            sceneChip
            Text(scene.title)
                .font(.body)
                .foregroundStyle(Color.neutral700)
        }
    }

    // S#1 ⌄ 누르면 씬 단축어 목록 → 고르면 그 열로 이동
    private var sceneChip: some View {
        Button { isPickingScene = true } label: { sceneChipLabel }
            .buttonStyle(.plain)
            .fixedSize()
            .appPopover(isPresented: $isPickingScene, width: nil) {
                PopoverCheckList(items: sortedScenes, selected: scene, title: { $0.code(in: sortedScenes) }) { onSelectScene($0) }
            }
    }

    private var sceneChipLabel: some View {
        HStack(spacing: 4) {
            Text(scene.code(in: sortedScenes))   // "S#1", "N#1" … 단축어만
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

    // 공연의 씬들 (왼쪽부터 순서대로)
    private var sortedScenes: [ShowScene] {
        (scene.production?.scenes ?? []).sorted { $0.order < $1.order }
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
            ForEach(cues(numbered: number)) { PriorityCueCard(cue: $0, number: number) }
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
    
    // 사이드바에서 이 큐가 놓인 칸 번호. 아직 안 옮겼으면 큐카드 번호 그대로
    private func slotNumber(of cue: Cue) -> Int {
        slots[cue.id] ?? cue.order
    }

    // 이 번호 칸에 들어갈 큐 (만든 순서)
    private func cues(numbered number: Int) -> [Cue] {
        sceneCues.filter { slotNumber(of: $0) == number }.sorted { $0.createdAt < $1.createdAt }
    }

    // 처음 열 때: 번호가 없는(00) 큐에 번호를 붙이고, 칸 수를 맞춤 (최소 5칸)
    // 같은 트리거의 큐는 같은 번호. 트리거 순서대로 다음 번호를 준다 (트리거에 이미 번호 있는 큐가 있으면 그 번호)
    private func numberNewCues() {
        closeGaps()   // 처음 열 때도 빈 번호부터 정리 → 열마다 1번부터
        var next = (sceneCues.map(\.order).max() ?? 0) + 1
        for trigger in (scene.triggers ?? []).sorted(by: { $0.order < $1.order }) {
            let newCues = (trigger.cues ?? []).filter { $0.order == 0 }
            guard !newCues.isEmpty else { continue }
            let number = (trigger.cues ?? []).first { $0.order > 0 }?.order ?? next
            for cue in newCues { cue.order = number }
            if number == next { next += 1 }
        }
        slotCount = max(5, next - 1)
    }

    // 끌어다 놓은 카드를 이 칸으로. 칸은 빈칸이 생겨도 그대로, 큐카드 번호는 빈칸 없이 당겨서 저장
    private func moveCue(id: String?, to number: Int) {
        guard let cue = sceneCues.first(where: { $0.id.uuidString == id }), slotNumber(of: cue) != number else { return }   // 없는 큐거나 같은 칸이면 그대로
        for sceneCue in sceneCues where slots[sceneCue.id] == nil { slots[sceneCue.id] = sceneCue.order }   // 지금 칸 기억 (번호가 당겨져도 칸은 그대로)
        let oldOrder = cue.order
        slots[cue.id] = number
        closeGaps()
        cue.addHistory("순서 변경", detail: "\(cue.editorName)님이 \(oldOrder)번 → \(cue.order)번으로 변경")
    }

    // 칸 번호(빈칸 포함) → 큐카드 번호: 빈칸은 건너뛰고 1번부터 (예: 칸 1, 3 → 번호 1, 2)
    // 사이드바의 칸은 그대로 두고, 큐카드에 저장되는 번호만 당긴다
    private func closeGaps() {
        let usedSlots = Set(sceneCues.map(slotNumber(of:))).filter { $0 > 0 }.sorted()
        for cue in sceneCues {
            let order = (usedSlots.firstIndex(of: slotNumber(of: cue)) ?? -1) + 1
            if cue.order != order { cue.order = order }
        }
    }
}

// 사이드바 안의 큐 카드: ≡ 손잡이 + 번호 · 트리거 · 제목 · 위치 (아래 버튼 없는 버전, 265 × 69)

private struct PriorityCueCard: View {
    let cue: Cue
    let number: Int   // 사이드바 칸 번호 (빈칸이 있어도 칸 그대로. 큐카드 번호와 다를 수 있음)

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
        Text(String(format: "%02d", number))
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
