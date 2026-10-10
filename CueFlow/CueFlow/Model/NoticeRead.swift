//
//  NoticeRead.swift
//  CueFlow
//
//  Created by yunseo on 10/10/26.
//

import Foundation
import SwiftData

@Model
final class NoticeRead {
    var id: UUID = UUID()
    var readAt: Date = Date()

    var notice: Notice?                       // 어느 공지를
    var member: Member?                 // 누가 읽었는지

    init() {}
}
