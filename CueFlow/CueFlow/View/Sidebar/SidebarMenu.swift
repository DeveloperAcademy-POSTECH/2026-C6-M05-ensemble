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

    // 사이드바에 보여줄 메뉴 (유저테스트 때는 프로젝트만)
    static var visibleCases: [SidebarMenu] {
        UserTest.hidesUnfinished ? [.project] : allCases
    }

    var title: String {
        switch self {
        case .project: "프로젝트"
        case .notice: "공지사항"
        case .help: "도움말"
        }
    }

    // SF Symbol 이름
    var icon: String {
        switch self {
        case .project: "folder"
        case .notice: "envelope"
        case .help: "info.circle"
        }
    }
}
