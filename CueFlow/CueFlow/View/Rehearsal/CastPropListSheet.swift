//
//  CastPropListSheet.swift
//  CueFlow
//
//  "배역 · 소품 목록" 창. 공연의 배역 · 소품 이름을 한 곳에서 보고 추가 · 삭제한다.
//  이 이름으로 리허설 무대 배치도가 큐 제목에서 배역 · 소품을 찾는다.
//  대본 입력에서 체크한 이름도 여기에 들어온다.
//

import SwiftUI

struct CastPropListSheet: View {
    let production: Production

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("배역 · 소품 목록")
                    .font(.title2.bold())
                Text("큐 제목에 이 이름이 들어 있으면 무대 배치도에 그 큐의 위치로 나와요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                NameListColumn(
                    title: "배역",
                    systemImage: "person.fill",
                    names: Binding(get: { production.castNames }, set: { production.castNames = $0 })
                )
                NameListColumn(
                    title: "소품",
                    systemImage: "shippingbox.fill",
                    names: Binding(get: { production.propNames }, set: { production.propNames = $0 })
                )
            }

            HStack {
                Spacer()
                Button("닫기") { dismiss() }
                    .buttonStyle(.primary)
                    .frame(width: 90, height: 34)
            }
        }
        .padding(28)
        .frame(width: 560, height: 520)
    }
}

// 이름 목록 한 열: 추가 칸 + 이름 줄들 (x로 삭제)
private struct NameListColumn: View {
    let title: String
    let systemImage: String
    @Binding var names: [String]

    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
                Text("\(names.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("\(title) 추가 후 Enter", text: $newName)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)

            ScrollView {
                VStack(spacing: 0) {
                    if names.isEmpty {
                        Text("아직 없어요")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 12)
                    }
                    ForEach(names, id: \.self) { name in
                        HStack {
                            Text(name)
                                .font(.callout)
                            Spacer()
                            Button {
                                names.removeAll { $0 == name }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("\(name) 삭제")
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        Divider()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if !names.contains(name) { names.append(name) }
        newName = ""
    }
}

#Preview {
    CastPropListSheet(production: RehearsalPreviewData.production)
}
