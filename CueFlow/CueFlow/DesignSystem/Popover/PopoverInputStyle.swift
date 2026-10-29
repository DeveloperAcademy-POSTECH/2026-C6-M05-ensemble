//
//  PopoverInputStyle.swift
//  CueFlow
//
//  Created by 김나현 on 10/13/26.
//

import SwiftUI

extension View {
    // TextField 뒤에 붙이면 팝오버 입력칸 모양이 됨
    func popoverInputStyle() -> some View {
        HStack {
            self.textFieldStyle(.plain)
            Image(systemName: "return")
                .foregroundStyle(Color.neutral300)
        }
        .font(.callout)
        .foregroundStyle(Color.neutral800)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)       // 글이 길어지면 줄이 늘어나며 칸도 같이 커짐
        .frame(minHeight: 30)        // 한 줄일 때는 원래처럼 30
        .background(.white, in: .rect(cornerRadius: 8))
    }
}

extension Text {
    // 입력칸이 비어 있을 때 보이는 회색 안내 글씨
    static var popoverPlaceholder: Text {
        Text("내용을 입력하세요")
            .foregroundStyle(Color.neutral400)
    }
}
