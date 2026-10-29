//
//  Production+Home.swift
//  CueFlow
//
//  홈 화면에 보여줄 글자를 공연 데이터로 만드는 곳.
//  아직 모델에 없는 정보(회차, 배우/스태프 수, 소유자)는 빈칸으로 둔다.
//

import Foundation

extension Production {
    // "뮤지컬_레미제라블"
    var listName: String {
        genre.isEmpty ? title : "\(genre)_\(title)"
    }

    // "오늘 16:32 수정" / "9월 28일 수정" (피그마 951:11299)
    var lastWorkedText: String {
        if Calendar.current.isDateInToday(updatedAt) {
            return "오늘 " + Self.format(updatedAt, "HH:mm") + " 수정"
        }
        return Self.format(updatedAt, "M월 d일") + " 수정"
    }

    // "총 38명"
    // TODO: 프로젝트 생성 화면에서 배우 · 스태프 수를 입력받으면 "배우 22명 · 스태프 16명 · 총 38명"
    //       (생성 화면 담당자가 Production에 칸을 추가한 뒤 연결)
    var memberCountText: String {
        "총 \(members?.count ?? 0)명"
    }

    // "2026.11.14-15 · 아트스페이스 A홀" (공연장이 비었으면 날짜만)
    var scheduleText: String {
        venue.isEmpty ? showPeriodText : "\(showPeriodText) · \(venue)"
    }

    // 공연 기간. 하루면 "2026.11.14", 같은 달이면 "2026.11.14-15", 달이 다르면 "2026.11.30-12.01", 해가 다르면 둘 다 전부
    private var showPeriodText: String {
        let start = Self.format(firstShowDate, "yyyy.MM.dd")
        let calendar = Calendar.current
        guard let lastShowDate, !calendar.isDate(lastShowDate, inSameDayAs: firstShowDate) else { return start }

        let end: String
        if !calendar.isDate(lastShowDate, equalTo: firstShowDate, toGranularity: .year) {
            end = Self.format(lastShowDate, "yyyy.MM.dd")
        } else if !calendar.isDate(lastShowDate, equalTo: firstShowDate, toGranularity: .month) {
            end = Self.format(lastShowDate, "MM.dd")
        } else {
            end = Self.format(lastShowDate, "dd")
        }
        return "\(start)-\(end)"
    }

    // "러닝타임 170분" (안 적었으면 nil → 카드에서 줄을 숨긴다)
    var runningTimeText: String? {
        runningTime.map { "러닝타임 \($0)분" }
    }

    // "1,200석" (객석 규모를 안 적었으면 빈칸)
    // TODO: 회차를 입력받게 되면 "1,200석 · 2회 공연"
    var summaryText: String {
        guard let seatCount else { return "" }
        return "\(seatCount.formatted())석"
    }

    // "9월 28일"
    var updatedDateText: String {
        Self.format(updatedAt, "M월 d일")
    }

    // 날짜를 정해진 모양의 글자로 바꾼다. 예: format(date, "yyyy.MM.dd") → "2026.11.14"
    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
