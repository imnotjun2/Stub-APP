import SwiftUI

private enum TripRoute: Hashable {
    case book(UUID)
}

struct TripsView: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @State private var showNewTrip = false

    let onEdit: (UUID) -> Void

    var body: some View {
        let palette = StubPalette(colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BrandHeader(trailing: AnyView(newTripButton(palette)))
                    .padding(.bottom, 22)

                SectionEyebrow(text: "TRIP BOOKS")
                Text(language == .zh ? "旅册" : "Journeys")
                    .font(.system(size: 39, weight: .regular, design: .serif))
                    .foregroundStyle(palette.memory)
                    .padding(.top, 6)
                Text(language == .zh
                     ? "把一路上的票根，装订成一本旅册。"
                     : "Bind the tickets from one journey into a book.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)

                mapExperience(palette)
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("tripsScreen")
        .stubScreenBackground(palette)
        .stubNavigationBarHidden()
        .navigationDestination(for: TripRoute.self) { route in
            switch route {
            case .book(let id):
                TripBookView(tripID: id, onEdit: onEdit)
            }
        }
        .sheet(isPresented: $showNewTrip) {
            NewTripSheet()
        }
    }

    private func newTripButton(_ palette: StubPalette) -> some View {
        Button { showNewTrip = true } label: {
            Image(systemName: "plus")
                .foregroundStyle(palette.primaryText)
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(palette.strongBorder, lineWidth: 0.8))
        }
        .accessibilityLabel(language == .zh ? "新建旅册" : "New trip book")
    }

    private func mapExperience(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                StubImage(reference: .bundled("trip-map.png"), contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: size.width * 0.27, y: size.height * 0.55))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.55, y: size.height * 0.31),
                        control1: CGPoint(x: size.width * 0.36, y: size.height * 0.57),
                        control2: CGPoint(x: size.width * 0.46, y: size.height * 0.33)
                    )
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.65, y: size.height * 0.66),
                        control1: CGPoint(x: size.width * 0.58, y: size.height * 0.42),
                        control2: CGPoint(x: size.width * 0.64, y: size.height * 0.51)
                    )
                    context.stroke(path, with: .color(palette.brand), lineWidth: 1.25)
                }
                .allowsHitTesting(false)

                mapLabel(language == .zh ? "小樽" : "Otaru", x: 0.23, y: 0.49, palette: palette)
                mapLabel(language == .zh ? "札幌" : "Sapporo", x: 0.43, y: 0.54, palette: palette, active: true)
                mapLabel(language == .zh ? "旭川" : "Asahikawa", x: 0.60, y: 0.28, palette: palette)
                mapLabel(language == .zh ? "新千岁" : "CTS", x: 0.72, y: 0.66, palette: palette)
            }
            .frame(maxWidth: .infinity, minHeight: 248, maxHeight: 248)
            .background(palette.sunken, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottom) {
                NavigationLink(value: TripRoute.book(StubFixtures.tripID)) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Label(language == .zh ? "札幌 · 第 4 日" : "Sapporo · Day 4", systemImage: "mappin.and.ellipse")
                                    .foregroundStyle(palette.brandOnSoft)
                                Text(language == .zh ? "2 枚存根" : "2 stubs")
                                    .foregroundStyle(palette.tertiaryText)
                            }
                            .font(.caption2)
                            Text(language == .zh ? "雨停以后，沿着狸小路慢慢走。" : "After the rain, we wandered through Tanukikoji.")
                                .font(.system(size: 13, design: .serif))
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.brand)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(palette.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.border, lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.09), radius: 9, y: 4)
                    .padding(12)
                }
                .buttonStyle(.plain)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.border, lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.07), radius: 14, y: 7)

            HStack(alignment: .firstTextBaseline) {
                Text(language == .zh ? "最近旅册" : "Recent book")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Text("\(store.browsableTrips.count) \(language == .zh ? "本" : "books")")
                    .font(.caption)
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding(.top, 2)

            NavigationLink(value: TripRoute.book(StubFixtures.tripID)) {
                TripCoverCard(trip: StubFixtures.trip)
            }
            .buttonStyle(.plain)
        }
    }

    private func mapLabel(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        palette: StubPalette,
        active: Bool = false
    ) -> some View {
        GeometryReader { proxy in
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(active ? palette.brandOnSoft : palette.primaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(palette.elevated.opacity(0.94), in: Capsule())
                .overlay(Capsule().stroke(active ? palette.brand : palette.strongBorder, lineWidth: 0.8))
                .position(x: proxy.size.width * x, y: proxy.size.height * y)
        }
        .allowsHitTesting(false)
    }

}

private struct TripCoverCard: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    let trip: TripBook

    var body: some View {
        let palette = StubPalette(colorScheme)
        HStack(spacing: 0) {
            StubImage(reference: .bundled("trip-map.png"), contentMode: .fill)
                .frame(width: 118, height: 145)
                .clipped()
            VStack(alignment: .leading, spacing: 7) {
                Text("HOKKAIDO · SUMMER 2026")
                    .font(.system(size: 8, weight: .medium, design: .serif))
                    .tracking(1)
                    .foregroundStyle(palette.memory)
                Text(trip.localizedTitle(language))
                    .font(.system(size: 22, design: .serif))
                    .foregroundStyle(palette.primaryText)
                Text("\(trip.localizedRoute(language)) · \(store.records(in: trip.id).count) \(language == .zh ? "枚存根" : "stubs")")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)
                Label(language == .zh ? "打开旅册" : "Open book", systemImage: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.brandOnSoft)
                    .padding(.top, 5)
            }
            .padding(16)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 145)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.border, lineWidth: 0.8))
        .shadow(color: .black.opacity(0.09), radius: 14, y: 7)
    }
}

