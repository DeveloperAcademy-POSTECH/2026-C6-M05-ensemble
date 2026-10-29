//
//  ParticipantsPopover.swift
//  CueFlow
//
//  큐시트 오른쪽 위 멤버 버튼을 누르면 뜨는 "참여자 현황" (피그마 참여자현황 951:10259).
//  나 + Spotlight me / 현재 보고 있는 사람 / 최근에 본 사람.
//  "보고 있음"은 Member.lastSeenAt으로 판단한다 — 큐시트를 열어 두면 1분마다 기록되고 iCloud로 다른 사람에게 간다.
//

import SwiftUI
import SwiftData

struct ParticipantsPopover: View {
    let production: Production
    let myUserID: String?          // 내 iCloud 계정 ID (Member.iCloudUserID와 비교해서 "나"를 찾는다)
    var now: Date = .now           // 미리보기에서 시간을 고정할 때

    // 이 시간 안에 기록이 있으면 "현재 보고 있는 사람" (1분마다 기록 + iCloud로 오는 데 걸리는 시간)
    private static let viewingWindow: TimeInterval = 3 * 60

    private var me: Member? {
        guard let myUserID else { return nil }
        return (production.members ?? []).first { $0.iCloudUserID == myUserID }
    }

    private var others: [Member] {
        (production.members ?? []).filter { $0.iCloudUserID == nil || $0.iCloudUserID != myUserID }
    }

    private func isViewing(_ member: Member) -> Bool {
        guard let seen = member.lastSeenAt else { return false }
        return now.timeIntervalSince(seen) < Self.viewingWindow
    }

    private var viewing: [Member] {
        others.filter(isViewing)
    }

    // 최근에 본 순서. 한 번도 안 본 사람은 맨 뒤
    private var recent: [Member] {
        others.filter { !isViewing($0) }
            .sorted { ($0.lastSeenAt ?? .distantPast) > ($1.lastSeenAt ?? .distantPast) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            meRow

            divider
                .padding(.top, 14)

            sectionTitle("현재 보고 있는 사람")
                .padding(.top, 11)   // 피그마 1618:7175
            VStack(alignment: .leading, spacing: 0) {
                if viewing.isEmpty {
                    emptyText("지금 보고 있는 사람이 없어요")
                } else {
                    ForEach(viewing) { member in
                        viewingRow(member)
                    }
                }
            }
            .padding(.top, 10)

            divider
                .padding(.top, 13)

            sectionTitle("최근에 본 사람")
                .padding(.top, 10)
            if recent.isEmpty {
                emptyText("아직 없어요")
                    .padding(.top, 10)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(recent) { member in
                            recentRow(member)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 260)   // 5명 넘으면 스크롤
            }
        }
        // 팀 팝오버가 사방 20 · 폭 426 · 바탕을 넣어 준다 → 피그마 여백(좌우 38 · 위 29 · 아래 25)에서 20을 뺀 만큼만
        .padding(.horizontal, 18)
        .padding(.top, 9)
        .padding(.bottom, 5)
    }
}

// 줄 모양

extension ParticipantsPopover {
    // 나 + Spotlight me
    private var meRow: some View {
        HStack {
            HStack(spacing: 15) {
                avatar(me?.name ?? "나", size: 36, fontSize: 18, color: .brandPrimaryDisabled)
                Text("\(me?.name ?? "나") (나)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.neutral900)
                    .lineLimit(1)
            }
            Spacer()
            // TODO: #69 리허설 동기화 모드 — 누르면 다른 사람 화면이 내 화면을 따라온다
            Button {} label: {
                Text("Spotlight me")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.neutral700)
                    .frame(width: 99, height: 30)
                    .background(Color.brandPrimarySubtle, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(true)
            .opacity(0.5)
            .help("리허설 동기화 모드가 생기면 쓸 수 있어요")
        }
    }

    // 현재 보고 있는 사람 한 줄: 보라 동그라미 + 이름
    private func viewingRow(_ member: Member) -> some View {
        HStack(spacing: 11) {
            avatar(member.name, size: 36, fontSize: 18, color: .brandPrimaryHover)
            Text(member.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.neutral900)
                .lineLimit(1)
        }
        .frame(height: 40)
    }

    // 최근에 본 사람 한 줄: 회색 동그라미 + 이름 + "5시간 전"
    private func recentRow(_ member: Member) -> some View {
        HStack(spacing: 10) {
            avatar(member.name, size: 36, fontSize: 15, color: .neutral300)
            VStack(alignment: .leading, spacing: 1) {
                Text(member.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.neutral900)
                    .lineLimit(1)
                Text(seenText(member.lastSeenAt))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.neutral400)
            }
        }
        .frame(height: 50)
    }

    // 이름 첫 글자를 넣은 동그라미
    private func avatar(_ name: String, size: CGFloat, fontSize: CGFloat, color: Color) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: .circle)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Color.neutral500)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(Color.neutral400)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.neutral200)
            .frame(height: 1)
    }

    // "5시간 전" · "1일 전". 기록이 없으면 아직 안 들어와 본 것
    private func seenText(_ date: Date?) -> String {
        guard let date else { return "아직 안 봤어요" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

extension Production {
    // 내가 이 공연 큐시트를 보고 있다고 기록한다 (내 멤버가 있을 때만 = 공유된 공연)
    // 저장하면 CloudSync가 iCloud에 올려서 다른 사람 참여자 현황에 보인다
    func markSeen(byUserID userID: String?) {
        guard let userID, let context = modelContext,
              let me = (members ?? []).first(where: { $0.iCloudUserID == userID }) else { return }
        me.lastSeenAt = .now
        try? context.save()
    }
}

#Preview {
    let container = try! ModelContainer(for: Production.self, configurations: .init(isStoredInMemoryOnly: true))
    let production = Production(title: "레미제라블", genre: "뮤지컬", firstShowDate: .now)
    container.mainContext.insert(production)
    let people: [(String, String, TimeInterval?)] = [
        ("Ubin", "me", 0), ("Katt", "katt", -30), ("곽선우", "a", -5 * 3600),
        ("셀리나", "b", -26 * 3600), ("최윤서", "c", -30 * 3600), ("ChoiYunseo", "d", nil),
    ]
    for (name, id, ago) in people {
        let member = Member(name: name, role: "")
        member.iCloudUserID = id
        member.lastSeenAt = ago.map { Date.now.addingTimeInterval($0) }
        member.production = production
        container.mainContext.insert(member)
    }
    return ParticipantsPopover(production: production, myUserID: "me")
        .popoverStyle(width: 426)
        .padding(40)
        .modelContainer(container)
}
