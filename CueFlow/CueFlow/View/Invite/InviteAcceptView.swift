//
//  InviteAcceptView.swift
//  CueFlow
//
//  초대 링크로 들어왔을 때 보이는 초대 수락 화면 (피그마 초대수락화면).
//  TODO: 실제 초대/공유(iCloud) 방식이 정해지면 초대 정보 받기 + 수락 시 공연 참여 연결
//

import SwiftUI

// 받은 초대 정보. 지금은 화면에 보여 줄 공연 이름만 있다.
struct PendingInvite: Equatable {
    var productionTitle: String   // 예: "별이 빛나는 밤 뮤지컬"
}

struct InviteAcceptView: View {
    let invite: PendingInvite
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 60) {
            Text("프로젝트 초대를 수락하시겠습니까?")
                .font(.system(size: 24, weight: .bold))   // 피그마 24pt (macOS .title은 22pt라 직접 지정)

            // 썸네일 + 공연 이름 + "초대받음"
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.neutral200)   // 피그마 초대수락화면 썸네일 = Neutral/200
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 8) {
                    Text(invite.productionTitle)
                        .font(.title3.weight(.semibold))
                    Text("초대받음")
                        .foregroundStyle(.secondary)
                }
            }

            Button("초대 수락하기", action: onAccept)
                .buttonStyle(.primary)
                .frame(width: 415, height: 52)
        }
        .padding(.top, 46)
        .padding(.bottom, 45)
        .frame(width: 609)
        .background {
            // 그림자는 카드 바탕에만 (글자에 붙으면 글자가 번져 보임)
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: .gray.opacity(0.35), radius: 1, x: 2, y: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // 창 가운데에 카드
    }
}

#Preview {
    InviteAcceptView(invite: PendingInvite(productionTitle: "별이 빛나는 밤 뮤지컬")) { }
        .frame(width: 1512, height: 932)
}
