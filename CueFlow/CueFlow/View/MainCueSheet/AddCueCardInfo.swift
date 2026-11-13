//
//  AddCueCardInfo.swift
//  CueFlow
//
//  Created by 김나현 on 10/12/26.
//

import SwiftUI

struct AddCueCardInfo: View {
    // 다 입력하고 Enter를 눌렀을 때 할 일 (트리거 글, 큐 제목, 위치)
    var onSave: (String, String, CuePosition) -> Void
    var scene: ShowScene?   // 이전 트리거를 찾을 열(씬) (없으면 후보 없음)
    var partName: String?   // 어느 파트의 큐인지 (입력칸 예시가 파트마다 다름)
    var closeRequest = 0    // 바깥 클릭 · Esc 할 때마다 +1 (연 쪽에서 넘겨줌) → 저장 · 경고 · 닫기를 여기서 정함
    @Environment(\.closeAppPopover) private var closePopover   // 저장하면 팝오버 닫기
    @State private var triggerText: String
    @State private var cueTitle: String
    @State private var position: CuePosition?   // nil = 아직 안 고름
    @FocusState private var focusedField: InputField?
    @State private var showPositionWarning = false   // 위치 안 고르고 저장하려 했는지
    @State private var highlightedSuggestion: Int?   // 방향키로 고른 후보 번호 (nil = 안 고름)
    @State private var showCueWarning = false   // 큐를 안 쓰고 저장하려 했는지 (* 빨강 + 경고 문구)
    @State private var isPickingPosition = false   // 위치 고르는 팝오버가 열려 있는지
    
    // 새로 만들 때는 빈 칸으로, 수정할 때는 원래 값을 채워서 연다
    init(triggerText: String = "", cueTitle: String = "", position: CuePosition? = nil,
         scene: ShowScene? = nil, partName: String? = nil, closeRequest: Int = 0,
         onSave: @escaping (String, String, CuePosition) -> Void = { _, _, _ in }) {
        _triggerText = State(initialValue: triggerText)
        _cueTitle = State(initialValue: cueTitle)
        _position = State(initialValue: position)
        self.scene = scene
        self.partName = partName
        self.onSave = onSave
        self.closeRequest = closeRequest
    }
    // 지금 글자를 치고 있는 칸
    private enum InputField {
        case trigger, cue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            positionMenu
                .frame(maxWidth: .infinity, alignment: .trailing)
            triggerSection
                .padding(.bottom, 16)
            inputSection(title: "큐", text: $cueTitle, field: .cue, isRequired: true)
            if showCueWarning {
                warning("큐 내용을 입력하지 않았습니다.")
                    .padding(.top, 10)
            }
            if showPositionWarning {
                warning("위치를 선택하지 않았습니다.")
                    .padding(.top, 10)
            }
        }
        .onAppear { focusedField = .trigger }
        .onChange(of: position) { showPositionWarning = false }
        .onChange(of: cueTitle) { showCueWarning = false }   // 큐를 쓰기 시작하면 * 다시 회색
        .onChange(of: closeRequest) { closeOrWarn() }   // 바깥 클릭 · Esc
    }
}

// 서브뷰

extension AddCueCardInfo {
    // 오른쪽 위 "위치 ▾" → 누르면 상수/하수/무대/콘솔 고르는 팝오버 (꼭 골라야 저장됨)
    private var positionMenu: some View {
        Button { isPickingPosition = true } label: { positionMenuLabel }
            .buttonStyle(.plain)
            .fixedSize()
            .appPopover(isPresented: $isPickingPosition, width: nil) {
                PopoverCheckList(items: CuePosition.allCases, selected: position, title: \.rawValue) { position = $0 }
            }
    }
    
    // 위치 버튼 생김새: 안 골랐으면 "위치", 안 고르고 저장하려 하면 빨갛게
    private var positionMenuLabel: some View {
        HStack(spacing: 4) {
            Text(position?.rawValue ?? "위치")
            Image(systemName: "chevron.down")
                .font(.appCaption2)
        }
        .font(.appCallout)
        .foregroundStyle(showPositionWarning ? Color.error : Color.noticeMetaText)
        .padding(.horizontal, 8)
        .frame(height: 25)
        .background(showPositionWarning ? Color.errorSubtle : Color.neutral200, in: .capsule)
        .overlay { Capsule().strokeBorder(showPositionWarning ? Color.error : .clear, lineWidth: 1) }
    }
    
