import SwiftUI

struct AccountsView: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var accountEditor = false
    @State private var cardEditor = false
    @State private var cashEditor = false
    var body: some View {
        List {
            Section("Saldos") {
                LabeledContent("Dinero total") { Amount(value: store.ledger.total) }
                LabeledContent("Reservado para metas") { Amount(value: store.ledger.reserved()) }
                LabeledContent("Disponible") { Amount(value: store.ledger.available) }
            }
            Section("Efectivo") {
                ForEach(store.ledger.accounts.filter(\.cash)) { account in
                    NavigationLink { AccountDetail(accountID: account.id) } label: {
                        HStack { Label(account.paymentLabel, systemImage: "banknote"); Spacer(); Amount(value: store.ledger.accountBalance(account.id)) }
                    }
                }
                Button("Añadir efectivo", systemImage: "plus") { cashEditor = true }
            }
            Section("Cuentas bancarias") {
                ForEach(store.ledger.accounts.filter { !$0.cash }) { account in
                    NavigationLink { AccountDetail(accountID: account.id) } label: {
                        HStack { Label(account.name, systemImage: account.cash ? "banknote" : "building.columns"); Spacer(); Amount(value: store.ledger.accountBalance(account.id)) }
                    }
                }
                Button("Añadir cuenta bancaria", systemImage: "plus") { accountEditor = true }
            }
            Section("Tarjetas") {
                ForEach(store.ledger.cards) { card in
                    NavigationLink { CardDetail(cardID: card.id) } label: {
                        VStack(alignment: .leading) {
                            Label(card.name, systemImage: "creditcard")
                            Text(card.credit ? "Crédito · deuda registrada" : "Débito · " + (store.ledger.accounts.first { $0.id == card.accountID }?.name ?? "Cuenta"))
                                .font(.caption).foregroundStyle(.secondary)
                            if card.credit { Amount(value: store.ledger.debt(card.id)) }
                        }
                    }
                }
                Button("Añadir tarjeta", systemImage: "plus") { cardEditor = true }
            }
            Section { Text("Las tarjetas de débito usan el saldo de su cuenta. El crédito disponible no se suma a tu dinero.").font(.caption).foregroundStyle(.secondary) }
        }
        .navigationTitle("Tu dinero")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        .sheet(isPresented: $accountEditor) { NavigationStack { AccountEditor() }.accountingDates() }
        .sheet(isPresented: $cashEditor) { NavigationStack { AccountEditor(cash: true) }.accountingDates() }
        .sheet(isPresented: $cardEditor) { NavigationStack { CardEditor() }.accountingDates() }
    }
}
struct AccountDetail: View {
    @Environment(FinanceStore.self) private var store
    var accountID: UUID
    @State private var editing = false
    var body: some View {
        List {
            if store.ledger.accounts.contains(where: { $0.id == accountID }) {
                Section {
                    LabeledContent("Saldo") { Amount(value: store.ledger.accountBalance(accountID)) }
                    LabeledContent("Reservado") { Amount(value: store.ledger.reserved(account: accountID)) }
                    LabeledContent("Disponible") { Amount(value: store.ledger.accountBalance(accountID) - store.ledger.reserved(account: accountID)) }
                    Button(store.ledger.accounts.first { $0.id == accountID }?.cash == true ? "Editar efectivo" : "Editar cuenta") { editing = true }
                }
                Section("Gasto directo · todo el historial") {
                    Amount(value: store.ledger.entries.filter { $0.accountID == accountID && $0.cardID == nil && $0.kind.consumesBudget }.reduce(0) { $0 + $1.amount })
                }
                Section("Movimientos relacionados") {
                    ForEach(store.ledger.entries.filter { $0.accountID == accountID || $0.destinationID == accountID }.sorted { $0.date > $1.date }) { entry in
                        NavigationLink { EntryDetail(entryID: entry.id) } label: { EntryRow(entry: entry) }
                    }
                }
            }
        }.navigationTitle(store.ledger.accounts.first { $0.id == accountID }?.name ?? "Cuenta")
            .sheet(isPresented: $editing) {
                if let account = store.ledger.accounts.first(where: { $0.id == accountID }) {
                    NavigationStack { AccountEditor(existing: account) }.accountingDates()
                }
            }
    }
}
struct AccountEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: Account?
    var onSaved: ((UUID) -> Void)?
    @State private var name: String
    @State private var cash: Bool
    @State private var opening: String
    @State private var error: String?
    init(existing: Account? = nil, cash: Bool = false, onSaved: ((UUID) -> Void)? = nil) {
        self.existing = existing
        self.onSaved = onSaved
        _name = State(initialValue: existing?.name ?? (cash ? "Efectivo" : ""))
        _cash = State(initialValue: existing?.cash ?? cash)
        _opening = State(initialValue: existing.map { Money.input($0.opening) } ?? "0")
    }
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(cash ? "Nombre del efectivo" : "Nombre").font(.caption).foregroundStyle(.secondary)
                    TextField("Nombre", text: $name).accessibilityIdentifier("account.name")
                }
                LabeledContent("Método", value: cash ? "Efectivo" : "Cuenta bancaria")
                AmountInput(title: "Saldo inicial", text: $opening)
                Text("El saldo inicial es el dinero que tenías antes de los movimientos registrados. No cuenta como ingreso.").font(.caption).foregroundStyle(.secondary)
            }
            InlineError(message: error)
        }.navigationTitle(cash ? (existing == nil ? "Añadir efectivo" : "Editar efectivo") : (existing == nil ? "Nueva cuenta" : "Editar cuenta"))
            .financeKeyboard()
            .formError($error)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save) }
            }
    }
    private func save() {
        do {
            let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, cleaned.count <= 60 else { throw FinanceError.invalid("Escribe un nombre de hasta 60 caracteres.") }
            var account = Account(name: cleaned, cash: cash, opening: try Money.parse(opening, allowZero: true))
            if let existing { account.id = existing.id }
            if store.change({ state in
                if let index = state.accounts.firstIndex(where: { $0.id == account.id }) { state.accounts[index] = account }
                else { state.accounts.append(account) }
            }) { onSaved?(account.id); dismiss() } else { error = store.errorMessage; store.errorMessage = nil }
        } catch { self.error = error.localizedDescription }
    }
}
struct CardEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: Card?
    @State private var name: String
    @State private var credit: Bool
    @State private var account: UUID?
    @State private var opening: String
    @State private var cut: Int
    @State private var pay: Int
    @State private var reminders: Bool
    @State private var error: String?
    init(existing: Card? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _credit = State(initialValue: existing?.credit ?? true)
        _account = State(initialValue: existing?.accountID)
        _opening = State(initialValue: existing.map { Money.input($0.openingDebt) } ?? "0")
        _cut = State(initialValue: existing?.cutDay ?? 10)
        _pay = State(initialValue: existing?.payDay ?? 30)
        _reminders = State(initialValue: existing?.reminders ?? true)
    }
    var body: some View {
        Form {
            Section {
                TextField("Nombre o alias", text: $name)
                Picker("Tipo", selection: $credit) { Text("Crédito").tag(true); Text("Débito").tag(false) }.disabled(existing != nil)
                if credit {
                    AmountInput(title: "Deuda inicial", text: $opening)
                    Picker("Día de corte", selection: $cut) { ForEach(1...31, id: \.self) { Text("Día \($0)").tag($0) } }
                    Picker("Día de pago", selection: $pay) { ForEach(1...31, id: \.self) { Text("Día \($0)").tag($0) } }
                    Toggle("Recordatorios de corte y pago", isOn: $reminders)
                    Text("Avisos 7 y 3 días antes, a las 9:00, hora de Ciudad de México. En meses cortos se usa el último día del mes. No se muestran alias ni importes.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Picker("Cuenta vinculada", selection: $account) {
                        Text("Selecciona").tag(nil as UUID?)
                        ForEach(store.ledger.accounts.filter { !$0.cash }) { Text($0.name).tag(Optional($0.id)) }
                    }.disabled(existing != nil)
                    Text("Añade primero una cuenta bancaria. El débito descontará de esa cuenta.").font(.caption)
                }
                Text("Usa solo un alias. No registres número completo, CVV ni credenciales.").font(.caption).foregroundStyle(.secondary)
            }
            InlineError(message: error)
        }.navigationTitle(existing == nil ? "Nueva tarjeta" : "Editar tarjeta")
            .financeKeyboard()
            .formError($error)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save) }
            }
    }
    private func save() {
        do {
            let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, cleaned.count <= 60 else { throw FinanceError.invalid("Introduce un alias de hasta 60 caracteres.") }
            if !credit && !store.ledger.accounts.contains(where: { $0.id == account && !$0.cash }) { throw FinanceError.invalid("Selecciona una cuenta bancaria para el débito.") }
            var card = Card(name: cleaned, credit: credit, accountID: credit ? nil : account,
                            openingDebt: credit ? try Money.parse(opening, allowZero: true) : 0,
                            cutDay: cut, payDay: pay, reminders: credit && reminders)
            if let existing { card.id = existing.id }
            if store.change({ state in
                if let index = state.cards.firstIndex(where: { $0.id == card.id }) { state.cards[index] = card }
                else { state.cards.append(card) }
            }) {
                Task { await store.refreshNotifications(request: credit && reminders) }
                dismiss()
            } else { error = store.errorMessage; store.errorMessage = nil }
        } catch { self.error = error.localizedDescription }
    }
}
struct CardDetail: View {
    @Environment(FinanceStore.self) private var store
    var cardID: UUID
    @State private var editing = false
    var body: some View {
        List {
            if let card = store.ledger.cards.first(where: { $0.id == cardID }) {
                Section {
                    LabeledContent("Tipo", value: card.credit ? "Crédito" : "Débito")
                    if card.credit {
                        LabeledContent("Deuda registrada") { Amount(value: store.ledger.debt(cardID)) }
                        LabeledContent("Próximo corte", value: FinanceDates.label(FinanceDates.next(day: card.cutDay, after: .now)))
                        LabeledContent("Próximo pago", value: FinanceDates.label(FinanceDates.next(day: card.payDay, after: .now)))
                        Text("Registra pagos parciales o totales usando + → Pago de tarjeta. El importe exigible debe consultarse en tu banco.").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Editar tarjeta") { editing = true }
                }
                Section("Gastos y otros egresos · todo el historial") {
                    Amount(value: store.ledger.entries.filter { $0.cardID == cardID && $0.kind.consumesBudget }.reduce(0) { $0 + $1.amount })
                }
                Section("Compras y pagos") {
                    ForEach(store.ledger.entries.filter { $0.cardID == cardID }.sorted { $0.date > $1.date }) { entry in
                        NavigationLink { EntryDetail(entryID: entry.id) } label: { EntryRow(entry: entry) }
                    }
                }
            }
        }.navigationTitle(store.ledger.cards.first { $0.id == cardID }?.name ?? "Tarjeta")
            .sheet(isPresented: $editing) {
                if let card = store.ledger.cards.first(where: { $0.id == cardID }) {
                    NavigationStack { CardEditor(existing: card) }.accountingDates()
                }
            }
    }
}
