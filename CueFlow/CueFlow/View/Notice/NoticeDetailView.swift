//
//  NoticeDetailView.swift
//  CueFlow
//
//  받은 공지 상세 화면 (피그마 공지사항_03).
//  카드 아래에 이전 글(목록에서 위) · 다음 글(목록에서 아래) 줄이 있고, 누르면 그 공지로 바뀐다.
//

import SwiftUI

struct NoticeDetailView: View {
    let notices: [Notice]   // 목록에 보이던 공지 순서 그대로 (이전/다음 글 찾기용)

    // 지금 보고 있는 공지. 이전/다음 글을 누르면 바뀐다.
    @State private var notice: Notice

    init(notice: Notice, notices: [Notice] = []) {
        self.notices = notices
        _notice = State(initialValue: notice)
    }

    // 목록에서 지금 공지 바로 위 (더 최근 공지)
    private var previousNotice: Notice? {
        guard let index = notices.firstIndex(of: notice), index > 0 else { return nil }
        return notices[index - 1]
    }

    // 목록에서 지금 공지 바로 아래 (더 오래된 공지)
    private var nextNotice: Notice? {
        guard let index = notices.firstIndex(of: notice), index + 1 < notices.count else { return nil }
        return notices[index + 1]
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    Text("받은 공지")
                        .font(.largeTitle.bold())
                        .id("top")

                    VStack(spacing: 28) {
                        card

                        VStack(spacing: 8) {
                            if let previousNotice {
                                NoticeNeighborRow(notice: previousNotice, direction: .previous) {
                                    notice = previousNotice
                                }
                            }
                            if let nextNotice {
                                NoticeNeighborRow(notice: nextNotice, direction: .next) {
                                    notice = nextNotice
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 1000, alignment: .leading)
                .padding(40)
            }
            // 다른 공지로 바뀌면 맨 위부터 보이게
            .onChange(of: notice) {
                proxy.scrollTo("top", anchor: .top)
            }
        }
    }

    // 공지 내용이 들어가는 큰 카드
    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 보낼 대상 태그: 전체공지 / 조명 공지 / 개인 공지
            Text(notice.targetTag)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandPrimaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.brandPrimarySubtle, in: Capsule())

            Text(notice.title)
                .font(.title.bold())

            infoRow(label: "프로젝트", value: notice.productionTitle)
            infoRow(label: "보낸사람", value: notice.senderName)

            Text(notice.sentDateDetailText)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 8)

            Text(notice.body)
                .lineSpacing(6)
                .textSelection(.enabled)   // 본문 글자를 드래그해서 복사할 수 있게
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    // "프로젝트  별마루" 처럼 이름표 + 값
    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.body.weight(.semibold))
                .frame(width: 60, alignment: .leading)
            Text(value)
        }
    }
}

// 카드 아래 이전 글 / 다음 글 한 줄: "^  ✉ 무대연출 이진환   공지 제목"
// TODO: 셀리나 색상 표에 Neutral 회색이 추가되면 바탕색 교체
struct NoticeNeighborRow: View {
    enum Direction {
        case previous   // 목록에서 위 (^)
        case next       // 목록에서 아래 (v)
    }

    let notice: Notice
    let direction: Direction
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: direction == .previous ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 30, alignment: .leading)

                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                    Text(notice.senderRoleAndName)
                }
                .frame(width: 149, alignment: .leading)

                Text(notice.title)
                    .lineLimit(1)

                Spacer()
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.leading, 17)
            .frame(height: 45)
            .background(
                isHovering ? Color(nsColor: .tertiarySystemFill) : Color(nsColor: .quinarySystemFill),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(Rectangle())   // 글자 말고 빈 곳을 눌러도 열리게
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(direction == .previous ? "이전 글" : "다음 글")
    }
}

#Preview {
    let samples = NoticePreviewData.samples
    NavigationStack {
        NoticeDetailView(notice: samples[1], notices: samples)
    }
    .frame(width: 1290, height: 930)
}
