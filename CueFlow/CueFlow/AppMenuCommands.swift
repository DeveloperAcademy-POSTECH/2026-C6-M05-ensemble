//
//  AppMenuCommands.swift
//  CueFlow
//
//  Created by 김나현 on 10/30/26.
//
//  메뉴 막대 (노션 "단축키 재정리" 기준)
//  화면이 할 수 있는 일을 focusedSceneValue로 넘겨 주면 켜지고, 아직 연결 안 한 항목은 회색(비활성)
//  시스템이 알아서 넣는 항목(Cuedit 정보 · 숨기기 · 종료, 실행 취소 · 복귀,
//  전체 화면, 창 메뉴 전부, 도움말 검색창)은 여기 없다
//

import SwiftUI
#if os(macOS)
import AppKit   // 편집 메뉴: 입력 중인 글자에 잘라내기 · 복사 등을 보내려고 (NSApp · NSText)
#endif

// 앱 전체에서 메뉴가 할 수 있는 일 (ContentView가 넣어 줌). nil인 항목은 회색
struct AppMenuActions {
    var recentProductions: [Production]   // 최근 사용 열기 (최근 3개)
    var newProject: () -> Void
    var open: (Production) -> Void
    var toggleSidebar: () -> Void
    var showShortcuts: () -> Void         // 도움말 > 키보드 단축키
    var close: (() -> Void)?              // 큐시트 · 리허설 · 새 프로젝트 중일 때만
    var showCueSheet: (() -> Void)?       // 리허설 중일 때만
    var showRehearsal: (() -> Void)?      // 큐시트를 보고 있을 때만
}

// 큐시트 표에서 메뉴가 할 수 있는 일 (CueGrid가 넣어 줌)
struct CueGridActions {
    var hasSelection: Bool            // 선택된 큐가 있는지
    var selectAll: () -> Void
    var deselectAll: () -> Void
    var deleteSelected: () -> Void    // 읽기 권한이면 아무것도 안 함
    var copy: () -> Void              // 선택한 큐 기억하기
    var cut: () -> Void               // 기억하고 지우기
    var paste: () -> Bool             // 마우스가 올라간 칸에 붙이기. 붙일 곳이 없으면 false
    var export: (CueSheetExportFormat) -> Void   // 파일 > 다음으로 내보내기 (저장 창)
}

// 파트 필터 바에서 메뉴가 할 수 있는 일 (MainCueSheetView가 넣어 줌)
struct PartFilterActions {
    var parts: [Part]                 // 파트 필터 바와 같은 순서
    var selectedPart: Part?           // nil = 전체
    var select: (Part?) -> Void
}

extension FocusedValues {
    @Entry var appMenu: AppMenuActions?
    @Entry var cueGrid: CueGridActions?
    @Entry var partFilter: PartFilterActions?
}

// 메뉴 막대 · 편집 메뉴 보내기 · 한글 ⇧C는 맥만 (AppKit). 아이패드는 위 Actions만 같이 쓴다
#if os(macOS)
struct AppMenuCommands: Commands {
    @FocusedValue(\.appMenu) private var app   // ContentView가 넣어 줌
    @FocusedValue(\.cueGrid) private var cueGrid   // CueGrid가 넣어 줌 (큐시트 표가 보일 때)
    @FocusedValue(\.partFilter) private var partFilter   // MainCueSheetView가 넣어 줌 (파트 필터 바)
    @AppStorage("showsCommentButton") private var showsComments = true   // 보기 > 댓글 표시 (CueCard와 같이 씀)
    var body: some Commands {
        appMenu
        fileMenu
        editMenu
        viewMenu
        helpMenu
    }
}

// Cuedit

extension AppMenuCommands {
    // 설정… ⌘, (설정 창을 만들면 Settings 씬으로 바꾼다)
    private var appMenu: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("설정…") {}
                .keyboardShortcut(",")
                .disabled(true)
        }
    }
}

// 파일

