import Foundation
import Combine

@MainActor
final class ArchiveStore: ObservableObject {
    @Published private(set) var userRecords: [StubRecord]
    @Published private(set) var userTrips: [TripBook]
    @Published private(set) var userPlacements: [TripPlacement]
    @Published private(set) var lastError: String?

    private let archiveURL: URL
    private let mediaDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    var hasUserContent: Bool {
        !userRecords.isEmpty || !userTrips.isEmpty
    }

    var records: [StubRecord] {
        (hasUserContent ? userRecords : StubFixtures.records)
            .sorted { $0.occurredOn > $1.occurredOn }
    }

    /// The sample book stays browsable without mixing demo records into a user's timeline.
    var browsableTrips: [TripBook] {
        [StubFixtures.trip] + userTrips.filter { $0.id != StubFixtures.tripID }
    }

    var trips: [TripBook] {
        hasUserContent ? userTrips : [StubFixtures.trip]
    }

    var placements: [TripPlacement] {
        hasUserContent ? userPlacements : StubFixtures.placements
    }

    init(preview: PersistedArchive? = nil, storageRoot: URL? = nil) {
        let fileManager = FileManager.default
        let root = storageRoot ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Stub", isDirectory: true)
        archiveURL = root.appendingPathComponent("archive-v1.json")
        mediaDirectory = root.appendingPathComponent("Media", isDirectory: true)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        if let preview {
            userRecords = preview.records
            userTrips = preview.trips
            userPlacements = preview.placements
            return
        }

        do {
            try fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
            let data = try Data(contentsOf: archiveURL)
            let archive = try decoder.decode(PersistedArchive.self, from: data)
            userRecords = archive.records
            userTrips = archive.trips
            userPlacements = archive.placements
        } catch {
            userRecords = []
            userTrips = []
            userPlacements = []
            if (error as NSError).code != NSFileReadNoSuchFileError {
                lastError = error.localizedDescription
            }
        }
    }

    func record(id: UUID) -> StubRecord? {
        userRecords.first(where: { $0.id == id })
            ?? StubFixtures.records.first(where: { $0.id == id })
    }

    func trip(id: UUID) -> TripBook? {
        userTrips.first(where: { $0.id == id })
            ?? (id == StubFixtures.tripID ? StubFixtures.trip : nil)
    }

    func placement(for stubID: UUID) -> TripPlacement? {
        placements.first(where: { $0.stubID == stubID })
    }

    func records(in tripID: UUID) -> [(TripPlacement, StubRecord)] {
        let tripPlacements = tripID == StubFixtures.tripID
            ? StubFixtures.placements + userPlacements
            : userPlacements

        return tripPlacements
            .filter { $0.tripID == tripID }
            .sorted { $0.order < $1.order }
            .compactMap { placement in
                record(id: placement.stubID).map { (placement, $0) }
            }
    }

    func save(_ draft: StubDraft) throws -> UUID {
        guard draft.canSave else { throw StoreError.incompleteDraft }

        let now = Date()
        let recordID = draft.editingID ?? UUID()
        let previous = userRecords.first(where: { $0.id == recordID })
        let primary = try mediaReference(
            existing: draft.existingPrimary,
            data: draft.primaryData,
            prefix: "ticket"
        )
        let newAttachments = try draft.attachmentData.map { data in
            try writeMedia(data, prefix: "memory")
        }
        let poster: MediaReference?
        if let posterData = draft.posterData {
            poster = try writeMedia(posterData, prefix: "poster")
        } else if draft.category == .movie && draft.useSuggestedPoster && Self.matchesBundledMovie(draft.title) {
            poster = .bundled("movie-poster.jpg")
        } else {
            poster = draft.existingPoster
        }

        var details = draft.details
        details.kind = switch draft.category {
        case .movie: .movie
        case .travel where draft.subtype == .flight: .flight
        case .travel where draft.subtype == .train: .train
        case .stay: .stay
        case .performance: .performance
        default: .generic
        }

        let record = StubRecord(
            id: recordID,
            source: .user,
            title: draft.resolvedTitle,
            occurredOn: draft.occurredOn,
            category: draft.category,
            subtype: draft.category == .travel ? draft.subtype : nil,
            note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: draft.tags,
            primaryMedia: primary,
            attachments: draft.existingAttachments + newAttachments,
            posterMedia: poster,
            details: details,
            createdAt: previous?.createdAt ?? now,
            updatedAt: now
        )

        userRecords.removeAll { $0.id == recordID }
        userRecords.append(record)
        setTrip(draft.tripID, for: recordID)
        try persist()
        return recordID
    }

