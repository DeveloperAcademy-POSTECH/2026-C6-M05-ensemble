//
//  Production+Home.swift
//  CueFlow
//
//  홈 화면에 보여줄 글자를 공연 데이터로 만드는 곳.
//  아직 모델에 없는 정보(공연장, 회차, 배우/스태프 수, 소유자)는 빈칸으로 둔다.
//

import Foundation

extension Production {
    // "뮤지컬 | 레미제라블"
    var cardTitle: String {
        genre.isEmpty ? title : "\(genre) | \(title)"
    }

    // "뮤지컬_레미제라블"
    var listName: String {
        genre.isEmpty ? title : "\(genre)_\(title)"
    }

    // "최근 작업 오늘 16:32" / "최근 작업 9월 28일"
    var lastWorkedText: String {
        if Calendar.current.isDateInToday(lastOpenedAt) {
            return "최근 작업 오늘 " + Self.format(lastOpenedAt, "HH:mm")
        }
        return "최근 작업 " + Self.format(lastOpenedAt, "M월 d일")
    }

    // "총 38명"  TODO: 배우/스태프 구분이 정해지면 "배우 22명 · 스태프 16명 · 총 38명"
    var memberCountText: String {
        "총 \(members?.count ?? 0)명"
    }

    // "2026.11.14"  TODO: 공연장·마지막 공연일이 생기면 "2026.11.14-15 · 아트스페이스 A홀"
    var scheduleText: String {
        Self.format(firstShowDate, "yyyy.MM.dd")
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
