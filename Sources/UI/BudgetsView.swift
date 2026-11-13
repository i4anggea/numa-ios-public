import SwiftUI

struct BudgetsView: View {
    @Environment(FinanceStore.self) private var store
    @State private var week = FinanceDates.week(.now)
    @State private var editing = false
    @State private var closing = false
    @State private var reopening = false
    var closure: WeekClosure? { store.ledger.closures.first { $0.week == week } }
    var body: some View {
        List {
            Section {
                HStack {
                    Button { week = FinanceDates.addDays(-7, to: week) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Semana anterior")
                    Spacer()
                    Text("\(FinanceDates.label(week))\n\(FinanceDates.label(FinanceDates.addDays(6, to: week)))").font(.subheadline).multilineTextAlignment(.center)
                    Spacer()
                    Button { week = FinanceDates.addDays(7, to: week) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Semana siguiente")
                }.buttonStyle(.borderless)
            }
            if let budget = store.ledger.budget(week) {
                Section("Presupuesto global") {
                    LabeledContent("Límite base") { Amount(value: budget.limit) }
                    LabeledContent("Margen recibido de la semana anterior") { Amount(value: store.ledger.carry(into: week)) }
                    LabeledContent("Gastos y otros egresos") { Amount(value: store.ledger.spent(week: week)) }
                    LabeledContent("Restante") { Amount(value: store.ledger.remaining(week)) }
                    if store.ledger.remaining(week) < 0 { Label("Presupuesto superado", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                    if closure == nil { Button("Editar límites") { editing = true } }
                }
                Section("Por categoría") {
                    ForEach(store.ledger.categories.filter { budget.categoryLimits[$0.id] != nil }) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category.name).font(.headline)
                            HStack { Text("Gastado"); Spacer(); Amount(value: store.ledger.spent(week: week, category: category.id)) }
                            HStack { Text("Límite"); Spacer(); Amount(value: budget.categoryLimits[category.id] ?? 0) }
                        }.font(.subheadline)
                    }
                    if budget.categoryLimits.isEmpty { Text("Puedes añadir límites por categoría al editar.").foregroundStyle(.secondary) }
                    Text("Cada egreso cuenta una vez en el global y en su categoría. Los límites no se suman como si fueran gastos.").font(.caption).foregroundStyle(.secondary)
                }
                if let closure {
                    Section("Semana cerrada") {
                        LabeledContent("Destinado a ahorro") { Amount(value: closure.saved) }
                        LabeledContent("Margen para la siguiente semana") { Amount(value: closure.carried) }
                        Button("Deshacer reparto", role: .destructive) { reopening = true }
                    }
                } else if week < FinanceDates.week(.now) {
                    Section { Button("Cerrar y repartir sobrante") { closing = true } }
                }
            } else {
                ContentUnavailableView {
                    Label("Semana sin presupuesto", systemImage: "chart.pie")
                } description: { Text("Define un límite global y, si quieres, límites por categoría.") }
                actions: { Button("Crear presupuesto") { editing = true }.buttonStyle(.borderedProminent) }
                if store.ledger.carry(into: week) > 0 { LabeledContent("Margen recibido, pendiente de presupuesto") { Amount(value: store.ledger.carry(into: week)) } }
            }
        }
        .sheet(isPresented: $editing) { NavigationStack { BudgetEditor(week: week) }.accountingDates() }
        .sheet(isPresented: $closing) { NavigationStack { ClosureEditor(week: week) }.accountingDates() }
        .confirmationDialog("¿Deshacer el reparto? Se retirará el margen trasladado y se revertirá el ahorro del cierre si todavía puede liberarse.", isPresented: $reopening, titleVisibility: .visible) {
            Button("Deshacer reparto", role: .destructive) { if let closure { store.change { try $0.reopen(closure) } } }
        }
    }
}

struct BudgetEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var week: Date
    @State private var limit = ""
    @State private var limits: [UUID: String] = [:]
    @State private var error: String?
    var body: some View {
        Form {
            Section("Semana del \(FinanceDates.label(week))") {
                AmountInput(title: "Límite global semanal", text: $limit)
                Text("El margen recibido se añade al límite global. Los límites por categoría se configuran por separado para esta semana.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Límites por categoría (opcionales)") {
                ForEach(store.ledger.categories.filter { !$0.archived }) { category in
                    AmountInput(title: category.name, text: Binding(get: { limits[category.id] ?? "" }, set: { limits[category.id] = $0 }))
                }
                Text("Deja vacío para no establecer límite individual. Cero significa que esa categoría no tiene margen de gasto.").font(.caption)
            }
            InlineError(message: error)
        }
        .navigationTitle("Presupuesto semanal")
        .financeKeyboard()
        .formError($error)
        .onAppear {
            if let budget = store.ledger.budget(week) {
                limit = Money.input(budget.limit)
                limits = budget.categoryLimits.mapValues(Money.input)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save) }
        }
    }
    private func save() {
        do {
            let global = try Money.parse(limit, allowZero: true)
            var categoryLimits: [UUID: Cents] = [:]
            for (id, value) in limits where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { categoryLimits[id] = try Money.parse(value, allowZero: true) }
            if store.change({ state in
                guard !state.closures.contains(where: { $0.week == week }) else { throw FinanceError.invalid("Deshaz el cierre antes de cambiar sus límites.") }
                var value = WeeklyBudget(week: week, limit: global, categoryLimits: categoryLimits)
                if let index = state.budgets.firstIndex(where: { $0.week == week }) { value.id = state.budgets[index].id; state.budgets[index] = value }
                else { state.budgets.append(value) }
            }) { dismiss() } else { error = store.errorMessage; store.errorMessage = nil }
        } catch { self.error = error.localizedDescription }
    }
}
struct ClosureEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var week: Date
    @State private var saved = "0"
    @State private var carried = "0"
    @State private var goal: UUID?
    @State private var account: UUID?
    @State private var error: String?
    var body: some View {
        Form {
            Section {
                LabeledContent("Sobrante de planificación") { Amount(value: max(0, store.ledger.remaining(week))) }
                AmountInput(title: "Reservar para ahorro", text: $saved)
                Picker("Meta", selection: $goal) {
                    Text("Selecciona si vas a ahorrar").tag(nil as UUID?)
                    ForEach(store.ledger.goals) { Text($0.name).tag(Optional($0.id)) }
                }
                .accessibilityIdentifier("closure.goal")
                Picker("Reservar desde", selection: $account) {
                    Text("Selecciona").tag(nil as UUID?)
                    ForEach(store.ledger.accounts) { Text($0.paymentLabel).tag(Optional($0.id)) }
                }
                .accessibilityIdentifier("closure.account")
                AmountInput(title: "Añadir al límite global siguiente", text: $carried)
                if let a = try? Money.parse(saved, allowZero: true), let b = try? Money.parse(carried, allowZero: true) {
                    LabeledContent("Sin asignar") { Amount(value: max(0, store.ledger.remaining(week)) - a - b) }
                }
                Text("El sobrante es margen de presupuesto. Para ahorrar necesitas dinero real en efectivo o en la cuenta. El traslado solo amplía el límite global de la siguiente semana; no crea un ingreso ni mueve dinero.").font(.caption).foregroundStyle(.secondary)
            }
            InlineError(message: error)
        }.navigationTitle("Repartir sobrante")
            .financeKeyboard()
            .formError($error)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Confirmar") {
                    do {
                        let a = try Money.parse(saved, allowZero: true)
                        let b = try Money.parse(carried, allowZero: true)
                        if store.change({ try $0.close(week: week, saved: a, carried: b, goal: goal, account: account) }) { dismiss() }
                        else { error = store.errorMessage; store.errorMessage = nil }
                    } catch { self.error = error.localizedDescription }
                } }
            }
    }
}
