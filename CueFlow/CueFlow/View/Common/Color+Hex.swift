//
//  Color+Hex.swift
//  CueFlow
//

import SwiftUI

extension Color {
    // 피그마 hex 값 그대로 쓰기: Color(hex: 0xC9CED6)
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
