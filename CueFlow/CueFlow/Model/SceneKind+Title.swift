//
//  SceneKind+Title.swift
//  CueFlow
//
//  Created by 김나현 on 11/3/26.
//

import Foundation

extension SceneKind {
    var title: String {
        switch self {
        case .scene: return "씬"
        case .number: return "넘버"
        case .transition: return "암전"
        }
    }
}
