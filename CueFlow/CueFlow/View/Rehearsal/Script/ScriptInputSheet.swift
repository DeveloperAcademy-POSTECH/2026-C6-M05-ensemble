//
//  ScriptInputSheet.swift
//  CueFlow
//
//  "대본 입력" 창. 1) 글 상자에 직접 쓰기 · 붙여넣기 · 파일 불러오기 → 2) 배역 확인 + 장면별 미리보기 → 적용
//

import SwiftUI

struct ScriptInputSheet: View {
    let production: Production
    let currentScene: ShowScene?   // 장면 표시(S1 등) 앞에 있는 글을 넣을 장면

    @Environment(\.dismiss) private var dismiss

    private enum Step { case input, review }
    @State private var step: Step = .input

    @State private var text = ""
    @State private var isImportingFile = false
    @State private var fileError: String?

    @State private var cast: [String] = []             // 배역 목록 (자동으로 찾은 것 + 직접 추가)
    @State private var selectedCast: Set<String> = []  // 체크된 배역만 배역으로 본다
    @State private var newName = ""
    @State private var props: [String] = []            // 소품 목록 (괄호 지문에서 찾은 것 + 직접 추가)
    @State private var selectedProps: Set<String> = []
    @State private var newProp = ""
    @State private var overrides = SceneOverrides()     // 미리보기에서 직접 나누기 · 합치기한 것

    init(production: Production, currentScene: ShowScene?, initialText: String = "") {
        self.production = production
        self.currentScene = currentScene
        _text = State(initialValue: initialText)
        // 전에 확인한 배역 · 소품은 체크된 채로 시작
        _cast = State(initialValue: production.castNames)
        _selectedCast = State(initialValue: Set(production.castNames))
        _props = State(initialValue: production.propNames)
        _selectedProps = State(initialValue: Set(production.propNames))
    }

