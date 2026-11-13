import Foundation

extension Ledger {
    func validDate(_ date: Date) -> Bool {
        date.timeIntervalSince1970.isFinite && date >= .distantPast && date <= .distantFuture
    }
    private func validName(_ value: String, maximum: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= maximum
    }

    // Validate shape and bounds before aggregating any money. The maximum
    // amounts and collection sizes keep all sums within Int64 capacity.
    func validateStructure() throws {
        try capture?.validate()
        guard accounts.count <= 1000, cards.count <= 1000, categories.count <= 1000, goals.count <= 1000,
              entries.count <= 100_000, savings.count <= 100_000, budgets.count <= 10_000, closures.count <= 10_000 else {
            throw FinanceError.invalid("Se alcanzó el límite de registros de esta versión.")
        }
        let ids = accounts.map(\.id) + cards.map(\.id) + categories.map(\.id) + goals.map(\.id)
            + entries.map(\.id) + savings.map(\.id) + budgets.map(\.id) + closures.map(\.id)
        guard Set(ids).count == ids.count, !ids.contains(CaptureSettings().id) else { throw FinanceError.invalid("Hay identificadores repetidos. No se modificará el archivo.") }
        let accountIDs = Set(accounts.map(\.id))
        let bankIDs = Set(accounts.filter { !$0.cash }.map(\.id))
        let goalIDs = Set(goals.map(\.id))
        let categoryIDs = Set(categories.map(\.id))
        let closureIDs = Set(closures.map(\.id))
        for account in accounts {
            guard validName(account.name, maximum: 60), (0...Money.maximum).contains(account.opening) else {
                throw FinanceError.invalid("Una cuenta tiene nombre o saldo inicial inválido.")
            }
        }
        for card in cards {
            guard validName(card.name, maximum: 60), (0...Money.maximum).contains(card.openingDebt),
                  (1...31).contains(card.cutDay), (1...31).contains(card.payDay),
                  card.credit ? card.accountID == nil : (card.accountID.map { bankIDs.contains($0) } == true && card.openingDebt == 0) else {
                throw FinanceError.invalid("Una tarjeta tiene datos inválidos o una cuenta bancaria inexistente.")
            }
        }
        for category in categories where !validName(category.name, maximum: 60) {
            throw FinanceError.invalid("Una categoría tiene un nombre inválido.")
        }
        for goal in goals {
            guard validName(goal.name, maximum: 80), goal.target > 0, goal.target <= Money.maximum,
                  goal.deadline.map(validDate) ?? true else { throw FinanceError.invalid("Una meta tiene objetivo o fecha inválidos.") }
        }
        for entry in entries { try validate(entry) }
        for event in savings {
            guard goalIDs.contains(event.goalID), accountIDs.contains(event.accountID), event.amount != 0,
                  event.amount >= -Money.maximum, event.amount <= Money.maximum, validDate(event.date),
                  event.closureID.map({ closureIDs.contains($0) }) ?? true else {
                throw FinanceError.invalid("Una reserva de ahorro tiene referencias, importe o fecha inválidos.")
            }
        }
        guard Set(budgets.map(\.week)).count == budgets.count, Set(closures.map(\.week)).count == closures.count else {
            throw FinanceError.invalid("Una semana tiene presupuestos o cierres duplicados.")
        }
        for budget in budgets {
            guard validDate(budget.week), budget.week == FinanceDates.week(budget.week),
                  (0...Money.maximum).contains(budget.limit),
                  budget.categoryLimits.allSatisfy({ categoryIDs.contains($0.key) && (0...Money.maximum).contains($0.value) }) else {
                throw FinanceError.invalid("Un presupuesto tiene fecha, categoría o límite inválidos.")
            }
        }
        for closure in closures {
            guard validDate(closure.week), closure.week == FinanceDates.week(closure.week), budget(closure.week) != nil,
                  (0...Money.maximum).contains(closure.saved), (0...Money.maximum).contains(closure.carried) else {
                throw FinanceError.invalid("Un cierre tiene referencias o importes inválidos.")
            }
            let linked = savings.filter { $0.closureID == closure.id }
            guard closure.saved == 0 ? linked.isEmpty : (linked.count == 1 && linked[0].amount == closure.saved) else {
                throw FinanceError.invalid("El ahorro de un cierre no coincide con su aportación.")
            }
        }
    }

    func validateHistory() throws {
        let calendar = FinanceDates.calendar
        let creditIDs = Set(cards.filter(\.credit).map(\.id))
        var changes: [UUID: [Date: Cents]] = [:]
        for entry in entries {
            guard let id = entry.cardID, creditIDs.contains(id) else { continue }
            let day = calendar.startOfDay(for: entry.date)
            changes[id, default: [:]][day, default: 0] += entry.kind == .cardPayment ? -entry.amount : entry.amount
        }
        for card in cards where card.credit {
            var outstanding = card.openingDebt
            let days = changes[card.id] ?? [:]
            for day in days.keys.sorted() {
                outstanding += days[day, default: 0]
                guard outstanding >= 0 else {
                    throw FinanceError.invalid("El pago o la modificación supera la deuda registrada a esa fecha. Revisa la fecha, la compra y la deuda inicial.")
                }
            }
        }
        struct ReserveKey: Hashable { var goal: UUID; var account: UUID }
        var held: [ReserveKey: Cents] = [:]
        let ordered = savings.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            // Deposits precede releases at the same timestamp, independent of fetch order.
            return lhs.amount > rhs.amount
        }
        for event in ordered {
            let key = ReserveKey(goal: event.goalID, account: event.accountID)
            held[key, default: 0] += event.amount
            guard held[key, default: 0] >= 0 else {
                throw FinanceError.invalid("Una liberación deja ahorro negativo en su fecha. Revisa las aportaciones relacionadas.")
            }
        }
        // Match expenses to closed-week intervals once, rather than scanning
        // the full history for every closure. Calendar ends preserve DST weeks.
        let weeks = closures.map(\.week).sorted()
        let ends = weeks.map { FinanceDates.addDays(7, to: $0) }
        var weeklySpend: [Date: Cents] = [:]
        if !weeks.isEmpty {
            for entry in entries where entry.kind.consumesBudget {
                var low = 0; var high = weeks.count
                while low < high {
                    let middle = (low + high) / 2
                    if weeks[middle] <= entry.date { low = middle + 1 } else { high = middle }
                }
                let index = low - 1
                if index >= 0 && entry.date < ends[index] { weeklySpend[weeks[index], default: 0] += entry.amount }
            }
        }
        let limits = Dictionary(uniqueKeysWithValues: budgets.map { ($0.week, $0.limit) })
        var incoming: [Date: Cents] = [:]
        for closure in closures { incoming[FinanceDates.addDays(7, to: closure.week), default: 0] += closure.carried }
        for closure in closures {
            let remainder = limits[closure.week, default: 0] + incoming[closure.week, default: 0] - weeklySpend[closure.week, default: 0]
            guard closure.saved + closure.carried <= max(0, remainder) else {
                throw FinanceError.invalid("El cierre reparte más que el sobrante de su semana.")
            }
        }
    }
}
