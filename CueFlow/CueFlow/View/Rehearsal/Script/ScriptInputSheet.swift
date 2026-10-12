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

    init(production: Production, currentScene: ShowScene?, initialText: String = "") {
        self.production = production
        self.currentScene = currentScene
        _text = State(initialValue: initialText)
    }

    private var parsedScenes: [ParsedScene] {
        ScriptParser.parse(text, cast: selectedCast)
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
                    Text("구글 닥스에서 복사해 붙여넣거나, 직접 쓰거나, 파일을 불러오세요.\n장면은 줄 맨 앞에 S1 · N1 · D1 처럼 적으면 장면별로 나눠져요.")
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
        step = .review
    }

    // MARK: 2단계 — 배역 확인 + 미리보기

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("이렇게 나눴어요")
                    .font(.title2.bold())
                Text("배역이 맞는지 확인해 주세요. 체크를 풀면 그 이름으로 시작하는 줄은 지문이 돼요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            castBar

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
                    ScriptImporter.apply(parsedScenes, to: production, currentScene: currentScene)
                    dismiss()
                }
                .buttonStyle(.primary)
                .frame(width: 90, height: 34)
            }
        }
    }

    // 배역 체크 칩 + 직접 추가
    private var castBar: some View {
        HStack(spacing: 6) {
            Text("배역")
                .font(.callout.weight(.semibold))
                .padding(.trailing, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(cast, id: \.self) { name in
                        let isOn = selectedCast.contains(name)
                        Button {
                            if isOn { selectedCast.remove(name) } else { selectedCast.insert(name) }
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

            TextField("배역 추가", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
                .onSubmit(addName)
        }
    }

    private func addName() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if !cast.contains(name) { cast.append(name) }
        selectedCast.insert(name)
        newName = ""
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
            }

            ForEach(parsed.lines) { line in
                ScriptLineView(speaker: line.speaker, text: line.text)
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

#Preview("1단계 글 넣기") {
    let production = RehearsalPreviewData.production
    ScriptInputSheet(
        production: production,
        currentScene: production.scenes?.first,
        initialText: RehearsalPreviewData.sampleScriptText
    )
}
