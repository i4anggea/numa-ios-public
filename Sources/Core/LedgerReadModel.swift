import Foundation

public struct LedgerSummary: Sendable, Equatable {
    public var balances: [UUID: Cents]
    public var debts: [UUID: Cents]
    public var held: Cents
    public var total: Cents { balances.values.reduce(0, +) }
    public var available: Cents { total - held }
    public var totalDebt: Cents { debts.values.reduce(0, +) }
}
public struct LedgerReport: Sendable, Equatable {
    public var income: Cents = 0
    public var expense: Cents = 0
    public var outflow: Cents = 0
    public var categoryTotals: [UUID: Cents] = [:]
    public var methodTotals: [UUID: Cents] = [:]
    public var cash: Cents = 0
    public var debit: Cents = 0
    public var credit: Cents = 0
    public var timeline: [DayBalance] = []
    public struct DayBalance: Sendable, Equatable, Identifiable {
        public var date: Date
        public var balance: Cents
        public var id: Date { date }
    }
}
public struct EntryFilter: Sendable, Hashable {
    public var search: String
    public var kind: EntryKind?
    public var category: UUID?
    public var method: UUID?
    public var interval: DateInterval?
    public init(search: String = "", kind: EntryKind? = nil, category: UUID? = nil, method: UUID? = nil, interval: DateInterval? = nil) {
        self.search = search; self.kind = kind; self.category = category; self.method = method; self.interval = interval
    }
}
public struct LedgerReadIndex: Sendable {
    public let orderedEntries: [Entry]
    public let summary: LedgerSummary
    private let ledger: Ledger
    private let methodNames: [UUID: String]
    private let categoryNames: [UUID: String]
    public init(_ ledger: Ledger) {
        self.ledger = ledger
        orderedEntries = ledger.entries.sorted { $0.date == $1.date ? Self.precedes($0.id, $1.id) : $0.date > $1.date }
        var balances = Dictionary(uniqueKeysWithValues: ledger.accounts.map { ($0.id, $0.opening) })
        var debts = Dictionary(uniqueKeysWithValues: ledger.cards.filter(\.credit).map { ($0.id, $0.openingDebt) })
        for entry in ledger.entries {
            if let id = entry.accountID, balances[id] != nil { balances[id, default: 0] += entry.kind == .income ? entry.amount : -entry.amount }
            if entry.kind == .transfer, let id = entry.destinationID, balances[id] != nil { balances[id, default: 0] += entry.amount }
            if let id = entry.cardID, debts[id] != nil { debts[id, default: 0] += entry.kind == .cardPayment ? -entry.amount : entry.amount }
        }
        summary = LedgerSummary(balances: balances, debts: debts, held: ledger.reserved())
        var names = Dictionary(uniqueKeysWithValues: ledger.accounts.map { ($0.id, $0.name) })
        for card in ledger.cards { names[card.id] = card.name + (card.credit ? " · Crédito" : " · Débito") }
        methodNames = names
        categoryNames = Dictionary(uniqueKeysWithValues: ledger.categories.map { ($0.id, $0.name) })
    }
    // UUID bytes preserve canonical-string order without allocating strings in every comparison.
    private static func precedes(_ left: UUID, _ right: UUID) -> Bool {
        let a = left.uuid; let b = right.uuid
        let a0 = (a.0, a.1, a.2, a.3, a.4, a.5); let b0 = (b.0, b.1, b.2, b.3, b.4, b.5)
        if a0 != b0 { return a0 < b0 }
        let a1 = (a.6, a.7, a.8, a.9, a.10, a.11); let b1 = (b.6, b.7, b.8, b.9, b.10, b.11)
        if a1 != b1 { return a1 < b1 }
        return (a.12, a.13, a.14, a.15) < (b.12, b.13, b.14, b.15)
    }
    public func matching(_ filter: EntryFilter) -> [Entry] {
        orderedEntries.filter { entry in
            (filter.kind == nil || entry.kind == filter.kind) && (filter.category == nil || entry.categoryID == filter.category) &&
            (filter.method == nil || entry.cardID == filter.method || (entry.cardID == nil && entry.accountID == filter.method)) &&
            (filter.interval == nil || (entry.date >= filter.interval!.start && entry.date < filter.interval!.end)) &&
            (filter.search.isEmpty || entry.note.localizedCaseInsensitiveContains(filter.search) ||
             ((entry.cardID ?? entry.accountID).flatMap { methodNames[$0] } ?? "Sin cuenta").localizedCaseInsensitiveContains(filter.search) ||
             (entry.categoryID.flatMap { categoryNames[$0] } ?? "").localizedCaseInsensitiveContains(filter.search))
        }
    }
    public func report(in interval: DateInterval, through now: Date) -> LedgerReport {
        var result = LedgerReport()
        let calendar = FinanceDates.calendar
        let accountIDs = Set(ledger.accounts.map(\.id))
        let cashIDs = Set(ledger.accounts.filter(\.cash).map(\.id))
        let cards = Dictionary(uniqueKeysWithValues: ledger.cards.map { ($0.id, $0) })
        for id in accountIDs { result.methodTotals[id] = 0 }
        for card in ledger.cards { result.methodTotals[card.id] = 0 }
        var opening = ledger.accounts.reduce(Cents(0)) { $0 + $1.opening }
        var dailyChanges: [Date: Cents] = [:]
        for entry in ledger.entries {
            var delta: Cents = 0
            if let account = entry.accountID, accountIDs.contains(account) { delta += entry.kind == .income ? entry.amount : -entry.amount }
            if entry.kind == .transfer, let destination = entry.destinationID, accountIDs.contains(destination) { delta += entry.amount }
            if entry.date < interval.start { opening += delta; continue }
            guard entry.date < interval.end else { continue }
            if delta != 0 { dailyChanges[calendar.startOfDay(for: entry.date), default: 0] += delta }
            switch entry.kind {
            case .income: result.income += entry.amount
            case .expense: result.expense += entry.amount
            case .outflow: result.outflow += entry.amount
            default: break
            }
            guard entry.kind.consumesBudget else { continue }
            if let category = entry.categoryID, categoryNames[category] != nil { result.categoryTotals[category, default: 0] += entry.amount }
            if let method = entry.cardID ?? entry.accountID, result.methodTotals[method] != nil { result.methodTotals[method, default: 0] += entry.amount }
            if let cardID = entry.cardID, let card = cards[cardID] {
                if card.credit { result.credit += entry.amount } else { result.debit += entry.amount }
            } else if entry.cardID == nil, let account = entry.accountID, cashIDs.contains(account) { result.cash += entry.amount }
        }
        let count = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
        var balance = opening
        for index in 0..<min(31, count) {
            let day = FinanceDates.addDays(index, to: interval.start)
            guard day <= calendar.startOfDay(for: now) else { break }
            balance += dailyChanges[day, default: 0]
            result.timeline.append(.init(date: day, balance: balance))
        }
        return result
    }
}
