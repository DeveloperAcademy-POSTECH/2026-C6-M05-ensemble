//
//  CueGrid.swift
//  CueFlow
//
//  Created by 김나현 on 10/11/26.
//

import SwiftUI
import SwiftData

struct CueGrid: View {
    let production: Production                    // 어느 공연의 표인지
    var selectedPart: Part? = nil                 // 파트 탭바에서 고른 파트 (nil = 전체)
    var remoteRevision = 0                        // iCloud에서 받을 때마다 +1 → 표를 다시 그린다
    var onShowHistory: (Cue) -> Void = { _ in }   // 큐 카드 우클릭 → History
    @Binding var priorityScene: ShowScene?        // 우선순위 사이드바에 보여줄 씬 (nil = 닫힘)
    @Environment(\.modelContext) private var modelContext   // 새 큐를 저장할 곳

    @State private var hoveredSlotKey: String?    // 마우스가 올라가 있는 칸 (파트id-씬id)
    @State private var isAddingScene = false      // 씬 추가 팝오버가 열려 있는지
    @State private var isAddingPart = false       // 파트 추가 팝오버가 열려 있는지
    @State private var editingScene: ShowScene?   // 더블클릭해서 수정 중인 씬
    @State private var editingPart: Part?         // 더블클릭해서 수정 중인 파트
    @State private var selectedScene: ShowScene?  // 머리칸을 눌러 고른 씬 열 (nil = 선택 안 함)
    @State private var selectedCueIDs: Set<UUID> = []   // 선택된 큐 카드들 (shift로 여러 개)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                cueTable
            }
            .contentMargins(.vertical, 12, for: .scrollContent)
            .onChange(of: priorityScene) { moveToColumn($1, proxy: proxy) }
        }
    }
}

// 표 전체

extension CueGrid {
    // 머리줄 + 파트 줄들 + 파트 추가 줄("전체"일 때만)
    private var cueTable: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            headerRow
            ForEach(visibleParts) { partRow($0) }
            if selectedPart == nil { addPartRow }   // "전체"일 때만 + 파트 추가 줄
        }
        .overlay(alignment: .topLeading) { selectedColumnEffect }
        .animation(.easeInOut(duration: 0.25), value: selectedScene)   // 선택 · 해제할 때 부드럽게
        .onTapGesture { clearSelection() }   // 표의 다른 곳을 누르면 선택 해제
        .background { escapeShortcut }          // Esc 키로 선택 해제
    }
    
    private var headerRow: some View {
        GridRow {
            cornerHeaderCell
            ForEach(sortedScenes) { sceneHeaderCell($0) }
            addSceneHeaderCell
        }
    }
    
    private func partRow(_ part: Part) -> some View {
        GridRow {
            partHeaderCell(part)
            ForEach(sortedScenes) { scene in cueCellSlot(part: part, scene: scene) }
            emptyCell(width: GridStyle.addSceneColumnWidth)
        }
    }
    
    private var addPartRow: some View {
        GridRow {
            addPartHeaderCell
            ForEach(sortedScenes) { _ in emptyCell(width: GridStyle.sceneColumnWidth) }
            emptyCell(width: GridStyle.addSceneColumnWidth)
        }
    }
}

