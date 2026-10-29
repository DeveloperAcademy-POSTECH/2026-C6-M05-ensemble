//
//  DateCard.swift
//  CueFlow
//
//  Created by 김나현 on 10/15/26.
//

import SwiftUI

// 공연 기간 달력 카드: 첫 클릭 = 시작일, 두 번째 클릭 = 종료일
struct DateCard: View {
    @Binding var startDate: Date
    @Binding var endDate: Date?
    var onComplete: () -> Void = {}
    
    @State private var month = Date()          // 왼쪽에 보이는 달
    @State private var pickedStart: Date?   // 첫 클릭으로 고른 시작일 (종료일 고를 때까지 카드 안에만 둠)
    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            monthView(month)
            monthView(calendar.date(byAdding: .month, value: 1, to: month)!)
        }
        .overlay(alignment: .top) { arrows }
        .onAppear { month = startDate }
    }
    
    // 2026 September + 요일 + 날짜들
    private func monthView(_ month: Date) -> some View {
        VStack(spacing: 8) {
            Text(String(calendar.component(.year, from: month)) + " "
                 + month.formatted(.dateTime.month(.wide).locale(Locale(identifier: "en_US"))))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.neutral900)
            
            HStack(spacing: 0) {
                ForEach(weekdays.indices, id: \.self) { index in
                    Text(weekdays[index])
                        .font(.system(size: 11))
                        .foregroundStyle(Color.neutral400)
                        .frame(width: 32)
                }
            }
            
            let days = days(in: month)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 0), count: 7), spacing: 4) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
        .frame(width: 32 * 7)
    }
    
    private func dayCell(_ date: Date) -> some View {
        let isEdge = pickedStart.map { isSame(date, $0) } ?? (endDate != nil && (isSame(date, startDate) || isSame(date, endDate)))
        return Text("\(calendar.component(.day, from: date))")
            .font(.system(size: 12, weight: isEdge ? .semibold : .regular))
            .foregroundStyle(isEdge ? .white : Color.neutral900)
            .frame(width: 32, height: 32)
            .background { if isEdge { Circle().fill(Color.brandPrimary) } }
            .background(band(for: date))
            .contentShape(.rect)
            .onTapGesture { select(date) }
    }
    
    // 시작일~종료일 사이 연보라 띠 (시작일은 오른쪽 반, 종료일은 왼쪽 반만)
    @ViewBuilder
    private func band(for date: Date) -> some View {
        if pickedStart == nil, let end = endDate, !isSame(startDate, end) {
            if isSame(date, startDate) {
                HStack(spacing: 0) { Color.clear; Color.brandPrimarySubtle }
            } else if isSame(date, end) {
                HStack(spacing: 0) { Color.brandPrimarySubtle; Color.clear }
            } else if date > startDate && date < end {
                Color.brandPrimarySubtle
            }
        }
    }
    
    // ‹ ›  달 넘기기
    private var arrows: some View {
        HStack {
            arrowButton("chevron.left", by: -1)
            Spacer()
            arrowButton("chevron.right", by: 1)
        }
    }
    
    private func arrowButton(_ icon: String, by value: Int) -> some View {
        Button {
            month = calendar.date(byAdding: .month, value: value, to: month)!
        } label: {
            Image(systemName: icon)
                .foregroundStyle(Color.neutral500)
        }
        .buttonStyle(.plain)
    }
    
    private func select(_ date: Date) {
        if let start = pickedStart, date >= start {
            startDate = start
            endDate = date
            pickedStart = nil
            onComplete()
        } else {
            pickedStart = date
        }
    }
    
    // 그 달의 날짜 배열 (1일 앞 빈칸은 nil)
    private func days(in month: Date) -> [Date?] {
        let first = calendar.dateInterval(of: .month, for: month)!.start
        let blanks = calendar.component(.weekday, from: first) - 1
        let count = calendar.range(of: .day, in: .month, for: first)!.count
        return Array(repeating: nil, count: blanks)
        + (0..<count).map { calendar.date(byAdding: .day, value: $0, to: first) }
    }
    
    private func isSame(_ date: Date, _ other: Date?) -> Bool {
        guard let other else { return false }
        return calendar.isDate(date, inSameDayAs: other)
    }
}

#Preview {
    @Previewable @State var start = Date()
    @Previewable @State var end: Date? = nil
    DateCard(startDate: $start, endDate: $end)
        .popoverStyle(width: nil)
        .padding(60)
}
