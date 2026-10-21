//
//  CreateStepLayout.swift
//  CueFlow
//
//  Created by 김나현 on 10/16/26.
//

import SwiftUI

// 새 공연 만들기 화면 공통 틀
// 제목 · 부제 · 단계 표시 · (가운데 내용) · 창 오른쪽 아래 이전으로 / 다음으로
struct CreateStepLayout<Content: View>: View {
    let title: String
    let subtitle: String
    let currentStep: Int
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}
    @ViewBuilder var content: Content

    private var steps: [String] { ["기본 정보", "파트 구성", "씬 구성", "생성 확인"] }

    var body: some View {
        ScrollView {
            page
        }
        .overlay(alignment: .bottom) { footer }
        .frame(minWidth: 850)
        .background(.white)
    }

    // 가운데 (폭 799). 내용과 단계 표시 사이 간격은 각 화면에서 정한다
    private var page: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            stepBar
                .padding(.top, 20)
            content
        }
        .frame(width: 799)
        .padding(.top, 163)
        .padding(.bottom, 209)
        .frame(maxWidth: .infinity)
    }
}

// 제목 · 단계

extension CreateStepLayout {
    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.neutral900)
            Text(subtitle)
                .font(.system(size: 17))
                .foregroundStyle(Color.neutral500)
        }
    }

    // 기본 정보 ── 파트 구성 ── 씬 구성 ── 생성 확인
    private var stepBar: some View {
        HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { index in
                stepItem(number: index + 1, title: steps[index])
                if index < steps.count - 1 { stepLine }
            }
        }
    }

    private func stepItem(number: Int, title: String) -> some View {
        let isCurrent = number == currentStep
        return HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isCurrent ? Color.neutral25 : Color.neutral500)
                .frame(width: 24, height: 24)
                .background(isCurrent ? Color.neutral400 : Color.neutral200, in: .circle)
            Text(title)
                .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? Color.neutral900 : Color.neutral400)
        }
    }

    private var stepLine: some View {
        Color.neutral300
            .frame(width: 50, height: 1)
    }
}

// 이전으로 · 다음으로

extension CreateStepLayout {
    private var footer: some View {
        footerButtons
            .background(Color.neutral25)
            .frame(width: 799, alignment: .trailing)
            .padding(.bottom, 124)
    }

    private var footerButtons: some View {
        HStack(spacing: 15) {
            Button("이전으로", action: onPrevious)
                .buttonStyle(.secondary)
                .frame(width: 175, height: 45)
            Button("다음으로", action: onNext)
                .buttonStyle(.primary)
                .frame(width: 175, height: 45)
        }
    }
}
