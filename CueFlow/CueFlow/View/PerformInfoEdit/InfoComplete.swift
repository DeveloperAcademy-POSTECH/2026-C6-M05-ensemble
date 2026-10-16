//
//  InfoComplete.swift
//  CueFlow
//
//  Created by 김나현 on 10/16/26.
//

import SwiftUI

// 완료: 프로젝트가 만들어졌다고 알려주는 마지막 화면 (창 정가운데)
struct InfoComplete: View {
    var onGoHome: () -> Void = {}         // 홈으로 가기
    var onStartEditing: () -> Void = {}   // 큐시트 편집 시작하기 (메인 큐시트로)

    var body: some View {
        VStack(spacing: 30) {
            message
            buttons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }
}

extension InfoComplete {
    // 제목 + 설명 (간격 10, 가운데 정렬)
    private var message: some View {
        VStack(spacing: 10) {
            Text("프로젝트가 생성되었습니다")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.neutral900)
            Text("파트별 큐와 변경 내용이 통합되었고, 필수 담당자의 확인이 완료되었습니다.")
                .font(.system(size: 15))
                .foregroundStyle(Color.neutral500)
        }
        .multilineTextAlignment(.center)
    }

    // 200 × 40 버튼 두 개, 간격 15
    private var buttons: some View {
        HStack(spacing: 15) {
            Button("홈으로 가기", action: onGoHome)
                .buttonStyle(.secondary)
                .frame(width: 200, height: 40)
            Button("큐시트 편집 시작하기", action: onStartEditing)
                .buttonStyle(.primary)
                .frame(width: 200, height: 40)
        }
    }
}

#Preview {
    InfoComplete()
        .frame(width: 1512, height: 982)
}
