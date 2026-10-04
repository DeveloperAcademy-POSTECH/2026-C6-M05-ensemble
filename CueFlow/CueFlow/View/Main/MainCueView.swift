//
//  MainCueView.swift
//  CueFlow
//
//  메인 큐 화면 (피그마 로우파이_4차 · 메인큐화면)
//  윗줄: 공연 제목 + 변경건 / 미확인 / 초대하기
//  둘째 줄: 파트 필터(B) + (트리거 단위일 때 씬 선택) + 씬 추가 / 리허설 모드 / 트리거 단위
//  그 아래: 파트 × 씬 표 (트리거 단위면 파트 × 그 씬의 트리거)
//

import SwiftUI

struct MainCueView: View {
    @Environment(CueStore.self) private var store
    @State private var mode: CueGridView.Mode = .scenes
    @State private var lastSceneID: ShowScene.ID?   // 트리거 단위로 다시 갈 때 보던 씬

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBar
                .padding(.top, 34)
            toolBar
                .padding(.top, 11)
                .padding(.bottom, 13)
            CueGridView(mode: mode) { sceneID in
                showTriggers(of: sceneID)
            }
            .id(mode)   // 화면이 바뀌면 스크롤 위치 처음으로
        }
        .padding(.horizontal, 32)
        .frame(minWidth: 1000, minHeight: 600, alignment: .topLeading)
        .background(.white)
    }

    // 변경건 · 미확인 · 초대하기는 이번 유저테스트 범위 밖이라 모양만 (동작 없음)
    private var titleBar: some View {
        HStack {
            Text(store.showTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)
            Spacer()
            HStack(spacing: 6) {
                ToolbarButton(title: "변경건", style: .outline) {}
                ToolbarButton(title: "미확인 4", style: .outline) {}
                InviteBox()
            }
        }
    }

    private var toolBar: some View {
        HStack(alignment: .bottom) {
            // TODO(B): 파트 필터 칩 + 파트 추가(+) 버튼
            Color.clear.frame(height: 24)
            Spacer()
            HStack(spacing: 4) {
                if case .triggers(let sceneID) = mode {
                    sceneMenu(selected: sceneID)
                        .padding(.trailing, 3)
                }
                // 트리거 단위에서 누르면 새 열이 보이도록 씬 단위로 돌아감
                ToolbarButton(title: "+ 씬 추가", style: .filled(Color(hex: 0xE2E2E2))) {
                    store.addScene(name: "#\(store.scenes.count + 1) Scene")
                    mode = .scenes
                }
                ToolbarButton(title: "리허설 모드", style: .filled(Color(hex: 0xB6B6B6))) {}
                // 씬 단위 ↔ 트리거 단위 전환
                ToolbarButton(title: mode == .scenes ? "트리거 단위" : "씬 단위", style: .outline) {
                    if mode == .scenes {
                        if let sceneID = lastSceneID ?? store.scenes.first?.id {
                            showTriggers(of: sceneID)
                        }
                    } else {
                        mode = .scenes
                    }
                }
            }
        }
    }

    private func showTriggers(of sceneID: ShowScene.ID) {
        lastSceneID = sceneID
        mode = .triggers(sceneID)
    }

    // 트리거 단위에서 볼 씬 고르기: "#1 Scene | 부제"
    private func sceneMenu(selected sceneID: ShowScene.ID) -> some View {
        Menu {
            ForEach(store.scenes) { scene in
                Button(sceneLabel(scene)) { showTriggers(of: scene.id) }
            }
        } label: {
            HStack {
                Text(store.scenes.first { $0.id == sceneID }.map(sceneLabel) ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0x111827))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: 0x111827))
            }
            .padding(.horizontal, 17)
            .frame(width: 301, height: 34)
            .background(Color(hex: 0xFDFDFD), in: .capsule)
            .overlay(Capsule().stroke(Color(hex: 0xE2E2E2)))
            .contentShape(.capsule)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func sceneLabel(_ scene: ShowScene) -> String {
        scene.subtitle.isEmpty ? scene.name : "\(scene.name)  |  \(scene.subtitle)"
    }
}

private struct ToolbarButton: View {
    enum Style {
        case outline
        case filled(Color)
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: 0x111827))
                .frame(width: 85, height: 34)
                .background(background, in: .rect(cornerRadius: 6))
                .overlay {
                    if case .outline = style {
                        RoundedRectangle(cornerRadius: 6).stroke(Color(hex: 0xC9CED6))
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        switch style {
        case .outline: .white
        case .filled(let color): color
        }
    }
}

// 팀원 아바타 + 초대하기 (모양만)
private struct InviteBox: View {
    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: -6) {
                ForEach(["U", "K"], id: \.self) { initial in
                    Text(initial)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0x6B7280))
                        .frame(width: 26, height: 26)
                        .background(Color(hex: 0xD9D9D9), in: .circle)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
                .foregroundStyle(Color(hex: 0x6B7280))
            Spacer(minLength: 0)
            ToolbarButton(title: "초대하기", style: .filled(Color(hex: 0xB6B6B6))) {}
        }
        .padding(.horizontal, 12)
        .frame(width: 186, height: 49)
        .background(Color(hex: 0xEEEEEE), in: .rect(cornerRadius: 6))
    }
}

#Preview {
    MainCueView()
        .environment(CueStore.sample())
        .frame(width: 1512, height: 930)
}
