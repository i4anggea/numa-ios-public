#if DEBUG
import Foundation

// Only reachable for an explicitly isolated UI test store. Never used by Release.
enum UITestFixtures {
    static func make(_ scenario: String) throws -> Ledger {
        if scenario == "large" { return try SyntheticLedger.make() }
        var state = Ledger.initial
        let week = FinanceDates.addDays(-7, to: FinanceDates.week(.now))
        if scenario == "shortcuts" {
            state.accounts = [Account(name: "Efectivo", cash: true, opening: 20_000), Account(name: "Banco", cash: false, opening: 100_000)]
            state.cards = [Card(name: "Santander ficticia", credit: false, accountID: state.accounts[1].id, reminders: false)]
            var settings = CaptureSettings()
            settings.cashID = state.accounts[0].id; settings.categoryID = state.categories[0].id
            settings.santanderCardID = state.cards[0].id
            settings.rules = [MerchantRule(merchant: "Mercado Libre", categoryID: state.categories[0].id)]
            try settings.receive(CaptureDraft(source: .santanderNotification, merchant: "Mercado Libre", cardID: state.cards[0].id))
            try settings.receive(CaptureDraft(source: .santanderEmail, merchant: "Mercado Libre", cardID: state.cards[0].id))
            state.capture = settings
        } else if scenario == "week" {
            state.accounts = [Account(name: "Efectivo", cash: true, opening: 0), Account(name: "Banco", cash: false, opening: 0)]
            let cash = state.accounts[0].id
            let bank = state.accounts[1].id
            state.cards = [Card(name: "Débito de prueba", credit: false, accountID: bank, reminders: false)]
            state.goals = [Goal(name: "Fondo", target: 500_000)]
            state.budgets = [WeeklyBudget(week: week, limit: 100_000, categoryLimits: [state.categories[0].id: 30_000])]
            try state.saveEntry(Entry(kind: .income, amount: 200_000, date: week, categoryID: state.categories[6].id, accountID: bank, note: "Ingreso de prueba"))
            try state.saveEntry(Entry(kind: .transfer, amount: 50_000, date: week, accountID: bank, destinationID: cash))
            try state.saveEntry(Entry(kind: .expense, amount: 20_000, date: FinanceDates.addDays(1, to: week), categoryID: state.categories[0].id, accountID: cash, note: "Comida de prueba"))
            try state.saveEntry(Entry(kind: .outflow, amount: 10_000, date: FinanceDates.addDays(2, to: week), categoryID: state.categories[7].id, accountID: bank, cardID: state.cards[0].id, note: "Otro egreso de prueba"))
        } else if scenario == "credit" {
            state.accounts = [Account(name: "Banco", cash: false, opening: 500_000)]
            state.cards = [Card(name: "Crédito de prueba", credit: true, reminders: false)]
            try state.saveEntry(Entry(kind: .expense, amount: 120_100, date: week,
                                     categoryID: state.categories[5].id, cardID: state.cards[0].id,
                                     note: "Compra de prueba", months: 3, price: 100_000,
                                     firstPayment: FinanceDates.addDays(14, to: week)))
        } else { throw FinanceError.invalid("Escenario de prueba desconocido.") }
        return state
    }
}
#endif
