//
//  KeyboardShortcustsView.swift
//  CueFlow
//
//  Created by 김나현 on 11/12/26.
//
//  도움말 > 키보드 단축키 ⌘/ → 화면 가운데에 뜨는 단축키 안내 (ContentView가 띄움)
//

import SwiftUI

struct KeyboardShortcutsView: View {
    var onClose: () -> Void = {}
    @State private var searchText = ""   // 서치바에 입력한 글자

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            searchField
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(filteredSections) { sectionView($0) }
                    if filteredSections.isEmpty { emptyResult }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 480, height: 560)
        .background(Color.surfaceWhite, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.neutral200))
        .compositingGroup()   // 카드를 하나로 합친 뒤 그림자 (안 넣으면 글자마다 그림자가 생김)
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)        .background { closeShortcut }
    }
}

extension KeyboardShortcutsView {
    // 제목 + ✕
    private var header: some View {
        HStack {
            Text("키보드 단축키")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.neutral900)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.neutral500)
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
    }

    // 일반 · 편집 · 보기 · 윈도우 한 묶음
    private func sectionView(_ section: ShortcutSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.neutral500)
            ForEach(section.items) { row($0) }
        }
    }

    // 기능 이름 ……… ⌘ N
    private func row(_ item: ShortcutItem) -> some View {
        HStack {
            Text(item.title)
                .font(.system(size: 13))
                .foregroundStyle(Color.neutral900)
            Spacer()
            HStack(spacing: 4) {
                ForEach(item.keys, id: \.self) { keyCap($0) }
            }
        }
        .frame(height: 28)
    }

    // 키 하나 (네모 안에 기호)
    private func keyCap(_ key: String) -> some View {
        keyLabel(key)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.neutral800)
            .padding(.horizontal, 5)
            .frame(minWidth: 22, minHeight: 22)
            .background(Color.tagBackground, in: .rect(cornerRadius: 5))
    }

    // "globe"는 🌐 키 아이콘, 나머지는 글자 그대로
    @ViewBuilder
    private func keyLabel(_ key: String) -> some View {
        if key == "globe" {
            Image(systemName: "globe")
        } else {
            Text(key)
        }
    }

    // Esc로 닫기 (화면에는 안 보이는 버튼)
    private var closeShortcut: some View {
        Button("닫기", action: onClose)
            .keyboardShortcut(.cancelAction)
            .opacity(0)
    }
    
    // 기능 이름으로 찾기 (예: "복사", "사이드바")
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.neutral500)
            TextField("", text: $searchText, prompt: Text("단축키 검색").foregroundStyle(Color.neutral400))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.neutral900)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color.tagBackground, in: .rect(cornerRadius: 8))
    }

    // 검색어가 들어간 기능만. 남는 게 없는 묶음은 숨김
    private var filteredSections: [ShortcutSection] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return ShortcutSection.all }
        return ShortcutSection.all.compactMap { section in
            let items = section.items.filter { $0.title.localizedCaseInsensitiveContains(keyword) }
            return items.isEmpty ? nil : ShortcutSection(title: section.title, items: items)
        }
    }

    // 맞는 게 하나도 없을 때
    private var emptyResult: some View {
        Text("'\(searchText)'에 맞는 단축키가 없어요")
            .font(.system(size: 13))
            .foregroundStyle(Color.neutral500)
    }
}

// 단축키 목록 (노션 "단축키 재정리" 기준). 메뉴 단축키를 바꾸면 여기도 같이 바꾸기

struct ShortcutItem: Identifiable {
    let title: String
    let keys: [String]   // 누르는 순서대로. "globe" = 🌐 키
    var id: String { title }
}

struct ShortcutSection: Identifiable {
    let title: String
    let items: [ShortcutItem]
    var id: String { title }

    static let all: [ShortcutSection] = [
        ShortcutSection(title: "일반", items: [
            ShortcutItem(title: "새 프로젝트", keys: ["⌘", "N"]),
            ShortcutItem(title: "닫기", keys: ["⌘", "W"]),
            ShortcutItem(title: "프린트", keys: ["⌘", "P"]),
            ShortcutItem(title: "설정", keys: ["⌘", ","]),
            ShortcutItem(title: "키보드 단축키", keys: ["⌘", "/"]),
            ShortcutItem(title: "Cuedit 숨기기", keys: ["⌘", "H"]),
            ShortcutItem(title: "기타 숨기기", keys: ["⌥", "⌘", "H"]),
            ShortcutItem(title: "Cuedit 종료", keys: ["⌘", "Q"])
        ]),
        ShortcutSection(title: "편집", items: [
            ShortcutItem(title: "실행 취소", keys: ["⌘", "Z"]),
            ShortcutItem(title: "실행 복귀", keys: ["⇧", "⌘", "Z"]),
            ShortcutItem(title: "잘라내기", keys: ["⌘", "X"]),
            ShortcutItem(title: "복사하기", keys: ["⌘", "C"]),
            ShortcutItem(title: "붙여넣기", keys: ["⌘", "V"]),
            ShortcutItem(title: "모두 선택", keys: ["⌘", "A"]),
            ShortcutItem(title: "모두 선택 해제", keys: ["⇧", "⌘", "A"])
        ]),
        ShortcutSection(title: "보기", items: [
            ShortcutItem(title: "사이드바 가리기", keys: ["⇧", "⌘", "\\"]),
            ShortcutItem(title: "댓글 표시", keys: ["⇧", "C"]),
            ShortcutItem(title: "전체 화면 시작/종료", keys: ["⌃", "⌘", "F"])
        ]),
        ShortcutSection(title: "윈도우", items: [
            ShortcutItem(title: "최소화", keys: ["⌘", "M"]),
            ShortcutItem(title: "채우기", keys: ["globe", "⌃", "F"]),
            ShortcutItem(title: "중앙 정렬", keys: ["globe", "⌃", "C"])
        ])
    ]
}

#Preview {
    KeyboardShortcutsView()
        .padding(40)
}
