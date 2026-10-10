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
