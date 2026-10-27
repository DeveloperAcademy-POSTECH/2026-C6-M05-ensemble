//
//  PerformInfo.swift
//  CueFlow
//
//  Created by 김나현 on 10/15/26.
//

import SwiftUI

// 새 공연 만들기에서 입력한 값을 모아 두는 곳 (마지막 단계에서 Production으로 저장)
struct ProductionDraft {
    var title = ""
    var genre = "뮤지컬"
    var firstShowDate = Date()
    var lastShowDate: Date?
    var venue = ""
    var seatCount: Int?
    var organizer = ""
    var runningTime: Int?
}

struct PerformInfo: View {
    @Binding var draft: ProductionDraft
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}
    
    @State private var isPickingDate = false   // 공연일 달력이 열려 있는지
    
    private static let genres = ["뮤지컬", "연극", "무용", "콘서트", "기타"]
    
    var body: some View {
        CreateStepLayout(
            title: "공연 기본 정보를 입력해주세요",
            subtitle: "큐시트 생성에 필요한 핵심 정보만 먼저 입력하고, 세부 항목은 나중에 보완합니다.",
            currentStep: 1,
            onPrevious: onPrevious,
            onNext: onNext
        ) {
            formFields
                .padding(.top, 50)
        }
    }
}

// 입력칸들

extension PerformInfo {
    private var formFields: some View {
        VStack(alignment: .leading, spacing: 25) {            labeledField("공연명", isRequired: true) { textField(text: $draft.title) }
            HStack(alignment: .top, spacing: 15) {
                labeledField("공연유형") { genrePicker }
                labeledField("공연일") { dateField }
            }
            HStack(alignment: .top, spacing: 15) {
                labeledField("공연장") { textField(text: $draft.venue) }
                labeledField("객석 규모") { numberField(value: $draft.seatCount, unit: "석") }
            }
            HStack(alignment: .top, spacing: 15) {
                labeledField("주최") { textField(text: $draft.organizer) }
                labeledField("러닝타임") { numberField(value: $draft.runningTime, unit: "분") }
            }
        }
    }
    
    // 제목 + 입력칸 한 묶음
    private func labeledField<Content: View>(_ title: String, isRequired: Bool = false,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel(title, isRequired: isRequired)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // "공연명*" 처럼 필수 항목은 뒤에 * 표시
    private func fieldLabel(_ title: String, isRequired: Bool) -> some View {
        HStack(spacing: 2) {
            Text(title)
                .foregroundStyle(Color.neutral900)
            if isRequired {
                Text("*")
                    .foregroundStyle(Color.neutral400)
            }
        }
        .font(.system(size: 17, weight: .semibold))
    }
    
    private func textField(text: Binding<String>) -> some View {
        TextField("", text: text)
            .textFieldStyle(.plain)
            .formBox()
    }
    
    // 숫자만 받는 입력칸 + 칸 안 오른쪽 끝에 고정 단위 (객석 규모 "석", 러닝타임 "분")
    private func numberField(value: Binding<Int?>, unit: String) -> some View {
        HStack(spacing: 4) {
            TextField("", value: value, format: .number)
                .textFieldStyle(.plain)
            Text(unit)
                .foregroundStyle(Color.neutral500)
        }
        .formBox()
    }
}

// 공연유형 · 공연일

extension PerformInfo {
    // 뮤지컬 · 연극 · 무용 · 콘서트 · 기타 중 하나 고르기
    private var genrePicker: some View {
        HStack(spacing: 4) {
            ForEach(Self.genres, id: \.self) { genreChip($0) }
        }
        .padding(7)
        .frame(height: 48)
        .background(Color.neutral25, in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.neutral300))
    }
    
    private func genreChip(_ genre: String) -> some View {
        let isSelected = draft.genre == genre
        return Button { draft.genre = genre } label: {
            Text(genre)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Color.neutral900 : Color.neutral500)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? Color.neutral100 : .clear, in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
    
    // 날짜 칸: 누르면 달력 팝오버
    private var dateField: some View {
        Button { isPickingDate = true } label: { dateFieldLabel }
            .buttonStyle(.plain)
            .popover(isPresented: $isPickingDate, arrowEdge: .bottom) { calendar }
    }
    
    private var dateFieldLabel: some View {
        HStack {
            Text(dateText)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(Color.neutral500)
        }
        .formBox()
        .contentShape(.rect)
    }
    
    // 날짜를 고르면 달력이 바로 닫힘
    private var calendar: some View {
        DateCard(startDate: $draft.firstShowDate,
                 endDate: $draft.lastShowDate,
                 onComplete: { isPickingDate = false })
        
    }
    
    
    // "2026.09.17 - 2026.10.17" (종료일이 없으면 시작일만)
    private var dateText: String {
        let start = Self.dateFormatter.string(from: draft.firstShowDate)
        guard let end = draft.lastShowDate else { return "" }
        return "\(start) ~ \(Self.dateFormatter.string(from: end))"    }
    
    // 2026.11.14 모양
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

// 입력칸 공통 모양: 흰 배경 + 연한 테두리

private extension View {
    func formBox() -> some View {
        self
            .font(.system(size: 13))
            .foregroundStyle(Color.neutral900)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(.white, in: .rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.neutral300))
    }
}

#Preview {
    @Previewable @State var draft = ProductionDraft()
    PerformInfo(draft: $draft)
        .frame(width: 1100, height: 800)
}
