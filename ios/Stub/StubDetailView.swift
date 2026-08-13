import SwiftUI

struct StubDetailView: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var error: String?

    let recordID: UUID
    let onEdit: (UUID) -> Void

    var body: some View {
        let palette = StubPalette(colorScheme)
        ScrollView {
            if let record = store.record(id: recordID) {
                VStack(alignment: .leading, spacing: 20) {
                    if record.details.kind == .movie, let poster = record.posterMedia {
                        movieHero(record, poster: poster, palette: palette)
                    }
                    if record.details.kind == .flight {
                        FlightCard(details: record.details)
                    }
                    if record.details.kind == .stay {
                        StayCard(details: record.details, checkIn: record.occurredOn)
                    }
                    if record.details.kind == .performance {
                        if let poster = record.posterMedia {
                            StubImage(reference: poster, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        PerformanceCard(details: record.details, date: record.occurredOn)
                    }

                    TicketArtifact(reference: record.primaryMedia)
                    detailCopy(record, palette: palette)

                    if !record.attachments.isEmpty {
                        Text(language == .zh ? "当时的照片" : "Photos from then")
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(record.attachments) { reference in
                                    StubImage(reference: reference, contentMode: .fill)
                                        .frame(width: 180, height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 13))
                                }
                            }
                        }
                    }

                    actions(record, palette: palette)

                    if let error {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            } else {
                ContentUnavailableView(
                    language == .zh ? "找不到这张存根" : "Stub not found",
                    systemImage: "ticket"
                )
            }
        }
        .stubScreenBackground(palette)
        .accessibilityIdentifier("stubDetailScreen")
        .navigationTitle(language == .zh ? "详情" : "Details")
        .stubInlineNavigationTitle()
        .confirmationDialog(
            language == .zh ? "移除这张存根？" : "Remove this stub?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(language == .zh ? "移除" : "Remove", role: .destructive) { deleteRecord() }
            Button(language == .zh ? "取消" : "Cancel", role: .cancel) {}
        } message: {
            Text(language == .zh ? "本地图片和旅册引用也会一并移除。" : "Its local images and trip placement will also be removed.")
        }
    }

    private func movieHero(_ record: StubRecord, poster: MediaReference, palette: StubPalette) -> some View {
        HStack(spacing: 16) {
            StubImage(reference: poster, contentMode: .fill)
                .frame(width: 110, height: 164)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 8) {
                Text(record.details.formatIDs.map(MovieFormat.label).joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.memory)
                Text(record.localizedTitle(language))
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.primaryText)
                Text(record.details.cinema)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                Text([record.details.hall, record.details.seat].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(palette.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stubPaperCard(palette)
    }

    private func detailCopy(_ record: StubRecord, palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(record.category.label(language).uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(palette.memory)
                Spacer()
                Text(StubDateFormatter.short(record.occurredOn, language: language))
                    .font(.caption)
                    .foregroundStyle(palette.tertiaryText)
            }
            if record.details.kind != .movie {
                Text(record.localizedTitle(language))
                    .font(.system(size: 27, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.primaryText)
            }
            FlowLayout(spacing: 7) {
                ForEach(record.details.kind == .movie ? record.details.formatIDs : [], id: \.self) {
                    TagChip(title: MovieFormat.label($0))
                }
                ForEach(record.tags, id: \.self) {
                    TagChip(title: SuggestedTag.label($0, language: language))
                }
            }
            if !record.localizedNote(language).isEmpty {
                Text(record.localizedNote(language))
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(palette.secondaryText)
                    .lineSpacing(6)
            }
        }
    }

    private func actions(_ record: StubRecord, palette: StubPalette) -> some View {
        VStack(spacing: 10) {
            if record.source == .user {
                Button {
                    onEdit(record.id)
                } label: {
                    Label(language == .zh ? "编辑标签与信息" : "Edit tags and details", systemImage: "pencil")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(palette.brand)
            }

            Menu {
                ForEach(store.trips) { trip in
                    Button(trip.localizedTitle(language)) {
                        do { try store.add(record.id, to: trip.id) }
                        catch { self.error = error.localizedDescription }
                    }
                }
                if store.placement(for: record.id) != nil {
                    Divider()
                    Button(language == .zh ? "从旅册移除" : "Remove from trip") {
                        do { try store.removeFromTrip(record.id) }
                        catch { self.error = error.localizedDescription }
                    }
                }
            } label: {
                Label(language == .zh ? "收进旅册" : "Add to trip book", systemImage: "book.closed")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .tint(palette.brand)

            if record.source == .user {
                Button(role: .destructive) { showDeleteConfirmation = true } label: {
                    Label(language == .zh ? "移除这张存根" : "Remove this stub", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
        }
    }

    private func deleteRecord() {
        do {
            try store.delete(recordID)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
