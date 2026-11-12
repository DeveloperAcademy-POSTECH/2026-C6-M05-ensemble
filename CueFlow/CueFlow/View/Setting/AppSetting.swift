//
//  AppSetting.swift
//  CueFlow
//
//  Created by 김나현 on 11/12/26.
//

import SwiftUI

// 앱 설정 (피그마 2705:20482): 알림 · 계정 · 정보
struct AppSetting: View {
    var onBack: () -> Void = {}

    @Environment(ICloudAccount.self) private var iCloudAccount
    @AppStorage(SystemNotifications.enabledKey) private var isNotificationOn = true   // 앱 알림 (SystemNotifications가 읽음)
    @AppStorage(CloudSync.lastSyncKey) private var lastSyncTime: Double = 0          // 마지막 동기화 (CloudSync가 저장)
    @AppStorage("profileEmail") private var email = ""                                // 이 맥에만 저장 (나중에 팀 공유로 바꿀 예정)
    @State private var isEditingEmail = false
    @State private var emailDraft = ""
    @FocusState private var isEmailFocused: Bool
    @State private var isShowingPrivacyPolicy = false   // 정보 > 개인정보 처리방침 화면
    @Environment(\.openURL) private var openURL         // 정보 > 문의 피드백 보내기

    var body: some View {
        if isShowingPrivacyPolicy {   // 정보 > 개인정보 처리방침
            PrivacyPolicyView(onBack: { isShowingPrivacyPolicy = false })
        } else {
            settingsPage
        }
    }

    private var settingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                notificationSection
                    .padding(.top, 42)
                accountSection
                    .padding(.top, 35)
                infoSection
                    .padding(.top, 35)
            }
            .frame(maxWidth: 1069, alignment: .leading)
            .padding(.top, 144)
            .padding(.bottom, 60)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topLeading) { backButton }
        .background(Color.appBackground)
    }
}

// 제목 · 뒤로가기

extension AppSetting {
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("설정")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.neutral900)
            Text("프로필과 앱 알림을 관리합니다.")
                .font(.system(size: 18))
                .foregroundStyle(Color.neutral700)
        }
    }

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

    // 소제목 + 회색 카드
    private func section<Content: View>(_ title: String, background: Color = .neutral50, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18))
                .foregroundStyle(Color.neutral900)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(background, in: .rect(cornerRadius: 8))
        }
    }
}

// 알림

extension AppSetting {
    private var notificationSection: some View {
        section("알림") {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("앱 알림")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.neutral900)
                    Text("초대와 내가 확인할 변경사항을 알려드립니다.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.neutral500)
                }
                Spacer()
                Toggle("", isOn: $isNotificationOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
                .tint(Color.neutral400)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 15)
        }
    }
}

// 계정

extension AppSetting {
    // 로그인돼 있으면 프로필 · 동기화, 아니면 로그인 안내 (피그마 2705:20715)
    private var accountSection: some View {
        section("계정", background: isLoggedIn ? Color.neutral50 : Color.errorSubtle) {
            if isLoggedIn {
                accountInfo
            } else {
                loginWarning
            }
        }
    }

    private var accountInfo: some View {
        HStack(spacing: 0) {   // 카드 안에서 세로 가운데
            avatar
                .padding(.trailing, 19)
            profileText
                .fixedSize()   // 사용자 ID 전체를 한 줄로
            Spacer()
            syncButton
        }
        .padding(.leading, 26)
        .padding(.trailing, 25)
        .frame(height: 129)
    }

    // ⓘ iCloud에 로그인해야 …        [시스템 설정 열기]
    private var loginWarning: some View {
        HStack(spacing: 0) {
            Text("\(Image(systemName: "info.circle")) iCloud에 로그인해야 팀원과 큐시트를 함께 쓸 수 있어요")
                .font(.system(size: 20))
                .foregroundStyle(Color.error)
            Spacer()
            Button(action: openAppleIDSettings) {
                Text("시스템 설정 열기")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.neutral900)
                    .frame(width: 133, height: 36)
                    .background(Color.neutral200, in: .rect(cornerRadius: 6))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 26)
        .frame(height: 129)
    }

