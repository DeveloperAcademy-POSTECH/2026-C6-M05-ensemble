//
//  StageGridSheet.swift
//  CueFlow
//
//  "무대 칸 설정" (피그마 무대칸설정 1361:9564). 무대를 3×3 · 4×4 · 5×5로 나누거나 구분선 없이(기본) 본다.
//  배우 · 소품 목록 → 다음으로 → 여기 → 적용 완료 → 무대 배치.
//  칸 수를 바꾸면 무대 큐가 고른 칸(Cue.stageCell) 번호가 맞지 않게 되므로, 묻고 나서 칸 미정으로 비운다.
//

import SwiftUI

struct StageGridSheet: View {
    let production: Production
    let onBack: () -> Void    // "<" → 배우 · 소품 목록으로
    let onApply: () -> Void   // "적용 완료" → 무대 배치로

    @State private var selected: Int
    @State private var isConfirmingReset = false

    // 고를 수 있는 칸: 3 · 4 · 5 = n×n, 0 = 기본(구분선 없음)
    private static let options = [3, 4, 5, 0]

    init(production: Production, onBack: @escaping () -> Void, onApply: @escaping () -> Void) {
        self.production = production
        self.onBack = onBack
        self.onApply = onApply
        _selected = State(initialValue: production.stageGridColumns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetBackButton(action: onBack)
                .padding(.leading, -2)

            SheetHeader(
                title: "무대 칸 설정",
                subtitle: "동선을 확인하기 위해 원하는 칸으로 무대를 나눠보세요."
            ) {
                EmptyView()
            }
            .padding(.top, 36)

            HStack(spacing: 20) {
                ForEach(Self.options, id: \.self) { columns in
                    StageGridOption(columns: columns, isSelected: selected == columns)
                        .onTapGesture { selected = columns }
                }
            }
            .padding(.top, 114)

            Spacer(minLength: 20)

            Button("적용 완료", action: apply)
                .buttonStyle(SheetSoftButtonStyle())
                .frame(width: 130, height: 36)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 69)
        .padding(.top, 52)
        .padding(.bottom, 50)
        .frame(width: 1049, height: 800)
        .background(Color.surfaceWhite)
        .alert("무대 칸을 바꿀까요?", isPresented: $isConfirmingReset) {
            Button("취소", role: .cancel) { }
            Button("바꾸기", role: .destructive) {
                cuesWithCell.forEach { $0.stageCell = nil }
                production.stageGridColumns = selected
                onApply()
            }
        } message: {
            Text("무대 큐 \(cuesWithCell.count)개의 칸 위치가 지워져요. 리허설 큐 목록에서 다시 골라주세요.")
        }
    }

    // 무대 칸을 이미 고른 큐 (칸 수가 바뀌면 다시 골라야 함)
    private var cuesWithCell: [Cue] {
        (production.scenes ?? [])
            .flatMap { $0.triggers ?? [] }
            .flatMap { $0.cues ?? [] }
            .filter { $0.stageCell != nil }
    }

    private func apply() {
        if selected != production.stageGridColumns, !cuesWithCell.isEmpty {
            isConfirmingReset = true
            return
        }
        production.stageGridColumns = selected
        onApply()
    }
}

// 칸 하나: 무대 미리보기 + "3x3" + "9개 영역". 고르면 보라 테두리 + 연보라 바탕
private struct StageGridOption: View {
    let columns: Int
    let isSelected: Bool

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    // 다크 피그마(2054:4440): 테두리 2 · 모서리 10
    private var cornerRadius: CGFloat { colorScheme == .dark ? 10 : 6 }
    private var borderWidth: CGFloat { colorScheme == .dark ? 2 : (isSelected ? 1.5 : 1) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.gridPreviewSelected : Color.gridPreview)
                StageGridLines(columns: columns)
                    .stroke(Color.gridPreviewLine, style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.gridPreviewBorder, lineWidth: 0.8)
            }
            .frame(width: 133, height: 82)

            Text(columns > 0 ? "\(columns)x\(columns)" : "기본")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.brandPrimaryText)
                .padding(.top, 32)
            Text(columns > 0 ? "\(columns * columns)개 영역" : "구분선 없이 보기")
                .font(.system(size: 12))
                .foregroundStyle(Color.neutral900)
                .padding(.top, 5)
        }
        .padding(.top, 38)
        .frame(width: 210, height: 240, alignment: .top)
        .background(
            isSelected ? Color.stageOptionSelected : Color.surfaceWhite,
            in: RoundedRectangle(cornerRadius: cornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    isSelected || isHovered ? Color.stageOptionSelectedBorder : Color.stageOptionBorder,
                    lineWidth: borderWidth
                )
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

#Preview {
    StageGridSheet(production: RehearsalPreviewData.production, onBack: { }, onApply: { })
}
