//
//  HomeEmptyView.swift
//  CueFlow
//
//  프로젝트가 하나도 없을 때 홈 화면.
//

import SwiftUI

struct HomeEmptyView: View {
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 14) {
                Text("아직 프로젝트가 없어요")
                    .font(.system(size: 28, weight: .bold))   // 피그마 Title1 28pt (macOS .title은 22pt라 직접 지정)
                    .foregroundStyle(.primary)

                Text("공연을 더 특별하게 만드는 첫걸음, 지금 프로젝트를 만들어보세요\n팀원과 함께 큐를 관리하고, 공연을 체계적으로 준비할 수 있습니다.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 15) {
                Button("홈으로 가기") {
                    // TODO: 동작 정하기 (디자이너 확인 필요)
                }
                .buttonStyle(.secondary)
                .frame(width: 200, height: 40)

                Button("새 프로젝트") {
                    // TODO: 프로젝트 생성 화면으로 이동 (다른 팀원 담당 화면)
                }
                .buttonStyle(.primary)
                .frame(width: 200, height: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HomeEmptyView()
        .frame(width: 1000, height: 700)
}
