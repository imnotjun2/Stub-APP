import PhotosUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

private enum EditorFocus: Hashable {
    case title
    case note
}

struct StubEditorView: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme

    let destination: EditorDestination

    @State private var draft = StubDraft()
    @State private var hasLoaded = false
    @State private var primaryItem: PhotosPickerItem?
    @State private var attachmentItems: [PhotosPickerItem] = []
    @State private var posterItem: PhotosPickerItem?
    @State private var isLoadingMedia = false
    @State private var saveError: String?
    @State private var showCamera = false
    @State private var showMovieSearch = false
    @State private var showCinemaSearch = false
    @State private var showPlaceSearch = false
    @State private var placePurpose: PlacePurpose = .generic
    @State private var lineupEntry = ""
    @FocusState private var focusedField: EditorFocus?

    var body: some View {
        let palette = StubPalette(colorScheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    templateSection(palette)
                    if ![StubTemplate.flight, .train, .stay, .performance].contains(draft.template) {
                        basicsSection(palette)
                    }
                    typeSpecificSection(palette)
                    artifactSection(palette)
                    tagsSection(palette)
                    memoriesSection(palette)
                    noteSection(palette)

                    if let saveError {
                        Label(saveError, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button { save() } label: {
                        HStack {
                            if isLoadingMedia { ProgressView().tint(.white) }
                            Text(draft.editingID == nil
                                 ? (language == .zh ? "保存这张存根" : "Save this stub")
                                 : (language == .zh ? "保存更改" : "Save changes"))
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!draft.canSave || isLoadingMedia)
                    .opacity((draft.canSave && !isLoadingMedia) ? 1 : 0.55)
                    .accessibilityIdentifier("saveStubButton")
                    .padding(.top, 2)
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("stubEditorScreen")
            .stubScreenBackground(palette)
            .navigationTitle(draft.editingID == nil
                             ? (language == .zh ? "留下一次经历" : "Add an Experience")
                             : (language == .zh ? "编辑存根" : "Edit Stub"))
            .stubInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language == .zh ? "取消" : "Cancel") { dismiss() }
                }
            }
        }
        .task { loadExistingIfNeeded() }
        .onChange(of: primaryItem) { _, item in
            guard let item else { return }
            Task { await loadPrimary(item) }
        }
        .onChange(of: attachmentItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadAttachments(items) }
        }
        .onChange(of: posterItem) { _, item in
            guard let item else { return }
            Task { await loadPoster(item) }
        }
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                draft.primaryData = data
            }
            .ignoresSafeArea()
        }
        #endif
        .sheet(isPresented: $showMovieSearch) {
            MovieSearchSheet { movie in
                draft.title = movie.title
                draft.details.filmTitle = movie.title
            }
        }
        .onChange(of: draft.occurredOn) { _, newDate in
            if draft.template == .stay, let checkOut = draft.details.checkOutOn, checkOut < newDate {
                draft.details.checkOutOn = Calendar.current.date(byAdding: .day, value: 1, to: newDate)
            }
        }
        .sheet(isPresented: $showCinemaSearch) {
            PlaceSearchSheet(
                title: language == .zh ? "选择影院" : "Choose Cinema",
                prompt: language == .zh ? "影院名称" : "Cinema name"
            ) { place in
                draft.details.cinema = [place.name, place.subtitle]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            }
        }
        .sheet(isPresented: $showPlaceSearch) {
            PlaceSearchSheet(
                title: placeSearchTitle,
                prompt: placeSearchPrompt
            ) { place in
                let fullName = [place.name, place.subtitle].filter { !$0.isEmpty }.joined(separator: " · ")
                switch placePurpose {
                case .hotel:
                    draft.details.hotelName = place.name
                    draft.details.hotelAddress = place.subtitle
                    draft.details.location = fullName
                case .venue:
                    draft.details.venue = fullName
                    draft.details.location = fullName
                case .generic:
                    draft.details.location = fullName
                }
            }
        }
    }

    private enum PlacePurpose {
        case hotel
        case venue
        case generic
    }

    private var placeSearchTitle: String {
        switch (placePurpose, language) {
        case (.hotel, .zh): "选择酒店"
        case (.hotel, .en): "Choose Hotel"
        case (.venue, .zh): "选择场馆"
        case (.venue, .en): "Choose Venue"
        case (.generic, .zh): "选择地点"
        case (.generic, .en): "Choose Place"
        }
    }

    private var placeSearchPrompt: String {
        switch (placePurpose, language) {
        case (.hotel, .zh): "酒店名称或城市"
        case (.hotel, .en): "Hotel name or city"
        case (.venue, .zh): "剧场、Livehouse 或体育馆"
        case (.venue, .en): "Theatre, livehouse or arena"
        case (.generic, .zh): "场馆、餐厅或商店"
        case (.generic, .en): "Venue, restaurant or shop"
        }
    }

    private func templateSection(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            editorHeader(
                icon: "sparkles.rectangle.stack",
                title: language == .zh ? "这是什么时刻？" : "What kind of moment?",
                subtitle: language == .zh ? "先选择一种事件，只显示它真正需要的信息。" : "Choose an event first; only its useful details will appear.",
                palette: palette
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 9)], spacing: 9) {
                ForEach(StubTemplate.allCases) { template in
                    Button {
                        withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                            draft.template = template
                            draft.tags.removeAll { !SuggestedTag.isApplicable($0, to: draft.category) }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: template.symbol)
                                .font(.system(size: 20, weight: .medium))
                            Text(template.label(language))
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(draft.template == template ? palette.brandOnSoft : palette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background(draft.template == template ? palette.brandSoft : palette.elevated, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(draft.template == template ? palette.brand : palette.border, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("template.\(template.rawValue)")
                }
            }
        }
        .stubPaperCard(palette)
    }

    private func artifactSection(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            editorHeader(
                icon: "ticket",
                title: language == .zh ? "票据或凭证" : "Ticket or proof",
                subtitle: language == .zh ? "票根、订单截图或现场照片都可以，原图始终保留。" : "A ticket, booking screenshot or scene photo all work; the original stays intact.",
                palette: palette
            )

            Group {
                if let data = draft.primaryData {
                    DraftImage(data: data, contentMode: .fit)
                } else if let reference = draft.existingPrimary {
                    StubImage(reference: reference, contentMode: .fit)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 42, weight: .light))
                        Text(language == .zh ? "拍摄或选择一张凭证图片" : "Take or choose a proof image")
                            .font(.subheadline)
                    }
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 190)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 340)
            .background(palette.sunken, in: RoundedRectangle(cornerRadius: 13))
            .clipShape(RoundedRectangle(cornerRadius: 13))

            HStack(spacing: 10) {
                #if canImport(UIKit)
                Button { showCamera = true } label: {
                    Label(language == .zh ? "拍摄" : "Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.bordered)
                .tint(palette.brand)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                #endif

                PhotosPicker(selection: $primaryItem, matching: .images) {
                    Label(language == .zh ? "照片" : "Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.bordered)
                .tint(palette.brand)
                .accessibilityIdentifier("primaryPhotoPicker")
            }
        }
        .stubPaperCard(palette)
    }

    private func basicsSection(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            editorHeader(
                icon: "square.and.pencil",
                title: language == .zh ? "基本信息" : "Basics",
                subtitle: language == .zh ? "名称与日期构成这次经历的身份。" : "Name and date identify this experience.",
                palette: palette
            )
            if draft.category == .movie {
                selectionField(
                    title: language == .zh ? "电影" : "Movie",
                    value: draft.title,
                    placeholder: language == .zh ? "搜索并选择电影" : "Search and choose a movie",
                    icon: "film.stack",
                    palette: palette
                ) { showMovieSearch = true }
            } else if ![StubTemplate.flight, .train, .stay, .performance].contains(draft.template) {
                field(language == .zh ? "标题" : "Title", palette: palette) {
                    TextField(language == .zh ? "例如：深夜场电影票" : "Late-night movie", text: $draft.title)
                        .focused($focusedField, equals: .title)
                        .accessibilityIdentifier("stubTitleField")
                }
            }
            field(language == .zh ? "日期" : "Date", palette: palette) {
                DatePicker("", selection: $draft.occurredOn, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: language.localeIdentifier))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .stubPaperCard(palette)
    }

    @ViewBuilder
    private func typeSpecificSection(_ palette: StubPalette) -> some View {
        switch draft.category {
        case .movie:
            movieSection(palette)
        case .travel:
            travelSection(palette)
        case .stay:
            staySection(palette)
        case .performance:
            performanceSection(palette)
        default:
            genericSection(palette)
        }
    }

    private func movieSection(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            editorHeader(
                icon: "film",
                title: language == .zh ? "电影信息" : "Movie details",
                subtitle: language == .zh ? "选择电影和影院，只补充票面上的个别信息。" : "Choose the movie and cinema, then add ticket details.",
                palette: palette
            )
            selectionField(
                title: language == .zh ? "影院" : "Cinema",
                value: draft.details.cinema,
                placeholder: language == .zh ? "搜索影院" : "Search cinemas",
                icon: "mappin.and.ellipse",
                palette: palette
            ) { showCinemaSearch = true }
            HStack(spacing: 10) {
                field(language == .zh ? "影厅" : "Hall", palette: palette) {
                    TextField(language == .zh ? "6号厅" : "Hall 6", text: $draft.details.hall)
                }
                field(language == .zh ? "座位" : "Seat", palette: palette) {
                    TextField("E07", text: $draft.details.seat)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(language == .zh ? "放映制式" : "Format")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                FlowLayout(spacing: 8) {
                    ForEach(MovieFormat.all, id: \.self) { format in
                        TagChip(title: MovieFormat.label(format), selected: draft.details.formatIDs.contains(format)) {
                            toggle(format, in: &draft.details.formatIDs)
                        }
                    }
                }
            }

            if ArchiveStore.matchesBundledMovie(draft.title) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        StubImage(reference: .bundled("movie-poster.jpg"), contentMode: .fill)
                            .frame(width: 76, height: 112)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 7) {
                            Label(language == .zh ? "本地片名匹配候选" : "Local title match", systemImage: "wand.and.stars")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.brandOnSoft)
                            Text(language == .zh ? "名侦探柯南：百万美元的五棱星" : "Detective Conan: The Million-dollar Pentagram")
                                .font(.subheadline.weight(.semibold))
                            Text(language == .zh
                                 ? "这是内置候选，不是联网自动识别；保存前由你确认。"
                                 : "This is a bundled candidate, not a live lookup; you confirm before saving.")
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                        }
                    }
                    Toggle(language == .zh ? "使用这张海报" : "Use this poster", isOn: $draft.useSuggestedPoster)
                        .tint(palette.brand)
                }
                .padding(12)
                .background(palette.brandSoft.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text(language == .zh
                     ? "暂无可靠海报候选；你可以直接保留票根，或手动上传海报。"
                     : "No reliable poster candidate. Keep the ticket or upload one manually.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            PhotosPicker(selection: $posterItem, matching: .images) {
                Label(language == .zh ? "手动上传海报" : "Upload poster", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(palette.brand)
        }
        .stubPaperCard(palette)
    }

    private func travelSection(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            editorHeader(
                icon: draft.subtype == .flight ? "airplane.departure" : "tram",
                title: draft.subtype == .flight
                    ? (language == .zh ? "这趟航班" : "This flight")
                    : (language == .zh ? "这趟列车" : "This train"),
                subtitle: draft.subtype == .flight
                    ? (language == .zh ? "用航班号和路线辨认它，先保存确定的信息。" : "Identify it by flight number and route; save only confirmed details.")
                    : (language == .zh ? "车次、路线和座位构成这次移动。" : "Train number, route and seat identify the journey."),
                palette: palette
            )

            if draft.subtype == .flight {
                HStack(spacing: 10) {
                    field(language == .zh ? "航班号" : "Flight no.", palette: palette) {
                        TextField("MU5237", text: $draft.details.flightNumber)
                    }
                    field(language == .zh ? "日期" : "Date", palette: palette) {
                        DatePicker("", selection: $draft.occurredOn, displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: language.localeIdentifier))
                    }
                }
                routeFields(palette)
                HStack(spacing: 10) {
                    field(language == .zh ? "起飞" : "Departure", palette: palette) {
                        TextField("08:25", text: $draft.details.departureTime)
                    }
                    field(language == .zh ? "到达" : "Arrival", palette: palette) {
                        TextField("13:05", text: $draft.details.arrivalTime)
                    }
                }
                Picker(language == .zh ? "舱位" : "Cabin", selection: $draft.details.cabin) {
                    Text(language == .zh ? "经济舱" : "Economy").tag("economy")
                    Text(language == .zh ? "超级经济舱" : "Premium").tag("premium")
                    Text(language == .zh ? "商务舱" : "Business").tag("business")
                    Text(language == .zh ? "头等舱" : "First").tag("first")
                }
                field(language == .zh ? "座位" : "Seat", palette: palette) {
                    TextField("12A", text: $draft.details.seat)
                }
                DisclosureGroup(language == .zh ? "补充航司和机型" : "Airline and aircraft") {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            field(language == .zh ? "航司" : "Airline", palette: palette) {
                                TextField(language == .zh ? "中国东方航空" : "China Eastern", text: $draft.details.airline)
                            }
                            field(language == .zh ? "二字码" : "IATA", palette: palette) {
                                TextField("MU", text: $draft.details.airlineCode)
                            }
                        }
                        field(language == .zh ? "机型" : "Aircraft", palette: palette) {
                            TextField("A320neo", text: $draft.details.aircraft)
                        }
                    }
                    .padding(.top, 10)
                }
                .font(.caption)
                .tint(palette.brand)
                FlightCard(details: draft.details)
            } else {
                HStack(spacing: 10) {
                    field(language == .zh ? "运营方" : "Operator", palette: palette) {
                        TextField(language == .zh ? "中国铁路" : "China Railway", text: $draft.details.trainOperator)
                    }
                    field(language == .zh ? "车次" : "Train no.", palette: palette) {
                        TextField("G7501", text: $draft.details.trainNumber)
                    }
                }
                routeFields(palette)
                Picker(language == .zh ? "席别" : "Seat class", selection: $draft.details.seatClass) {
                    Text(language == .zh ? "二等座" : "Second").tag("second")
                    Text(language == .zh ? "一等座" : "First").tag("first")
                    Text(language == .zh ? "商务座" : "Business").tag("business")
                    Text(language == .zh ? "卧铺" : "Sleeper").tag("sleeper")
                }
                HStack(spacing: 10) {
                    field(language == .zh ? "车厢" : "Coach", palette: palette) {
                        TextField("02", text: $draft.details.coach)
                    }
                    field(language == .zh ? "座位" : "Seat", palette: palette) {
                        TextField("08A", text: $draft.details.seat)
                    }
                }
            }

            tripPicker
        }
        .stubPaperCard(palette)
    }

    private func staySection(_ palette: StubPalette) -> some View {
        let checkOutBinding = Binding<Date>(
            get: { draft.details.checkOutOn ?? Calendar.current.date(byAdding: .day, value: 1, to: draft.occurredOn) ?? draft.occurredOn },
            set: { draft.details.checkOutOn = $0 }
        )
        return VStack(alignment: .leading, spacing: 16) {
            editorHeader(
                icon: "bed.double",
                title: language == .zh ? "这次入住" : "This stay",
                subtitle: language == .zh ? "搜索酒店，再补充入住区间与房型。" : "Find the hotel, then add dates and room type.",
                palette: palette
            )
            selectionField(
                title: language == .zh ? "酒店" : "Hotel",
                value: draft.details.hotelName ?? "",
                placeholder: language == .zh ? "搜索酒店名称或城市" : "Search by hotel or city",
                icon: "magnifyingglass",
                palette: palette
            ) {
                placePurpose = .hotel
                showPlaceSearch = true
            }
            HStack(spacing: 10) {
                field(language == .zh ? "入住" : "Check-in", palette: palette) {
                    DatePicker("", selection: $draft.occurredOn, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: language.localeIdentifier))
                }
                field(language == .zh ? "退房" : "Check-out", palette: palette) {
                    DatePicker("", selection: checkOutBinding, in: draft.occurredOn..., displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: language.localeIdentifier))
                }
            }
            field(language == .zh ? "房型" : "Room", palette: palette) {
                Picker("", selection: Binding(
                    get: { draft.details.roomType ?? "standard" },
                    set: { draft.details.roomType = $0 }
                )) {
                    Text(language == .zh ? "标准房" : "Standard").tag("standard")
                    Text(language == .zh ? "景观房" : "View room").tag("view")
                    Text(language == .zh ? "套房" : "Suite").tag("suite")
                    Text(language == .zh ? "别墅" : "Villa").tag("villa")
                    Text(language == .zh ? "其他" : "Other").tag("other")
                }
                .labelsHidden()
            }
            DisclosureGroup(language == .zh ? "预订信息" : "Booking details") {
                HStack(spacing: 10) {
                    field(language == .zh ? "品牌" : "Brand", palette: palette) {
                        TextField("Hyatt", text: optionalBinding(\.hotelBrand))
                    }
                    field(language == .zh ? "渠道" : "Booked via", palette: palette) {
                        TextField(language == .zh ? "官网" : "Direct", text: optionalBinding(\.bookingChannel))
                    }
                }
                .padding(.top, 10)
            }
            .font(.caption)
            .tint(palette.brand)
            tripPicker
        }
        .stubPaperCard(palette)
    }

    private func performanceSection(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            editorHeader(
                icon: "music.mic",
                title: language == .zh ? "这场现场" : "This live show",
                subtitle: language == .zh ? "演出、场馆和阵容是以后找回那晚的入口。" : "Show, venue and lineup bring the night back.",
                palette: palette
            )
            field(language == .zh ? "演出 / 剧目" : "Show", palette: palette) {
                TextField(language == .zh ? "例如：五月天 5525" : "e.g. 5525 Live", text: optionalBinding(\.performanceTitle))
            }
            selectionField(
                title: language == .zh ? "场馆" : "Venue",
                value: draft.details.venue ?? "",
                placeholder: language == .zh ? "搜索剧场、Livehouse 或体育馆" : "Search theatre, livehouse or arena",
                icon: "mappin.and.ellipse",
                palette: palette
            ) {
                placePurpose = .venue
                showPlaceSearch = true
            }
            HStack(spacing: 10) {
                field(language == .zh ? "日期" : "Date", palette: palette) {
                    DatePicker("", selection: $draft.occurredOn, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: language.localeIdentifier))
                }
                field(language == .zh ? "状态" : "Status", palette: palette) {
                    Picker("", selection: Binding(
                        get: { draft.details.attendanceStatus ?? "attended" },
                        set: { draft.details.attendanceStatus = $0 }
                    )) {
                        Text(language == .zh ? "已看" : "Attended").tag("attended")
                        Text(language == .zh ? "待看" : "Upcoming").tag("upcoming")
                    }
                    .labelsHidden()
                }
            }
            field(language == .zh ? "座位" : "Seat", palette: palette) {
                TextField(language == .zh ? "看台 12 区 8 排" : "Section 12, Row 8", text: $draft.details.seat)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text(language == .zh ? "阵容 / 卡司" : "Lineup / cast")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                HStack(spacing: 8) {
                    TextField(language == .zh ? "输入名字" : "Add a name", text: $lineupEntry)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 46)
                        .background(palette.elevated, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(palette.strongBorder, lineWidth: 0.8))
                    Button {
                        let name = lineupEntry.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        var lineup = draft.details.lineup ?? []
                        if !lineup.contains(name) { lineup.append(name) }
                        draft.details.lineup = lineup
                        lineupEntry = ""
                    } label: {
                        Image(systemName: "plus").frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(palette.brand)
                }
                FlowLayout(spacing: 8) {
                    ForEach(draft.details.lineup ?? [], id: \.self) { name in
                        TagChip(title: name, selected: true) {
                            draft.details.lineup?.removeAll { $0 == name }
                        }
                    }
                }
            }
            PhotosPicker(selection: $posterItem, matching: .images) {
                Label(language == .zh ? "添加演出海报" : "Add show poster", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(palette.brand)
        }
        .stubPaperCard(palette)
    }

    private func routeFields(_ palette: StubPalette) -> some View {
        HStack(spacing: 10) {
            field(language == .zh ? "出发" : "From", palette: palette) {
                TextField("SHA", text: $draft.details.departure)
            }
            field(language == .zh ? "到达" : "To", palette: palette) {
                TextField("CTS", text: $draft.details.arrival)
            }
        }
    }

    private func genericSection(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            editorHeader(
                icon: "mappin.and.ellipse",
                title: language == .zh ? "地点" : "Location",
                subtitle: language == .zh ? "从地点库选择，找不到时再手动填写。" : "Choose from places, or enter one if it is missing.",
                palette: palette
            )
            selectionField(
                title: language == .zh ? "地点" : "Location",
                value: draft.details.location,
                placeholder: language == .zh ? "搜索地点" : "Search places",
                icon: "mappin.and.ellipse",
                palette: palette
            ) {
                placePurpose = .generic
                showPlaceSearch = true
            }
            DisclosureGroup(language == .zh ? "找不到？手动填写" : "Can't find it? Enter manually") {
                TextField(language == .zh ? "例如：札幌 · 狸小路" : "Sapporo · Tanukikoji", text: $draft.details.location)
                    .padding(.horizontal, 13)
                    .frame(minHeight: 46)
                    .background(palette.elevated, in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(palette.strongBorder, lineWidth: 0.8))
                    .padding(.top, 8)
            }
            .font(.caption)
            .tint(palette.brand)
        }
        .stubPaperCard(palette)
    }

    private var tripPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(language == .zh ? "收进旅册" : "Trip book")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StubPalette(colorScheme).secondaryText)
            Picker("", selection: $draft.tripID) {
                Text(language == .zh ? "暂不收录" : "Not now").tag(nil as UUID?)
                ForEach(store.trips) { trip in
                    Text(trip.localizedTitle(language)).tag(Optional(trip.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 13)
            .background(StubPalette(colorScheme).elevated, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(StubPalette(colorScheme).strongBorder, lineWidth: 0.8))
        }
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<StubDetails, String?>) -> Binding<String> {
        Binding(
            get: { draft.details[keyPath: keyPath] ?? "" },
            set: { draft.details[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func tagsSection(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            editorHeader(
                icon: "tag",
                title: language == .zh ? "记忆线索" : "Memory threads",
                subtitle: language == .zh ? "选择真正有助于以后想起这一天的线索。" : "Choose cues that will help you remember the day.",
                palette: palette
            )
            ForEach(SuggestedTag.Group.allCases) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.label(language))
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.9)
                        .foregroundStyle(palette.tertiaryText)
                    FlowLayout(spacing: 8) {
                        ForEach(SuggestedTag.definitions(in: group, category: draft.category)) { tag in
                            TagChip(title: language == .zh ? tag.zh : tag.en, selected: draft.tags.contains(tag.id)) {
                                toggle(tag.id, in: &draft.tags)
                            }
                        }
                    }
                }
            }
        }
        .stubPaperCard(palette)
    }

    private func memoriesSection(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            editorHeader(
                icon: "photo.on.rectangle.angled",
                title: language == .zh ? "当时的照片" : "Memory photos",
                subtitle: language == .zh ? "最多 6 张，例如食物、同行的人或街景。" : "Up to 6 photos: food, companions or the street outside.",
                palette: palette
            )
            if !draft.existingAttachments.isEmpty || !draft.attachmentData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(draft.existingAttachments) { reference in
                            StubImage(reference: reference, contentMode: .fill)
                                .frame(width: 112, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                        }
                        ForEach(Array(draft.attachmentData.enumerated()), id: \.offset) { _, data in
                            DraftImage(data: data, contentMode: .fill)
                                .frame(width: 112, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                        }
                    }
                }
            }
            PhotosPicker(
                selection: $attachmentItems,
                maxSelectionCount: max(1, 6 - draft.existingAttachments.count - draft.attachmentData.count),
                matching: .images
            ) {
                Label(language == .zh ? "添加生活照片" : "Add memory photos", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.bordered)
            .tint(palette.brand)
            .disabled(draft.existingAttachments.count + draft.attachmentData.count >= 6)
            .accessibilityIdentifier("memoryPhotosPicker")
        }
        .stubPaperCard(palette)
    }

    private func noteSection(_ palette: StubPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            editorHeader(
                icon: "quote.opening",
                title: language == .zh ? "想记住的一句话" : "A line to remember",
                subtitle: language == .zh ? "票面之外，那天还发生了什么？" : "What happened beyond the ticket?",
                palette: palette
            )
            TextField(language == .zh ? "那天发生了什么？" : "What happened that day?", text: $draft.note, axis: .vertical)
                .lineLimit(3...7)
                .focused($focusedField, equals: .note)
                .padding(13)
                .background(palette.elevated, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(palette.strongBorder, lineWidth: 0.8))
        }
        .stubPaperCard(palette)
    }

    private func editorHeader(
        icon: String,
        title: String,
        subtitle: String,
        palette: StubPalette
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon).foregroundStyle(palette.brand)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(palette.primaryText)
                Text(subtitle).font(.caption).foregroundStyle(palette.secondaryText)
            }
        }
    }

    private func field<Content: View>(
        _ title: String,
        palette: StubPalette,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(palette.secondaryText)
            content()
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .background(palette.elevated, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(palette.strongBorder, lineWidth: 0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionField(
        title: String,
        value: String,
        placeholder: String,
        icon: String,
        palette: StubPalette,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(palette.secondaryText)
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: icon).foregroundStyle(palette.brand)
                    Text(value.isEmpty ? placeholder : value)
                        .foregroundStyle(value.isEmpty ? palette.tertiaryText : palette.primaryText)
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.tertiaryText)
                }
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(palette.elevated, in: RoundedRectangle(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(palette.strongBorder, lineWidth: 0.8)
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func loadExistingIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        if case .edit(let id) = destination, let record = store.record(id: id), record.source == .user {
            draft = StubDraft(record: record, tripID: store.placement(for: id)?.tripID)
        }
        #if DEBUG
        if case .add = destination,
           let rawTemplate = ProcessInfo.processInfo.environment["STUB_QA_TEMPLATE"],
           let template = StubTemplate(rawValue: rawTemplate) {
            draft.template = template
        }
        #endif
    }

    private func loadPrimary(_ item: PhotosPickerItem) async {
        isLoadingMedia = true
        defer { isLoadingMedia = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            draft.primaryData = ImageCodec.prepareForStorage(data)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func loadAttachments(_ items: [PhotosPickerItem]) async {
        isLoadingMedia = true
        defer {
            isLoadingMedia = false
            attachmentItems = []
        }
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    draft.attachmentData.append(ImageCodec.prepareForStorage(data, maxDimension: 2000))
                }
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    private func loadPoster(_ item: PhotosPickerItem) async {
        isLoadingMedia = true
        defer { isLoadingMedia = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            draft.posterData = ImageCodec.prepareForStorage(data, maxDimension: 1800)
            draft.useSuggestedPoster = false
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func toggle(_ value: String, in values: inout [String]) {
        if values.contains(value) {
            values.removeAll { $0 == value }
        } else {
            values.append(value)
        }
    }

    private func save() {
        focusedField = nil
        saveError = nil
        do {
            _ = try store.save(draft)
            dismiss()
        } catch {
            saveError = language == .zh ? "请先填写标题并选择票据图片。" : error.localizedDescription
        }
    }
}

#if !STATIC_CHECK
#Preview("New Stub") {
    StubEditorView(destination: .add)
        .environmentObject(ArchiveStore(preview: PersistedArchive()))
        .environment(\.stubLanguage, .zh)
}
#endif
