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
        .padding(28)
        .frame(width: 760, height: 640)
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("대본 입력")
                        .font(.title2.bold())
                    Text("구글 닥스에서 복사해 붙여넣거나, 직접 쓰거나, 파일을 불러오세요.\n줄 맨 앞의 S1 · 씬 1 · 1장 · N1 · M1 · D1 같은 표시로 장면을 나눠요. 다음 화면에서 고칠 수 있어요.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isImportingFile = true
                } label: {
                    Label("파일에서 불러오기", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.secondary)
                .frame(width: 150, height: 32)
            }

            if let fileError {
                Text(fileError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            TextEditor(text: $text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("S1 (하루가 끝날 무렵, 공장 안)\n판틴 (편지를 숨기며) 아무것도 아니에요.\n공장장 일하는 시간에 편지라니!")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .padding(13)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Spacer()
                Button("취소") { dismiss() }
                    .buttonStyle(.secondary)
                    .frame(width: 90, height: 34)
                Button("다음") { goToReview() }
                    .buttonStyle(.primary)
                    .frame(width: 90, height: 34)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
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
            VStack(alignment: .leading, spacing: 6) {
                Text("이렇게 나눴어요")
                    .font(.title2.bold())
                Text("배역 · 소품이 맞는지 확인해 주세요. 체크한 것만 무대 배치도에 나와요.\n장면이 잘못 나뉘었으면 줄에 마우스를 올려 '여기서 나누기', 장면 제목 옆 '앞 장면에 합치기'를 눌러요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            chipBar(title: "배역", names: $cast, selected: $selectedCast, newName: $newName, placeholder: "배역 추가")
            chipBar(title: "소품", names: $props, selected: $selectedProps, newName: $newProp, placeholder: "소품 추가")

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(parsedScenes) { parsed in
                        sceneSection(parsed)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }

            HStack {
                Button("뒤로") { step = .input }
                    .buttonStyle(.secondary)
                    .frame(width: 90, height: 34)
                Spacer()
                Text("\(parsedScenes.count)개 장면")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("적용") {
                    ScriptImporter.apply(
                        parsedScenes, to: production, currentScene: currentScene,
                        cast: selectedCast, props: selectedProps
                    )
                    dismiss()
                }
                .buttonStyle(.primary)
                .frame(width: 90, height: 34)
            }
        }
    }

    // 배역 · 소품 체크 칩 + 직접 추가
    private func chipBar(
        title: String,
        names: Binding<[String]>,
        selected: Binding<Set<String>>,
        newName: Binding<String>,
        placeholder: String
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
                .padding(.trailing, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(names.wrappedValue, id: \.self) { name in
                        let isOn = selected.wrappedValue.contains(name)
                        Button {
                            if isOn { selected.wrappedValue.remove(name) } else { selected.wrappedValue.insert(name) }
                        } label: {
                            Label(name, systemImage: isOn ? "checkmark" : "plus")
                                .font(.caption)
                                .foregroundStyle(isOn ? Color.white : Color.brandPrimaryText)
                                .padding(.horizontal, 10)
                                .frame(height: 24)
                                .background(isOn ? Color.brandPrimaryHover : Color.clear, in: Capsule())
                                .overlay {
                                    Capsule().strokeBorder(Color.brandPrimaryHover, lineWidth: isOn ? 0 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            TextField(placeholder, text: newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
                .onSubmit { add(newName, to: names, selected: selected) }
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
                    .font(.headline)
                if let badge = sceneBadge(parsed) {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.brandPrimaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brandPrimarySubtle, in: Capsule())
                }
                Spacer()
                Text("\(parsed.lines.count)줄")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

// 미리보기 대본 한 줄. 마우스를 올리면 "여기서 나누기" 메뉴가 보인다
private struct PreviewLineRow: View {
    let line: ParsedLine
    let canSplit: Bool
    let onSplit: (SceneKind) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ScriptLineView(speaker: line.speaker, text: line.text)
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
