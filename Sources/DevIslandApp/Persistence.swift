import Foundation
import SwiftData
import DevIslandCore

@Model final class LedgerSnapshot {
    @Attribute(.unique) var key: String
    var data: Data
    init(data: Data) { key = "ledger-v1"; self.data = data }
}

@MainActor final class SessionRepository {
    private let container: ModelContainer
    private let context: ModelContext
    init(root: URL) throws {
        let schema = Schema([LedgerSnapshot.self])
        let config = ModelConfiguration("DevIsland", schema: schema, url: root.appendingPathComponent("sessions.store"), cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }
    func load() throws -> SessionLedger {
        guard let snapshot = try context.fetch(FetchDescriptor<LedgerSnapshot>()).first else { return .init() }
        return try JSONDecoder().decode(SessionLedger.self, from: snapshot.data)
    }
    func save(_ ledger: SessionLedger) throws {
        let data = try JSONEncoder().encode(ledger.persistentCopy)
        if let snapshot = try context.fetch(FetchDescriptor<LedgerSnapshot>()).first { snapshot.data = data }
        else { context.insert(LedgerSnapshot(data: data)) }
        try context.save()
    }
}