    func add(_ stubID: UUID, to tripID: UUID) throws {
        setTrip(tripID, for: stubID)
        try persist()
    }

    func removeFromTrip(_ stubID: UUID) throws {
        userPlacements.removeAll { $0.stubID == stubID }
        try persist()
    }

    func createTrip(title: String, startDate: Date, endDate: Date, route: String, note: String) throws -> UUID {
        let trip = TripBook(
            id: UUID(),
            source: .user,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            route: route.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        userTrips.append(trip)
        try persist()
        return trip.id
    }

    func delete(_ recordID: UUID) throws {
        guard let record = userRecords.first(where: { $0.id == recordID }) else { return }
        let references = [record.primaryMedia] + record.attachments + [record.posterMedia].compactMap { $0 }
        for reference in references where reference.location == .stored {
            try? FileManager.default.removeItem(at: mediaDirectory.appendingPathComponent(reference.value))
        }
        userRecords.removeAll { $0.id == recordID }
        userPlacements.removeAll { $0.stubID == recordID }
        try persist()
    }

    func storedURL(for reference: MediaReference) -> URL? {
        reference.location == .stored ? mediaDirectory.appendingPathComponent(reference.value) : nil
    }

    func archiveExportURL() throws -> URL {
        try persist()
        return archiveURL
    }

    static func matchesBundledMovie(_ title: String) -> Bool {
        let normalized = title.lowercased()
            .replacingOccurrences(of: "：", with: " ")
            .replacingOccurrences(of: ":", with: " ")
        return ["名侦探柯南", "百万美元的五棱星", "detective conan", "million-dollar pentagram"]
            .contains(where: normalized.contains)
    }

    private func setTrip(_ tripID: UUID?, for stubID: UUID) {
        userPlacements.removeAll { $0.stubID == stubID }
        if StubFixtures.placements.contains(where: { $0.stubID == stubID }) {
            return
        }
        guard let tripID else { return }
        let nextOrder = placements.filter { $0.tripID == tripID }.count + 1
        userPlacements.append(TripPlacement(
            id: UUID(),
            tripID: tripID,
            stubID: stubID,
            order: nextOrder,
            day: max(1, nextOrder),
            caption: "",
            rotation: 0,
            scale: 1
        ))
    }

    private func mediaReference(existing: MediaReference?, data: Data?, prefix: String) throws -> MediaReference {
        if let data { return try writeMedia(data, prefix: prefix) }
        if let existing { return existing }
        throw StoreError.incompleteDraft
    }

    private func writeMedia(_ data: Data, prefix: String) throws -> MediaReference {
        let id = UUID()
        let filename = "\(prefix)-\(id.uuidString.lowercased()).jpg"
        try data.write(to: mediaDirectory.appendingPathComponent(filename), options: .atomic)
        return MediaReference(id: id, location: .stored, value: filename)
    }

    private func persist() throws {
        do {
            let archive = PersistedArchive(
                records: userRecords,
                trips: userTrips,
                placements: userPlacements
            )
            let data = try encoder.encode(archive)
            try data.write(to: archiveURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
}

extension ArchiveStore {
    enum StoreError: LocalizedError {
        case incompleteDraft

        var errorDescription: String? {
            switch self {
            case .incompleteDraft:
                "A title and ticket image are required."
            }
        }
    }
}