    private var parsedScenes: [ParsedScene] {
        ScriptParser.parse(text, cast: selectedCast, overrides: overrides)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch step {
            case .input: inputStep
            case .review: reviewStep
            }
        }
        .padding(.horizontal, 51)
        .padding(.top, 39)
        .padding(.bottom, 32)
        .frame(width: 1009, height: 769)
        .background(Color.neutral25)
        .onChange(of: text) { overrides = SceneOverrides() }   // 글이 바뀌면 문단 번호가 달라지니 고친 것도 처음부터
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: ScriptImporter.fileTypes) { result in
            guard case .success(let url) = result else { return }
            if let loaded = ScriptImporter.text(from: url), !loaded.isEmpty {
                text = loaded
                fileError = nil
            } else {
                fileError = "파일에서 글자를 읽지 못했어요. 한글(.hwp)은 PDF나 워드로 저장해서 불러와 주세요."
            }
        }
    }

    // MARK: 1단계 — 글 넣기

    private var inputStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(
                title: "대본 입력",
                subtitle: "작성해둔 대본을 복사해 붙여넣거나, 직접 쓰거나, 파일을 불러오세요.\nS#1 씬 이름 · N#1 넘버 이름 · 암전으로 장면을 나누고, 대사는 \"배역: 대사\", 행동은 (괄호)로 적어요. 다음 화면에서 고칠 수 있어요."
            ) {
                importButton
            }

            if let fileError {
                Text(fileError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            TextEditor(text: $text)
                .font(.system(size: 17))
                .lineSpacing(5)
                .foregroundStyle(Color.neutral900)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 36)
                .padding(.vertical, 32)
                .sheetBox()
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("S#1 공장\n(판틴과 노동자들이 공장에서 일하고 있다.)\n판틴: 오늘도 일을 마쳐야 해.\nN#1 하루의 끝에서\n판틴: 코제트를 위해 버텨야 해.\n(판틴이 공장을 떠난다.)\n암전\n(노동자들이 퇴장하고 공장 작업대를 반출한다.)\nS#2 거리")
                            .font(.system(size: 17))
                            .lineSpacing(5)
                            .foregroundStyle(Color.neutral400)
                            .padding(.leading, 41)
                            .padding(.top, 32)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Spacer()
                Button("취소") { dismiss() }
                    .buttonStyle(.secondary)
                    .frame(width: 112, height: 36)
                Button("다음") { goToReview() }
                    .buttonStyle(SheetPrimaryButtonStyle())
                    .frame(width: 112, height: 36)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // 오른쪽 위 "불러오기" (파일에서 대본 불러오기)
    private var importButton: some View {
        Button {
            isImportingFile = true
        } label: {
            Label("불러오기", systemImage: "arrow.down.document")
                .font(.body)
                .foregroundStyle(Color.brandPrimaryText)
                .frame(width: 95, height: 30)
                .background(Color.neutral25, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.brandPrimary, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("txt · docx · pdf · rtf 파일에서 불러오기")
    }

    private func goToReview() {
        let found = ScriptParser.castCandidates(in: text)
        // 앞에서 직접 추가했던 배역은 남긴다
        cast = found + cast.filter { !found.contains($0) }
        selectedCast = selectedCast.union(found)

        let foundProps = ScriptParser.propCandidates(in: text, cast: selectedCast)
        props = foundProps + props.filter { !foundProps.contains($0) }
        selectedProps = selectedProps.union(foundProps.filter(ScriptParser.isLikelyProp))   // 손 · 고개 · 노동자들 같은 말은 꺼 둔다
        step = .review
    }

    // MARK: 2단계 — 배역 확인 + 미리보기

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(
                title: "나눈 배역과 소품을 확인해주세요",
                subtitle: "배역 · 소품이 맞는지 확인해 주세요. 체크한 것만 무대 배치도에 나와요."
            ) {
                importButton
            }

            VStack(alignment: .leading, spacing: 14) {
                chipBar(title: "배역", names: $cast, selected: $selectedCast, newName: $newName, placeholder: "배역 추가")
                chipBar(title: "소품", names: $props, selected: $selectedProps, newName: $newProp, placeholder: "소품 추가")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(parsedScenes) { parsed in
                        sceneSection(parsed)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .sheetBox()

            HStack {
                Spacer()
                Button("뒤로") { step = .input }
                    .buttonStyle(.secondary)
                    .frame(width: 112, height: 43)
                Button("적용하기") {
                    ScriptImporter.apply(
                        parsedScenes, to: production, currentScene: currentScene,
                        cast: selectedCast, props: selectedProps
                    )
                    dismiss()
                }
                .buttonStyle(SheetPrimaryButtonStyle())
                .frame(width: 112, height: 43)
            }
        }
    }

    // 배역 · 소품 칩 (누르면 체크 켜기/끄기) + 맨 끝 "+"로 직접 추가
    private func chipBar(
        title: String,
        names: Binding<[String]>,
        selected: Binding<Set<String>>,
        newName: Binding<String>,
        placeholder: String
    ) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.neutral900)
                .frame(width: 37, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(names.wrappedValue, id: \.self) { name in
                        let isOn = selected.wrappedValue.contains(name)
                        Button {
                            if isOn { selected.wrappedValue.remove(name) } else { selected.wrappedValue.insert(name) }
                        } label: {
                            // 체크한 것: 연보라 바탕 + 보라 글자 / 뺀 것: 테두리만 + 회색 글자
                            Text(name)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(isOn ? Color.brandPrimaryText : Color.neutral400)
                                .padding(.horizontal, 8)
                                .frame(height: 26)
                                .background(isOn ? Color.brandPrimarySubtle.opacity(0.5) : Color.clear, in: Capsule())
                                .overlay {
                                    Capsule().strokeBorder(Color.neutral300, lineWidth: isOn ? 0 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .help(isOn ? "\(name) 빼기" : "\(name) 넣기")
                    }

                    AddChip(text: newName, placeholder: placeholder) {
                        add(newName, to: names, selected: selected)
                    }
                }
            }
        }
    }

    private func add(_ newName: Binding<String>, to names: Binding<[String]>, selected: Binding<Set<String>>) {
        let name = newName.wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if !names.wrappedValue.contains(name) { names.wrappedValue.append(name) }
        selected.wrappedValue.insert(name)
        newName.wrappedValue = ""
    }

    // 미리보기: 장면 하나
    private func sceneSection(_ parsed: ParsedScene) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(sceneTitle(parsed))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.neutral900)
                if let badge = sceneBadge(parsed) {
                    Text(badge)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.neutral900)
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .background(Color.neutral100, in: Capsule())
                }
                Spacer()
                Text("\(parsed.lines.count)줄")
                    .font(.caption)
                    .foregroundStyle(Color.neutral500)
                if let index = parsed.headingIndex {
                    Button("앞 장면에 합치기") { overrides.merged.insert(index) }
                        .buttonStyle(.link)
                        .font(.caption)
                } else if let index = parsed.splitIndex {
                    Button("나누기 취소") { overrides.splits[index] = nil }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }

            ForEach(Array(parsed.lines.enumerated()), id: \.element.id) { position, line in
                // 장면 첫 줄에서 나누면 빈 장면이 생기니 둘째 줄부터
                PreviewLineRow(line: line, canSplit: position > 0) { kind in
                    overrides.splits[line.index] = kind
                }
            }
        }
    }

    private func sceneTitle(_ parsed: ParsedScene) -> String {
        if parsed.kind == nil {
            return currentScene?.title ?? "장면 없음"
        }
        return parsed.title.isEmpty ? parsed.code : "\(parsed.code) \(parsed.title)"
    }

    // 장면 옆 작은 표시: 앱에 없어서 새로 만드는지, 지금 장면에 들어가는지
    private func sceneBadge(_ parsed: ParsedScene) -> String? {
        if parsed.kind == nil {
            return currentScene == nil ? "넣을 장면 없음" : "지금 장면에 넣어요"
        }
        return ScriptImporter.existingScene(for: parsed, in: production) == nil ? "새 장면으로 만들어요" : nil
    }
}

