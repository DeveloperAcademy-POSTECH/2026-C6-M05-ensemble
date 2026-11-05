//
//  SidebarCloseButton.swift
//  CueFlow
//
//  Created by 김나현 on 11/5/26.
//

import SwiftUI

// 오른쪽 사이드바 닫기 버튼 « (피그마 Sidebar: chevron.left.2, SF Pro Regular 16, neutral/900, 19 × 19)
struct SidebarCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left.2")
                .font(.system(size: 16))
                .foregroundStyle(Color.neutral900)
                .frame(width: 19, height: 19)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
