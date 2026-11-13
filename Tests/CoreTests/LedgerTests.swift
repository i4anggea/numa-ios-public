import XCTest
@testable import FinanceCore

final class LedgerTests: XCTestCase {
    func fixture() -> Ledger {
        var state = Ledger.initial
        state.accounts = [Account(name: "Efectivo", cash: true, opening: 200_000), Account(name: "Banco", cash: false, opening: 500_000)]
        state.cards = [Card(name: "Crédito", credit: true), Card(name: "Débito", credit: false, accountID: state.accounts[1].id)]
        return state
    }
    func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value + "T12:00:00Z")! }

    func testMoneyParsingRejectsAmbiguityAndPrecisionLoss() throws {
        XCTAssertEqual(try Money.parse("123.45"), 12345)
        XCTAssertEqual(try Money.parse("0,01"), 1)
        XCTAssertEqual(try Money.parse("0", allowZero: true), 0)
        for input in ["-1", "1,000.00", "1.001", "NaN", "", "1e3", "0", "1000000001"] { XCTAssertThrowsError(try Money.parse(input), input) }
    }
    func testCreditPurchaseAndPaymentDoNotDuplicateBudget() throws {
        var state = fixture()
        let account = state.accounts[0].id
        let card = state.cards[0].id
        var purchase = Entry(kind: .expense, amount: 120_000, categoryID: state.categories[0].id, cardID: card,
                             months: 3, price: 120_000, firstPayment: .now)
        purchase.date = FinanceDates.calendar.startOfDay(for: .now)
        try state.saveEntry(purchase)
        XCTAssertEqual(state.total, 700_000)
        XCTAssertEqual(state.debt(card), 120_000)
        XCTAssertEqual(state.spent(week: .now), 120_000)
        try state.saveEntry(Entry(kind: .cardPayment, amount: 40_000, accountID: account, cardID: card))
        XCTAssertEqual(state.total, 660_000)
        XCTAssertEqual(state.debt(card), 80_000)
        XCTAssertEqual(state.spent(week: .now), 120_000)
        XCTAssertEqual(state.installments(purchase).map(\.amount), [40_000, 40_000, 40_000])
    }
    func testDebitUsesLinkedAccountAndTransfersAreNeutral() throws {
        var state = fixture()
        try state.saveEntry(Entry(kind: .expense, amount: 10_000, categoryID: state.categories[0].id,
                                 accountID: state.accounts[1].id, cardID: state.cards[1].id))
        XCTAssertEqual(state.accountBalance(state.accounts[1].id), 490_000)
        try state.saveEntry(Entry(kind: .transfer, amount: 20_000, accountID: state.accounts[1].id, destinationID: state.accounts[0].id))
        XCTAssertEqual(state.total, 690_000)
        XCTAssertEqual(state.spent(week: .now), 10_000)
    }
    func testSavingsReserveAndReleaseDoNotChangeTotal() throws {
        var state = fixture()
        let goal = Goal(name: "Viaje", target: 100_000)
        state.goals = [goal]
        try state.reserve(goal: goal.id, account: state.accounts[0].id, amount: 10_000)
        XCTAssertEqual(state.total, 700_000)
        XCTAssertEqual(state.available, 690_000)
        try state.reserve(goal: goal.id, account: state.accounts[0].id, amount: -4_000)
        XCTAssertEqual(state.available, 694_000)
        XCTAssertThrowsError(try state.reserve(goal: goal.id, account: state.accounts[1].id, amount: -1))
        XCTAssertThrowsError(try state.reserve(goal: goal.id, account: state.accounts[0].id, amount: 999_999))
    }
    func testWeekBoundariesAndCategoryTotals() throws {
        var state = fixture()
        let monday = FinanceDates.week(date("2026-10-19"))
        let sunday = FinanceDates.addDays(6, to: monday)
        let next = FinanceDates.addDays(7, to: monday)
        let category = state.categories[0].id
        for (day, amount) in [(monday, Cents(100)), (sunday, 200), (next, 400)] {
            try state.saveEntry(Entry(kind: .outflow, amount: amount, date: day, categoryID: category, accountID: state.accounts[0].id))
        }
        XCTAssertEqual(state.spent(week: monday), 300)
        XCTAssertEqual(state.spent(week: monday, category: category), 300)
        XCTAssertEqual(state.spent(week: next), 400)
    }
    func testInstallmentsPreserveCentsAndMonthAnchor() {
        let state = fixture()
        let entry = Entry(kind: .expense, amount: 100_001, cardID: state.cards[0].id,
                          months: 3, price: 90_000, firstPayment: date("2027-01-31"))
        let plan = state.installments(entry)
        XCTAssertEqual(plan.map(\.amount), [33_334, 33_334, 33_333])
        XCTAssertEqual(plan.reduce(0) { $0 + $1.amount }, entry.amount)
        XCTAssertEqual(plan.map { FinanceDates.calendar.component(.day, from: $0.date) }, [31, 28, 31])
    }
    func testCloseCarryAndReopen() throws {
        var state = fixture()
        let week = FinanceDates.week(date("2026-09-07"))
        state.budgets = [WeeklyBudget(week: week, limit: 100_000)]
        state.goals = [Goal(name: "Reserva", target: 200_000)]
        try state.close(week: week, saved: 20_000, carried: 30_000, goal: state.goals[0].id, account: state.accounts[0].id)
        XCTAssertEqual(state.carry(into: FinanceDates.addDays(7, to: week)), 30_000)
        XCTAssertEqual(state.total, 700_000)
        XCTAssertEqual(state.available, 680_000)
        XCTAssertThrowsError(try state.close(week: week, saved: 0, carried: 0, goal: nil, account: nil))
        XCTAssertThrowsError(try state.saveEntry(Entry(kind: .expense, amount: 1, date: week, categoryID: state.categories[0].id, accountID: state.accounts[0].id)))
        try state.reopen(state.closures[0])
        XCTAssertEqual(state.available, 700_000)
        XCTAssertTrue(state.closures.isEmpty)
    }
    func testReopenCannotRemoveReleasedSavings() throws {
        var state = fixture()
        let week = FinanceDates.week(date("2026-09-07"))
        state.budgets = [WeeklyBudget(week: week, limit: 100_000)]
        let goal = Goal(name: "Reserva", target: 200_000)
        state.goals = [goal]
        try state.close(week: week, saved: 20_000, carried: 0, goal: goal.id, account: state.accounts[0].id)
        try state.reserve(goal: goal.id, account: state.accounts[0].id, amount: -10_000)
        XCTAssertThrowsError(try state.reopen(state.closures[0]))
    }
    func testWarningsAllowHistoricalNegativeBalances() throws {
        var state = fixture()
        let entry = Entry(kind: .expense, amount: 300_000, categoryID: state.categories[0].id, accountID: state.accounts[0].id)
        XCTAssertFalse(state.warnings(for: entry).isEmpty)
        try state.saveEntry(entry)
        XCTAssertEqual(state.accountBalance(state.accounts[0].id), -100_000)
    }
    func testCannotOverpayCredit() throws {
        var state = fixture()
        let before = state
        XCTAssertThrowsError(try state.saveEntry(Entry(kind: .cardPayment, amount: 1, accountID: state.accounts[0].id, cardID: state.cards[0].id)))
        XCTAssertEqual(state, before, "Una operación inválida no debe mutar el registro")
    }
    func testEditingAndDeletionRecalculateBalances() throws {
        var state = fixture()
        var entry = Entry(kind: .expense, amount: 12_500, categoryID: state.categories[0].id, accountID: state.accounts[0].id)
        try state.saveEntry(entry)
        XCTAssertEqual(state.total, 687_500)
        entry.amount = 20_000
        try state.saveEntry(entry)
        XCTAssertEqual(state.entries.count, 1)
        XCTAssertEqual(state.total, 680_000)
        try state.deleteEntry(entry.id)
        XCTAssertEqual(state.total, 700_000)
        XCTAssertEqual(state.spent(week: .now), 0)
    }
    func testCannotDeletePurchaseThatWouldMakePaidDebtNegative() throws {
        var state = fixture()
        let purchase = Entry(kind: .expense, amount: 10_000, categoryID: state.categories[0].id, cardID: state.cards[0].id)
        try state.saveEntry(purchase)
        try state.saveEntry(Entry(kind: .cardPayment, amount: 10_000, accountID: state.accounts[0].id, cardID: state.cards[0].id))
        let before = state
        XCTAssertThrowsError(try state.deleteEntry(purchase.id))
        XCTAssertEqual(state, before)
    }
}