// 칸
extension CueGrid {
    // 왼쪽 위 모서리 칸
    private var cornerHeaderCell: some View {
        Text("파트 / 씬")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.neutral900)
            .padding(.leading, 16)
            .padding(.top, 19)
            .frame(width: GridStyle.partColumnWidth, height: GridStyle.headerHeight, alignment: .topLeading)
            .background(Color.neutral50)
            .gridCellBorder()
    }
    
    // 씬 머리칸: 윗줄은 S#1 / N#1 / 전환, 아랫줄은 입력한 내용
    private func sceneHeaderCell(_ scene: ShowScene) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sceneLabel(for: scene))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.neutral900)
            Text(scene.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.neutral700)
                .lineLimit(1)
        }
        .padding(.leading, 14)
        .padding(.top, 19)
        .frame(width: GridStyle.sceneColumnWidth, height: GridStyle.headerHeight, alignment: .topLeading)
        .background(Color.neutral50)
        .gridCellBorder()
        .contentShape(.rect)
        .id(scene.id)   // 사이드바에서 고른 씬 열로 스크롤할 때 찾는 이름표
        .onTapGesture(count: 2) { editingScene = scene }   // 더블클릭하면 수정 팝오버
        .onTapGesture { selectColumn(scene) }   // 한 번 누르면 이 씬 열 선택
        .overlay(alignment: .topTrailing) { selectedMark(for: scene) }
        .appPopover(isPresented: isEditing(scene)) {
            AddScene(title: scene.title, kind: scene.kind) { scene.title = $0; scene.kind = $1 }
        }
        .contextMenu {   // 우클릭 메뉴
            Button("삭제", role: .destructive) { deleteScene(scene) }
        }
    }
    
    // + 씬 추가 칸
    private var addSceneHeaderCell: some View {
        Button { isAddingScene = true } label: { Text("+").font(.system(size: 25, weight: .semibold)) }
            .appPopover(isPresented: $isAddingScene) { AddScene(onSave: addScene) }
            .buttonStyle(.plain)
            .foregroundStyle(Color.neutral900)
            .frame(width: GridStyle.addSceneColumnWidth, height: GridStyle.headerHeight)
            .background(Color.neutral50)
            .gridCellBorder()
    }
    
    // 파트 칸: 파트 이름(왼쪽 위, 피그마 위치) + 왼쪽 파트색 막대
    private func partHeaderCell(_ part: Part) -> some View {
        Text(part.name)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.neutral900)
            .padding(.leading, 15)
            .padding(.top, 25)
            .frame(width: GridStyle.partColumnWidth, alignment: .leading)
            .frame(minHeight: GridStyle.minRowHeight, maxHeight: .infinity, alignment: .top)
            .background(Color.neutral25)
            .overlay(alignment: .leading) { part.color.accent.frame(width: 6) }
            .gridCellBorder()
            .contentShape(.rect)
            .onTapGesture(count: 2) { editingPart = part }   // 더블클릭하면 수정 팝오버
            .appPopover(isPresented: isEditing(part), edge: .trailing) {
                AddPart(name: part.name) { part.name = $0 }
            }
            .contextMenu {   // 우클릭 메뉴
                Button("삭제", role: .destructive) { deletePart(part) }
            }
    }
    
    // 파트 × 씬 칸: 큐가 있으면 항상 보이고, 비어 있으면 마우스를 올렸을 때만 셀이 보임
    private func cueCellSlot(part: Part, scene: ShowScene) -> some View {
        let key = "\(part.id)-\(scene.id)"                              // 이 칸의 이름표
        let slotCues = cues(of: part, in: scene)
        let isCellVisible = !slotCues.isEmpty || hoveredSlotKey == key
        return CueCell(
            part: part,
            cues: slotCues,
            isHovering: hoveredSlotKey == key,
            onAddCue: { addCue(part: part, scene: scene, triggerText: $0, cueTitle: $1, position: $2) },
            onShowHistory: onShowHistory,
            selectedCueIDs: selectedCueIDs,
            onSelectCue: { selectCue($0, isShiftPressed: $1) }
        )
            .opacity(isCellVisible ? 1 : 0)
            .padding(.horizontal, 13)
            .padding(.vertical, 5)
            .frame(width: GridStyle.sceneColumnWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(.white)
            .contentShape(.rect)
            .onHover { hoveredSlotKey = $0 ? key : nil }                // 들어오면 이 칸, 나가면 없음
            .gridCellBorder()
    }
    
    // + 파트 추가 칸
    private var addPartHeaderCell: some View {
        Button { isAddingPart = true } label: { Text("+").font(.system(size: 25, weight: .semibold)) }   // 씬 추가 + 와 같은 모양
            .appPopover(isPresented: $isAddingPart, edge: .trailing) { AddPart(onSave: addPart) }
            .buttonStyle(.plain)
            .foregroundStyle(Color.neutral900)
            .frame(width: GridStyle.partColumnWidth, height: GridStyle.addPartRowHeight)
            .background(Color.neutral25)
            .overlay(alignment: .leading) { Color.partAddaccent.frame(width: 6) }
            .gridCellBorder()
    }
    
    // 아무것도 없는 흰 칸
    private func emptyCell(width: CGFloat) -> some View {
        Color.white
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .gridCellBorder()
    }
}

// 씬 열 선택: 머리칸을 한 번 누르면 그 열만 밝게 + 테두리 일렁임, 나머지는 회색으로 흐리게

extension CueGrid {
    @ViewBuilder
    private var selectedColumnEffect: some View {
        if let selectedScene { columnEffect(for: selectedScene) }
    }

    // [회색 | 고른 열(일렁이는 테두리) | 회색]
    private func columnEffect(for scene: ShowScene) -> some View {
        HStack(spacing: 0) {
            dimmedArea
                .frame(width: columnX(of: scene))
            PulseBorder()
                .frame(width: GridStyle.sceneColumnWidth)
            dimmedArea
        }
        .allowsHitTesting(false)   // 덮어도 아래 칸은 그대로 누를 수 있게
    }

