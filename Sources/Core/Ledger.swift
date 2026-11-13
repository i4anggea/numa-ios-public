import Foundation

public typealias Cents = Int64

public enum FinanceError: Error, LocalizedError, Equatable {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

public enum Money {
    // Keep all user-entered amounts and aggregate arithmetic within Int64 limits.
    public static let maximum: Cents = 100_000_000_000
    public static func parse(_ text: String, allowZero: Bool = false) throws -> Cents {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^\d{1,10}([.,]\d{1,2})?$"#
        guard value.range(of: pattern, options: .regularExpression) != nil,
              let decimal = Decimal(string: value.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) else {
            throw FinanceError.invalid("Introduce un importe sin separadores de miles y con hasta dos decimales.")
        }
        let cents = NSDecimalNumber(decimal: decimal * 100).int64Value
        guard cents >= (allowZero ? 0 : 1), cents <= maximum else {
            throw FinanceError.invalid("El importe debe ser \(allowZero ? "cero o mayor" : "mayor que cero") y no superar $1,000,000,000.")
        }
        return cents
    }
    public static func format(_ cents: Cents) -> String {
        let number = NSDecimalNumber(decimal: Decimal(cents) / 100)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? "MXN —"
    }
    public static func input(_ cents: Cents) -> String {
        NSDecimalNumber(decimal: Decimal(cents) / 100).stringValue
    }
}

public enum EntryKind: String, CaseIterable, Codable, Sendable {
    case income, expense, outflow, transfer, cardPayment
    public var label: String {
        switch self {
        case .income: return "Ingreso"
        case .expense: return "Gasto"
        case .outflow: return "Otro egreso"
        case .transfer: return "Transferencia"
        case .cardPayment: return "Pago de tarjeta"
        }
    }
    public var consumesBudget: Bool { self == .expense || self == .outflow }
}

public struct Account: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var cash: Bool
    public var opening: Cents
    public init(name: String, cash: Bool, opening: Cents) {
        self.name = name; self.cash = cash; self.opening = opening
    }
}
public struct Card: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var credit: Bool
    public var accountID: UUID?
    public var openingDebt: Cents
    public var cutDay: Int
    public var payDay: Int
    public var reminders: Bool
    public init(name: String, credit: Bool, accountID: UUID? = nil, openingDebt: Cents = 0,
                cutDay: Int = 10, payDay: Int = 30, reminders: Bool = true) {
        self.name = name; self.credit = credit; self.accountID = accountID
        self.openingDebt = openingDebt; self.cutDay = cutDay; self.payDay = payDay; self.reminders = reminders
    }
}
public struct Category: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var archived = false
    public init(_ name: String) { self.name = name }
}
public struct Entry: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var kind: EntryKind
    public var amount: Cents
    public var date: Date
    public var categoryID: UUID?
    public var accountID: UUID?
    public var cardID: UUID?
    public var destinationID: UUID?
    public var note: String
    public var months: Int
    public var price: Cents
    public var firstPayment: Date?
    public init(kind: EntryKind, amount: Cents, date: Date = .now, categoryID: UUID? = nil,
                accountID: UUID? = nil, cardID: UUID? = nil, destinationID: UUID? = nil,
                note: String = "", months: Int = 1, price: Cents = 0, firstPayment: Date? = nil) {
        self.kind = kind; self.amount = amount; self.date = date; self.categoryID = categoryID
        self.accountID = accountID; self.cardID = cardID; self.destinationID = destinationID
        self.note = note; self.months = months; self.price = price; self.firstPayment = firstPayment
    }
}
public struct Goal: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var target: Cents
    public var deadline: Date?
    public init(name: String, target: Cents, deadline: Date? = nil) {
        self.name = name; self.target = target; self.deadline = deadline
    }
}
public struct SavingsEvent: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var goalID: UUID
    public var accountID: UUID
    public var amount: Cents // Positive reserves funds; negative releases them.
    public var date: Date
    public var closureID: UUID?
    public init(goalID: UUID, accountID: UUID, amount: Cents, date: Date = .now, closureID: UUID? = nil) {
        self.goalID = goalID; self.accountID = accountID; self.amount = amount; self.date = date; self.closureID = closureID
    }
}
public struct WeeklyBudget: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var week: Date
    public var limit: Cents
    public var categoryLimits: [UUID: Cents]
    public init(week: Date, limit: Cents, categoryLimits: [UUID: Cents] = [:]) {
        self.week = week; self.limit = limit; self.categoryLimits = categoryLimits
    }
}
public struct WeekClosure: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var week: Date
    public var saved: Cents
    public var carried: Cents
    public init(week: Date, saved: Cents, carried: Cents) {
        self.week = week; self.saved = saved; self.carried = carried
    }
}
public struct Installment: Identifiable, Equatable, Sendable {
    public var id: Int
    public var date: Date
    public var amount: Cents
}

