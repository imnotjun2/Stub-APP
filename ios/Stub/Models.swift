import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case zh
    case en

    var id: String { rawValue }
    var localeIdentifier: String { self == .zh ? "zh-Hans" : "en" }
    var shortLabel: String { self == .zh ? "中文" : "EN" }
}

enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum StubCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case movie
    case travel
    case stay
    case performance
    case exhibition
    case food
    case shopping
    case other

    var id: String { rawValue }

    func label(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.movie, .zh): "电影"
        case (.movie, .en): "Movie"
        case (.travel, .zh): "旅行"
        case (.travel, .en): "Travel"
        case (.stay, .zh): "酒店"
        case (.stay, .en): "Stay"
        case (.performance, .zh): "演出"
        case (.performance, .en): "Live"
        case (.exhibition, .zh): "展览"
        case (.exhibition, .en): "Exhibition"
        case (.food, .zh): "餐饮"
        case (.food, .en): "Food"
        case (.shopping, .zh): "购物"
        case (.shopping, .en): "Shopping"
        case (.other, .zh): "其他"
        case (.other, .en): "Other"
        }
    }

    var symbol: String {
        switch self {
        case .movie: "film"
        case .travel: "airplane"
        case .stay: "bed.double"
        case .performance: "music.mic"
        case .exhibition: "building.columns"
        case .food: "fork.knife"
        case .shopping: "bag"
        case .other: "square.grid.2x2"
        }
    }
}

enum TravelSubtype: String, CaseIterable, Identifiable, Codable, Hashable {
    case flight
    case train
    case unknown

    var id: String { rawValue }

    func label(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.flight, .zh): "机票"
        case (.flight, .en): "Flight"
        case (.train, .zh): "火车票"
        case (.train, .en): "Train"
        case (.unknown, .zh): "待确认"
        case (.unknown, .en): "Unconfirmed"
        }
    }
}

enum DetailKind: String, Codable, Hashable {
    case movie
    case flight
    case train
    case stay
    case performance
    case generic
}

enum StubTemplate: String, CaseIterable, Identifiable, Hashable {
    case movie
    case flight
    case train
    case stay
    case performance
    case exhibition
    case food
    case shopping
    case other

    var id: String { rawValue }

    func label(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.movie, .zh): "电影"
        case (.movie, .en): "Movie"
        case (.flight, .zh): "航班"
        case (.flight, .en): "Flight"
        case (.train, .zh): "火车"
        case (.train, .en): "Train"
        case (.stay, .zh): "酒店"
        case (.stay, .en): "Stay"
        case (.performance, .zh): "演出"
        case (.performance, .en): "Live"
        case (.exhibition, .zh): "展览"
        case (.exhibition, .en): "Exhibition"
        case (.food, .zh): "餐饮"
        case (.food, .en): "Food"
        case (.shopping, .zh): "购物"
        case (.shopping, .en): "Shopping"
        case (.other, .zh): "其他"
        case (.other, .en): "Other"
        }
    }

    var symbol: String {
        switch self {
        case .movie: "film"
        case .flight: "airplane.departure"
        case .train: "tram"
        case .stay: "bed.double"
        case .performance: "music.mic"
        case .exhibition: "building.columns"
        case .food: "fork.knife"
        case .shopping: "bag"
        case .other: "square.grid.2x2"
        }
    }

    var category: StubCategory {
        switch self {
        case .movie: .movie
        case .flight, .train: .travel
        case .stay: .stay
        case .performance: .performance
        case .exhibition: .exhibition
        case .food: .food
        case .shopping: .shopping
        case .other: .other
        }
    }

    var subtype: TravelSubtype {
        switch self {
        case .flight: .flight
        case .train: .train
        default: .unknown
        }
    }

    var detailKind: DetailKind {
        switch self {
        case .movie: .movie
        case .flight: .flight
        case .train: .train
        case .stay: .stay
        case .performance: .performance
        default: .generic
        }
    }

    init(category: StubCategory, subtype: TravelSubtype?) {
        switch category {
        case .movie: self = .movie
        case .travel: self = subtype == .train ? .train : .flight
        case .stay: self = .stay
        case .performance: self = .performance
        case .exhibition: self = .exhibition
        case .food: self = .food
        case .shopping: self = .shopping
        case .other: self = .other
        }
    }
}

