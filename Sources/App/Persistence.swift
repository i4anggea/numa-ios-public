import Foundation
import SwiftData
import Observation
import UIKit

enum FinanceSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [StoredEntity.self] }

    // Each domain entity has its own row. Encoding keeps framework details out
    // of the value-based financial engine and permits atomic multi-entity saves.
    @Model final class StoredEntity {
        @Attribute(.unique) var id: UUID
        var kind: String
        var payload: Data
        init(id: UUID, kind: String, payload: Data) {
            self.id = id; self.kind = kind; self.payload = payload
        }
    }
}
enum FinanceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [FinanceSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum RepositoryFailure: Error {
    // save() committed; never invite repeating the transaction blindly.
    case protectionAfterCommit
}

@MainActor protocol FinanceRepository: AnyObject {
    func load() throws -> Ledger
    func save(_ state: Ledger) throws
    func recordTiming(_ operation: String, since start: ContinuousClock.Instant)
}

@MainActor final class LocalRepository: FinanceRepository {
    let container: ModelContainer
    private let context: ModelContext
    private let directory: URL
    private typealias Row = FinanceSchemaV1.StoredEntity
    private var loadedRows: [UUID: Row] = [:]
    private var savedLedger: Ledger?
    private(set) var lastEncodedCount = 0

    init(directory override: URL? = nil) throws {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        var directoryName = "PrivateFinance"
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           let token = ProcessInfo.processInfo.environment["FINANCE_TEST_STORE"], UUID(uuidString: token) != nil {
            directoryName = "UITest-" + token
        }
        #endif
        directory = override ?? support.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.complete])
        try Self.protect(directory)
        let configuration = ModelConfiguration("Finance", schema: Schema(versionedSchema: FinanceSchemaV1.self),
                                                url: directory.appendingPathComponent("Finance.store"),
                                                cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(versionedSchema: FinanceSchemaV1.self),
                                       migrationPlan: FinanceMigrationPlan.self, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
        try protectFiles()
    }
    private static func protect(_ url: URL) throws {
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try target.setResourceValues(values)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    }
    private func protectFiles() throws {
        try Self.protect(directory)
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try Self.protect(url)
        }
    }
    func load() throws -> Ledger {
        let rows = try context.fetch(FetchDescriptor<Row>())
        guard !rows.isEmpty else {
            #if DEBUG
            let process = ProcessInfo.processInfo
            if process.arguments.contains("--ui-testing"),
               let token = process.environment["FINANCE_TEST_STORE"], UUID(uuidString: token) != nil,
               let scenario = process.environment["FINANCE_TEST_SCENARIO"] {
                return try UITestFixtures.make(scenario)
            }
            #endif
            return .initial
        }
        var state = Ledger()
        let decoder = JSONDecoder()
        func decode<T: Decodable & Identifiable>(_ type: T.Type, row: Row) throws -> T where T.ID == UUID {
            let value = try decoder.decode(type, from: row.payload)
            guard value.id == row.id else {
                throw FinanceError.invalid("El identificador de un registro no coincide con su contenido. No se modificará el archivo.")
            }
            return value
        }
        for row in rows {
            switch row.kind {
            case "capture":
                guard state.capture == nil else { throw FinanceError.invalid("Hay configuraciones de Atajos repetidas.") }
                state.capture = try decode(CaptureSettings.self, row: row)
            case "account": state.accounts.append(try decode(Account.self, row: row))
            case "card": state.cards.append(try decode(Card.self, row: row))
            case "category": state.categories.append(try decode(Category.self, row: row))
            case "entry": state.entries.append(try decode(Entry.self, row: row))
            case "goal": state.goals.append(try decode(Goal.self, row: row))
            case "savings": state.savings.append(try decode(SavingsEvent.self, row: row))
            case "budget": state.budgets.append(try decode(WeeklyBudget.self, row: row))
            case "closure": state.closures.append(try decode(WeekClosure.self, row: row))
            default: throw FinanceError.invalid("El archivo usa un formato que esta versión no puede abrir. No se eliminarán los datos.")
            }
        }
        try state.validateIntegrity()
        loadedRows = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        savedLedger = state
        return state
    }
    func save(_ state: Ledger) throws {
        lastEncodedCount = 0
        if savedLedger == state { try protectFiles(); return } // Already validated and persisted by this repository.
        try state.validateIntegrity()
        try protectFiles()
        let byID = loadedRows
        var nextRows = loadedRows
        var keep = Set<UUID>()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        func persist<T: Encodable & Identifiable & Equatable>(_ values: [T], previous: [T], kind: String) throws where T.ID == UUID {
            let prior = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
            for value in values {
                keep.insert(value.id)
                if prior[value.id] == value { continue }
                let data = try encoder.encode(value)
                lastEncodedCount += 1
                if let row = byID[value.id] {
                    guard row.kind == kind else { throw FinanceError.invalid("Se detectó un conflicto de identificadores. No se guardaron cambios.") }
                    if row.payload != data { row.payload = data }
                } else {
                    let row = Row(id: value.id, kind: kind, payload: data)
                    context.insert(row)
                    nextRows[value.id] = row
                }
            }
        }
        do {
            try persist(state.capture.map { [$0] } ?? [], previous: savedLedger?.capture.map { [$0] } ?? [], kind: "capture")
            try persist(state.accounts, previous: savedLedger?.accounts ?? [], kind: "account")
            try persist(state.cards, previous: savedLedger?.cards ?? [], kind: "card")
            try persist(state.categories, previous: savedLedger?.categories ?? [], kind: "category")
            try persist(state.entries, previous: savedLedger?.entries ?? [], kind: "entry")
            try persist(state.goals, previous: savedLedger?.goals ?? [], kind: "goal")
            try persist(state.savings, previous: savedLedger?.savings ?? [], kind: "savings")
            try persist(state.budgets, previous: savedLedger?.budgets ?? [], kind: "budget")
            try persist(state.closures, previous: savedLedger?.closures ?? [], kind: "closure")
            for (id, row) in byID where !keep.contains(id) { context.delete(row); nextRows[id] = nil }
            try context.save()
            loadedRows = nextRows
            savedLedger = state
        } catch {
            context.rollback()
            throw error
        }
        // Frameworks may create new journal files during save. A failure here
        // occurs after commit and must be reported differently from a rollback.
        do { try protectFiles() } catch { throw RepositoryFailure.protectionAfterCommit }
    }
    func recordTiming(_ operation: String, since start: ContinuousClock.Instant) {
        #if DEBUG
        let process = ProcessInfo.processInfo
        guard process.arguments.contains("--ui-testing"), process.environment["FINANCE_PERFORMANCE"] == "1",
              let token = process.environment["FINANCE_TEST_STORE"], UUID(uuidString: token) != nil else { return }
        let duration = start.duration(to: .now).components
        let milliseconds = Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15
        let path = directory.appendingPathComponent("performance.json")
        // Diagnostics contain only timings and counts, never financial contents.
        do {
            var records = (try? Data(contentsOf: path)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []
            records.append(["operation": operation, "milliseconds": milliseconds, "encodedRows": lastEncodedCount])
            let data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: path, options: [.atomic, .completeFileProtection])
            try Self.protect(path)
        } catch { /* Optional test diagnostics must not change transaction success. */ }
        #endif
    }
}

