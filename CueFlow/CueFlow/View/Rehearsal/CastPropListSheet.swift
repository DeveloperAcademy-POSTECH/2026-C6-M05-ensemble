//
//  CastPropListSheet.swift
//  CueFlow
//
//  "배우 · 소품 목록" (피그마 배우소품목록입력01). 공연의 배역 · 소품 이름을 한 곳에서 보고 추가 · 삭제한다.
//  여기 이름이 무대 배치 창의 카드가 된다. 대본 입력에서 체크한 이름도 여기에 들어온다.
//

import SwiftUI

struct CastPropListSheet: View {
    let production: Production
    let onNext: () -> Void   // "다음으로" → 최초 상태 무대 배치

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            SheetHeader(
                title: "배우 · 소품 목록",
                subtitle: "큐 제목에 이 이름이 들어 있으면 무대 배치도에 그 큐의 위치로 나와요."
            ) {
                EmptyView()
            }

            HStack(alignment: .top, spacing: 41) {
                NameListColumn(
                    title: "배역",
                    systemImage: "person",
                    names: Binding(get: { production.castNames }, set: { production.castNames = $0 })
                )
                NameListColumn(
                    title: "소품",
                    systemImage: "gift",
                    names: Binding(get: { production.propNames }, set: { production.propNames = $0 })
                )
            }

            Button("다음으로", action: onNext)
                .buttonStyle(SheetPrimaryButtonStyle())
                .frame(width: 99, height: 29)
                .disabled(production.castNames.isEmpty && production.propNames.isEmpty)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 48)
        .padding(.top, 62)
        .padding(.bottom, 52)
        .frame(width: 1009)
        .background(Color.neutral25)
    }
}

// 이름 목록 한 열: 제목 + 추가 칸 · 등록 버튼 + 이름 칸 4개씩 (x로 삭제)
private struct NameListColumn: View {
    let title: String
    let systemImage: String
    @Binding var names: [String]

    @State private var newName = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(names.count)개")
                    .font(.body)
                    .foregroundStyle(Color.neutral500)
                    .padding(.leading, 4)
            }
            .foregroundStyle(Color.neutral900)
            .padding(.leading, 6)

            HStack(spacing: 12) {
                HStack {
                    TextField("\(title)을 추가해주세요", text: $newName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(Color.neutral900)
                        .onSubmit(add)
                    Image(systemName: "arrow.turn.down.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.neutral300)
                }
                .padding(.horizontal, 15)
                .frame(height: 36)
                .background(Color.neutral50, in: RoundedRectangle(cornerRadius: 6))

                Button(action: add) {
                    Text("등록")
                        .font(.body)
                        .foregroundStyle(Color.brandPrimaryText)
                        .frame(width: 60, height: 36)
                        .background(Color.brandPrimarySubtle, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 9)

            if names.isEmpty {
                Text("아직 없어요")
                    .font(.caption)
                    .foregroundStyle(Color.neutral400)
                    .padding(.top, 28)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(names, id: \.self) { name in
                        NameTile(name: name) {
                            names.removeAll { $0 == name }
                        }
                    }
                }
                .padding(.top, 28)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if !names.contains(name) { names.append(name) }
        newName = ""
    }
}

// 이름 칸 하나: 이름 + 오른쪽 x
private struct NameTile: View {
    let name: String
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.neutral900)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.brandPrimaryDisabled)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("\(name) 삭제")
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(height: 36)
        .background(Color.neutral25, in: RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.brandPrimaryDisabled, lineWidth: 0.5)
        }
    }
}

#Preview {
    CastPropListSheet(production: RehearsalPreviewData.production) { }
}
