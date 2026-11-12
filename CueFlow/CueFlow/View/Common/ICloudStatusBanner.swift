//
//  ICloudStatusBanner.swift
//  CueFlow
//
//  iCloud에 로그인 안 된 맥 · 아이패드에서 오른쪽 내용 영역 맨 위에 띄우는 안내 카드.
//  로그인돼 있으면(또는 확인 중이면) 아무것도 안 보인다. ✕로 닫으면 앱을 켜 둔 동안은 안 보인다.
//

import SwiftUI

struct ICloudStatusBanner: View {
    let status: ICloudAccount.Status
    var onClose: (() -> Void)? = nil   // ✕ 버튼. 없으면 ✕가 안 보인다

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let text {
            HStack(spacing: 12) {
                // 연보라 동그라미 안 아이콘
                Image(systemName: "icloud.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.brandPrimarySubtle, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(text.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.neutral900)
                    Text(text.detail)
                        .font(.footnote)
                        .foregroundStyle(Color.neutral700)
                }

                Spacer(minLength: 12)

                if status == .noAccount {
                    Button {
                        if let url = Self.settingsURL {
                            openURL(url)
                        }
                    } label: {
                        Text(Self.settingsButtonTitle)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                    }
                    .buttonStyle(.tertiaryFilled)   // 연보라 바탕 + 보라 테두리 (리허설 "다음 큐"와 같은 모양)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 30)
                }

                if let onClose {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { onClose() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.neutral700)
                            .frame(width: 28, height: 28)   // 아이패드 손가락으로도 누르기 쉽게
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("안내 닫기")
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .background(Color.neutral25, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.neutral300, lineWidth: 1)
            }
        }
    }

    // 굵은 제목 + 작은 설명
    private var text: (title: String, detail: String)? {
        let device = Self.deviceName
        return switch status {
        case .checking, .available:
            nil
        case .noAccount:
            ("iCloud에 로그인되어 있지 않음", "팀원과 공유하려면 iCloud에 로그인하세요.")
        case .restricted:
            ("iCloud 사용이 제한됨", "큐시트는 이 \(device)에만 저장돼요.")
        case .unavailable:
            ("iCloud에 연결할 수 없음", "큐시트는 이 \(device)에 저장되고, 연결되면 다시 확인해요.")
        }
    }

    // 맥은 시스템 설정 → Apple 계정으로 바로 간다.
    // 아이패드는 Apple 계정 화면으로 바로 가는 공개 주소가 없어서 설정 앱의 이 앱 화면을 연다 (#156)
    #if os(macOS)
    private static let deviceName = "맥"
    private static let settingsButtonTitle = "시스템 설정"
    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings")
    #else
    private static let deviceName = "아이패드"
    private static let settingsButtonTitle = "설정"
    private static let settingsURL = URL(string: UIApplication.openSettingsURLString)
    #endif
}

#Preview("로그인 안 됨") {
    ICloudStatusBanner(status: .noAccount, onClose: {})
        .frame(width: 900)
}

#Preview("연결 안 됨") {
    ICloudStatusBanner(status: .unavailable)
        .frame(width: 900)
}