enum MediaLocation: String, Codable, Hashable {
    case bundled
    case stored
}

struct MediaReference: Codable, Hashable, Identifiable {
    var id: UUID
    var location: MediaLocation
    var value: String

    static func bundled(_ name: String, id: UUID = UUID()) -> MediaReference {
        MediaReference(id: id, location: .bundled, value: name)
    }
}

struct StubDetails: Codable, Hashable {
    var kind: DetailKind = .generic
    var filmTitle = ""
    var cinema = ""
    var hall = ""
    var seat = ""
    var formatIDs: [String] = []
    var airline = ""
    var airlineCode = ""
    var flightNumber = ""
    var aircraft = ""
    var cabin = "economy"
    var departure = ""
    var arrival = ""
    var departureTime = ""
    var arrivalTime = ""
    var trainOperator = ""
    var trainNumber = ""
    var seatClass = "second"
    var coach = ""
    var location = ""
    // Optional additions keep archives created by earlier builds decodable.
    var hotelName: String? = nil
    var hotelAddress: String? = nil
    var hotelBrand: String? = nil
    var roomType: String? = nil
    var bookingChannel: String? = nil
    var checkOutOn: Date? = nil
    var performanceTitle: String? = nil
    var venue: String? = nil
    var lineup: [String]? = nil
    var performanceType: String? = nil
    var attendanceStatus: String? = nil

    init(
        kind: DetailKind = .generic,
        filmTitle: String = "",
        cinema: String = "",
        hall: String = "",
        seat: String = "",
        formatIDs: [String] = [],
        airline: String = "",
        airlineCode: String = "",
        flightNumber: String = "",
        aircraft: String = "",
        cabin: String = "economy",
        departure: String = "",
        arrival: String = "",
        departureTime: String = "",
        arrivalTime: String = "",
        trainOperator: String = "",
        trainNumber: String = "",
        seatClass: String = "second",
        coach: String = "",
        location: String = "",
        hotelName: String? = nil,
        hotelAddress: String? = nil,
        hotelBrand: String? = nil,
        roomType: String? = nil,
        bookingChannel: String? = nil,
        checkOutOn: Date? = nil,
        performanceTitle: String? = nil,
        venue: String? = nil,
        lineup: [String]? = nil,
        performanceType: String? = nil,
        attendanceStatus: String? = nil
    ) {
        self.kind = kind
        self.filmTitle = filmTitle
        self.cinema = cinema
        self.hall = hall
        self.seat = seat
        self.formatIDs = formatIDs
        self.airline = airline
        self.airlineCode = airlineCode
        self.flightNumber = flightNumber
        self.aircraft = aircraft
        self.cabin = cabin
        self.departure = departure
        self.arrival = arrival
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.trainOperator = trainOperator
        self.trainNumber = trainNumber
        self.seatClass = seatClass
        self.coach = coach
        self.location = location
        self.hotelName = hotelName
        self.hotelAddress = hotelAddress
        self.hotelBrand = hotelBrand
        self.roomType = roomType
        self.bookingChannel = bookingChannel
        self.checkOutOn = checkOutOn
        self.performanceTitle = performanceTitle
        self.venue = venue
        self.lineup = lineup
        self.performanceType = performanceType
        self.attendanceStatus = attendanceStatus
    }

