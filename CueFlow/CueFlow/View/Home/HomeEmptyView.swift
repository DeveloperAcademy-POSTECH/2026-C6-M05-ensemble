//
//  HomeEmptyView.swift
//  CueFlow
//
//  프로젝트가 하나도 없을 때 홈 화면.
//

import SwiftUI

struct HomeEmptyView: View {
    var onGoHome: () -> Void = {}   // "홈으로 가기" → 프로젝트 목록 홈 화면 (피그마 951:11194)
    var onNewProject: () -> Void = {}   // "새 프로젝트" → 새 공연 만들기 흐름

    var body: some View {
        if Platform.canEditCueSheet {
            macBody
        } else {
            iPadBody
        }
    }

    // 아이패드: 공연은 맥에서 만든다는 안내 (#156). 같은 iCloud 계정이면 맥에서 만든 공연이 자동으로 들어온다
    private var iPadBody: some View {
        VStack(spacing: 30) {
            Image(systemName: "macbook.and.ipad")
                .font(.system(size: 56))
                .foregroundStyle(Color.brandPrimary)

            VStack(spacing: 14) {
                Text("큐시트는 Mac에서 만들어요")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Mac의 Cuedit에서 공연을 만들면 같은 iCloud 계정의 iPad에 자동으로 나타나요.\n팀원에게 초대받은 공연도 여기에서 볼 수 있어요.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("홈으로 가기", action: onGoHome)
                .buttonStyle(.secondary)
                .frame(width: 200, height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var macBody: some View {
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
                Button("홈으로 가기", action: onGoHome)
                .buttonStyle(.secondary)
                .frame(width: 200, height: 40)

                Button("새 프로젝트") {
                    onNewProject()
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
