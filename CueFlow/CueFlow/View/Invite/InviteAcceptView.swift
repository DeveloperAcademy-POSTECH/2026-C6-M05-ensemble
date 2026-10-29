//
//  InviteAcceptView.swift
//  CueFlow
//
//  초대 링크로 들어왔을 때 보이는 초대 수락 화면 (피그마 초대수락화면).
//  링크로 앱이 열리면 ShareInvites가 초대를 받아 ContentView가 이 화면을 띄운다 (#68).
//

import SwiftUI
import CloudKit

// 받은 초대 정보
struct PendingInvite: Equatable {
    var productionTitle: String          // 예: "별이 빛나는 밤 뮤지컬"
    var metadata: CKShare.Metadata?      // iCloud가 준 초대 정보. 수락할 때 씀 (미리보기에선 nil)

    // 초대받은 공연의 id (공연 폴더 이름 = "Production-공연id"). 수락 후 역할 선택 화면에서 씀
    var productionID: UUID? {
        guard let zoneName = metadata?.share.recordID.zoneID.zoneName else { return nil }
        return UUID(uuidString: zoneName.replacingOccurrences(of: "Production-", with: ""))
    }
}

struct InviteAcceptView: View {
    let invite: PendingInvite
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 60) {
            Text("프로젝트 초대를 수락하시겠습니까?")
                .font(.system(size: 26, weight: .bold))   // 피그마 26pt (macOS 기본 스타일에 없어서 직접 지정)
                .foregroundStyle(Color.neutral900)

            // 썸네일 + 공연 이름 + "초대받음"
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.neutral200)   // 피그마 초대수락화면 썸네일 = Neutral/200
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 8) {
                    Text(invite.productionTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.neutral700)
                    Text("초대받음")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.neutral500)
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
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.neutral300, radius: 1, x: 2, y: 2)   // 피그마 Grays/Gray 3 #C7C7CC에 가장 가까운 색
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.neutral100, lineWidth: 1)   // 피그마 Backgrounds/Secondary #F2F2F7에 가장 가까운 색
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // 창 가운데에 카드
    }
}

#Preview {
    InviteAcceptView(invite: PendingInvite(productionTitle: "별이 빛나는 밤 뮤지컬")) { }
        .frame(width: 1512, height: 932)
}