struct TripBookView: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    let tripID: UUID
    let onEdit: (UUID) -> Void

    var body: some View {
        let palette = StubPalette(colorScheme)
        ScrollView {
            if let trip = store.trip(id: tripID) {
                LazyVStack(spacing: 24) {
                    tripCover(trip, palette: palette)
                    ForEach(store.records(in: tripID), id: \.0.id) { placement, record in
                        bookPage(placement, record: record, palette: palette)
                    }

                    if store.records(in: tripID).isEmpty {
                        ContentUnavailableView(
                            language == .zh ? "这本旅册还没有纸片" : "This trip book is empty",
                            systemImage: "book.closed",
                            description: Text(language == .zh
                                              ? "打开任意存根，把它收进这本旅册。"
                                              : "Open a stub and add it to this trip book.")
                        )
                        .padding(.vertical, 60)
                    }
                }
                .padding(20)
                .padding(.bottom, 36)
            } else {
                ContentUnavailableView(
                    language == .zh ? "找不到这本旅册" : "Trip book unavailable",
                    systemImage: "book.closed",
                    description: Text(language == .zh
                                      ? "它可能已被移除。请返回旅册后重新选择。"
                                      : "It may have been removed. Return to Trips and choose another book.")
                )
                .padding(.top, 100)
            }
        }
        .stubScreenBackground(palette)
        .accessibilityIdentifier("tripBookScreen")
        .navigationTitle(language == .zh ? "一本旅册" : "Trip Book")
        .stubInlineNavigationTitle()
    }

    private func tripCover(_ trip: TripBook, palette: StubPalette) -> some View {
        VStack(spacing: 0) {
            StubImage(reference: .bundled("trip-map.png"), contentMode: .fill)
                .frame(height: 165)
                .clipped()
            VStack(alignment: .leading, spacing: 8) {
                Text("STUB · TRIP BOOK")
                    .font(.system(size: 9, weight: .medium, design: .serif))
                    .tracking(1.2)
                    .foregroundStyle(palette.memory)
                Text(trip.localizedTitle(language))
                    .font(.system(size: 28, design: .serif))
                    .foregroundStyle(palette.primaryText)
                Text(trip.localizedRoute(language))
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                Text("\(StubDateFormatter.short(trip.startDate, language: language)) — \(StubDateFormatter.short(trip.endDate, language: language))")
                    .font(.caption2)
                    .foregroundStyle(palette.tertiaryText)
                Text(trip.note)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(palette.memory)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.border, lineWidth: 0.8))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 7)
    }

    private func bookPage(_ placement: TripPlacement, record: StubRecord, palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("DAY \(String(format: "%02d", placement.day))")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .tracking(1.2)
                    .foregroundStyle(palette.brandOnSoft)
                Spacer()
                Text(StubDateFormatter.short(record.occurredOn, language: language))
                    .font(.caption2)
                    .foregroundStyle(palette.tertiaryText)
            }
            Divider().overlay(palette.border)
            if record.details.kind == .flight {
                FlightCard(details: record.details)
            }
            NavigationLink(value: record.id) {
                TicketArtifact(reference: record.primaryMedia, maxHeight: 270)
                    .rotationEffect(.degrees(placement.rotation))
            }
            .buttonStyle(.plain)
            Text(placement.caption.isEmpty ? record.category.label(language) : placement.caption)
                .font(.caption)
                .foregroundStyle(palette.memory)
            Text(record.localizedTitle(language))
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(palette.primaryText)
            Text(record.localizedNote(language))
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
        .stubPaperCard(palette, radius: 16)
    }
}

private struct NewTripSheet: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @State private var title = ""
    @State private var route = ""
    @State private var note = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var error: String?

    var body: some View {
        let palette = StubPalette(colorScheme)
        NavigationStack {
            Form {
                Section(language == .zh ? "旅册" : "Trip book") {
                    TextField(language == .zh ? "例如：京都 · 2026 秋" : "Kyoto · Autumn 2026", text: $title)
                    TextField(language == .zh ? "路线" : "Route", text: $route)
                    DatePicker(language == .zh ? "开始" : "Start", selection: $startDate, displayedComponents: .date)
                    DatePicker(language == .zh ? "结束" : "End", selection: $endDate, displayedComponents: .date)
                }
                Section(language == .zh ? "封面一句话" : "Cover note") {
                    TextField(language == .zh ? "想怎样记住这趟旅行？" : "How do you want to remember it?", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.canvas)
            .navigationTitle(language == .zh ? "新建旅册" : "New trip book")
            .stubInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language == .zh ? "取消" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language == .zh ? "放上书架" : "Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        do {
            _ = try store.createTrip(
                title: title,
                startDate: startDate,
                endDate: max(startDate, endDate),
                route: route,
                note: note
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#if !STATIC_CHECK
#Preview("Trips") {
    NavigationStack { TripsView(onEdit: { _ in }) }
        .environmentObject(ArchiveStore(preview: PersistedArchive()))
        .environment(\.stubLanguage, .zh)
}
#endif
