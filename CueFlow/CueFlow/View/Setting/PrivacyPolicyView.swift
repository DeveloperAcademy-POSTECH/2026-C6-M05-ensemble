//
//  PrivacyPolicyView.swift
//  CueFlow
//
//  Created by 김나현 on 11/13/26.
//
//  설정 > 정보 > 개인정보 처리방침
//

import SwiftUI

struct PrivacyPolicyView: View {
    var onBack: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                policyCard
                    .padding(.top, 32)
            }
            .frame(maxWidth: 1069, alignment: .leading)
            .padding(.top, 151)
            .padding(.bottom, 60)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topLeading) { backButton }
        .background(Color.appBackground)
    }
}

extension PrivacyPolicyView {
    // 개인정보 처리방침 / 최종 업데이트
    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("개인정보 처리방침")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.neutral900)
            Text("최종 업데이트: \(Self.updatedAt)")
                .font(.system(size: 15))
                .foregroundStyle(Color.neutral500)
        }
    }

    // ← 설정으로 (설정 화면과 같은 위치)
    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "arrow.left")
                .font(.system(size: 24))
                .foregroundStyle(Color.neutral700)
                .frame(width: 36, height: 36)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.leading, 54)
        .padding(.top, 33.5)
    }

    // 흰 카드 안에 항목들, 사이사이 구분선
    private var policyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Self.sections.indices, id: \.self) { index in
                if index > 0 { divider }
                sectionView(Self.sections[index])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
        .background(Color.surfaceWhite, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.neutral200))
    }

    // 항목 하나: 제목 + 내용
    private func sectionView(_ section: PolicySection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.neutral900)
            Text(section.body)
                .font(.system(size: 13))
                .lineSpacing(4)   // 줄 높이 20
                .foregroundStyle(Color.neutral700)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 20)
    }

    private var divider: some View {
        Color.neutral100   // 피그마 #EEF0F3은 토큰이 없어 가장 가까운 색으로
            .frame(height: 1)
    }
}

// 내용 (바뀌면 여기만 고치기)

private struct PolicySection {
    let title: String
    let body: String
}

extension PrivacyPolicyView {
    private static let updatedAt = "2026년 10월 14일"

    private static let sections = [
        PolicySection(
            title: "수집하는 정보",
            body: "프로젝트에서 사용할 표시 이름과 프로필 사진, 사용자가 직접 작성한 공연 프로젝트 및 큐 정보를 처리합니다."
        ),
        PolicySection(
            title: "정보의 이용 목적",
            body: "팀원 식별, 공동 큐시트 작성, 변경사항 동기화와 알림 제공을 위해 사용합니다."
        ),
        PolicySection(
            title: "iCloud 동기화",
            body: "프로젝트 데이터는 사용자의 iCloud 계정을 통해 동기화됩니다. 앱은 별도의 로그인 계정이나 비밀번호를 저장하지 않습니다."
        ),
        PolicySection(
            title: "데이터 관리",
            body: "프로젝트를 삭제하면 해당 프로젝트 데이터도 삭제됩니다. 공동 프로젝트는 다른 참여자의 기기에 남아 있을 수 있습니다."
        ),
        PolicySection(
            title: "문의",
            body: "개인정보 관련 문의는 App Store에 등록된 지원 연락처를 이용해 주세요."
        )
    ]
}

#Preview {
    PrivacyPolicyView()
        .frame(width: 1512, height: 932)
}
