#if DEBUG || SWIFT_PACKAGE
import Foundation
#if SWIFT_PACKAGE
import FinanceCore
#endif

public enum SyntheticLedger {
    public static let reference = Date(timeIntervalSince1970: 1_792_584_000) // Fixed accounting reference, not the device clock.
    public static func identifier(_ group: Int, _ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-%04X-%012X", group, index + 1))!
    }
    public static func make(count: Int = 10_000) throws -> Ledger {
        var state = Ledger()
        for i in 0..<10 {
            var account = Account(name: i < 5 ? "Banco \(i + 1)" : "Efectivo \(i - 4)", cash: i >= 5, opening: 10_000_000)
            account.id = identifier(1, i); state.accounts.append(account)
        }
        for i in 0..<8 {
            var card = Card(name: "Tarjeta \(i + 1)", credit: i < 5,
                            accountID: i < 5 ? nil : state.accounts[i - 5].id,
                            openingDebt: i < 5 ? 1_000_000 : 0, reminders: false)
            card.id = identifier(2, i); state.cards.append(card)
        }
        let names = ["Alimentación", "Transporte", "Hogar", "Salud", "Compras", "Otros", "Sueldo", "Ocio"]
        for i in 0..<20 {
            var category = Category(i < names.count ? names[i] : "Categoría \(i + 1)")
            category.id = identifier(3, i); state.categories.append(category)
        }
        for i in 0..<6 {
            var goal = Goal(name: "Meta \(i + 1)", target: 1_000_000)
            goal.id = identifier(4, i); state.goals.append(goal)
        }
        var seed: UInt64 = 42
        func random() -> Cents {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Cents((seed >> 32) % 25_000) + 100
        }
        let start = FinanceDates.addDays(-2100, to: FinanceDates.calendar.startOfDay(for: reference))
        for i in 0..<count {
            let day = FinanceDates.addDays(i * 2100 / max(1, count), to: start)
            let card = state.cards[(i / 10) % 5]
            let bank = state.accounts[(i / 10) % 5]
            let cash = state.accounts[5 + (i / 10) % 5]
            let category = state.categories[i % 20]
            let value = random()
            var entry: Entry
            switch i % 10 {
            case 0, 9: entry = Entry(kind: .income, amount: value + 10_000, date: day, categoryID: state.categories[6].id, accountID: bank.id)
            case 1: entry = Entry(kind: .expense, amount: value, date: day, categoryID: category.id, accountID: cash.id)
            case 2:
                let debit = state.cards[5 + (i / 10) % 3]
                entry = Entry(kind: .expense, amount: value, date: day, categoryID: category.id, accountID: debit.accountID, cardID: debit.id)
            case 3: entry = Entry(kind: .expense, amount: value + 2000, date: day, categoryID: category.id, cardID: card.id)
            case 4: entry = Entry(kind: .expense, amount: value + 5000, date: day, categoryID: category.id, cardID: card.id,
                                  months: 3, price: value + 4000, firstPayment: FinanceDates.addDays(30, to: day))
            case 5: entry = Entry(kind: .outflow, amount: value, date: day, categoryID: category.id, accountID: cash.id)
            case 7: entry = Entry(kind: .transfer, amount: value, date: day, accountID: bank.id, destinationID: cash.id)
            case 8: entry = Entry(kind: .cardPayment, amount: 500, date: day, accountID: bank.id, cardID: card.id)
            default: entry = Entry(kind: .expense, amount: value, date: day, categoryID: category.id, accountID: bank.id)
            }
            entry.id = identifier(5, i); entry.note = "Movimiento de prueba \(i + 1)"
            state.entries.append(entry)
        }
        for i in 0..<120 {
            let day = FinanceDates.addDays(i * 10, to: start)
            var deposit = SavingsEvent(goalID: state.goals[i % 6].id, accountID: state.accounts[i % 10].id, amount: 1000, date: day)
            deposit.id = identifier(6, i * 2)
            var release = SavingsEvent(goalID: deposit.goalID, accountID: deposit.accountID, amount: -500, date: FinanceDates.addDays(1, to: day))
            release.id = identifier(6, i * 2 + 1)
            state.savings.append(contentsOf: [deposit, release])
            let week = FinanceDates.addDays((i - 119) * 7, to: FinanceDates.week(reference))
            var budget = WeeklyBudget(week: week, limit: 10_000_000,
                                      categoryLimits: Dictionary(uniqueKeysWithValues: state.categories.map { ($0.id, Cents(1_000_000)) }))
            budget.id = identifier(7, i); state.budgets.append(budget)
            if i % 2 == 0 {
                var closure = WeekClosure(week: week, saved: 0, carried: 1000)
                closure.id = identifier(8, i); state.closures.append(closure)
            }
        }
        try state.validateIntegrity()
        return state
    }
}
#endif
