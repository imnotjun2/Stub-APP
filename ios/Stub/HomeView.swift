import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: StubCategory?
    @State private var selectedTag: String?
    @State private var showFilters = false

    let onEdit: (UUID) -> Void

    private var visibleRecords: [StubRecord] {
        store.records.filter { record in
            (selectedCategory == nil || record.category == selectedCategory) &&
            (selectedTag == nil || record.tags.contains(selectedTag!))
        }
    }

    private var displayedMonth: Date {
        store.records.first?.occurredOn ?? Date()
    }

    var body: some View {
        let palette = StubPalette(colorScheme)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                BrandHeader(trailing: AnyView(filterButton(palette)))
                    .padding(.bottom, 22)

                SectionEyebrow(text: StubDateFormatter.monthEyebrow(displayedMonth))
                Text(StubDateFormatter.month(displayedMonth, language: language))
                    .font(.system(size: language == .zh ? 41 : 38, weight: .regular, design: .serif))
                    .foregroundStyle(palette.memory)
                    .padding(.top, 6)
                Text(language == .zh ? "记录生活，留住每个瞬间。" : "Keep the small proofs that life happened.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .padding(.top, 7)

                if selectedCategory != nil || selectedTag != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(filterSummary)
                        Button(language == .zh ? "清除" : "Clear") {
                            selectedCategory = nil
                            selectedTag = nil
                        }
                        .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundStyle(palette.brandOnSoft)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(palette.brandSoft, in: Capsule())
                    .padding(.top, 14)
                }

                LazyVStack(spacing: 20) {
                    ForEach(Array(visibleRecords.enumerated()), id: \.element.id) { index, record in
                        NavigationLink(value: record.id) {
                            TimelineStubCard(record: record, isFeatured: index == 0)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("stubCard.\(record.id.uuidString)")
                    }
                }
                .padding(.top, 20)

                if visibleRecords.isEmpty {
                    ContentUnavailableView(
                        language == .zh ? "没有符合筛选的存根" : "No matching stubs",
                        systemImage: "ticket",
                        description: Text(language == .zh ? "换一个类型或标签看看。" : "Try another category or tag.")
                    )
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 72)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("homeScreen")
        .stubScreenBackground(palette)
        .stubNavigationBarHidden()
        .sheet(isPresented: $showFilters) {
            FilterSheet(
                selectedCategory: $selectedCategory,
                selectedTag: $selectedTag,
                availableTags: Array(Set(store.records.flatMap(\.tags)))
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func filterButton(_ palette: StubPalette) -> some View {
        Button { showFilters = true } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.primaryText)
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(palette.strongBorder, lineWidth: 0.8))
        }
        .accessibilityLabel(language == .zh ? "筛选存根" : "Filter stubs")
        .accessibilityIdentifier("homeFilterButton")
    }

    private var filterSummary: String {
        [
            selectedCategory.map { $0.label(language) },
            selectedTag.map { SuggestedTag.label($0, language: language) }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

private struct TimelineStubCard: View {
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    let record: StubRecord
    let isFeatured: Bool

    var body: some View {
        let palette = StubPalette(colorScheme)
        VStack(alignment: .leading, spacing: 13) {
            TicketArtifact(reference: record.primaryMedia, maxHeight: isFeatured ? 380 : 250)

            VStack(alignment: .leading, spacing: 10) {
                if !record.localizedNote(language).isEmpty {
                    Text(record.localizedNote(language))
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(palette.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("— \(StubDateFormatter.short(record.occurredOn, language: language))")
                    .font(.caption)
                    .foregroundStyle(palette.memory)

                FlowLayout(spacing: 6) {
                    if record.details.kind == .movie {
                        ForEach(record.details.formatIDs, id: \.self) {
                            TagChip(title: MovieFormat.label($0))
                        }
                    }
                    ForEach(record.tags.prefix(3), id: \.self) {
                        TagChip(title: SuggestedTag.label($0, language: language))
                    }
                }
            }
            .padding(.leading, 17)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(palette.memory)
                    .frame(width: 3)
                    .padding(.vertical, 14)
            }

            if !isFeatured {
                HStack {
                    Text(record.category.label(language))
                        .font(.caption)
                        .foregroundStyle(palette.tertiaryText)
                    Text(record.localizedTitle(language))
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(palette.tertiaryText)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

private struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedCategory: StubCategory?
    @Binding var selectedTag: String?
    let availableTags: [String]

    var body: some View {
        let palette = StubPalette(colorScheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    filterGroup(language == .zh ? "类型" : "Category") {
                        TagChip(title: language == .zh ? "全部" : "All", selected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(StubCategory.allCases) { category in
                            TagChip(title: category.label(language), selected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }

                    filterGroup(language == .zh ? "标签" : "Tag") {
                        TagChip(title: language == .zh ? "全部标签" : "All tags", selected: selectedTag == nil) {
                            selectedTag = nil
                        }
                        ForEach(availableTags.sorted { SuggestedTag.label($0, language: language) < SuggestedTag.label($1, language: language) }, id: \.self) { tagID in
                            TagChip(title: SuggestedTag.label(tagID, language: language), selected: selectedTag == tagID) {
                                selectedTag = tagID
                            }
                        }
                    }
                }
                .padding(24)
            }
            .stubScreenBackground(palette)
            .navigationTitle(language == .zh ? "筛选存根" : "Filter stubs")
            .stubInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language == .zh ? "完成" : "Done") { dismiss() }
                }
            }
        }
    }

    private func filterGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            FlowLayout(spacing: 8) { content() }
        }
    }
}

#if !STATIC_CHECK
#Preview("Home") {
    NavigationStack { HomeView(onEdit: { _ in }) }
        .environmentObject(ArchiveStore(preview: PersistedArchive()))
        .environment(\.stubLanguage, .zh)
}
#endif