@MainActor @Observable final class FinanceStore {
    static let shared = FinanceStore()
    var quickRequest: UUID?
    private(set) var ledger = Ledger.initial
    private(set) var index = LedgerReadIndex(.initial)
    private(set) var revision = UUID()
    private(set) var ready = false
    private(set) var protectedDataUnavailable = false
    var errorMessage: String?
    var notificationStatus = "No solicitado"
    private var repository: (any FinanceRepository)?
    private var notificationTask: Task<String, Error>?
    private var notificationRequest = UUID()
    private let protectedDataAvailable: () -> Bool
    private let makeRepository: () throws -> any FinanceRepository
    init(protectedDataAvailable: @escaping () -> Bool = { UIApplication.shared.isProtectedDataAvailable },
         makeRepository: @escaping () throws -> any FinanceRepository = { try LocalRepository() }) {
        self.protectedDataAvailable = protectedDataAvailable
        self.makeRepository = makeRepository
        open()
    }
    func suspendProtectedData() {
        protectedDataUnavailable = true
        ready = false
        repository = nil
        ledger = .initial
        index = LedgerReadIndex(.initial)
        revision = UUID()
        errorMessage = nil
        notificationRequest = UUID()
    }
    func resumeProtectedData() {
        guard protectedDataAvailable() else { suspendProtectedData(); return }
        if protectedDataUnavailable { open() }
    }
    func open() {
        guard protectedDataAvailable() else { suspendProtectedData(); return }
        protectedDataUnavailable = false
        ready = false
        repository = nil
        let start = ContinuousClock.now
        do {
            let repository = try makeRepository()
            let data = try repository.load()
            try repository.save(data)
            self.repository = repository
            ledger = data
            index = LedgerReadIndex(data)
            revision = UUID()
            repository.recordTiming("open", since: start)
            ready = true
            errorMessage = nil
            Task { await refreshNotifications() }
        } catch {
            ready = false
            ledger = .initial
            index = LedgerReadIndex(.initial)
            revision = UUID()
            let reason = (error as? FinanceError)?.errorDescription
            errorMessage = "No se pudo abrir el archivo local. Tus registros se conservaron. "
                + (reason ?? "Reintenta abrirlo. Si el problema continúa, conserva la app y sus datos para revisarlos.")
        }
    }
    @discardableResult func change(_ operation: (inout Ledger) throws -> Void) -> Bool {
        let start = ContinuousClock.now
        guard protectedDataAvailable() else { suspendProtectedData(); return false }
        guard let repository, ready else { errorMessage = "El archivo no está disponible. Reintenta abrirlo."; return false }
        do {
            var candidate = ledger
            try operation(&candidate)
            try repository.save(candidate)
            ledger = candidate
            index = LedgerReadIndex(candidate)
            revision = UUID()
            repository.recordTiming("change", since: start)
            return true
        } catch RepositoryFailure.protectionAfterCommit {
            suspendProtectedData()
            errorMessage = "La escritura terminó, pero no se pudo verificar la protección del archivo. Reabre el archivo y comprueba el movimiento antes de repetirlo."
            return false
        } catch {
            errorMessage = (error as? FinanceError)?.errorDescription
                ?? "No se pudieron guardar los cambios. Reintenta cuando el iPhone esté desbloqueado."
            return false
        }
    }
    func refreshNotifications(request: Bool = false) async {
        guard ready, protectedDataAvailable() else { return }
        let previous = notificationTask
        let requestID = UUID()
        notificationRequest = requestID
        let task = Task { @MainActor in
            // Foreground changes and card edits can overlap across await points.
            // Finish the previous reconciliation, then use the latest card state.
            if let previous { _ = try? await previous.value }
            guard ready, protectedDataAvailable() else { throw CancellationError() }
            return try await ReminderScheduler.reconcile(cards: ledger.cards, requestPermission: request)
        }
        notificationTask = task
        do {
            let status = try await task.value
            if notificationRequest == requestID { notificationStatus = status }
        } catch {
            if notificationRequest == requestID { notificationStatus = "No se pudieron programar los avisos. Reintenta desde Ajustes." }
        }
    }
}