    enum CodingKeys: String, CodingKey {
        case kind, filmTitle, cinema, hall, seat, formatIDs, airline, airlineCode
        case flightNumber, aircraft, cabin, departure, arrival, departureTime, arrivalTime
        case trainOperator, trainNumber, seatClass, coach, location
        case hotelName, hotelAddress, hotelBrand, roomType, bookingChannel, checkOutOn
        case performanceTitle, venue, lineup, performanceType, attendanceStatus
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decodeIfPresent(DetailKind.self, forKey: .kind) ?? .generic
        filmTitle = try values.decodeIfPresent(String.self, forKey: .filmTitle) ?? ""
        cinema = try values.decodeIfPresent(String.self, forKey: .cinema) ?? ""
        hall = try values.decodeIfPresent(String.self, forKey: .hall) ?? ""
        seat = try values.decodeIfPresent(String.self, forKey: .seat) ?? ""
        formatIDs = try values.decodeIfPresent([String].self, forKey: .formatIDs) ?? []
        airline = try values.decodeIfPresent(String.self, forKey: .airline) ?? ""
        airlineCode = try values.decodeIfPresent(String.self, forKey: .airlineCode) ?? ""
        flightNumber = try values.decodeIfPresent(String.self, forKey: .flightNumber) ?? ""
        aircraft = try values.decodeIfPresent(String.self, forKey: .aircraft) ?? ""
        cabin = try values.decodeIfPresent(String.self, forKey: .cabin) ?? "economy"
        departure = try values.decodeIfPresent(String.self, forKey: .departure) ?? ""
        arrival = try values.decodeIfPresent(String.self, forKey: .arrival) ?? ""
        departureTime = try values.decodeIfPresent(String.self, forKey: .departureTime) ?? ""
        arrivalTime = try values.decodeIfPresent(String.self, forKey: .arrivalTime) ?? ""
        trainOperator = try values.decodeIfPresent(String.self, forKey: .trainOperator) ?? ""
        trainNumber = try values.decodeIfPresent(String.self, forKey: .trainNumber) ?? ""
        seatClass = try values.decodeIfPresent(String.self, forKey: .seatClass) ?? "second"
        coach = try values.decodeIfPresent(String.self, forKey: .coach) ?? ""
        location = try values.decodeIfPresent(String.self, forKey: .location) ?? ""
        hotelName = try values.decodeIfPresent(String.self, forKey: .hotelName)
        hotelAddress = try values.decodeIfPresent(String.self, forKey: .hotelAddress)
        hotelBrand = try values.decodeIfPresent(String.self, forKey: .hotelBrand)
        roomType = try values.decodeIfPresent(String.self, forKey: .roomType)
        bookingChannel = try values.decodeIfPresent(String.self, forKey: .bookingChannel)
        checkOutOn = try values.decodeIfPresent(Date.self, forKey: .checkOutOn)
        performanceTitle = try values.decodeIfPresent(String.self, forKey: .performanceTitle)
        venue = try values.decodeIfPresent(String.self, forKey: .venue)
        lineup = try values.decodeIfPresent([String].self, forKey: .lineup)
        performanceType = try values.decodeIfPresent(String.self, forKey: .performanceType)
        attendanceStatus = try values.decodeIfPresent(String.self, forKey: .attendanceStatus)
    }
}

struct StubRecord: Codable, Hashable, Identifiable {
    var schemaVersion = 1
    var id: UUID
    var source: Source
    var title: String
    var titleEN: String? = nil
    var occurredOn: Date
    var category: StubCategory
    var subtype: TravelSubtype? = nil
    var note: String
    var noteEN: String? = nil
    var tags: [String]
    var primaryMedia: MediaReference
    var attachments: [MediaReference]
    var posterMedia: MediaReference? = nil
    var details: StubDetails
    var createdAt: Date
    var updatedAt: Date

    enum Source: String, Codable, Hashable {
        case user
        case sample
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        language == .en ? (titleEN ?? title) : title
    }

    func localizedNote(_ language: AppLanguage) -> String {
        language == .en ? (noteEN ?? note) : note
    }

    var wallCover: MediaReference {
        posterMedia ?? attachments.first ?? primaryMedia
    }
}

struct TripBook: Codable, Hashable, Identifiable {
    var id: UUID
    var source: StubRecord.Source
    var title: String
    var titleEN: String? = nil
    var startDate: Date
    var endDate: Date
    var route: String
    var routeEN: String? = nil
    var note: String

    func localizedTitle(_ language: AppLanguage) -> String {
        language == .en ? (titleEN ?? title) : title
    }

    func localizedRoute(_ language: AppLanguage) -> String {
        language == .en ? (routeEN ?? route) : route
    }
}

struct TripPlacement: Codable, Hashable, Identifiable {
    var id: UUID
    var tripID: UUID
    var stubID: UUID
    var order: Int
    var day: Int
    var caption: String
    var rotation: Double
    var scale: Double
}

struct PersistedArchive: Codable {
    var records: [StubRecord] = []
    var trips: [TripBook] = []
    var placements: [TripPlacement] = []
}