    // 하단 경고: ⓘ 위치를 선택하지 않았습니다. / ⓘ 큐 내용을 입력하지 않았습니다.
    private func warning(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.app(size: 14))
            Text(text)
                .font(.app(size: 10))
        }
        .foregroundStyle(Color.error)
    }
    
    // 제목("트리거" / "큐*") + 입력칸. 필수 칸은 제목 옆에 *
    private func inputSection(title: String, text: Binding<String>, field: InputField, isRequired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 0) {
                Text(title)
                    .font(.appBody.weight(.semibold))
                    .foregroundStyle(Color.neutral800)
                if isRequired { requiredMark }
            }
            inputField(text: text, field: field)
        }
    }

    // 필수 표시 * (피그마: SemiBold 16, 평소 neutral400 · 비우고 저장하려 하면 error)
    private var requiredMark: some View {
        Text("*")
            .font(.app(size: 16, weight: .semibold))
            .foregroundStyle(showCueWarning ? Color.error : Color.neutral400)
    }
    
    // 입력칸
    private func inputField(text: Binding<String>, field: InputField) -> some View {
        TextField("", text: text, prompt: placeholder(for: field), axis: .vertical)   // 길면 아랫줄로 넘어가며 칸이 늘어남
            .focused($focusedField, equals: field)
            .onKeyPress(.downArrow) { moveHighlight(by: 1, in: field) }
            .onKeyPress(.upArrow) { moveHighlight(by: -1, in: field) }
            .onSubmit { handleReturn(in: field) }
            .popoverInputStyle()
    }
    
    // 입력칸 예시 글: 파트마다 다름 (없는 파트면 "내용을 입력하세요")
    private func placeholder(for field: InputField) -> Text {
        let example = Self.examples[partName ?? ""]
        let text = field == .trigger ? example?.trigger : example?.cue
        return Text(text ?? "내용을 입력하세요").foregroundStyle(Color.noticePlaceholder)
    }
    
    // 파트별 예시 (피그마 무대 · 소품 · 의상 · 조명 · 음향_큐카드입력)
    private static let examples: [String: (trigger: String, cue: String)] = [
        "무대": ("배우 B의 \"들어오세요\" 대사 종료 시", "배우 A가 상수에서 입장해 무대 중앙 식탁 앞에 서기"),
        "소품": ("암전 시작 시", "무대 중앙 식탁을 하수 대기 위치로 이동"),
        "의상": ("배우 A가 하수로 퇴장 시", "배우 A의 검은 코트를 벗기고 흰 셔츠·청바지로 교체"),
        "조명": ("배우 A가 식탁 앞 표시점에 도착 시", "식탁 앞 흰색 스폿 조명을 70%로 켜기"),
        "음향": ("배우 A의 세 번째 노크 시", "나무문이 삐걱 열리는 효과음 재생"),
    ]
    
    // 트리거 입력칸 + 그 아래 이전 트리거 후보
    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            inputSection(title: "트리거", text: $triggerText, field: .trigger)
            if !matchingTriggers.isEmpty { suggestionList }
        }
        .onChange(of: triggerText) { highlightedSuggestion = nil }
    }
    
    // 후보 목록 (흰 상자)
    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(matchingTriggers, id: \.self) { suggestionRow($0) }
        }
        .background(Color.surfaceWhite, in: .rect(cornerRadius: 8))
        .clipShape(.rect(cornerRadius: 8))
    }
    
    // 후보 한 줄
    private func suggestionRow(_ text: String) -> some View {
        Button { pickSuggestion(text) } label: {
            Text(text)
                .font(.appCallout)
                .foregroundStyle(Color.neutral800)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(isHighlighted(text) ? Color.brandPrimarySubtle : Color.clear)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
    
    // 방향키로 고른 후보인지
    private func isHighlighted(_ text: String) -> Bool {
        matchingTriggers.firstIndex(of: text) == highlightedSuggestion
    }
}

// 동작

extension AddCueCardInfo {
    // 트리거 칸에서 Enter → 큐 칸으로 이동, 큐 칸에서 Enter → 큐 추가
    private func handleReturn(in field: InputField) {
        // 방향키로 고른 후보가 있으면 Enter = 그 후보로 채우기
        if field == .trigger, let index = highlightedSuggestion, matchingTriggers.indices.contains(index) {
            pickSuggestion(matchingTriggers[index])
            return
        }
        if field == .trigger {
            moveToCueField()
            return
        }
        addCue()
    }
    
    // 저장: 큐 · 위치가 다 있으면 저장하고 닫기, 빠진 게 있으면 경고만 (트리거는 선택)
    private func addCue() {
        let title = cueTitle.trimmingCharacters(in: .whitespaces)
        showCueWarning = title.isEmpty
        showPositionWarning = position == nil
        guard !title.isEmpty, let position else { return }
        onSave(triggerText, title, position)
        closePopover()
    }
    
    // 바깥 클릭 · Esc: 큐도 위치도 없으면(트리거만 썼어도) 그냥 닫기, 아니면 Enter와 같이 (저장하고 닫기 / 빠진 것 경고)
    private func closeOrWarn() {
        let title = cueTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty || position != nil else { return closePopover() }
        addCue()
    }
    
    // 한글 입력이 끝난 다음에 칸을 옮겨야 트리거 칸 글자가 남는다
    private func moveToCueField() {
        DispatchQueue.main.async {
            focusedField = .cue
        }
    }
    
    // 이 열(씬)에서 이미 쓴 트리거 중, 지금 친 글자가 들어 있는 것 (최대 3개)
    private var matchingTriggers: [String] {
        let typed = triggerText.trimmingCharacters(in: .whitespaces)
        guard focusedField == .trigger, !typed.isEmpty else { return [] }
        let usedTexts = (scene?.triggers ?? []).map(\.text)
        let matches = Set(usedTexts).filter { $0.contains(typed) && $0 != typed }
        return Array(matches.sorted().prefix(3))
    }
    
    // ↑↓: 트리거 칸에 후보가 있을 때만 후보 사이를 오르내림 (맨 위 · 맨 아래에서 멈춤)
    private func moveHighlight(by step: Int, in field: InputField) -> KeyPress.Result {
        guard field == .trigger, !matchingTriggers.isEmpty else { return .ignored }
        let next = (highlightedSuggestion ?? -1) + step
        highlightedSuggestion = min(max(next, 0), matchingTriggers.count - 1)
        return .handled
    }
    
    // 후보를 누르면: 트리거 칸에 채우기만 하고 커서는 그대로 → 필요하면 이어서 고친 뒤 Enter
    private func pickSuggestion(_ text: String) {
        triggerText = text
        highlightedSuggestion = nil
    }
}

#Preview {
    AddCueCardInfo(partName: "무대")
        .popoverStyle()
        .padding(60)
}
