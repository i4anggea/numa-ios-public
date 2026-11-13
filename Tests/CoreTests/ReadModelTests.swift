import XCTest
@testable import FinanceCore
import FinanceFixtures

final class ReadModelTests: XCTestCase {
    func testLargeSummaryMatchesIndependentLedgerCalculations() throws {
        let ledger = try SyntheticLedger.make()
        let index = LedgerReadIndex(ledger)
        XCTAssertEqual(index.summary.total, ledger.total)
        XCTAssertEqual(index.summary.available, ledger.available)
        XCTAssertEqual(index.summary.held, ledger.reserved())
        XCTAssertEqual(index.summary.totalDebt, ledger.totalDebt)
        for account in ledger.accounts { XCTAssertEqual(index.summary.balances[account.id], ledger.accountBalance(account.id)) }
        for card in ledger.cards.filter(\.credit) { XCTAssertEqual(index.summary.debts[card.id], ledger.debt(card.id)) }
    }
    func testReportsMatchFrozenReferenceWithTenThousandEntries() throws {
        let ledger = try SyntheticLedger.make()
        let optimized = LedgerReadIndex(ledger)
        let reference = ReferenceReadIndex(ledger)
        for date in [SyntheticLedger.reference, FinanceDates.addDays(-360, to: SyntheticLedger.reference)] {
            for component: Calendar.Component in [.day, .weekOfYear, .month] {
                let interval = FinanceDates.calendar.dateInterval(of: component, for: date)!
                XCTAssertEqual(optimized.report(in: interval, through: SyntheticLedger.reference), reference.report(in: interval, through: SyntheticLedger.reference), "Periodo \(component), \(date)")
            }
        }
    }
    func testFiltersSearchAndOrderingMatchReference() throws {
        let ledger = try SyntheticLedger.make()
        let optimized = LedgerReadIndex(ledger)
        let reference = ReferenceReadIndex(ledger)
        let interval = FinanceDates.calendar.dateInterval(of: .month, for: SyntheticLedger.reference)!
        let filters = [EntryFilter(), EntryFilter(search: "Transporte"), EntryFilter(search: "TARJETA 1"),
                       EntryFilter(kind: .expense, category: ledger.categories[1].id),
                       EntryFilter(method: ledger.cards[0].id), EntryFilter(method: ledger.accounts[0].id),
                       EntryFilter(interval: interval), EntryFilter(search: "no existe")]
        for filter in filters { XCTAssertEqual(optimized.matching(filter), reference.matching(filter)) }
        XCTAssertEqual(optimized.matching(EntryFilter()).count, 10_000)
    }
    func testReadModelUpdatesAfterEditAndDeletion() throws {
        var ledger = try SyntheticLedger.make()
        var entry = Entry(kind: .expense, amount: 1234, date: SyntheticLedger.reference,
                          categoryID: ledger.categories[0].id, accountID: ledger.accounts[0].id)
        let original = LedgerReadIndex(ledger)
        try ledger.saveEntry(entry)
        XCTAssertEqual(LedgerReadIndex(ledger).summary.available, original.summary.available - 1234)
        entry.amount = 2000
        try ledger.saveEntry(entry)
        XCTAssertEqual(LedgerReadIndex(ledger).summary.available, original.summary.available - 2000)
        try ledger.deleteEntry(entry.id)
        XCTAssertEqual(LedgerReadIndex(ledger).summary, original.summary)
    }
}
