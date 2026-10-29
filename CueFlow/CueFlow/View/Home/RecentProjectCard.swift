//
//  RecentProjectCard.swift
//  CueFlow
//
//  홈 화면 "최근에 열어본 프로젝트" 카드 한 장 (피그마 951:11292).
//  보여줄 글자는 바깥에서 받는다. (데이터 연결은 HomeView에서)
//  수정한 때 / 제목 + 태그(장르 · 규모) / 일정 / 구분선 / 인원 · 러닝타임 / 버튼 두 개
//

import SwiftUI

struct RecentProjectCard: View {
    let lastWorked: String      // 예: "오늘 16:32 수정"
    let title: String           // 예: "레미제라블"
    let tags: [String]          // 예: ["뮤지컬", "중극장"] (빈 글자는 숨김)
    let members: String         // 예: "배우 22명 · 스태프 16명"
    var runningTime: String?    // 예: "러닝타임 170분" (없으면 숨김)
    let schedule: String        // 예: "2026.11.14-15 · 아트스페이스 A홀"
    let onRehearsal: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 피그마 글자: 10 regular neutral400 / 17 bold neutral700 / 12 semibold neutral500 / 11 semibold neutral600
            VStack(alignment: .leading, spacing: 6) {
                Text(lastWorked)
                    .font(.footnote)
                    .foregroundStyle(Color.neutral400)

                HStack(spacing: 5) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(Color.neutral700)
                    HStack(spacing: 7) {
                        ForEach(tags.filter { !$0.isEmpty }, id: \.self) { tag in
                            Text(tag)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.neutral500)
                                .padding(.horizontal, 6)
                                .frame(height: 25)
                                .background(Color.neutral100, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.callout)
                    Text(schedule)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.neutral600)

                Divider()

                HStack(spacing: 10) {
                    Text(members)
                    if let runningTime {
                        Text(runningTime)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.neutral600)
            }
            .padding(.top, 21)

            Spacer(minLength: 0)

            // 피그마 951:11296: 리허설 모드는 흰 바탕, 이어서 작업하기는 연보라 바탕 (예전과 반대)
            HStack(spacing: 10) {
                Button("리허설 모드", action: onRehearsal)
                    .buttonStyle(ProjectCardButtonStyle(isFilled: false))
                Button("이어서 작업하기", action: onContinue)
                    .buttonStyle(ProjectCardButtonStyle(isFilled: true))
            }
            .frame(height: 36)
        }
        .lineLimit(1)
        .padding(25)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 213)
        .background {
            // 피그마: 바탕 #FBFBFF, 그림자 2·2·1 #D1D1D6 → 색상 표에서 가장 가까운 neutral25 · neutral300
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.neutral25)
                .shadow(color: Color.neutral300, radius: 0.5, x: 2, y: 2)
        }
    }
}

// 카드 버튼 (피그마 btn_project_01 · 02): 보라 테두리 + 진보라 글자. 이어서 작업하기는 연보라 바탕, 리허설 모드는 흰 바탕
// 피그마 바탕 #CFCCFF · 글자 #1C0C6C는 색상 표에 없어서 가장 가까운 brandPrimaryDisabled · brandPrimaryText (셀리나 확인 필요)
private struct ProjectCardButtonStyle: ButtonStyle {
    let isFilled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.brandPrimaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.brandPrimaryHover, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }

    private func background(isPressed: Bool) -> Color {
        if isFilled {
            return isPressed ? Color.brandPrimaryHover : Color.brandPrimaryDisabled
        }
        return isPressed ? Color.brandPrimarySubtle : Color.neutral25
    }
}

#Preview {
    RecentProjectCard(
        lastWorked: "오늘 16:32 수정",
        title: "레미제라블",
        tags: ["뮤지컬", "중극장"],
        members: "배우 22명 · 스태프 16명",
        runningTime: "러닝타임 170분",
        schedule: "2026.11.14-15 · 아트스페이스 A홀",
        onRehearsal: {},
        onContinue: {}
    )
    .frame(width: 386)
    .padding()
}
