//
//  ICloudStatusBanner.swift
//  CueFlow
//
//  iCloud에 로그인 안 된 맥에서 화면 위에 띄우는 안내 띠.
//  로그인돼 있으면(또는 확인 중이면) 아무것도 안 보인다.
//

import SwiftUI

struct ICloudStatusBanner: View {
    let status: ICloudAccount.Status

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let message {
            HStack(spacing: 10) {
                Image(systemName: "icloud.slash")
                    .foregroundStyle(Color.neutral700)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(Color.neutral900)

                Spacer()

                if status == .noAccount {
                    Button("시스템 설정 열기") {
                        // 시스템 설정 → Apple 계정
                        if let url = URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.tertiary)
                    .frame(width: 120, height: 28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.neutral25)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.neutral300)
                    .frame(height: 1)
            }
        }
    }

    private var message: String? {
        switch status {
        case .checking, .available:
            nil
        case .noAccount:
            "이 맥이 iCloud에 로그인돼 있지 않아요. 로그인하면 팀원과 큐시트를 공유할 수 있어요."
        case .restricted:
            "이 맥에서는 iCloud 사용이 제한돼 있어요. 큐시트는 이 맥에만 저장돼요."
        case .unavailable:
            "지금 iCloud에 연결할 수 없어요. 큐시트는 이 맥에 저장되고, 연결되면 다시 확인해요."
        }
    }
}

#Preview("로그인 안 됨") {
    ICloudStatusBanner(status: .noAccount)
        .frame(width: 900)
}

#Preview("연결 안 됨") {
    ICloudStatusBanner(status: .unavailable)
        .frame(width: 900)
}
