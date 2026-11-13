import XCTest
import SwiftData
@testable import Finanzas

@MainActor final class StorageTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FinanceIntegration-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func fixture() -> Ledger {
        var state = Ledger.initial
        state.accounts = [Account(name: "Banco ficticio", cash: false, opening: 100_000)]
        state.goals = [Goal(name: "Meta ficticia", target: 50_000)]
        return state
    }
    func testCaptureAndExpenseCommitTogetherAndSurviveReopen() throws {
        let path = try directory()
        let store = FinanceStore(makeRepository: { try LocalRepository(directory: path) })
        var ledger = fixture()
        let card = Card(name: "Débito ficticio", credit: false, accountID: ledger.accounts[0].id, reminders: false)
        ledger.cards = [card]
        var settings = CaptureSettings()
        let draft = CaptureDraft(source: .santanderEmail, merchant: "Mercado Libre", cardID: card.id, eventID: "sample-id")
        try settings.receive(draft); ledger.capture = settings
        XCTAssertTrue(store.change { $0 = ledger })
        XCTAssertEqual(store.ledger.total, 100_000)
        let reopened = try LocalRepository(directory: path).load()
        XCTAssertEqual(reopened.capture, settings)
        XCTAssertFalse(store.change { state in
            var invalid = Entry(kind: .expense, amount: 0, categoryID: state.categories[0].id, accountID: state.accounts[0].id, cardID: card.id)
            invalid.id = draft.id
            try state.saveCapturedExpense(invalid, captureID: draft.id)
        })
        XCTAssertEqual(store.ledger.capture?.drafts[0].status, .pending)
        XCTAssertTrue(store.ledger.entries.isEmpty)
        XCTAssertTrue(store.change { state in
            var entry = Entry(kind: .expense, amount: 12550, categoryID: state.categories[0].id, accountID: state.accounts[0].id, cardID: card.id, note: draft.merchant)
            entry.id = draft.id
            try state.saveCapturedExpense(entry, captureID: draft.id)
        })
        let after = try LocalRepository(directory: path).load()
        XCTAssertEqual(after.accountBalance(ledger.accounts[0].id), 87450)
        XCTAssertEqual(after.capture?.drafts[0].status, .saved)
        XCTAssertEqual(after.entries.count, 1)
        XCTAssertFalse(store.change { state in try state.saveCapturedExpense(after.entries[0], captureID: draft.id) })
        XCTAssertEqual(store.ledger.total, 87450)
        var replay = try XCTUnwrap(after.capture)
        XCTAssertEqual(try replay.receive(draft), draft.id)
        XCTAssertEqual(replay.drafts.count, 1)
    }

    func testShortcutInputUsesConfiguredDebitAndRejectsLockedWrites() throws {
        var unlocked = true
        let path = try directory()
        let store = FinanceStore(protectedDataAvailable: { unlocked }, makeRepository: { try LocalRepository(directory: path) })
        var state = fixture()
        let debit = Card(name: "Santander de prueba", credit: false, accountID: state.accounts[0].id, reminders: false)
        state.cards = [debit]
        var config = CaptureSettings(); config.santanderCardID = debit.id; state.capture = config
        XCTAssertTrue(store.change { $0 = state })
        try store.prepareCapture(source: .santanderNotification, text: "Haz realizado una compra en Mercado Libre", merchant: nil, amount: nil, currency: nil, cardID: nil, eventID: "event-one", date: .now)
        XCTAssertEqual(store.ledger.capture?.drafts.first?.cardID, debit.id)
        XCTAssertNil(store.ledger.capture?.drafts.first?.amount)
        XCTAssertTrue(store.ledger.entries.isEmpty)
        XCTAssertEqual(store.ledger.total, 100_000)
        unlocked = false; store.suspendProtectedData()
        XCTAssertThrowsError(try store.prepareCapture(source: .wallet, text: nil, merchant: "Tienda", amount: "10", currency: "MXN", cardID: debit.id, eventID: "event-two", date: .now))
        unlocked = true; store.resumeProtectedData()
        XCTAssertEqual(store.ledger.capture?.drafts.count, 1)
    }

    func testStartLockedDoesNotOpenOrCreateRepository() throws {
        var available = false
        var opens = 0
        let path = try directory()
        let store = FinanceStore(protectedDataAvailable: { available }, makeRepository: {
            opens += 1; return try LocalRepository(directory: path)
        })
        XCTAssertFalse(store.ready)
        XCTAssertTrue(store.protectedDataUnavailable)
        XCTAssertEqual(opens, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path.appendingPathComponent("Finance.store").path))
        available = true; store.resumeProtectedData()
        XCTAssertTrue(store.ready)
        XCTAssertEqual(opens, 1)
    }
    func testRepeatedLockRejectsWritesAndReloadsPersistedBalances() throws {
        var available = true
        let path = try directory()
        let store = FinanceStore(protectedDataAvailable: { available }, makeRepository: { try LocalRepository(directory: path) })
        XCTAssertTrue(store.change { $0 = self.fixture() })
        let id = store.ledger.accounts[0].id
        XCTAssertTrue(store.change { try $0.saveEntry(Entry(kind: .expense, amount: 12_345, categoryID: $0.categories[0].id, accountID: id)) })
        for _ in 0..<3 {
            available = false; store.suspendProtectedData()
            XCTAssertFalse(store.ready)
            XCTAssertTrue(store.ledger.entries.isEmpty)
            XCTAssertEqual(store.index.summary.total, 0)
            var invoked = false
            XCTAssertFalse(store.change { _ in invoked = true })
            XCTAssertFalse(invoked)
            store.resumeProtectedData(); XCTAssertFalse(store.ready)
            available = true; store.resumeProtectedData()
            XCTAssertTrue(store.ready)
            XCTAssertFalse(store.protectedDataUnavailable)
            XCTAssertEqual(store.ledger.entries.count, 1)
            XCTAssertEqual(store.index.summary.total, 87_655)
        }
    }
    func testSaveReopenEditDeleteAndBackupExclusion() throws {
        let path = try directory()
        var state = fixture()
        var entry = Entry(kind: .expense, amount: 100, categoryID: state.categories[0].id, accountID: state.accounts[0].id)
        try state.saveEntry(entry)
        do { let repo = try LocalRepository(directory: path); try repo.save(state); try repo.save(state) }
        let repo = try LocalRepository(directory: path)
        var loaded = try repo.load()
        XCTAssertEqual(loaded.entries, state.entries)
        entry.amount = 234; try loaded.saveEntry(entry); try repo.save(loaded)
        XCTAssertEqual(try LocalRepository(directory: path).load().entries.first?.amount, 234)
        loaded.entries.removeAll(); try repo.save(loaded)
        XCTAssertTrue(try LocalRepository(directory: path).load().entries.isEmpty)
        let files = [path] + (try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil))
        XCTAssertTrue(files.contains { $0.lastPathComponent == "Finance.store" })
        for file in files { XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true, file.lastPathComponent) }
    }
    func testInvalidCandidateDoesNotReplacePersistedState() throws {
        let path = try directory()
        let repo = try LocalRepository(directory: path)
        let valid = fixture(); try repo.save(valid)
        var invalid = valid; invalid.accounts[0].opening = Int64.max
        XCTAssertThrowsError(try repo.save(invalid))
        XCTAssertEqual(try LocalRepository(directory: path).load().accounts, valid.accounts)
    }
    func testTransactionRollbackAfterPartialContextMutation() throws {
        let path = try directory()
        let repo = try LocalRepository(directory: path)
        let original = fixture(); try repo.save(original); _ = try repo.load()
        var candidate = original
        let reusedID = candidate.accounts[0].id
        candidate.accounts[0].id = UUID()
        var category = Category("Conflicto ficticio")
        category.id = reusedID
        candidate.categories.append(category)
        try candidate.validateIntegrity() // Domain shape is valid; row kind reuse is not.
        XCTAssertThrowsError(try repo.save(candidate))
        let persisted = try LocalRepository(directory: path).load()
        XCTAssertEqual(persisted.accounts, original.accounts)
        XCTAssertEqual(Set(persisted.categories.map(\.id)), Set(original.categories.map(\.id)))
        var retry = original; retry.accounts[0].name = "Corrección válida"
        try repo.save(retry)
        XCTAssertEqual(try LocalRepository(directory: path).load().accounts[0].name, "Corrección válida")
    }
    func testWeeklyClosureSavingsAndCarrySurviveReopen() throws {
        let path = try directory()
        var state = try UITestFixtures.make("week")
        let week = state.budgets[0].week
        try state.close(week: week, saved: 20_000, carried: 30_000, goal: state.goals[0].id, account: state.accounts[1].id)
        do { let repo = try LocalRepository(directory: path); try repo.save(state) }
        let reloaded = try LocalRepository(directory: path).load()
        XCTAssertEqual(reloaded.total, 170_000)
        XCTAssertEqual(reloaded.available, 150_000)
        XCTAssertEqual(reloaded.remaining(week), 70_000)
        XCTAssertEqual(reloaded.reserved(), 20_000)
        XCTAssertEqual(reloaded.carry(into: FinanceDates.addDays(7, to: week)), 30_000)
    }
    func testInstallmentPurchaseAndPartialPaymentSurviveReopen() throws {
        let path = try directory()
        var state = try UITestFixtures.make("credit")
        let purchase = state.entries[0]
        try state.saveEntry(Entry(kind: .cardPayment, amount: 40_034, accountID: state.accounts[0].id, cardID: state.cards[0].id))
        do { let repo = try LocalRepository(directory: path); try repo.save(state) }
        let loaded = try LocalRepository(directory: path).load()
        XCTAssertEqual(loaded.debt(state.cards[0].id), 80_066)
        XCTAssertEqual(loaded.total, 459_966)
        XCTAssertEqual(loaded.entries.filter { $0.kind.consumesBudget }.reduce(0) { $0 + $1.amount }, 120_100)
        XCTAssertEqual(loaded.entries.first { $0.id == purchase.id }?.months, 3)
        XCTAssertEqual(loaded.entries.first { $0.id == purchase.id }?.price, 100_000)
    }
    private func rejectTampering(_ mode: String) throws {
        let path = try directory()
        let repo = try LocalRepository(directory: path); try repo.save(fixture())
        let context = ModelContext(repo.container)
        let row = try XCTUnwrap(try context.fetch(FetchDescriptor<FinanceSchemaV1.StoredEntity>()).first { $0.kind == "account" })
        switch mode {
        case "json": row.payload = Data("{invalid".utf8)
        case "identity":
            var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: row.payload) as? [String: Any])
            payload["id"] = UUID().uuidString
            row.payload = try JSONSerialization.data(withJSONObject: payload)
        default: row.kind = "future-format"
        }
        try context.save()
        let payload = row.payload, kind = row.kind
        XCTAssertThrowsError(try LocalRepository(directory: path).load())
        let unchanged = try XCTUnwrap(try context.fetch(FetchDescriptor<FinanceSchemaV1.StoredEntity>()).first { $0.id == row.id })
        XCTAssertEqual(unchanged.payload, payload)
        XCTAssertEqual(unchanged.kind, kind)
    }
    func testRejectsMalformedPayloadWithoutReplacingIt() throws { try rejectTampering("json") }
    func testRejectsMismatchedIdentityWithoutReplacingIt() throws { try rejectTampering("identity") }
    func testRejectsUnknownKindWithoutReplacingIt() throws { try rejectTampering("kind") }
    func testOpeningFailureHidesInternalErrorDetails() {
        let store = FinanceStore(protectedDataAvailable: { true }, makeRepository: {
            throw NSError(domain: "PRIVATE_INTERNAL_SENTINEL", code: 42)
        })
        XCTAssertFalse(store.ready)
        XCTAssertFalse(store.errorMessage?.contains("PRIVATE_INTERNAL_SENTINEL") ?? true)
        XCTAssertTrue(store.errorMessage?.contains("registros se conservaron") ?? false)
    }
    func testCommittedProtectionFailureRequiresReopenWithoutDuplicate() {
        let repository = FaultRepository(state: fixture())
        let store = FinanceStore(protectedDataAvailable: { true }, makeRepository: { repository })
        repository.failAfterCommit = true
        let id = store.ledger.accounts[0].id
        XCTAssertFalse(store.change { try $0.saveEntry(Entry(kind: .expense, amount: 500, categoryID: $0.categories[0].id, accountID: id)) })
        XCTAssertFalse(store.ready)
        XCTAssertEqual(repository.state.entries.count, 1)
        XCTAssertTrue(store.errorMessage?.contains("antes de repetirlo") ?? false)
        repository.failAfterCommit = false; store.open()
        XCTAssertTrue(store.ready)
        XCTAssertEqual(store.ledger.entries.count, 1)
        XCTAssertEqual(store.index.summary.total, 99_500)
    }
    func testFailedSavePreservesPublishedAndPersistedBalances() {
        let repository = FaultRepository(state: fixture())
        let store = FinanceStore(protectedDataAvailable: { true }, makeRepository: { repository })
        repository.failBeforeCommit = true
        let id = store.ledger.accounts[0].id
        XCTAssertFalse(store.change { try $0.saveEntry(Entry(kind: .expense, amount: 500, categoryID: $0.categories[0].id, accountID: id)) })
        XCTAssertTrue(store.ready)
        XCTAssertEqual(store.index.summary.total, 100_000)
        XCTAssertTrue(repository.state.entries.isEmpty)
        XCTAssertFalse(store.errorMessage?.contains("PRIVATE_INTERNAL_SENTINEL") ?? true)
        repository.failBeforeCommit = false
        XCTAssertTrue(store.change { try $0.saveEntry(Entry(kind: .expense, amount: 500, categoryID: $0.categories[0].id, accountID: id)) })
        XCTAssertEqual(repository.state.entries.count, 1)
    }
}

@MainActor private final class FaultRepository: FinanceRepository {
    var state: Ledger
    var failBeforeCommit = false
    var failAfterCommit = false
    init(state: Ledger) { self.state = state }
    func load() throws -> Ledger { state }
    func save(_ value: Ledger) throws {
        if failBeforeCommit { throw NSError(domain: "PRIVATE_INTERNAL_SENTINEL", code: 9) }
        state = value
        if failAfterCommit { throw RepositoryFailure.protectionAfterCommit }
    }
    func recordTiming(_ operation: String, since start: ContinuousClock.Instant) {}
}
