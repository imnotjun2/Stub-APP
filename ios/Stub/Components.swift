import SwiftUI

struct BrandHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.stubLanguage) private var language

    var trailing: AnyView? = nil

    var body: some View {
        let palette = StubPalette(colorScheme)
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stub")
                    .font(.system(size: 35, weight: .bold, design: .serif))
                    .tracking(-1.2)
                    .foregroundStyle(palette.primaryText)
                Text(language == .zh ? "生活存根" : "LIFE, KEPT.")
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .tracking(language == .zh ? 2.2 : 1.4)
                    .foregroundStyle(palette.tertiaryText)
            }
            Spacer()
            trailing
        }
    }
}

struct SectionEyebrow: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .serif))
            .tracking(1.7)
            .foregroundStyle(StubPalette(colorScheme).memory)
    }
}

struct TagChip: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var selected = false
    var action: (() -> Void)?

    var body: some View {
        let palette = StubPalette(colorScheme)
        Group {
            if let action {
                Button(action: action) { label(palette) }
                    .buttonStyle(.plain)
            } else {
                label(palette)
            }
        }
    }

    private func label(_ palette: StubPalette) -> some View {
        Text(title)
            .font(.system(size: 12, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? palette.brandOnSoft : palette.secondaryText)
            .padding(.horizontal, 13)
            .frame(minHeight: 36)
            .background(selected ? palette.brandSoft : palette.surface, in: Capsule())
            .overlay {
                Capsule().stroke(selected ? palette.brand : palette.border, lineWidth: 0.8)
            }
            .contentShape(Capsule())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let arrangement = arrange(proposal: proposal, subviews: subviews)
        for (index, point) in arrangement.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var points: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}

struct TicketArtifact: View {
    @Environment(\.colorScheme) private var colorScheme
    let reference: MediaReference
    var maxHeight: CGFloat = 360

    var body: some View {
        let palette = StubPalette(colorScheme)
        StubImage(reference: reference, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: maxHeight)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(palette.border, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.11), radius: 16, y: 8)
    }
}

