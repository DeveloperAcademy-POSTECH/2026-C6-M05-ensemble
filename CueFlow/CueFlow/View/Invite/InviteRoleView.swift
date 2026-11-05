//
//  InviteRoleView.swift
//  CueFlow
//
//  초대 수락 다음 화면 — 이 공연에서 맡은 역할 고르기 (피그마 역할 선택_초대 수락 후, #68).
//  공연에 설정된 스태프 파트 → 내 멤버의 맡은 파트(Member.parts)로 넣는다.
//  수락 직후엔 공연이 아직 iCloud에서 안 왔을 수 있어서, 올 때까지 기다리는 화면을 보여 준다.
//

import SwiftUI
import SwiftData

struct InviteRoleView: View {
    // 개발용 메뉴 "가짜 초대 수락"을 누르면 보낸다
    static let fakeAcceptNotification = Notification.Name("InviteRoleView.fakeAccept")

    var onPrevious: () -> Void = {}
    var onDone: (Production) -> Void = { _ in }   // 다음으로 → 그 공연 열기

    @Environment(\.modelContext) private var modelContext
    @Environment(ICloudAccount.self) private var iCloudAccount

    // 수락한 공연 (아직 안 받아 왔으면 비어 있음)
    @Query private var productions: [Production]
    private var production: Production? { productions.first }

    @State private var selectedPartIDs: Set<UUID> = []      // 고른 스태프 파트
    @State private var isSaving = false

    init(productionID: UUID, onPrevious: @escaping () -> Void = {}, onDone: @escaping (Production) -> Void = { _ in }) {
        _productions = Query(filter: #Predicate<Production> { $0.id == productionID })
        self.onPrevious = onPrevious
        self.onDone = onDone
    }

    var body: some View {
        Group {
            if let production {
                ScrollView {
                    page(production)
                }
                .overlay(alignment: .bottom) { footer(production) }
            } else {
                // 수락은 됐는데 공연이 아직 안 옴 → CloudSync가 받아 오면 자동으로 바뀐다
                VStack(spacing: 12) {
                    ProgressView()
                    Text("공연 정보를 받아 오는 중이에요")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.noticeSecondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 850)
        .background(Color.appBackground)
    }

    // 가운데 (폭 796): 위 안내 → 스태프
    private func page(_ production: Production) -> some View {
        VStack(alignment: .leading, spacing: 40) {
            header(production)
            section(
                title: "스태프",
                caption: "프로젝트에 설정된 제작 파트입니다.",
                count: selectedPartIDs.count
            ) {
                ForEach(sortedParts(of: production)) { part in
                    roleCard(name: part.name, icon: icon(for: part.name), isSelected: selectedPartIDs.contains(part.id)) {
                        selectedPartIDs.toggle(part.id)
                    }
                }
            }
        }
        .frame(width: 796, alignment: .leading)
        .padding(.top, 163)
        .padding(.bottom, 209)   // 아래 버튼에 가리지 않게
        .frame(maxWidth: .infinity)
    }
}

// 위 안내

extension InviteRoleView {
    // ● 레미제라블 | 초대 수락 완료
    //   맡은 역할을 선택해 주세요
    //   이 프로젝트에서 …
    private func header(_ production: Production) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: 7, height: 7)
                Text("\(production.title) | 초대 수락 완료")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.brandPrimaryText)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("맡은 역할을 선택해 주세요")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.neutral900)
                Text("이 프로젝트에서 맡은 역할을 모두 선택해 주세요. 여러 개를 선택할 수 있습니다.")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.noticeSecondaryText)
            }
        }
    }
}

// 역할 고르기 (새 공연 만들기의 파트 카드와 같은 모양)

extension InviteRoleView {
    // 스태프 [4개 선택]
    // 프로젝트에 설정된 …
    // [카드][카드][카드][카드]
    private func section<Cards: View>(title: String, caption: String, count: Int, @ViewBuilder cards: () -> Cards) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.neutral800)
                    Text("\(count)개 선택")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.brandPrimaryText)
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .background(Color.partCountBadge, in: .capsule)
                }
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.noticeSecondaryText)
            }
            // 4칸씩 줄바꿈, 가로·세로 간격 18
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(185), spacing: 18), count: 4),
                      alignment: .leading, spacing: 18) {
                cards()
            }
        }
    }

    private func roleCard(name: String, icon: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(name)
                    .font(.system(size: 17, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.brandPrimaryText : Color.neutral900)
            .padding(.horizontal, 20)
            .frame(width: 185, height: 66)
            .background(isSelected ? Color.partCardSelected : Color.neutral25,
                        in: .rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.stageOptionSelectedBorder : Color.partCardBorder, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func sortedParts(of production: Production) -> [Part] {
        (production.parts ?? []).sorted { $0.order < $1.order }
    }

    // 기본 파트는 새 공연 만들기와 같은 아이콘, 직접 추가한 파트는 기타 아이콘
    private func icon(for partName: String) -> String {
        PartOption.all.first { $0.name == partName }?.icon ?? PartOption.customIcon
    }
}

// 이전으로 · 다음으로

extension InviteRoleView {
    private func footer(_ production: Production) -> some View {
        HStack(spacing: 15) {
            Button("이전으로", action: onPrevious)
                .buttonStyle(.secondary)
                .frame(width: 175, height: 45)
            Button("다음으로") { save(in: production) }
                .buttonStyle(.primary)
                .frame(width: 175, height: 45)
                .disabled(isSaving)
        }
        .frame(width: 796, alignment: .trailing)
        .padding(.bottom, 124)
    }

    // 고른 역할을 "나" 멤버에 저장하고 공연 열기. 저장하면 CloudSync가 iCloud에 올린다
    private func save(in production: Production) {
        isSaving = true
        Task {
            // 아직 멤버로 안 들어가 있으면 먼저 넣는다 (이미 있으면 그대로)
            if !ICloudAccount.isRunningForPreviews {
                production.addMember(try? await CloudShare.myParticipant(in: production))
            }
            if let myID = iCloudAccount.userRecordName,
               let me = (production.members ?? []).first(where: { $0.iCloudUserID == myID }) {
                me.parts = sortedParts(of: production).filter { selectedPartIDs.contains($0.id) }
                try? modelContext.save()
                print("역할 저장: \(me.name) — 파트 \((me.parts ?? []).map(\.name))")
            } else {
                print("역할 저장 실패: 이 공연에서 내 멤버를 못 찾음")
            }
            isSaving = false
            onDone(production)
        }
    }
}

private extension Set {
    // 있으면 빼고, 없으면 넣기
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

#Preview {
    let container = HomePreviewData.container
    let production = try! container.mainContext.fetch(FetchDescriptor<Production>()).first!
    return InviteRoleView(productionID: production.id)
        .modelContainer(container)
        .environment(ICloudAccount())
        .frame(width: 1512, height: 932)
}
