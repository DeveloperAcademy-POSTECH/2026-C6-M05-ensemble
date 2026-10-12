//
//  RehearsalView.swift
//  CueFlow
//
//  리허설 모드 (피그마 리허설모드_수정중). 사이드바 없이 창 전체를 쓴다.
//  왼쪽: 대본 / 오른쪽 위: 무대 배치도 / 오른쪽 아래: 큐 목록
//

import SwiftUI

struct RehearsalView: View {
    let production: Production
    let onExit: () -> Void   // "리허설 모드 종료"

    // 지금 보고 있는 장면 (공연 흐름 순서에서 몇 번째인지)
    @State private var sceneIndex = 0

    // 공연 흐름 순서대로 정렬한 장면들
    private var scenes: [ShowScene] {
        (production.scenes ?? []).sorted { $0.order < $1.order }
    }

    private var currentScene: ShowScene? {
        scenes.indices.contains(sceneIndex) ? scenes[sceneIndex] : nil
    }

    // 지금 장면의 큐 (트리거 순서 → 트리거 안 큐 순서)
    private var currentSceneCues: [Cue] {
        let triggers = (currentScene?.triggers ?? []).sorted { $0.order < $1.order }
        return triggers.flatMap { ($0.cues ?? []).sorted { $0.order < $1.order } }
    }

    var body: some View {
        VStack(spacing: 33) {
            header

            HStack(alignment: .top, spacing: 21) {
                RehearsalScriptPanel(lines: RehearsalPreviewData.scriptLines)   // TODO: 장면별 대본 (모델 생기면)
                    .frame(width: 360)

                VStack(spacing: 23) {
                    RehearsalStageMap(cues: currentSceneCues)
                        .frame(height: 378)

                    // TODO: 4단계 큐 목록 (셀리나 메인 큐시트 PR #40 머지 후)
                    RehearsalCard(title: "큐 목록")
                }
            }
        }
        .padding(.leading, 52)
        .padding(.trailing, 70)
        .padding(.top, 46)
        .padding(.bottom, 45)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // 공연 이름 · 장면 이동 · 종료 버튼
    private var header: some View {
        HStack(spacing: 0) {
            Text(production.title)
                .font(.title3.weight(.bold))

            Spacer()

            HStack(spacing: 8) {
                sceneStepper
                scenePicker
            }

            Spacer()

            // TODO: #41 머지 후 .buttonStyle(.tertiary)로 교체
            Button("리허설 모드 종료", action: onExit)
                .buttonStyle(.plain)
                .frame(width: 115, height: 36)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.primary, lineWidth: 1)
                }
        }
    }

    // < > 이전/다음 장면
    private var sceneStepper: some View {
        HStack(spacing: 0) {
            stepButton(systemImage: "chevron.left", help: "이전 장면", isEnabled: sceneIndex > 0) {
                sceneIndex -= 1
            }
            Divider()
            stepButton(systemImage: "chevron.right", help: "다음 장면", isEnabled: sceneIndex < scenes.count - 1) {
                sceneIndex += 1
            }
        }
        .frame(height: 36)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func stepButton(systemImage: String, help: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 36, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .help(help)
    }

    // "장면  S#3 시장 등장 ⌃⌄" 누르면 장면 목록
    private var scenePicker: some View {
        Menu {
            ForEach(scenes.indices, id: \.self) { index in
                Button(scenes[index].displayName(in: scenes)) {
                    sceneIndex = index
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text("장면")
                    .foregroundStyle(.secondary)
                Text(currentScene?.displayName(in: scenes) ?? "장면 없음")
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 15)
            .frame(width: 170, height: 36)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// 흰 바탕 카드 (대본 · 무대 배치 · 큐 목록 공용 틀). 제목이 없으면 위 제목 줄 없이 내용만.
struct RehearsalCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content = { EmptyView() }) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 22)
                    .frame(height: 54)
                Divider()
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }
}

#Preview {
    RehearsalView(production: RehearsalPreviewData.production) { }
        .frame(width: 1512, height: 932)
}
