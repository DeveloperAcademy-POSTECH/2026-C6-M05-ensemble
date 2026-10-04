//
//  MainCueView.swift
//  CueFlow
//
//  메인 큐 화면 (피그마 로우파이_4차 · 메인큐화면)
//  윗줄: 공연 제목 + 변경건 / 미확인 / 초대하기
//  둘째 줄: 파트 필터(B) + 씬 추가 / 리허설 모드 / 트리거 단위
//  그 아래: 파트 × 씬 표
//

import SwiftUI

struct MainCueView: View {
    @Environment(CueStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBar
                .padding(.top, 34)
            toolBar
                .padding(.top, 11)
                .padding(.bottom, 13)
            CueGridView()
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
                ToolbarButton(title: "+ 씬 추가", style: .filled(Color(hex: 0xE2E2E2))) {
                    store.addScene(name: "#\(store.scenes.count + 1) Scene")
                }
                ToolbarButton(title: "리허설 모드", style: .filled(Color(hex: 0xB6B6B6))) {}
                ToolbarButton(title: "트리거 단위", style: .outline) {}   // 다음 단계: 트리거 뷰로 이동
            }
        }
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
