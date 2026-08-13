import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @Binding var languageRaw: String
    @Binding var appearanceRaw: String
    @State private var showSettings = false

    private var userRecords: [StubRecord] {
        store.records.filter { $0.source == .user }
    }

    private var years: Int {
        Set(userRecords.map { Calendar.current.component(.year, from: $0.occurredOn) }).count
    }

    private var usedTags: [(id: String, count: Int)] {
        let counts = Dictionary(grouping: userRecords.flatMap(\.tags), by: { $0 }).mapValues(\.count)
        return counts.sorted { lhs, rhs in
            lhs.value == rhs.value
                ? SuggestedTag.label(lhs.key, language: language) < SuggestedTag.label(rhs.key, language: language)
                : lhs.value > rhs.value
        }
        .prefix(5)
        .map { ($0.key, $0.value) }
    }

    var body: some View {
        let palette = StubPalette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BrandHeader(trailing: AnyView(settingsButton(palette)))
                    .padding(.bottom, 22)
                SectionEyebrow(text: language == .zh ? "YOUR MOMENTS" : "YOUR MOMENTS")
                Text(language == .zh ? "回顾" : "Review")
                    .font(.system(size: 39, design: .serif))
                    .foregroundStyle(palette.memory)
                    .padding(.top, 6)
                Text(language == .zh ? "从留住的纸片里，再遇见那些日子。" : "Meet your days again through the things you kept.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .padding(.top, 7)

                if userRecords.isEmpty {
                    emptyReview(palette)
                        .padding(.top, 22)
                } else {
                    memoryOverview(palette)
                        .padding(.top, 22)

                    if !usedTags.isEmpty {
                        sectionTitle(language == .zh ? "常出现的记忆线索" : "Memory threads", palette: palette)
                        FlowLayout(spacing: 8) {
                            ForEach(usedTags, id: \.id) { item in
                                Label {
                                    Text("\(SuggestedTag.label(item.id, language: language)) · \(item.count)")
                                } icon: {
                                    Image(systemName: SuggestedTag.symbol(item.id))
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(palette.primaryText)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 38)
                                .background(palette.surface, in: Capsule())
                                .overlay(Capsule().stroke(palette.border, lineWidth: 0.8))
                            }
                        }
                    }

                    sectionTitle(language == .zh ? "最近留下" : "Recently kept", palette: palette)
                    VStack(spacing: 10) {
                        ForEach(userRecords.sorted { $0.occurredOn > $1.occurredOn }.prefix(3)) { record in
                            NavigationLink(value: record.id) {
                                recentRow(record, palette: palette)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("profileScreen")
        .stubScreenBackground(palette)
        .stubNavigationBarHidden()
        .sheet(isPresented: $showSettings) {
            SettingsView(languageRaw: $languageRaw, appearanceRaw: $appearanceRaw)
        }
    }

    private func settingsButton(_ palette: StubPalette) -> some View {
        Button { showSettings = true } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.primaryText)
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(palette.strongBorder, lineWidth: 0.8))
        }
        .accessibilityLabel(language == .zh ? "设置" : "Settings")
        .accessibilityIdentifier("settingsButton")
    }

    private func memoryOverview(_ palette: StubPalette) -> some View {
        HStack(spacing: 0) {
            overviewValue(userRecords.count, language == .zh ? "枚存根" : "stubs", palette: palette)
            Divider().frame(height: 44).overlay(palette.border)
            overviewValue(store.trips.count, language == .zh ? "本旅册" : "trip books", palette: palette)
            Divider().frame(height: 44).overlay(palette.border)
            overviewValue(years, language == .zh ? "年记忆" : "years", palette: palette)
        }
        .frame(maxWidth: .infinity)
        .stubPaperCard(palette)
    }

    private func overviewValue(_ value: Int, _ label: String, palette: StubPalette) -> some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(palette.primaryText)
                .contentTransition(.numericText())
            Text(label).font(.caption2).foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ title: String, palette: StubPalette) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold, design: .serif))
            .foregroundStyle(palette.primaryText)
            .padding(.top, 28)
            .padding(.bottom, 12)
    }

    private func emptyReview(_ palette: StubPalette) -> some View {
        ContentUnavailableView(
            language == .zh ? "还没有可以回看的日子" : "Nothing to revisit yet",
            systemImage: "clock.arrow.circlepath",
            description: Text(language == .zh ? "留下第一张属于你的存根后，它会出现在这里。" : "Your first saved stub will appear here.")
        )
        .foregroundStyle(palette.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func recentRow(_ record: StubRecord, palette: StubPalette) -> some View {
        HStack(spacing: 12) {
            StubImage(reference: record.wallCover, contentMode: .fill)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(record.localizedTitle(language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                Text("\(record.category.label(language)) · \(StubDateFormatter.short(record.occurredOn, language: language))")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.tertiaryText)
        }
        .padding(12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.border, lineWidth: 0.8)
                .allowsHitTesting(false)
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @Binding var languageRaw: String
    @Binding var appearanceRaw: String
    @State private var exportItem: ExportItem?

    var body: some View {
        let palette = StubPalette(colorScheme)
        NavigationStack {
            Form {
                Section(language == .zh ? "显示" : "Display") {
                    Picker(language == .zh ? "语言" : "Language", selection: $languageRaw) {
                        Text("中文").tag(AppLanguage.zh.rawValue)
                        Text("English").tag(AppLanguage.en.rawValue)
                    }
                    Picker(language == .zh ? "外观" : "Appearance", selection: $appearanceRaw) {
                        Text(language == .zh ? "跟随系统" : "System").tag(AppearanceMode.system.rawValue)
                        Text(language == .zh ? "浅色" : "Light").tag(AppearanceMode.light.rawValue)
                        Text(language == .zh ? "深色" : "Dark").tag(AppearanceMode.dark.rawValue)
                    }
                }

                Section {
                    Button {
                        exportItem = try? ExportItem(url: store.archiveExportURL())
                    } label: {
                        Label(language == .zh ? "导出存根索引" : "Export stub index", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text(language == .zh ? "数据与备份" : "Data & backup")
                } footer: {
                    Text(language == .zh
                         ? "当前内容只保存在这台 iPhone。导出文件包含文字和结构，不包含原始图片。"
                         : "Your content currently stays on this iPhone. The export includes text and structure, not original images.")
                }

                Section(language == .zh ? "关于" : "About") {
                    LabeledContent("Stub", value: "0.1")
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.canvas)
            .navigationTitle(language == .zh ? "设置" : "Settings")
            .stubInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language == .zh ? "完成" : "Done") { dismiss() }
                }
            }
        }
        .sheet(item: $exportItem) { item in
            ActivityShareView(items: [item.url])
        }
    }
}

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

#if canImport(UIKit)
import UIKit

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
private struct ActivityShareView: View {
    let items: [Any]
    var body: some View { Text("Export is available on iOS.") }
}
#endif

#if !STATIC_CHECK
#Preview("Review") {
    NavigationStack {
        ProfileView(languageRaw: .constant("zh"), appearanceRaw: .constant("system"))
    }
    .environmentObject(ArchiveStore(preview: PersistedArchive()))
    .environment(\.stubLanguage, .zh)
}
#endif
