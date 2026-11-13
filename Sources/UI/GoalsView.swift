import SwiftUI

struct GoalsView: View {
    @Environment(FinanceStore.self) private var store
    @State private var creating = false
    var body: some View {
        List {
            if store.ledger.goals.isEmpty {
                ContentUnavailableView("Tu próxima meta", systemImage: "target", description: Text("Elige un objetivo y aparta dinero sin perder de vista tu saldo disponible."))
            }
            ForEach(store.ledger.goals) { goal in
                NavigationLink { GoalDetail(goalID: goal.id) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(goal.name).font(.headline)
                        GoalProgress(saved: store.ledger.reserved(goal: goal.id), target: goal.target)
                        HStack { Amount(value: store.ledger.reserved(goal: goal.id)); Text("de").foregroundStyle(.secondary); Amount(value: goal.target) }.font(.subheadline)
                        if let deadline = goal.deadline { Text("Objetivo: " + FinanceDates.label(deadline)).font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical, 4)
                }
            }
            Button("Crear meta de ahorro", systemImage: "plus") { creating = true }
        }.sheet(isPresented: $creating) { NavigationStack { GoalEditor() }.accountingDates() }
    }
}
struct GoalDetail: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var goalID: UUID
    @State private var editing = false
    @State private var funding = false
    @State private var deleting = false
    var goal: Goal? { store.ledger.goals.first { $0.id == goalID } }
    var body: some View {
        List {
            if let goal {
                Section {
                    GoalProgress(saved: store.ledger.reserved(goal: goal.id), target: goal.target)
                    LabeledContent("Objetivo") { Amount(value: goal.target) }
                    LabeledContent("Reservado") { Amount(value: store.ledger.reserved(goal: goal.id)) }
                    LabeledContent("Falta") { Amount(value: max(0, goal.target - store.ledger.reserved(goal: goal.id))) }
                    if let deadline = goal.deadline {
                        LabeledContent("Fecha objetivo", value: FinanceDates.label(deadline))
                        let days = max(1, FinanceDates.calendar.dateComponents([.day], from: .now, to: deadline).day ?? 1)
                        let weeks = Cents(max(1, (days + 6) / 7))
                        let pending = max(0, goal.target - store.ledger.reserved(goal: goal.id))
                        LabeledContent("Sugerencia semanal") { Amount(value: (pending + weeks - 1) / weeks) }
                        Text("La sugerencia es orientativa; las aportaciones siempre son manuales.").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Aportar o liberar dinero") { funding = true }
                    Button("Editar meta") { editing = true }
                }
                Section("Historial de reservas") {
                    ForEach(store.ledger.savings.filter { $0.goalID == goalID }.sorted { $0.date > $1.date }) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.amount > 0 ? "Aportación" : "Liberación")
                            HStack { Text(store.ledger.accounts.first { $0.id == item.accountID }?.name ?? "Cuenta"); Spacer(); Amount(value: abs(item.amount)) }.font(.subheadline)
                            Text(FinanceDates.label(item.date)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Button("Eliminar meta", role: .destructive) { deleting = true }
                    Text("Solo se puede eliminar una meta sin reservas ni historial. Las metas con historial se conservan para mantener la trazabilidad.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.navigationTitle(goal?.name ?? "Meta")
            .sheet(isPresented: $editing) {
                if let goal { NavigationStack { GoalEditor(existing: goal) }.accountingDates() }
            }
            .sheet(isPresented: $funding) { NavigationStack { SavingsEditor(goalID: goalID) }.accountingDates() }
            .confirmationDialog("¿Eliminar la meta?", isPresented: $deleting) {
                Button("Eliminar", role: .destructive) {
                    if store.change({ state in
                        guard !state.savings.contains(where: { $0.goalID == goalID }) else { throw FinanceError.invalid("Conserva las metas con historial. Puedes liberar sus reservas.") }
                        state.goals.removeAll { $0.id == goalID }
                    }) { dismiss() }
                }
            }
    }
}
struct GoalEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: Goal?
    @State private var name: String
    @State private var target: String
    @State private var dated: Bool
    @State private var deadline: Date
    @State private var error: String?
    init(existing: Goal? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _target = State(initialValue: existing.map { Money.input($0.target) } ?? "")
        _dated = State(initialValue: existing?.deadline != nil)
        _deadline = State(initialValue: existing?.deadline ?? FinanceDates.addDays(90, to: .now))
    }
    var body: some View {
        Form {
            Section {
                TextField("Nombre", text: $name)
                AmountInput(title: "Importe objetivo", text: $target)
                Toggle("Fecha objetivo", isOn: $dated)
                if dated { DatePicker("Fecha", selection: $deadline, displayedComponents: .date) }
            }
            InlineError(message: error)
        }.navigationTitle(existing == nil ? "Nueva meta" : "Editar meta")
            .financeKeyboard()
            .formError($error)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") {
                    do {
                        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleaned.isEmpty, cleaned.count <= 80 else { throw FinanceError.invalid("Escribe un nombre de hasta 80 caracteres.") }
                        var goal = Goal(name: cleaned, target: try Money.parse(target), deadline: dated ? deadline : nil)
                        if let existing { goal.id = existing.id }
                        if store.change({ state in
                            if let index = state.goals.firstIndex(where: { $0.id == goal.id }) { state.goals[index] = goal }
                            else { state.goals.append(goal) }
                        }) { dismiss() } else { error = store.errorMessage; store.errorMessage = nil }
                    } catch { self.error = error.localizedDescription }
                } }
            }
    }
}
struct SavingsEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var goalID: UUID
    @State private var releasing = false
    @State private var account: UUID?
    @State private var amount = ""
    @State private var error: String?
    var body: some View {
        Form {
            Section {
                Picker("Acción", selection: $releasing) { Text("Aportar").tag(false); Text("Liberar").tag(true) }.pickerStyle(.segmented)
                Picker("Efectivo o cuenta", selection: $account) {
                    Text("Selecciona").tag(nil as UUID?)
                    ForEach(store.ledger.accounts) { Text($0.paymentLabel).tag(Optional($0.id)) }
                }
                .accessibilityIdentifier("savings.account")
                if let account {
                    if releasing {
                        let held = store.ledger.savings.filter { $0.goalID == goalID && $0.accountID == account }.reduce(0) { $0 + $1.amount }
                        LabeledContent("Reservado en este origen") { Amount(value: held) }
                    } else { LabeledContent("Disponible en este origen") { Amount(value: store.ledger.accountBalance(account) - store.ledger.reserved(account: account)) } }
                }
                AmountInput(title: "Importe", text: $amount)
                Text(releasing ? "El dinero vuelve a estar disponible en el mismo origen. No se registra un ingreso." : "El dinero sigue en el origen elegido, pero se separa de lo disponible para gastar.").font(.caption).foregroundStyle(.secondary)
            }
            InlineError(message: error)
        }.navigationTitle(releasing ? "Liberar ahorro" : "Aportar a la meta")
            .financeKeyboard()
            .formError($error)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Confirmar") {
                    do {
                        guard let account else { throw FinanceError.invalid("Selecciona efectivo o una cuenta.") }
                        let value = try Money.parse(amount)
                        if store.change({ try $0.reserve(goal: goalID, account: account, amount: releasing ? -value : value) }) { dismiss() }
                        else { error = store.errorMessage; store.errorMessage = nil }
                    } catch { self.error = error.localizedDescription }
                } }
            }
    }
}