public enum FinanceDates {
    // Stable accounting dates; traveling must not move entries across budget weeks.
    public static let calendar: Calendar = {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "America/Mexico_City")!
        result.firstWeekday = 2
        result.minimumDaysInFirstWeek = 4
        return result
    }()
    public static func week(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)!.start
    }
    public static func addDays(_ count: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: count, to: date)!
    }
    public static func monthDate(anchor: Date, offset: Int, day: Int) -> Date {
        let start = calendar.dateInterval(of: .month, for: anchor)!.start
        let month = calendar.date(byAdding: .month, value: offset, to: start)!
        let last = calendar.range(of: .day, in: .month, for: month)!.count
        return calendar.date(byAdding: .day, value: min(max(day, 1), last) - 1, to: month)!
    }
    public static func next(day: Int, after date: Date) -> Date {
        let today = calendar.startOfDay(for: date)
        let candidate = monthDate(anchor: today, offset: 0, day: day)
        return candidate >= today ? candidate : monthDate(anchor: today, offset: 1, day: day)
    }
    public static func label(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

public struct Ledger: Codable, Equatable, Sendable {
    public var capture: CaptureSettings?
    public var accounts: [Account] = []
    public var cards: [Card] = []
    public var categories: [Category] = []
    public var entries: [Entry] = []
    public var goals: [Goal] = []
    public var savings: [SavingsEvent] = []
    public var budgets: [WeeklyBudget] = []
    public var closures: [WeekClosure] = []
    public init() {}
    public static var initial: Ledger {
        var state = Ledger()
        state.categories = ["Alimentación", "Transporte", "Hogar", "Salud", "Entretenimiento", "Compras", "Sueldo", "Otros"].map(Category.init)
        return state
    }
    public func accountBalance(_ id: UUID, until: Date? = nil) -> Cents {
        var result = accounts.first { $0.id == id }?.opening ?? 0
        for entry in entries where until == nil || entry.date < until! {
            if entry.accountID == id {
                if entry.kind == .income { result += entry.amount }
                else { result -= entry.amount }
            }
            if entry.kind == .transfer && entry.destinationID == id { result += entry.amount }
        }
        return result
    }
    public func reserved(account: UUID? = nil, goal: UUID? = nil) -> Cents {
        savings.filter { (account == nil || $0.accountID == account) && (goal == nil || $0.goalID == goal) }.reduce(0) { $0 + $1.amount }
    }
    public var total: Cents { accounts.reduce(0) { $0 + accountBalance($1.id) } }
    public var available: Cents { total - reserved() }
    public func debt(_ id: UUID) -> Cents {
        (cards.first { $0.id == id }?.openingDebt ?? 0) + entries.filter { $0.cardID == id }.reduce(0) {
            $0 + ($1.kind == .cardPayment ? -$1.amount : $1.amount)
        }
    }
    public var totalDebt: Cents { cards.filter(\.credit).reduce(0) { $0 + debt($1.id) } }
    public func spent(week: Date, category: UUID? = nil) -> Cents {
        let start = FinanceDates.week(week)
        let end = FinanceDates.addDays(7, to: start)
        return entries.filter { $0.kind.consumesBudget && $0.date >= start && $0.date < end && (category == nil || $0.categoryID == category) }.reduce(0) { $0 + $1.amount }
    }
    public func budget(_ week: Date) -> WeeklyBudget? { budgets.first { $0.week == FinanceDates.week(week) } }
    public func carry(into week: Date) -> Cents {
        closures.filter { FinanceDates.addDays(7, to: $0.week) == FinanceDates.week(week) }.reduce(0) { $0 + $1.carried }
    }
    public func remaining(_ week: Date) -> Cents { (budget(week)?.limit ?? 0) + carry(into: week) - spent(week: week) }
    public func method(_ entry: Entry) -> String {
        if let card = cards.first(where: { $0.id == entry.cardID }) { return card.name + (card.credit ? " · Crédito" : " · Débito") }
        return accounts.first { $0.id == entry.accountID }?.name ?? "Sin cuenta"
    }
    public func installments(_ entry: Entry) -> [Installment] {
        guard entry.months > 1, let first = entry.firstPayment else { return [] }
        let day = FinanceDates.calendar.component(.day, from: first)
        let base = entry.amount / Cents(entry.months)
        let residual = Int(entry.amount % Cents(entry.months))
        return (0..<entry.months).map { index in
            Installment(id: index + 1, date: FinanceDates.monthDate(anchor: first, offset: index, day: day),
                        amount: base + (index < residual ? 1 : 0))
        }
    }
    public func warnings(for entry: Entry) -> [String] {
        var messages: [String] = []
        if entry.kind != .income, let account = entry.accountID {
            if accountBalance(account) - reserved(account: account) < entry.amount { messages.append("La cuenta quedará con saldo disponible negativo.") }
        }
        if entry.kind.consumesBudget, let budget = budget(entry.date) {
            if remaining(entry.date) < entry.amount { messages.append("Superarás el presupuesto global de esta semana.") }
            if let category = entry.categoryID, let limit = budget.categoryLimits[category], spent(week: entry.date, category: category) + entry.amount > limit {
                messages.append("Superarás el presupuesto de la categoría.")
            }
        }
        return messages
    }

    public mutating func saveEntry(_ entry: Entry) throws {
        let affected = [entry.date, entries.first { $0.id == entry.id }?.date].compactMap { $0 }
        guard !affected.contains(where: { date in closures.contains { $0.week == FinanceDates.week(date) } }) else {
            throw FinanceError.invalid("Deshaz primero el reparto del cierre de esa semana.")
        }
        try validate(entry)
        if let category = categories.first(where: { $0.id == entry.categoryID }), category.archived,
           entries.first(where: { $0.id == entry.id })?.categoryID != entry.categoryID {
            throw FinanceError.invalid("La categoría está archivada. Selecciona una activa o restáurala en Ajustes.")
        }
        let previous = entries
        if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index] = entry }
        else { entries.append(entry) }
        do { try validateIntegrity() } catch { entries = previous; throw error }
    }
    public mutating func deleteEntry(_ id: UUID) throws {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        guard !closures.contains(where: { $0.week == FinanceDates.week(entry.date) }) else {
            throw FinanceError.invalid("Deshaz primero el reparto del cierre de esa semana.")
        }
        let previous = entries
        entries.removeAll { $0.id == id }
        do { try validateIntegrity() } catch { entries = previous; throw error }
    }
    public mutating func reserve(goal: UUID, account: UUID, amount: Cents) throws {
        try validateIntegrity()
        guard goals.contains(where: { $0.id == goal }), accounts.contains(where: { $0.id == account }), amount != 0, amount >= -Money.maximum, amount <= Money.maximum else {
            throw FinanceError.invalid("Selecciona una meta, una cuenta y un importe válido.")
        }
        if amount > 0 {
            guard accountBalance(account) - reserved(account: account) >= amount else { throw FinanceError.invalid("No hay dinero disponible suficiente para reservar en esa cuenta.") }
        } else {
            let held = savings.filter { $0.goalID == goal && $0.accountID == account }.reduce(0) { $0 + $1.amount }
            guard held >= -amount else { throw FinanceError.invalid("No puedes liberar más de lo reservado en esa meta y cuenta.") }
        }
        var candidate = self
        candidate.savings.append(SavingsEvent(goalID: goal, accountID: account, amount: amount))
        try candidate.validateIntegrity()
        self = candidate
    }
    public mutating func close(week: Date, saved: Cents, carried: Cents, goal: UUID?, account: UUID?) throws {
        try validateIntegrity()
        let start = FinanceDates.week(week)
        guard start < FinanceDates.week(.now), budget(start) != nil, !closures.contains(where: { $0.week == start }),
              saved >= 0, carried >= 0, saved <= Money.maximum, carried <= Money.maximum,
              saved + carried <= max(0, remaining(start)) else {
            throw FinanceError.invalid("Solo puedes repartir una semana terminada con presupuesto, sin repetir el cierre ni exceder el sobrante.")
        }
        if carried > 0 && closures.contains(where: { $0.week == FinanceDates.addDays(7, to: start) }) {
            throw FinanceError.invalid("Deshaz primero el cierre de la semana siguiente antes de cambiar su margen recibido.")
        }
        var candidate = self
        let closure = WeekClosure(week: start, saved: saved, carried: carried)
        if saved > 0 {
            guard let goal, let account else { throw FinanceError.invalid("Selecciona meta y cuenta para el ahorro.") }
            try candidate.reserve(goal: goal, account: account, amount: saved)
            candidate.savings[candidate.savings.count - 1].closureID = closure.id
        }
        candidate.closures.append(closure)
        try candidate.validateIntegrity()
        self = candidate
    }
    public mutating func reopen(_ closure: WeekClosure) throws {
        try validateIntegrity()
        guard closures.contains(where: { $0 == closure }) else {
            throw FinanceError.invalid("El cierre ya cambió o no existe. Vuelve a abrir esta pantalla.")
        }
        guard !closures.contains(where: { $0.week == FinanceDates.addDays(7, to: closure.week) }) else {
            throw FinanceError.invalid("Deshaz primero el cierre de la semana siguiente.")
        }
        let linked = savings.filter { $0.closureID == closure.id }
        for item in linked {
            let held = savings.filter { $0.goalID == item.goalID && $0.accountID == item.accountID }.reduce(0) { $0 + $1.amount }
            guard held >= item.amount else { throw FinanceError.invalid("Parte del ahorro del cierre ya se liberó. No puede deshacerse sin afectar otras operaciones.") }
        }
        var candidate = self
        candidate.savings.removeAll { $0.closureID == closure.id }
        candidate.closures.removeAll { $0.id == closure.id }
        do { try candidate.validateIntegrity() }
        catch { throw FinanceError.invalid("No se puede deshacer: una liberación posterior depende del ahorro de este cierre.") }
        self = candidate
    }
    public func validate(_ entry: Entry) throws {
        guard entry.amount > 0, entry.amount <= Money.maximum, entry.note.count <= 500,
              (1...120).contains(entry.months), validDate(entry.date) else {
            throw FinanceError.invalid("Revisa importe, fecha, nota y mensualidades (1 a 120).")
        }
        if entry.kind.consumesBudget || entry.kind == .income {
            guard let category = entry.categoryID, categories.contains(where: { $0.id == category }) else { throw FinanceError.invalid("Selecciona una categoría.") }
        } else if entry.categoryID != nil { throw FinanceError.invalid("Los pagos y transferencias no tienen categoría de ingreso o gasto.") }
        let card = cards.first { $0.id == entry.cardID }
        if entry.kind == .cardPayment {
            guard card?.credit == true, entry.accountID != nil, entry.months == 1 else { throw FinanceError.invalid("Selecciona una tarjeta de crédito y la cuenta de pago.") }
        } else if let card {
            guard entry.kind.consumesBudget else { throw FinanceError.invalid("Este movimiento requiere una cuenta, no una tarjeta.") }
            if card.credit {
                guard entry.accountID == nil else { throw FinanceError.invalid("Una compra de crédito no descuenta efectivo al registrarse.") }
            } else {
                guard entry.accountID == card.accountID else { throw FinanceError.invalid("El débito debe usar su cuenta vinculada.") }
            }
        } else {
            guard entry.cardID == nil, entry.accountID != nil else { throw FinanceError.invalid("Selecciona un método de pago válido.") }
        }
        if let account = entry.accountID, !accounts.contains(where: { $0.id == account }) { throw FinanceError.invalid("No existe la cuenta seleccionada.") }
        if entry.kind == .transfer {
            guard let target = entry.destinationID, target != entry.accountID, accounts.contains(where: { $0.id == target }) else { throw FinanceError.invalid("Selecciona una cuenta de destino diferente.") }
        } else if entry.destinationID != nil { throw FinanceError.invalid("Este movimiento no admite cuenta destino.") }
        if entry.months > 1 {
            guard entry.kind.consumesBudget, card?.credit == true, entry.price > 0, entry.price <= entry.amount,
                  let first = entry.firstPayment, validDate(first), first >= FinanceDates.calendar.startOfDay(for: entry.date), entry.amount >= Cents(entry.months) else {
                throw FinanceError.invalid("Revisa precio, total y primera fecha de pago del plan de crédito.")
            }
        } else if entry.price != 0 || entry.firstPayment != nil {
            throw FinanceError.invalid("Un movimiento sin plan no debe conservar datos de mensualidades.")
        }
    }
    public func validateIntegrity() throws {
        try validateStructure()
        try validateHistory()
    }
}