extension AppMenuCommands {
    @CommandsBuilder
    private var fileMenu: some Commands {
        // 시스템 "새로운 윈도우" 자리
        CommandGroup(replacing: .newItem) {
            Button("새 프로젝트") { app?.newProject() }
                .keyboardShortcut("n")
                .disabled(app == nil)
            recentMenu
        }
        // 시스템 "닫기 ⌘W" 자리
        CommandGroup(replacing: .saveItem) {
            Button("닫기") { app?.close?() }
                .keyboardShortcut("w")
                .disabled(app?.close == nil)
        }
        CommandGroup(replacing: .importExport) {
            Menu("다음으로 내보내기") {   // 통합 큐시트 내보내기 버튼과 같은 저장 창
                Button("CSV (엑셀)") { cueGrid?.export(.csv) }
                Button("PDF") { cueGrid?.export(.pdf) }
            }
            .disabled(cueGrid == nil)
            Button("프로젝트 설정…") {}
                .disabled(true)
        }
        CommandGroup(replacing: .printItem) {
            Button("프린트…", systemImage: "printer") {}
                .keyboardShortcut("p")
                .disabled(true)
        }
    }
    
    // 최근에 연 프로젝트 3개
    private var recentMenu: some View {
        Menu("최근 사용 열기") {
            ForEach(app?.recentProductions ?? []) { production in
                Button(production.title) { app?.open(production) }
            }
        }
        .disabled(app?.recentProductions.isEmpty ?? true)
    }
}

// 편집