    // 고르지 않은 곳을 덮는 회색 (피그마: #697586 10%)
    private var dimmedArea: some View {
        Color.neutral500.opacity(0.1)
    }

    // 표 왼쪽 끝에서 이 씬 열까지의 거리
    private func columnX(of scene: ShowScene) -> CGFloat {
        let index = sortedScenes.firstIndex(of: scene) ?? 0
        return GridStyle.partColumnWidth + CGFloat(index) * GridStyle.sceneColumnWidth
    }

    // 한 번 누르면 이 씬 열 선택. 우선순위 사이드바가 열려 있으면 새 열로 바뀜
    private func selectColumn(_ scene: ShowScene) {
        selectedScene = scene
        if priorityScene != nil { priorityScene = scene }
    }
    
    // 우선순위 사이드바에서 다른 씬을 고르면: 그 열을 선택하고 화면을 그 열로 옮김
    private func moveToColumn(_ scene: ShowScene?, proxy: ScrollViewProxy) {
        guard let scene, scene != selectedScene else { return }   // 오른쪽 상단 버튼으로 연 경우(이미 선택된 열)는 그대로
        selectedScene = scene
        withAnimation { proxy.scrollTo(scene.id, anchor: .leading) }
    }

    // 고른 씬 머리칸 오른쪽 위 흔들리는 ⓝ 버튼 → 우선순위 사이드바 열기 / 닫기
    @ViewBuilder
    private func selectedMark(for scene: ShowScene) -> some View {
        if selectedScene == scene {
            Button { togglePriority(scene) } label: { priorityIcon }
                .buttonStyle(.plain)
                .padding(.top, 11)
                .padding(.trailing, 13)
        }
    }
    
    private var priorityIcon: some View {
        Image(systemName: "number.circle")
            .font(.system(size: 16))
            .foregroundStyle(Color.brandPrimaryText)
            .wiggle()
    }
    
    private func togglePriority(_ scene: ShowScene) {
        priorityScene = priorityScene == scene ? nil : scene
    }
    
    // 열 선택 해제 (우선순위 사이드바도 닫힘)
    private func clearSelection() {
        selectedScene = nil
        priorityScene = nil
        selectedCueIDs = []
    }
    
    // 큐 카드 클릭: 그 카드만 선택. shift를 누른 채 클릭하면 선택에 추가 (이미 선택된 카드면 빠짐)
    private func selectCue(_ cue: Cue, isShiftPressed: Bool) {
        guard isShiftPressed else {
            selectedCueIDs = [cue.id]
            return
        }
        if selectedCueIDs.contains(cue.id) {
            selectedCueIDs.remove(cue.id)
        } else {
            selectedCueIDs.insert(cue.id)
        }
    }
    
    // 화면에는 안 보이는 버튼: Esc 키를 누르면 선택 해제
    private var escapeShortcut: some View {
        Button("선택 해제", action: clearSelection)            .keyboardShortcut(.cancelAction)
            .opacity(0)
    }
}

// 동작

extension CueGrid {
    // 씬 추가 팝오버에서 Enter: 맨 오른쪽에 새 씬 한 칸 (#번호는 자동)
    private func addScene(title: String, kind: SceneKind) {
        let newScene = ShowScene(title: title, kind: kind, order: sortedScenes.count)
        production.scenes = (production.scenes ?? []) + [newScene]
    }
    
    // 파트 추가 팝오버에서 Enter: 맨 아래에 새 파트 한 줄 (색은 다음 순서 색)
    private func addPart(name: String) {
        let nextOrder = sortedParts.count
        let newPart = Part(name: name, order: nextOrder, colorIndex: nextOrder)
        production.parts = (production.parts ?? []) + [newPart]
    }
    
    // Add new 팝오버에서 입력을 마치면: 트리거와 큐를 새로 만들어 이 칸 맨 아래에 넣기
    private func addCue(part: Part, scene: ShowScene, triggerText: String, cueTitle: String, position: CuePosition) {
        let trigger = Trigger(text: triggerText, order: scene.triggers?.count ?? 0)
        let cue = Cue(title: cueTitle, position: position, order: 0)   // 번호는 우선순위 사이드바에서 정함
        modelContext.insert(cue)
        cue.trigger = trigger
        cue.part = part
        scene.triggers = (scene.triggers ?? []) + [trigger]
        cue.addHistory("큐 생성", detail: "\(CurrentEditor.name)님이 이 큐를 만들었습니다.", isChange: false)
    }
    
