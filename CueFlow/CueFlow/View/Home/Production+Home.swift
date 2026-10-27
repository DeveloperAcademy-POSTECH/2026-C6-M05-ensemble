//
//  Production+Home.swift
//  CueFlow
//
//  홈 화면에 보여줄 글자를 공연 데이터로 만드는 곳.
//  아직 모델에 없는 정보(회차, 소유자)는 빈칸으로 둔다.
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

    // "배우 22명 · 스태프 16명 · 총 38명" — 초대 수락 후 고른 역할로 센다 (InviteRoleView)
    // 배우 = 무대 위 역할을 고른 사람, 스태프 = 파트를 맡은 사람. 둘 다 고른 사람은 양쪽에 세고, 총은 사람 수
    var memberCountText: String {
        let members = members ?? []
        let onStage = members.filter(\.isOnStage).count
        let staff = members.filter(\.isStaff).count
        return "배우 \(onStage)명 · 스태프 \(staff)명 · 총 \(members.count)명"
    }

    // "2026.11.14 · 아트스페이스 A홀" (공연장이 비었으면 날짜만)
    var scheduleText: String {
        let date = Self.format(firstShowDate, "yyyy.MM.dd")
        return venue.isEmpty ? date : "\(date) · \(venue)"
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