    // 시스템 설정 > Apple 계정 (화면 위 iCloud 안내 띠와 같은 주소)
    private func openAppleIDSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings") {
            openURL(url)
        }
    }

    // 이름 첫 글자 동그라미 (피그마 80 × 78)
    private var avatar: some View {
        Text(String(name.prefix(1)))
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(Color.neutral500)
            .frame(width: 80, height: 78)
            .background(Color.neutral200, in: .capsule)
    }

    // 이름 / 이메일 / 사용자 ID
    private var profileText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.neutral900)
            HStack(spacing: 32) {   // 이메일 옆에 Apple ID 연결됨 · 마지막 동기화 (32 + 로고 자리 18 = 50)
                emailField
                syncStatus
            }
            .font(.system(size: 16))
            .padding(.top, 9)
            Text("사용자 ID : \(userID)")
                .font(.system(size: 16))
                .foregroundStyle(Color.neutral900)
                .padding(.top, 7)
        }
    }

    // Apple ID 연결됨   마지막 동기화 오늘 오후 3:21
    private var syncStatus: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "apple.logo")
                    .frame(width: 14)
                Text(isLoggedIn ? "Apple ID 연결됨" : "Apple ID 연결 안 됨")
            }
            .foregroundStyle(Color.neutral900)
            .frame(minWidth: 140, alignment: .leading)   // 로고 18 + 글자 칸 122 ("연결 안 됨"이면 더 길어짐)
            Text("마지막 동기화 \(lastSyncText)")
                .foregroundStyle(Color.neutral500)   // 피그마 #5C5C63(cuedit-neutral-600)은 토큰이 없어 임시로
        }
        .font(.system(size: 16))
    }

    // 누르면 CloudSync가 바로 받고 올림. 로그인 안 돼 있으면 회색
    private var syncButton: some View {
        Button {
            NotificationCenter.default.post(name: CloudSync.syncNowNotification, object: nil)
        } label: {
            Text("지금 동기화")
                .font(.system(size: 16))
                .foregroundStyle(Color.neutral900)
                .frame(width: 105, height: 36)
                .background(Color.neutral200, in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isLoggedIn)
        .opacity(isLoggedIn ? 1 : 0.5)
    }
    
    // 이메일: 누르면 입력칸. Enter로 저장, Esc로 취소 (이 맥에만 저장)
    @ViewBuilder
    private var emailField: some View {
        if isEditingEmail {
            TextField("이메일", text: $emailDraft)
                .textFieldStyle(.plain)
                .frame(width: 240)   // 입력하는 동안 옆 "Apple ID 연결됨"이 움직이지 않게
                .focused($isEmailFocused)
                .onAppear { isEmailFocused = true }
                .onSubmit { saveEmail() }
                .onExitCommand { isEditingEmail = false }
        } else {
            Text(email.isEmpty ? "이메일 추가" : email)
                .foregroundStyle(email.isEmpty ? Color.neutral400 : Color.neutral900)
                .onTapGesture { startEmailEdit() }
        }
    }

    private func startEmailEdit() {
        emailDraft = email
        isEditingEmail = true
    }

    private func saveEmail() {
        email = emailDraft.trimmingCharacters(in: .whitespaces)
        isEditingEmail = false
    }
}

// 계정 정보 값

extension AppSetting {
    private var isLoggedIn: Bool { iCloudAccount.status == .available }

    // 맥 사용자 이름 (큐 수정 기록에 쓰는 이름과 같음)
    private var name: String { CurrentEditor.name }

    private var userID: String { iCloudAccount.userRecordName ?? "-" }

    // 마지막 동기화: "오늘 오후 3:21" / "어제 오후 3:21" / "11월 10일 오후 3:21". 기록이 없으면 "없음"
    private var lastSyncText: String {
        guard lastSyncTime > 0 else { return "없음" }
        let date = Date(timeIntervalSince1970: lastSyncTime)
        let time = date.formatted(.dateTime.hour().minute().locale(Self.korean))   // "오전 12:42" (앱 언어가 영어여도 한국어로)
        if Calendar.current.isDateInToday(date) { return "오늘 \(time)" }
        if Calendar.current.isDateInYesterday(date) { return "어제 \(time)" }
        return "\(date.formatted(.dateTime.month().day().locale(Self.korean))) \(time)"
    }
    
    private static let korean = Locale(identifier: "ko_KR")
}

// 정보

extension AppSetting {
    // 문의 피드백 보내기 링크 (정해지면 채우기. 비어 있으면 그 줄은 회색 · 안 눌림)
    private static let feedbackURL = URL(string: "")   // 예: "mailto:주소@도메인" 또는 설문 링크

    // 버전 / 개인정보 처리방침 / 문의 피드백 보내기 (한 줄 56, 카드 높이 168)
    private var infoSection: some View {
        section("정보") {
            VStack(spacing: 0) {
                infoRow("버전") {
                    Text(appVersion)
                        .foregroundStyle(Color.neutral500)
                }
                Color.neutral200.frame(height: 1)
                buttonRow("개인정보 처리방침") { isShowingPrivacyPolicy = true }
                Color.neutral200.frame(height: 1)
                buttonRow("문의 피드백 보내기", isEnabled: Self.feedbackURL != nil) {
                    if let url = Self.feedbackURL { openURL(url) }
                }
            }
        }
    }

    // 왼쪽 제목 + 오른쪽 내용
    private func infoRow<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.neutral900)
            Spacer()
            trailing()
        }
        .font(.system(size: 16))
        .padding(.horizontal, 24)
        .frame(height: 56)
        .contentShape(.rect)
    }

    // 줄 전체가 버튼 (오른쪽 >)
    private func buttonRow(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            infoRow(title) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.neutral500)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    // Xcode 프로젝트의 Version (예: 1.0.1)
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
}

#Preview {
    AppSetting()
        .frame(width: 1512, height: 932)
        .environment(ICloudAccount())
}
