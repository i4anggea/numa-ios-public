import XCTest
@testable import FinanceCore

final class ReviewTests: XCTestCase {
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value + "T18:00:00Z")!
    }
    private func fixture() -> Ledger {
        var state = Ledger.initial
        state.accounts = [Account(name: "Efectivo", cash: true, opening: 200_000), Account(name: "Banco", cash: false, opening: 500_000)]
        state.cards = [Card(name: "Crédito", credit: true), Card(name: "Débito", credit: false, accountID: state.accounts[1].id)]
        state.goals = [Goal(name: "Fondo", target: 500_000)]
        return state
    }
    func testRejectsOrphanedEntryOnLoad() throws {
        var state = fixture()
        state.entries = [Entry(kind: .expense, amount: 100, categoryID: state.categories[0].id, accountID: UUID())]
        XCTAssertThrowsError(try state.validateIntegrity())
    }
    func testRejectsInvalidMoneyBeforeDoingArithmetic() throws {
        var state = fixture()
        state.accounts[0].opening = Int64.max
        XCTAssertThrowsError(try state.validateIntegrity())
        state = fixture()
        state.entries = [Entry(kind: .expense, amount: -100, categoryID: state.categories[0].id, accountID: state.accounts[0].id)]
        XCTAssertThrowsError(try state.validateIntegrity())
    }
    func testRejectsDuplicateIDsAndWeeks() throws {
        var state = fixture()
        state.categories[0].id = state.accounts[0].id
        XCTAssertThrowsError(try state.validateIntegrity())
        state = fixture()
        let week = FinanceDates.week(date("2026-09-07"))
        state.budgets = [WeeklyBudget(week: week, limit: 100), WeeklyBudget(week: week, limit: 200)]
        XCTAssertThrowsError(try state.validateIntegrity())
    }
    func testCannotCarryIntoAnAlreadyClosedWeek() throws {
        var state = fixture()
        let first = FinanceDates.week(date("2026-09-07"))
        let second = FinanceDates.addDays(7, to: first)
        state.budgets = [WeeklyBudget(week: first, limit: 100_000), WeeklyBudget(week: second, limit: 100_000)]
        try state.close(week: second, saved: 0, carried: 0, goal: nil, account: nil)
        let before = state
        XCTAssertThrowsError(try state.close(week: first, saved: 0, carried: 20_000, goal: nil, account: nil))
        XCTAssertEqual(state, before)
    }
    func testReopenDoesNotCreateNegativeHistoricalReserve() throws {
        var state = fixture()
        let week = FinanceDates.week(date("2026-09-07"))
        state.budgets = [WeeklyBudget(week: week, limit: 100_000)]
        try state.close(week: week, saved: 20_000, carried: 0, goal: state.goals[0].id, account: state.accounts[0].id)
        let closure = state.closures[0]
        state.savings[0].date = date("2026-09-14")
        try state.reserve(goal: state.goals[0].id, account: state.accounts[0].id, amount: -10_000)
        state.savings[1].date = date("2026-09-15")
        try state.reserve(goal: state.goals[0].id, account: state.accounts[0].id, amount: 10_000)
        state.savings[2].date = date("2026-09-16")
        let before = state
        XCTAssertThrowsError(try state.reopen(closure))
        XCTAssertEqual(state, before)
    }
    func testPaymentCannotPrecedeRecordedDebt() throws {
        var state = fixture()
        try state.saveEntry(Entry(kind: .expense, amount: 10_000, date: date("2026-09-15"), categoryID: state.categories[0].id, cardID: state.cards[0].id))
        let before = state
        XCTAssertThrowsError(try state.saveEntry(Entry(kind: .cardPayment, amount: 5_000, date: date("2026-09-14"), accountID: state.accounts[0].id, cardID: state.cards[0].id)))
        XCTAssertEqual(state, before)
    }
    func testRejectsOrphanedDebitAndSavings() throws {
        var state = fixture()
        state.cards[1].accountID = UUID()
        XCTAssertThrowsError(try state.validateIntegrity())
        state = fixture()
        state.savings = [SavingsEvent(goalID: UUID(), accountID: state.accounts[0].id, amount: 100)]
        XCTAssertThrowsError(try state.validateIntegrity())
    }
    func testArchivedCategoryCannotBeUsedForNewEntryButHistoryCanBeEdited() throws {
        var state = fixture()
        var entry = Entry(kind: .expense, amount: 100, categoryID: state.categories[0].id, accountID: state.accounts[0].id)
        try state.saveEntry(entry)
        state.categories[0].archived = true
        entry.note = "Corrección permitida"
        try state.saveEntry(entry)
        entry.id = UUID()
        XCTAssertThrowsError(try state.saveEntry(entry))
    }
    func testFullWeekIncomeDebitSavingsAndCarry() throws {
        var state = fixture()
        let week = FinanceDates.week(date("2026-09-07"))
        state.budgets = [WeeklyBudget(week: week, limit: 100_000, categoryLimits: [state.categories[0].id: 30_000])]
        try state.saveEntry(Entry(kind: .income, amount: 100_000, date: date("2026-09-07"), categoryID: state.categories[6].id, accountID: state.accounts[1].id))
        try state.saveEntry(Entry(kind: .expense, amount: 20_000, date: date("2026-09-08"), categoryID: state.categories[0].id, accountID: state.accounts[0].id))
        try state.saveEntry(Entry(kind: .outflow, amount: 10_000, date: date("2026-09-09"), categoryID: state.categories[7].id, accountID: state.accounts[1].id, cardID: state.cards[1].id))
        XCTAssertEqual(state.total, 770_000)
        XCTAssertEqual(state.remaining(week), 70_000)
        try state.close(week: week, saved: 20_000, carried: 30_000, goal: state.goals[0].id, account: state.accounts[1].id)
        XCTAssertEqual(state.total, 770_000)
        XCTAssertEqual(state.available, 750_000)
        XCTAssertEqual(state.carry(into: FinanceDates.addDays(7, to: week)), 30_000)
        XCTAssertEqual(state.spent(week: week), 30_000)
        try state.validateIntegrity()
    }
    func testInterestPurchasePaymentCorrectionAndDeletion() throws {
        var state = fixture()
        var purchase = Entry(kind: .expense, amount: 120_100, date: date("2026-09-07"), categoryID: state.categories[5].id, cardID: state.cards[0].id,
                             months: 3, price: 100_000, firstPayment: date("2026-09-30"))
        try state.saveEntry(purchase)
        XCTAssertEqual(state.installments(purchase).map(\.amount), [40_034, 40_033, 40_033])
        let payment = Entry(kind: .cardPayment, amount: 40_034, date: date("2026-09-30"), accountID: state.accounts[1].id, cardID: state.cards[0].id)
        try state.saveEntry(payment)
        purchase.amount = 130_100
        try state.saveEntry(purchase)
        XCTAssertEqual(state.debt(state.cards[0].id), 90_066)
        XCTAssertEqual(state.spent(week: purchase.date), 130_100)
        let before = state
        XCTAssertThrowsError(try state.deleteEntry(purchase.id))
        XCTAssertEqual(state, before)
        try state.deleteEntry(payment.id)
        try state.deleteEntry(purchase.id)
        XCTAssertEqual(state.total, 700_000)
        XCTAssertEqual(state.debt(state.cards[0].id), 0)
    }
    func testClosedWeekValidationHandlesBoundariesAndUnclosedGaps() throws {
        var state = fixture()
        let first = FinanceDates.week(date("2026-09-07"))
        let third = FinanceDates.addDays(14, to: first)
        state.budgets = [WeeklyBudget(week: first, limit: 1000), WeeklyBudget(week: third, limit: 1000)]
        state.entries = [Entry(kind: .expense, amount: 500, date: FinanceDates.addDays(6, to: first), categoryID: state.categories[0].id, accountID: state.accounts[0].id),
                         Entry(kind: .expense, amount: 10_000, date: FinanceDates.addDays(7, to: first), categoryID: state.categories[0].id, accountID: state.accounts[0].id)]
        state.closures = [WeekClosure(week: first, saved: 0, carried: 500), WeekClosure(week: third, saved: 0, carried: 1000)]
        try state.validateIntegrity()
        state.closures[0].carried = 501
        XCTAssertThrowsError(try state.validateIntegrity())
        state.closures[0].carried = 500
        state.closures[1].carried = 1001
        XCTAssertThrowsError(try state.validateIntegrity())
    }
    func testClosedWeekValidationPreservesDaylightSavingBoundary() throws {
        var state = fixture()
        let week = FinanceDates.week(date("2021-10-25"))
        let sunday = FinanceDates.calendar.date(bySettingHour: 23, minute: 30, second: 0, of: FinanceDates.addDays(6, to: week))!
        state.budgets = [WeeklyBudget(week: week, limit: 1000)]
        state.entries = [Entry(kind: .expense, amount: 600, date: sunday, categoryID: state.categories[0].id, accountID: state.accounts[0].id)]
        state.closures = [WeekClosure(week: week, saved: 0, carried: 400)]
        try state.validateIntegrity()
        state.closures[0].carried = 401
        XCTAssertThrowsError(try state.validateIntegrity())
    }
}