struct StubDraft {
    var editingID: UUID?
    var title = ""
    var occurredOn = Date()
    var category: StubCategory = .other
    var subtype: TravelSubtype = .unknown
    var note = ""
    var tags: [String] = []
    var existingPrimary: MediaReference?
    var primaryData: Data?
    var existingAttachments: [MediaReference] = []
    var attachmentData: [Data] = []
    var existingPoster: MediaReference?
    var posterData: Data?
    var useSuggestedPoster = true
    var details = StubDetails()
    var tripID: UUID?

    init() {}

    init(record: StubRecord, tripID: UUID?) {
        editingID = record.id
        title = record.title
        occurredOn = record.occurredOn
        category = record.category
        subtype = record.subtype ?? .unknown
        note = record.note
        tags = record.tags
        existingPrimary = record.primaryMedia
        existingAttachments = record.attachments
        existingPoster = record.posterMedia
        details = record.details
        self.tripID = tripID
    }

    var template: StubTemplate {
        get { StubTemplate(category: category, subtype: subtype) }
        set {
            category = newValue.category
            subtype = newValue.subtype
            details.kind = newValue.detailKind
            if newValue == .stay, details.checkOutOn == nil {
                details.checkOutOn = Calendar.current.date(byAdding: .day, value: 1, to: occurredOn)
            }
            if newValue == .performance, details.attendanceStatus == nil {
                details.attendanceStatus = "attended"
            }
        }
    }

