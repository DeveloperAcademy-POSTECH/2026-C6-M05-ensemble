//
//  NoticeDetailView.swift
//  CueFlow
//
//  받은 공지 상세 화면 (피그마 공지사항_03).
//  카드 아래에 이전 글(목록에서 위) · 다음 글(목록에서 아래) 줄이 있고, 누르면 그 공지로 바뀐다.
//

import SwiftData
import SwiftUI

struct NoticeDetailView: View {
    let notices: [Notice]   // 목록에 보이던 공지 순서 그대로 (이전/다음 글 찾기용)

    // 지금 보고 있는 공지. 이전/다음 글을 누르면 바뀐다.
    @State private var notice: Notice
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringTop = false   // 위쪽에 마우스를 올리면 버튼 줄이 보인다

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
                VStack(alignment: .leading, spacing: 28) {
                    // 피그마 951:7518: 위쪽 가운데 삭제 · 답장 · 전체 답장 · 전달
                    // 평소엔 숨기고, 위쪽(버튼 줄 ~ "받은 공지" 줄)에 마우스를 올리면 보인다 (공지 목록 별표처럼)
                    VStack(alignment: .leading, spacing: 22) {
                        actionBar
                            .frame(maxWidth: .infinity)
                            .opacity(isHoveringTop ? 1 : 0)
                            .allowsHitTesting(isHoveringTop)

                        Text("받은 공지")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.neutral900)
                            .id("top")
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) { isHoveringTop = hovering }
                    }

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
                .frame(maxWidth: 1065, alignment: .leading)
                .padding(40)
            }
            .background(.white)
            // 다른 공지로 바뀌면 맨 위부터 보이게
            .onChange(of: notice) {
                proxy.scrollTo("top", anchor: .top)
            }
            // 열어 본 공지는 읽음 (#82)
            .onChange(of: notice, initial: true) { _, notice in
                notice.markRead(in: modelContext)
            }
        }
    }

    // 삭제 · 답장 · 전체 답장 · 전달. 마우스를 올린 버튼만 회색 동그라미
    // TODO: 답장 · 전체 답장 · 전달은 동작이 정해지면 연결 (보낸 사람에게 개인 공지? 아래에 댓글처럼? — 팀 미정)
    private var actionBar: some View {
        HStack(spacing: 0) {
            NoticeActionButton(systemImage: "trash", help: "삭제", action: deleteNotice)
            actionSeparator
            NoticeActionButton(systemImage: "arrowshape.turn.up.backward", help: "답장 (준비 중)", action: {})
                .disabled(true)
            NoticeActionButton(systemImage: "arrowshape.turn.up.left.2", help: "전체 답장 (준비 중)", action: {})
                .disabled(true)
            NoticeActionButton(systemImage: "arrowshape.turn.up.forward", help: "전달 (준비 중)", action: {})
                .disabled(true)
        }
        .padding(3)
        .background(Color.neutral50, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.neutral200, lineWidth: 0.5))
    }

    private var actionSeparator: some View {
        Rectangle()
            .fill(Color.neutral300)
            .frame(width: 1, height: 16)
            .padding(.horizontal, 2)
    }

    // 목록으로 돌아간 다음 지운다 (읽음 기록도 같이 지워지고 iCloud에서도 지워진다)
    // 먼저 지우면 닫히기 전에 지워진 공지를 한 번 더 그리다가 멈출 수 있어서 순서를 바꿈
    private func deleteNotice() {
        let target = notice
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))   // 닫히는 동안 기다림
            modelContext.delete(target)
        }
    }

    // 공지 내용이 들어가는 큰 카드 (피그마 951:7484: 흰 바탕 · neutral200 테두리 · 모서리 8 · 안쪽 30 · 높이 495 이상)
    private var card: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 27) {
                VStack(alignment: .leading, spacing: 19) {
                    // 보낼 대상 태그: 전체공지 / 조명 공지 / 개인 공지
                    Text(notice.targetTag)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brandPrimaryText)
                        .padding(.horizontal, 15)
                        .frame(height: 27)
                        .background(Color.brandPrimarySubtle, in: Capsule())

                    Text(notice.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.neutral900)
                }

                VStack(alignment: .leading, spacing: 19) {
                    infoRow(label: "프로젝트", value: notice.productionTitle)
                    infoRow(label: "보낸사람", value: notice.senderName)
                }

                Text(notice.sentDateDetailText)
                    .font(.callout)
                    .foregroundStyle(Color.neutral500)
            }

            Rectangle()
                .fill(Color.neutral200)
                .frame(height: 1)

            Text(notice.body)
                .font(.body)
                .foregroundStyle(Color.neutral700)
                .lineSpacing(6)
                .textSelection(.enabled)   // 본문 글자를 드래그해서 복사할 수 있게
        }
        .padding(30)
        .frame(maxWidth: .infinity, minHeight: 495, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.neutral200, lineWidth: 1)
        }
    }

    // "프로젝트  별마루" 처럼 이름표 + 값 (13 · 사이 17)
    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 17) {
            Text(label)
                .font(.body.weight(.semibold))
            Text(value)
                .font(.body)
        }
        .foregroundStyle(Color.neutral900)
    }
}

// 위쪽 버튼 줄의 버튼 하나: 아이콘만, 마우스를 올리면 회색 동그라미 (피그마 Segmented Control Selected)
struct NoticeActionButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(isEnabled ? Color.neutral700 : Color.neutral300)
                .frame(width: 34, height: 26)
                .background(isHovering && isEnabled ? Color.neutral200 : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

// 카드 아래 이전 글 / 다음 글 한 줄: "^  ✉ 무대연출 이진환   공지 제목"
// 피그마 951:7502 · 7510: 평소 neutral50 · 회색 글자, 마우스를 올리면 neutral100 · 진한 글자
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
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.neutral600)
                    .frame(width: 30, alignment: .leading)

                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                        .font(.footnote)
                    Text(notice.senderRoleAndName)
                }
                .frame(width: 149, alignment: .leading)

                Text(notice.title)
                    .lineLimit(1)

                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(isHovering ? Color.neutral900 : Color.neutral500)
            .padding(.leading, 17)
            .frame(height: 45)
            .background(
                isHovering ? Color.neutral100 : Color.neutral50,
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