// 창 위쪽 제목 + 설명 + 오른쪽 버튼 (대본 입력 · 배역 소품 확인 · 배역 소품 목록 공용)
struct SheetHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 11) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.neutral900)
                Text(subtitle)
                    .font(.system(size: 17))
                    .lineSpacing(3)
                    .foregroundStyle(Color.neutral600)
            }
            Spacer()
            trailing
        }
    }
}

// 연한 바탕 + 회색 테두리 상자 (대본 글 상자 · 미리보기)
extension View {
    func sheetBox() -> some View {
        background(Color.neutral25, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.neutral300, lineWidth: 1)
            }
    }
}

// 무대 배치 창의 "다음으로" · "배치 완료": 연보라 바탕 + 보라 글자 (피그마 무대배치02 · 03)
struct SheetSoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(Color.brandPrimaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.brandPrimarySubtle, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// 창 왼쪽 위 "<" 뒤로 버튼 (피그마 무대배치02 · 03)
struct SheetBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 22))
                .foregroundStyle(Color.black)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("뒤로")
    }
}

// 대본 입력 창의 "다음" · "적용하기". 못 누를 때는 연보라 바탕 + 보라 글자 (피그마)
// TODO: 다른 화면에도 쓰이면 AppButtonStyle의 primary에 합치기 (#39 머지 후, 충돌 피하려고 지금은 따로)
struct SheetPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SheetPrimaryButton(configuration: configuration)
    }

    private struct SheetPrimaryButton: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.body.weight(.semibold))
                .foregroundStyle(isEnabled ? Color.white : Color.brandPrimaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }

        private var background: Color {
            if !isEnabled { return .brandPrimaryDisabled }
            return configuration.isPressed ? .brandPrimaryPressed : .brandPrimary
        }
    }
}

// 칩 줄 맨 끝 "+". 누르면 이름 입력 칸으로 바뀌고, Enter로 추가
private struct AddChip: View {
    @Binding var text: String
    let placeholder: String
    let onAdd: () -> Void

    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 10.5, weight: .medium))
                .focused($isFocused)
                .padding(.horizontal, 10)
                .frame(width: 90, height: 26)
                .background(Color.neutral100, in: Capsule())
                .onAppear { isFocused = true }
                .onSubmit {
                    onAdd()
                    isEditing = false
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused { isEditing = false }   // 다른 곳을 누르면 다시 "+"로
                }
        } else {
            Button {
                isEditing = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.neutral600)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Color.neutral100, in: Capsule())
            }
            .buttonStyle(.plain)
            .help(placeholder)
        }
    }
}

// 미리보기 대본 한 줄. 마우스를 올리면 "여기서 나누기" 메뉴가 보인다
private struct PreviewLineRow: View {
    let line: ParsedLine
    let canSplit: Bool
    let onSplit: (SceneKind) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ScriptLineView(speaker: line.speaker, text: line.text, fontSize: 17)
                .frame(maxWidth: .infinity, alignment: .leading)

            if canSplit {
                Menu("여기서 나누기") {
                    ForEach(SceneKind.allCases, id: \.self) { kind in
                        Button("새 \(kind.rawValue)으로") { onSplit(kind) }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .font(.caption)
                .opacity(isHovered ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

#Preview("1단계 글 넣기") {
    let production = RehearsalPreviewData.production
    ScriptInputSheet(
        production: production,
        currentScene: production.scenes?.first,
        initialText: RehearsalPreviewData.sampleScriptText
    )
}