    // 이 씬의 수정 팝오버를 열고 닫는 스위치
    private func isEditing(_ scene: ShowScene) -> Binding<Bool> {
        Binding(get: { editingScene == scene }, set: { if !$0 { editingScene = nil } })
    }
    
    // 이 파트의 수정 팝오버를 열고 닫는 스위치
    private func isEditing(_ part: Part) -> Binding<Bool> {
        Binding(get: { editingPart == part }, set: { if !$0 { editingPart = nil } })
    }
    
    // 씬 삭제: 이 씬의 트리거와 큐도 같이 지워짐
    private func deleteScene(_ scene: ShowScene) {
        production.scenes?.removeAll { $0 == scene }
        modelContext.delete(scene)
        renumberScenes()
    }
    
    // 파트 삭제: 이 파트의 큐(와 그 트리거)도 같이 지움
    private func deletePart(_ part: Part) {
        (part.cues ?? []).forEach(modelContext.deleteCue)
        production.parts?.removeAll { $0 == part }
        modelContext.delete(part)
        renumberParts()
    }
    
    // 지운 뒤 빈 번호가 없게 0, 1, 2 …로 다시 매김
    private func renumberScenes() {
        for (index, scene) in sortedScenes.enumerated() { scene.order = index }
    }
    
    private func renumberParts() {
        for (index, part) in sortedParts.enumerated() { part.order = index }
    }
}

// 데이터

extension CueGrid {
    // 씬을 왼쪽부터 순서대로
    private var sortedScenes: [ShowScene] {
        (production.scenes ?? []).sorted { $0.order < $1.order }
    }
    
    // 파트를 위에서부터 순서대로
    private var sortedParts: [Part] {
        (production.parts ?? []).sorted { $0.order < $1.order }
    }
    
    // 파트 탭바에서 고른 파트만 (안 골랐으면 전체)
    private var visibleParts: [Part] {
        guard let selectedPart else { return sortedParts }
        return sortedParts.filter { $0 == selectedPart }
    }
    
    // 이 파트의 큐 중에서, 이 씬에 속한 것만
    private func cues(of part: Part, in scene: ShowScene) -> [Cue] {
        (part.cues ?? []).filter { $0.trigger?.scene == scene }
    }
    
    // 씬 머리칸 윗줄: 씬 → S#1, 넘버 → N#1, 전환 → 전환
    private func sceneLabel(for scene: ShowScene) -> String {
        let number = kindNumber(of: scene)
        switch scene.kind {
        case .scene: return "S#\(number)"
        case .number: return "N#\(number)"
        case .transition: return "전환"
        }
    }
    
    // 같은 종류끼리 왼쪽부터 몇 번째인지
    private func kindNumber(of scene: ShowScene) -> Int {
        sortedScenes.filter { $0.kind == scene.kind && $0.order <= scene.order }.count
    }
}

// 크기

private enum GridStyle {
    static let partColumnWidth: CGFloat = 178
    static let sceneColumnWidth: CGFloat = 278
    static let addSceneColumnWidth: CGFloat = 278
    static let headerHeight: CGFloat = 80
    static let addPartRowHeight: CGFloat = 100
    static let minRowHeight: CGFloat = 148
}

// 칸마다 오른쪽 · 아래에 얇은 선
private extension View {
    func gridCellBorder() -> some View {
        overlay(alignment: .trailing) { Color.neutral200.frame(width: 1) }
            .overlay(alignment: .bottom) { Color.neutral200.frame(height: 1) }
    }
}


#Preview {
    let container = try! ModelContainer(for: Production.self, configurations: .init(isStoredInMemoryOnly: true))
    let production = Production(title: "레미제라블", genre: "뮤지컬", firstShowDate: .now)
    let firstScene = ShowScene(title: "죄수들 들어오는 씬", kind: .scene, order: 0)
    let secondScene = ShowScene(title: "장발장 연행", kind: .scene, order: 1)
    let trigger = Trigger(text: "오프닝 \"Look Down\" 전주", order: 0)
    let cue = Cue(title: "죄수들 노역 위치 입장", position: .sangsu, order: 1)
    container.mainContext.insert(production)
    production.parts = Part.makeDefaultParts()
    production.scenes = [firstScene, secondScene]
    firstScene.triggers = [trigger]
    cue.trigger = trigger
    cue.part = production.parts?.first { $0.order == 0 }
    
    return CueGrid(production: production, priorityScene: .constant(nil))        .frame(width: 1100, height: 600)
        .modelContainer(container)
}