struct FlightCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.stubLanguage) private var language
    let details: StubDetails

    var body: some View {
        let palette = StubPalette(colorScheme)
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                airlineMark
                VStack(alignment: .leading, spacing: 2) {
                    Text(details.airline.isEmpty ? (language == .zh ? "航司" : "Airline") : details.airline)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                    Text(details.flightNumber.isEmpty ? "—" : details.flightNumber)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                }
                Spacer()
                Text(language == .zh ? "行程存根" : "TRIP STUB")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.success)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(palette.success.opacity(0.5)))
            }

            HStack(alignment: .center) {
                airport(details.departure, time: details.departureTime, palette: palette)
                Spacer()
                HStack(spacing: 8) {
                    Rectangle().fill(palette.border).frame(width: 28, height: 1)
                    Image(systemName: "airplane")
                        .foregroundStyle(palette.brand)
                    Rectangle().fill(palette.border).frame(width: 28, height: 1)
                }
                Spacer()
                airport(details.arrival, time: details.arrivalTime, palette: palette)
            }

            Divider().overlay(palette.border)
            HStack {
                detailColumn(language == .zh ? "机型" : "AIRCRAFT", details.aircraft, palette: palette)
                Spacer()
                detailColumn(language == .zh ? "舱位" : "CABIN", cabinLabel, palette: palette)
                Spacer()
                detailColumn(language == .zh ? "座位" : "SEAT", details.seat, palette: palette)
            }
        }
        .stubPaperCard(palette, radius: 15)
    }

    @ViewBuilder
    private var airlineMark: some View {
        let code = details.airlineCode.uppercased()
        let resource: String? = switch code {
        case "MU": "airline-mu.png"
        case "CA": "airline-ca.png"
        case "CZ": "airline-cz.png"
        default: nil
        }
        if let resource {
            StubImage(reference: .bundled(resource), contentMode: .fit)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Text(code.isEmpty ? "--" : code)
                .font(.caption.weight(.bold))
                .frame(width: 34, height: 34)
                .background(StubPalette(colorScheme).brandSoft, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func airport(_ code: String, time: String, palette: StubPalette) -> some View {
        VStack(alignment: code == details.departure ? .leading : .trailing, spacing: 3) {
            Text(code.isEmpty ? "—" : code)
                .font(.system(size: 31, weight: .bold, design: .serif))
                .foregroundStyle(palette.primaryText)
            Text(time.isEmpty ? "--:--" : time)
                .font(.caption2)
                .foregroundStyle(palette.tertiaryText)
        }
    }

    private func detailColumn(_ title: String, _ value: String, palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(palette.tertiaryText)
            Text(value.isEmpty ? "—" : value).font(.caption).foregroundStyle(palette.primaryText)
        }
    }

    private var cabinLabel: String {
        switch (details.cabin, language) {
        case ("business", .zh): "商务舱"
        case ("business", .en): "Business"
        case ("first", .zh): "头等舱"
        case ("first", .en): "First"
        case ("premium", .zh): "超级经济舱"
        case ("premium", .en): "Premium"
        case (_, .zh): "经济舱"
        default: "Economy"
        }
    }
}

struct StayCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.stubLanguage) private var language
    let details: StubDetails
    let checkIn: Date

    var body: some View {
        let palette = StubPalette(colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(palette.brand)
                    .frame(width: 42, height: 42)
                    .background(palette.brandSoft, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(language == .zh ? "入住" : "STAY")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(palette.memory)
                    Text((details.hotelName ?? "").isEmpty ? (language == .zh ? "酒店" : "Hotel") : details.hotelName!)
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                }
                Spacer()
                if let checkOut = details.checkOutOn {
                    Text(nightCount(checkOut))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.brandOnSoft)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(palette.brandSoft, in: Capsule())
                }
            }
            if let address = details.hotelAddress, !address.isEmpty {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }
            Divider().overlay(palette.border)
            HStack {
                stayDate(language == .zh ? "入住" : "CHECK-IN", checkIn, palette: palette)
                Spacer()
                if let checkOut = details.checkOutOn {
                    stayDate(language == .zh ? "退房" : "CHECK-OUT", checkOut, palette: palette)
                }
                Spacer()
                detail(language == .zh ? "房型" : "ROOM", roomLabel, palette: palette)
            }
        }
        .stubPaperCard(palette, radius: 15)
    }

    private func stayDate(_ title: String, _ date: Date, palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(palette.tertiaryText)
            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.primaryText)
        }
    }

    private func detail(_ title: String, _ value: String, palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(palette.tertiaryText)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(palette.primaryText)
        }
    }

    private func nightCount(_ checkOut: Date) -> String {
        let count = max(1, Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 1)
        return language == .zh ? "\(count) 晚" : "\(count) nights"
    }

    private var roomLabel: String {
        switch (details.roomType ?? "standard", language) {
        case ("view", .zh): "景观房"
        case ("view", .en): "View"
        case ("suite", .zh): "套房"
        case ("suite", .en): "Suite"
        case ("villa", .zh): "别墅"
        case ("villa", .en): "Villa"
        case ("other", .zh): "其他"
        case ("other", .en): "Other"
        case (_, .zh): "标准房"
        default: "Standard"
        }
    }
}

struct PerformanceCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.stubLanguage) private var language
    let details: StubDetails
    let date: Date

    var body: some View {
        let palette = StubPalette(colorScheme)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "music.mic")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(palette.brand)
                    .frame(width: 42, height: 42)
                    .background(palette.brandSoft, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusLabel)
                        .font(.caption2.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(palette.memory)
                    Text((details.performanceTitle ?? "").isEmpty ? (language == .zh ? "现场演出" : "Live show") : details.performanceTitle!)
                        .font(.system(size: 21, weight: .semibold, design: .serif))
                        .foregroundStyle(palette.primaryText)
                }
            }
            if let venue = details.venue, !venue.isEmpty {
                Label(venue, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }
            HStack(spacing: 12) {
                Label(StubDateFormatter.short(date, language: language), systemImage: "calendar")
                if !details.seat.isEmpty {
                    Label(details.seat, systemImage: "ticket")
                }
            }
            .font(.caption)
            .foregroundStyle(palette.secondaryText)
            if let lineup = details.lineup, !lineup.isEmpty {
                FlowLayout(spacing: 7) {
                    ForEach(lineup, id: \.self) { TagChip(title: $0) }
                }
            }
        }
        .stubPaperCard(palette, radius: 15)
    }

    private var statusLabel: String {
        if details.attendanceStatus == "upcoming" {
            return language == .zh ? "待看的现场" : "UPCOMING"
        }
        return language == .zh ? "看过的现场" : "ATTENDED"
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let palette = StubPalette(colorScheme)
        configuration.label
            .font(.headline)
            .foregroundStyle(Color(hex: 0xFFF8F0))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(configuration.isPressed ? palette.brandPressed : palette.brand, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