    var resolvedTitle: String {
        let explicit = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty { return explicit }
        switch template {
        case .flight:
            let flight = details.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !flight.isEmpty { return flight.uppercased() }
            return [details.departure, details.arrival].filter { !$0.isEmpty }.joined(separator: " → ")
        case .train:
            let train = details.trainNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !train.isEmpty { return train.uppercased() }
            return [details.departure, details.arrival].filter { !$0.isEmpty }.joined(separator: " → ")
        case .stay:
            return (details.hotelName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        case .performance:
            return (details.performanceTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return explicit
        }
    }

    var canSave: Bool {
        !resolvedTitle.isEmpty &&
        (existingPrimary != nil || primaryData != nil)
    }
}

enum SuggestedTag {
    enum Group: String, CaseIterable, Identifiable {
        case company
        case moment
        case feeling

        var id: String { rawValue }

        func label(_ language: AppLanguage) -> String {
            switch (self, language) {
            case (.company, .zh): "同行"
            case (.company, .en): "WITH"
            case (.moment, .zh): "那一刻"
            case (.moment, .en): "MOMENT"
            case (.feeling, .zh): "感受"
            case (.feeling, .en): "FEELING"
            }
        }
    }

    struct Definition: Identifiable, Hashable {
        let id: String
        let group: Group
        let zh: String
        let en: String
        let symbol: String
        let categories: Set<StubCategory>
    }

    private static let everyCategory = Set(StubCategory.allCases)

    static let all: [Definition] = [
        Definition(id: "tag.with-friends", group: .company, zh: "和朋友", en: "Friends", symbol: "person.2", categories: everyCategory),
        Definition(id: "tag.with-family", group: .company, zh: "和家人", en: "Family", symbol: "house", categories: everyCategory),
        Definition(id: "tag.solo-trip", group: .company, zh: "一个人", en: "Solo", symbol: "person", categories: everyCategory),
        Definition(id: "tag.premiere", group: .moment, zh: "首映", en: "Premiere", symbol: "sparkles", categories: [.movie]),
        Definition(id: "tag.rainy-day", group: .moment, zh: "雨天", en: "Rainy day", symbol: "cloud.rain", categories: [.movie, .travel, .stay, .performance, .exhibition, .food]),
        Definition(id: "tag.celebration", group: .moment, zh: "庆祝", en: "Celebration", symbol: "party.popper", categories: everyCategory),
        Definition(id: "tag.first-time", group: .moment, zh: "第一次", en: "First time", symbol: "1.circle", categories: everyCategory),
        Definition(id: "tag.rewatch", group: .feeling, zh: "想再来一次", en: "Do it again", symbol: "arrow.clockwise", categories: [.movie, .travel, .stay, .performance, .exhibition, .food]),
        Definition(id: "tag.delicious", group: .feeling, zh: "太好吃了", en: "Delicious", symbol: "heart", categories: [.food]),
        Definition(id: "tag.moved", group: .feeling, zh: "很感动", en: "Moved", symbol: "heart.fill", categories: [.movie, .travel, .performance, .exhibition, .other]),
        Definition(id: "tag.unforgettable", group: .feeling, zh: "忘不了", en: "Unforgettable", symbol: "bookmark.fill", categories: everyCategory)
    ]

    static func definitions(in group: Group, category: StubCategory) -> [Definition] {
        all.filter { $0.group == group && $0.categories.contains(category) }
    }

    static func isApplicable(_ id: String, to category: StubCategory) -> Bool {
        all.first(where: { $0.id == id })?.categories.contains(category) ?? true
    }

    static func label(_ id: String, language: AppLanguage) -> String {
        guard let tag = all.first(where: { $0.id == id }) else { return id }
        return language == .zh ? tag.zh : tag.en
    }

    static func symbol(_ id: String) -> String {
        all.first(where: { $0.id == id })?.symbol ?? "tag"
    }
}

enum MovieFormat {
    static let all = ["imax", "dolby-cinema", "cinity", "4dx"]

    static func label(_ id: String) -> String {
        switch id {
        case "dolby-cinema": "Dolby Cinema"
        case "cinity": "CINITY"
        case "4dx": "4DX"
        default: "IMAX"
        }
    }
}

enum StubFixtures {
    static let movieID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let flightID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let foodID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    static let trainID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
    static let stayID = UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
    static let performanceID = UUID(uuidString: "10000000-0000-0000-0000-000000000006")!
    static let tripID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(
            timeZone: TimeZone(identifier: "Asia/Shanghai"),
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    static let records: [StubRecord] = [
        StubRecord(
            id: movieID,
            source: .sample,
            title: "名侦探柯南：百万美元的五棱星",
            titleEN: "Detective Conan: The Million-dollar Pentagram",
            occurredOn: date(2026, 8, 10),
            category: .movie,
            note: "和你一起看柯南首映的夜晚，散场时外面还在下雨。",
            noteEN: "The premiere ended while the rain was still falling outside.",
            tags: ["tag.premiere", "tag.rainy-day"],
            primaryMedia: .bundled("movie-ticket.png"),
            attachments: [],
            posterMedia: .bundled("movie-poster.jpg"),
            details: StubDetails(
                kind: .movie,
                filmTitle: "名侦探柯南：百万美元的五棱星",
                cinema: "CGV影城 合生汇店",
                hall: "6号厅",
                seat: "E07",
                formatIDs: ["imax"]
            ),
            createdAt: date(2026, 8, 10),
            updatedAt: date(2026, 8, 10)
        ),
        StubRecord(
            id: flightID,
            source: .sample,
            title: "上海虹桥 → 札幌新千岁",
            titleEN: "Shanghai Hongqiao → Sapporo New Chitose",
            occurredOn: date(2026, 8, 3),
            category: .travel,
            subtype: .flight,
            note: "夏天从一张登机牌开始。",
            noteEN: "Summer began with a boarding pass.",
            tags: ["tag.solo-trip"],
            primaryMedia: .bundled("boarding-pass.png"),
            attachments: [],
            details: StubDetails(
                kind: .flight,
                seat: "12A",
                airline: "中国东方航空",
                airlineCode: "MU",
                flightNumber: "MU5237",
                aircraft: "Airbus A320neo",
                cabin: "economy",
                departure: "SHA",
                arrival: "CTS",
                departureTime: "08:25",
                arrivalTime: "13:05"
            ),
            createdAt: date(2026, 8, 3),
            updatedAt: date(2026, 8, 3)
        ),
        StubRecord(
            id: foodID,
            source: .sample,
            title: "札幌雨夜的味噌拉面",
            titleEN: "Miso ramen on a rainy Sapporo night",
            occurredOn: date(2026, 8, 6),
            category: .food,
            note: "窗外是雨，汤里是很长的一天。",
            noteEN: "Rain outside, and a very long day held in the broth.",
            tags: ["tag.delicious", "tag.rainy-day"],
            primaryMedia: .bundled("ramen.jpg"),
            attachments: [],
            details: StubDetails(kind: .generic, location: "札幌 · 狸小路"),
            createdAt: date(2026, 8, 6),
            updatedAt: date(2026, 8, 6)
        ),
        StubRecord(
            id: trainID,
            source: .sample,
            title: "杭州东 → 苏州",
            titleEN: "Hangzhoudong → Suzhou",
            occurredOn: date(2026, 8, 1),
            category: .travel,
            subtype: .train,
            note: "去见朋友，也路过西湖。",
            noteEN: "A train to see a friend, passing the lake on the way.",
            tags: ["tag.with-friends"],
            primaryMedia: .bundled("train-ticket.png"),
            attachments: [],
            details: StubDetails(
                kind: .train,
                seat: "08A",
                departure: "杭州东",
                arrival: "苏州",
                departureTime: "10:15",
                trainOperator: "中国铁路",
                trainNumber: "G7501",
                seatClass: "second",
                coach: "02"
            ),
            createdAt: date(2026, 8, 1),
            updatedAt: date(2026, 8, 1)
        ),
        StubRecord(
            id: stayID,
            source: .sample,
            title: "札幌公园凯悦酒店",
            titleEN: "Park Hyatt Sapporo",
            occurredOn: date(2026, 8, 3),
            category: .stay,
            note: "清晨从窗边看见城市慢慢醒来。",
            noteEN: "The city slowly woke outside the window.",
            tags: ["tag.solo-trip", "tag.first-time"],
            primaryMedia: .bundled("boarding-pass.png"),
            attachments: [.bundled("trip-map.png")],
            details: StubDetails(
                kind: .stay,
                location: "札幌",
                hotelName: "札幌公园凯悦酒店",
                hotelAddress: "北海道札幌市",
                hotelBrand: "Hyatt",
                roomType: "view",
                bookingChannel: "direct",
                checkOutOn: date(2026, 8, 7)
            ),
            createdAt: date(2026, 8, 3),
            updatedAt: date(2026, 8, 3)
        ),
        StubRecord(
            id: performanceID,
            source: .sample,
            title: "夏夜音乐祭",
            titleEN: "Summer Night Live",
            occurredOn: date(2026, 8, 8, 19),
            category: .performance,
            note: "最后一首歌结束时，所有人都没有立刻离开。",
            noteEN: "No one left when the final song ended.",
            tags: ["tag.with-friends", "tag.moved"],
            primaryMedia: .bundled("movie-ticket.png"),
            attachments: [],
            posterMedia: .bundled("movie-poster.jpg"),
            details: StubDetails(
                kind: .performance,
                seat: "A区 12排",
                location: "札幌文化艺术剧场",
                performanceTitle: "夏夜音乐祭",
                venue: "札幌文化艺术剧场",
                lineup: ["青叶市子", "折坂悠太"],
                performanceType: "concert",
                attendanceStatus: "attended"
            ),
            createdAt: date(2026, 8, 8),
            updatedAt: date(2026, 8, 8)
        )
    ]

    static let trip = TripBook(
        id: tripID,
        source: .sample,
        title: "札幌 · 2026 夏",
        titleEN: "Sapporo · Summer 2026",
        startDate: date(2026, 8, 3),
        endDate: date(2026, 8, 10),
        route: "上海—札幌",
        routeEN: "Shanghai—Sapporo",
        note: "雨、拉面和几张舍不得丢掉的纸。"
    )

    static let placements = [
        TripPlacement(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            tripID: tripID,
            stubID: flightID,
            order: 1,
            day: 1,
            caption: "抵达",
            rotation: -0.5,
            scale: 1
        ),
        TripPlacement(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
            tripID: tripID,
            stubID: foodID,
            order: 2,
            day: 4,
            caption: "雨夜",
            rotation: 0.8,
            scale: 1
        ),
        TripPlacement(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
            tripID: tripID,
            stubID: stayID,
            order: 3,
            day: 1,
            caption: "住下",
            rotation: -0.3,
            scale: 1
        ),
        TripPlacement(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000004")!,
            tripID: tripID,
            stubID: performanceID,
            order: 4,
            day: 6,
            caption: "现场",
            rotation: 0.4,
            scale: 1
        )
    ]
}
