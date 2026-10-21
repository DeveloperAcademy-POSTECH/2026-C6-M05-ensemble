//
//  ICloudAccount.swift
//  CueFlow
//
//  이 맥의 iCloud 로그인 상태와 내 iCloud 계정 ID.
//  앱 안에 로그인 화면은 없다 — 맥 시스템 설정에 로그인된 iCloud 계정을 그대로 쓴다.
//  계정 ID는 나중에 팀원 공유(#68)에서 Member.iCloudUserID와 연결해 "나"를 찾는 데 쓴다.
//

import CloudKit
import Observation

@MainActor
@Observable
final class ICloudAccount {
    // Signing & Capabilities → iCloud에 추가한 컨테이너 이름과 같아야 한다
    static let containerID = "iCloud.Happymondayy.CueFlow"

    enum Status {
        case checking            // 확인 중 (앱 켜자마자)
        case available           // 로그인됨 → 공유·동기화 가능
        case noAccount           // 이 맥에 iCloud 로그인 안 됨
        case restricted          // 자녀 보호 등으로 막힘
        case unavailable         // 잠깐 못 씀 (iCloud 약관 미동의 등) 또는 확인 실패
    }

    private(set) var status: Status = .checking

    // 내 iCloud 계정 ID (CloudKit 사용자 레코드 이름). 로그인 안 됐으면 nil
    private(set) var userRecordName: String?

    // 쓸 때 만든다 — iCloud 권한(entitlements)이 없는 미리보기에서 만들기만 해도 멈추기 때문
    private var container: CKContainer { CKContainer(identifier: Self.containerID) }
    private var accountChangeTask: Task<Void, Never>?

    init() {
        // 앱을 켜 둔 채로 시스템 설정에서 로그인/로그아웃하면 다시 확인
        accountChangeTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                await self?.refresh()
            }
        }
    }

    // Xcode 캔버스(미리보기)에서 실행 중인지. 미리보기는 iCloud 권한 없이 돌아서 CloudKit을 부르면 멈춘다
    private static let isRunningForPreviews =
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    func refresh() async {
        // 미리보기에서는 로그인된 것으로 치고 넘어간다 (안내 띠 모양은 ICloudStatusBanner 미리보기로 확인)
        guard !Self.isRunningForPreviews else {
            status = .available
            return
        }

        do {
            switch try await container.accountStatus() {
            case .available:
                userRecordName = try? await container.userRecordID().recordName
                status = .available
            case .noAccount:
                userRecordName = nil
                status = .noAccount
            case .restricted:
                userRecordName = nil
                status = .restricted
            default:   // .couldNotDetermine, .temporarilyUnavailable
                userRecordName = nil
                status = .unavailable
            }
        } catch {
            userRecordName = nil
            status = .unavailable
        }
    }
}