extension AppMenuCommands {
    @CommandsBuilder
    private var editMenu: some Commands {
        // 잘라내기 ~ 모두 선택 해제: 글을 입력 중이면 글자에, 아니면 큐 카드에
        CommandGroup(replacing: .pasteboard) {
            Button("잘라내기") { cutOrCopy(isCut: true) }
                .keyboardShortcut("x")
                .disabled(!canEditSelection)
            Button("복사하기") { cutOrCopy(isCut: false) }
                .keyboardShortcut("c")
                .disabled(!canEditSelection)
            Button("붙여넣기") { pasteHere() }
                .keyboardShortcut("v")
                .disabled(!canPaste)
            Button("삭제") { deleteSelection() }
                .disabled(!canEditSelection)
            Divider()
            Button("모두 선택") { selectAll() }
                .keyboardShortcut("a")
                .disabled(!canSelectAll)
            Button("모두 선택 해제") { cueGrid?.deselectAll() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(cueGrid?.hasSelection != true)
        }
        // 찾기 · 맞춤법 및 문법 · 대체 · 변형 · 말하기 (시스템 기본)
        TextEditingCommands()
    }

    // 지금 입력칸에 커서가 있는지 (TextEditingWatcher가 지켜봄)
    private var isEditingText: Bool {
        TextEditingWatcher.shared.isEditing
    }
    
    // 잘라내기 · 복사하기 · 삭제: 글을 입력 중이거나 큐 카드를 선택했을 때
    private var canEditSelection: Bool {
        isEditingText || cueGrid?.hasSelection == true
    }

    // 붙여넣기: 글을 입력 중이거나, 통합 큐시트에서 복사해 둔 큐 카드가 있을 때
    private var canPaste: Bool {
        isEditingText || (cueGrid != nil && !CueClipboard.shared.cues.isEmpty)
    }

    // 모두 선택: 글을 입력 중이거나 통합 큐시트일 때
    private var canSelectAll: Bool {
        isEditingText || cueGrid != nil
    }

    // 입력 중인 글자에 시스템 기본 동작 보내기
    private func sendToText(_ action: Selector) {
        NSApp.sendAction(action, to: nil, from: nil)
    }
    
    // 잘라내기 · 복사하기: 글을 입력 중이면 글자, 아니면 선택한 큐 카드
    private func cutOrCopy(isCut: Bool) {
        guard let cueGrid, cueGrid.hasSelection, !isEditingText else {
            sendToText(isCut ? #selector(NSText.cut(_:)) : #selector(NSText.copy(_:)))
            return
        }
        if isCut { cueGrid.cut() } else { cueGrid.copy() }
    }

    // 붙여넣기: 마우스가 올라간 칸에 큐 카드. 붙일 칸이 없거나 글을 입력 중이면 글자
    private func pasteHere() {
        if let cueGrid, !isEditingText, cueGrid.paste() { return }
        sendToText(#selector(NSText.paste(_:)))
    }
    
    // 댓글 표시 ⇧C: 글을 입력 중이면 대문자 C를 입력칸에 넣고, 아니면 켜기 · 끄기
    private var commentToggle: Binding<Bool> {
        Binding(
            get: { showsComments },
            set: { isOn in
                if isEditingText {
                    NSApp.sendAction(#selector(NSResponder.insertText(_:)), to: nil, from: "C")
                } else {
                    showsComments = isOn
                }
            }
        )
    }

    // 삭제: 글을 입력 중이면 글자, 아니면 선택한 큐 카드
    private func deleteSelection() {
        if let cueGrid, !isEditingText {
            cueGrid.deleteSelected()
        } else {
            sendToText(#selector(NSText.delete(_:)))
        }
    }

    // 모두 선택: 글을 입력 중이면 글자, 아니면 보이는 큐 카드 전부
    private func selectAll() {
        if let cueGrid, !isEditingText {
            cueGrid.selectAll()
        } else {
            sendToText(#selector(NSText.selectAll(_:)))
        }
    }
}

// 보기

extension AppMenuCommands {
    private var viewMenu: some Commands {
        CommandGroup(before: .sidebar) {
            Button("통합 큐시트 보기") { app?.showCueSheet?() }
                .disabled(app?.showCueSheet == nil)
            Button("리허설모드 보기") { app?.showRehearsal?() }
                .disabled(app?.showRehearsal == nil)
            partMenu
            Button("미확인 사이드바 보기") {}
                .disabled(true)
            Button("History 사이드바 보기") {}
                .disabled(true)
            Button("우선순위 사이드바 보기") {}
                .disabled(true)
            Divider()
            Button("사이드바 가리기") { app?.toggleSidebar() }
                .keyboardShortcut("\\", modifiers: [.command, .shift])
                .disabled(app == nil)
            Toggle("댓글 표시", isOn: commentToggle)   // 체크하면 큐 카드 💬 버튼이 보임
                .keyboardShortcut("c", modifiers: .shift)
            Divider()
        }
    }
    
    // 파트별 큐시트보기 > 전체 | 무대 · 음향 … (파트 필터 바와 같은 선택에 체크)
    private var partMenu: some View {
        Menu("파트별 큐시트보기") {
            Toggle("전체", isOn: partToggle(nil))
            Divider()
            ForEach(partFilter?.parts ?? []) { part in
                Toggle(part.name, isOn: partToggle(part))
            }
        }
        .disabled(partFilter == nil)
    }

    // 선택된 파트면 체크. 누르면 그 파트로 (이미 선택된 걸 눌러도 그대로)
    private func partToggle(_ part: Part?) -> Binding<Bool> {
        Binding(
            get: { partFilter?.selectedPart == part },
            set: { _ in partFilter?.select(part) }
        )
    }}

// 도움말

extension AppMenuCommands {
    // 검색창은 시스템이 넣는다
    private var helpMenu: some Commands {
        CommandGroup(replacing: .help) {
            Button("Cuedit 도움말") {}
                .disabled(true)
            Button("키보드 단축키") { app?.showShortcuts() }
                .keyboardShortcut("/")
                .disabled(app == nil)
            Divider()
            Button("Cuedit 피드백 제공 및 문제 신고") {}
                .disabled(true)
        }
    }
}

// 보기 > 댓글 표시 ⇧C를 입력 언어(한글 · 영어)와 상관없이 받기 (피그마 방식)
// 메뉴 단축키는 입력된 글자로 비교해서 한글이면 "ㅊ"이 돼 안 맞음 → 키보드의 C 자리로 직접 확인
// 글자를 입력 중이면 그냥 통과 (대문자 C · ㅊ이 정상으로 입력됨). 앱이 켜질 때 AppDelegate가 한 번 부른다
enum CommentShortcut {
    static func start() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard modifiers == .shift, event.keyCode == 8, !TextEditingWatcher.shared.isEditing else { return event }   // 8 = C 키 자리
            let isShowing = UserDefaults.standard.object(forKey: "showsCommentButton") as? Bool ?? true
            UserDefaults.standard.set(!isShowing, forKey: "showsCommentButton")   // 메뉴 · CueCard의 @AppStorage도 같이 바뀜
            return nil   // 여기서 처리했으니 메뉴로는 안 보냄
        }
    }
}

// 지금 입력칸에 커서가 있는지 지켜보기 (편집 메뉴 켜고 끄기용)
// 앞에 있는 창의 "키보드를 받는 곳(firstResponder)"이 바뀔 때마다 갱신 → 메뉴가 바로 다시 그려짐
@Observable
final class TextEditingWatcher {
    static let shared = TextEditingWatcher()
    private(set) var isEditing = false
    @ObservationIgnored private var observation: NSKeyValueObservation?

    // 앱이 켜질 때 AppDelegate가 한 번 부른다
    func start() {
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.watch(window)
        }
    }

    private func watch(_ window: NSWindow) {
        observation = window.observe(\.firstResponder, options: [.initial, .new]) { [weak self] window, _ in
            self?.isEditing = window.firstResponder is NSText
        }
    }
}
#endif
