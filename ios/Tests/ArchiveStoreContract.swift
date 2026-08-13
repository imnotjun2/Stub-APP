import Foundation

@main
struct ArchiveStoreContract {
    @MainActor
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("stub-native-contract-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ArchiveStore(storageRoot: root)
        precondition(store.userRecords.isEmpty)
        precondition(store.records.count == StubFixtures.records.count)
        precondition(store.trips == [StubFixtures.trip])
        precondition(store.placements == StubFixtures.placements)

        var draft = StubDraft()
        draft.title = "Contract Ticket"
        draft.note = "Saved locally"
        draft.category = .movie
        draft.details.formatIDs = ["imax", "dolby-cinema"]
        draft.tags = ["tag.premiere"]
        draft.primaryData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        draft.attachmentData = [Data([0xFF, 0xD8, 0xFF, 0xD9])]
        draft.tripID = StubFixtures.tripID

        let id = try store.save(draft)
        precondition(store.userRecords.count == 1)
        precondition(store.userPlacements.count == 1)
        precondition(store.userPlacements[0].stubID == id)
        precondition(store.userRecords[0].attachments.count == 1)
        precondition(store.records.count == 1)
        precondition(store.records.allSatisfy { $0.source == .user })
        precondition(store.trips.isEmpty)
        precondition(store.placements.count == 1)
        precondition(store.record(id: StubFixtures.movieID) != nil)
        precondition(store.trip(id: StubFixtures.tripID) == StubFixtures.trip)
        precondition(store.browsableTrips.contains(StubFixtures.trip))
        precondition(store.records(in: StubFixtures.tripID).count == StubFixtures.placements.count + 1)

        let reloaded = ArchiveStore(storageRoot: root)
        precondition(reloaded.userRecords.count == 1)
        precondition(reloaded.userPlacements.count == 1)
        precondition(reloaded.userRecords[0].details.formatIDs == ["imax", "dolby-cinema"])

        var edited = StubDraft(record: reloaded.userRecords[0], tripID: StubFixtures.tripID)
        edited.note = "Edited without duplication"
        _ = try reloaded.save(edited)
        precondition(reloaded.userRecords.count == 1)
        precondition(reloaded.userRecords[0].note == "Edited without duplication")
        precondition(reloaded.userPlacements.count == 1)

        try reloaded.delete(id)
        let afterDelete = ArchiveStore(storageRoot: root)
        precondition(afterDelete.userRecords.isEmpty)
        precondition(afterDelete.userPlacements.isEmpty)
        precondition(afterDelete.records.count == StubFixtures.records.count)
        precondition(afterDelete.trips == [StubFixtures.trip])

        let legacyJSON = """
        {"kind":"flight","flightNumber":"MU5237","departure":"SHA","arrival":"CTS"}
        """.data(using: .utf8)!
        let legacyDetails = try JSONDecoder().decode(StubDetails.self, from: legacyJSON)
        precondition(legacyDetails.flightNumber == "MU5237")
        precondition(legacyDetails.hotelName == nil)
        precondition(legacyDetails.performanceTitle == nil)

        var hotelDraft = StubDraft()
        hotelDraft.template = .stay
        hotelDraft.details.hotelName = "Park Hyatt"
        precondition(hotelDraft.resolvedTitle == "Park Hyatt")

        var performanceDraft = StubDraft()
        performanceDraft.template = .performance
        performanceDraft.details.performanceTitle = "Summer Live"
        precondition(performanceDraft.resolvedTitle == "Summer Live")

        print("ArchiveStore contract passed.")
    }
}
