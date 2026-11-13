// Frozen pre-optimization query implementation for equivalence tests.
import Foundation
@testable import FinanceCore

struct ReferenceReadIndex: Sendable {
    let orderedEntries: [Entry]
    let summary: LedgerSummary
    private let ledger: Ledger
    init(_ ledger: Ledger) {
        self.ledger = ledger
        orderedEntries = ledger.entries.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
        summary = LedgerSummary(balances: Dictionary(uniqueKeysWithValues: ledger.accounts.map { ($0.id, ledger.accountBalance($0.id)) }),
                                debts: Dictionary(uniqueKeysWithValues: ledger.cards.filter(\.credit).map { ($0.id, ledger.debt($0.id)) }),
                                held: ledger.reserved())
    }
    func matching(_ filter: EntryFilter) -> [Entry] {
        orderedEntries.filter { entry in
            (filter.kind == nil || entry.kind == filter.kind) && (filter.category == nil || entry.categoryID == filter.category) &&
            (filter.method == nil || entry.cardID == filter.method || (entry.cardID == nil && entry.accountID == filter.method)) &&
            (filter.interval == nil || (entry.date >= filter.interval!.start && entry.date < filter.interval!.end)) &&
            (filter.search.isEmpty || entry.note.localizedCaseInsensitiveContains(filter.search) || ledger.method(entry).localizedCaseInsensitiveContains(filter.search) || (ledger.categories.first { $0.id == entry.categoryID }?.name ?? "").localizedCaseInsensitiveContains(filter.search))
        }
    }
    func report(in interval: DateInterval, through now: Date) -> LedgerReport {
        var result = LedgerReport()
        let entries = ledger.entries.filter { $0.date >= interval.start && $0.date < interval.end }
        result.income = entries.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
        result.expense = entries.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
        result.outflow = entries.filter { $0.kind == .outflow }.reduce(0) { $0 + $1.amount }
        for category in ledger.categories {
            let total = entries.filter { $0.categoryID == category.id && $0.kind.consumesBudget }.reduce(0) { $0 + $1.amount }
            if total > 0 { result.categoryTotals[category.id] = total }
        }
        for account in ledger.accounts {
            let total = entries.filter { $0.accountID == account.id && $0.cardID == nil && $0.kind.consumesBudget }.reduce(0) { $0 + $1.amount }
            result.methodTotals[account.id] = total
            if account.cash { result.cash += total }
        }
        for card in ledger.cards {
            let total = entries.filter { $0.cardID == card.id && $0.kind.consumesBudget }.reduce(0) { $0 + $1.amount }
            result.methodTotals[card.id] = total
            if card.credit { result.credit += total } else { result.debit += total }
        }
        let count = FinanceDates.calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
        for index in 0..<min(31, count) {
            let day = FinanceDates.addDays(index, to: interval.start)
            guard day <= FinanceDates.calendar.startOfDay(for: now) else { break }
            let next = FinanceDates.addDays(1, to: day)
            result.timeline.append(.init(date: day, balance: ledger.accounts.reduce(0) { $0 + ledger.accountBalance($1.id, until: next) }))
        }
        return result
    }
}
