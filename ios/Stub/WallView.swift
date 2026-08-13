import SwiftUI

struct WallView: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: StubCategory?
    @State private var selectedTag: String?

    let onEdit: (UUID) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 11),
        GridItem(.flexible(), spacing: 11)
    ]

    private var visibleRecords: [StubRecord] {
        store.records.filter {
            (selectedCategory == nil || $0.category == selectedCategory) &&
            (selectedTag == nil || $0.tags.contains(selectedTag!))
        }
    }

    private var availableTags: [String] {
        Array(Set(store.records.flatMap(\.tags)))
            .sorted { SuggestedTag.label($0, language: language) < SuggestedTag.label($1, language: language) }
    }

    var body: some View {
        let palette = StubPalette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BrandHeader()
                    .padding(.bottom, 22)
                SectionEyebrow(text: "THE STUB WALL")
                Text(language == .zh ? "存根墙" : "The Wall")
                    .font(.system(size: 39, design: .serif))
                    .foregroundStyle(palette.memory)
                    .padding(.top, 6)
                Text(language == .zh
                     ? "海报、照片与票根，拼成生活的全景。"
                     : "Posters, photos and tickets — your life at a glance.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .padding(.top, 7)

                WallFilterBar(
                    selectedCategory: $selectedCategory,
                    selectedTag: $selectedTag,
                    resultCount: visibleRecords.count,
                    availableTags: availableTags
                )
                .padding(.top, 18)

                LazyVGrid(columns: columns, alignment: .center, spacing: 11) {
                    ForEach(visibleRecords) { record in
                        NavigationLink(value: record.id) {
                            WallTile(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("wallScreen")
        .stubScreenBackground(palette)
        .stubNavigationBarHidden()
    }

}

private struct WallFilterBar: View {
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedCategory: StubCategory?
    @Binding var selectedTag: String?
    let resultCount: Int
    let availableTags: [String]

    var body: some View {
        let palette = StubPalette(colorScheme)
        HStack(spacing: 9) {
            categoryMenu(palette)
                .frame(maxWidth: .infinity)
            tagMenu(palette)
                .frame(maxWidth: .infinity)
            Text("\(resultCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(palette.tertiaryText)
                .frame(minWidth: 20)
        }
    }

    private func categoryMenu(_ palette: StubPalette) -> some View {
        Menu {
            Button(language == .zh ? "全部类型" : "All categories") { selectedCategory = nil }
            Divider()
            ForEach(StubCategory.allCases) { category in
                Button(category.label(language)) { selectedCategory = category }
            }
        } label: {
            filterLabel(
                eyebrow: language == .zh ? "类型" : "TYPE",
                value: selectedCategory?.label(language) ?? (language == .zh ? "全部" : "All"),
                palette: palette
            )
        }
        .accessibilityLabel(language == .zh ? "按类型筛选" : "Filter by category")
    }

    private func tagMenu(_ palette: StubPalette) -> some View {
        Menu {
            Button(language == .zh ? "全部标签" : "All tags") { selectedTag = nil }
            Divider()
            ForEach(availableTags, id: \.self) { tagID in
                Button(SuggestedTag.label(tagID, language: language)) { selectedTag = tagID }
            }
        } label: {
            filterLabel(
                eyebrow: language == .zh ? "标签" : "TAG",
                value: selectedTag.map { SuggestedTag.label($0, language: language) } ?? (language == .zh ? "全部" : "All"),
                palette: palette
            )
        }
        .accessibilityLabel(language == .zh ? "按标签筛选" : "Filter by tag")
    }

    private func filterLabel(eyebrow: String, value: String, palette: StubPalette) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(palette.tertiaryText)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(palette.memory)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.border, lineWidth: 0.8)
        }
    }
}

private struct WallTile: View {
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    let record: StubRecord

    var body: some View {
        let palette = StubPalette(colorScheme)
        VStack(alignment: .leading, spacing: 0) {
            StubImage(reference: record.wallCover, contentMode: .fill)
                .frame(height: coverHeight)
                .frame(maxWidth: .infinity)
                .clipped()
            VStack(alignment: .leading, spacing: 5) {
                Text("\(record.category.label(language)) · \(StubDateFormatter.short(record.occurredOn, language: language))")
                    .font(.system(size: 9.5))
                    .foregroundStyle(palette.tertiaryText)
                    .lineLimit(1)
                Text(record.localizedTitle(language))
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(2)
            }
            .padding(12)
        }
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: 0.8))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 5)
    }

    private var coverHeight: CGFloat {
        switch record.category {
        case .movie: 210
        case .performance: 205
        case .stay: 165
        case .food: 150
        case .travel: 125
        default: 170
        }
    }
}

#if !STATIC_CHECK
#Preview("Wall") {
    NavigationStack { WallView(onEdit: { _ in }) }
        .environmentObject(ArchiveStore(preview: PersistedArchive()))
        .environment(\.stubLanguage, .zh)
}
#endif
