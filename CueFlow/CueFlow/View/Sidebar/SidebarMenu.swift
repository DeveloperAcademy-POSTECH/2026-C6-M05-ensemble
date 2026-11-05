//
//  SidebarMenu.swift
//  CueFlow
//
//  사이드바 메뉴 종류. 메뉴마다 보여줄 이름과 아이콘을 함께 가진다.
//

import Foundation

enum SidebarMenu: CaseIterable {
    case project
    case notice
    case help

    // 사이드바에 보여줄 메뉴
    // 도움말은 화면이 생기면 다시 넣는다 (지금은 빈 화면이라 App Store 심사 전에 숨김)
    static var visibleCases: [SidebarMenu] { [.project, .notice] }

    var title: String {
        switch self {
        case .project: "홈"
        case .notice: "공지사항"
        case .help: "도움말"
        }
    }

    // SF Symbol 이름
    var icon: String {
        switch self {
        case .project: "house"
        case .notice: "envelope"
        case .help: "info.circle"
        }
    }
}
