import SwiftUI

struct EntryEditor: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: Entry?
    var captureID: UUID?
    var quick: Bool
    @State private var kind: EntryKind
    @State private var amount: String
    @State private var categoryID: UUID?
    @State private var method: String
    @State private var paymentAccount: UUID?
    @State private var paymentCard: UUID?
    @State private var destination: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var monthly: Bool
    @State private var interest: Bool
    @State private var price: String
    @State private var months: Int
    @State private var first: Date
    @State private var error: String?
    @State private var warning: String?
    @State private var pending: Entry?
    @State private var confirming = false
    @State private var creatingCash = false

    init(existing: Entry? = nil, prefill: Entry? = nil, captureID: UUID? = nil, quick: Bool = false) {
        self.existing = existing
        self.captureID = captureID
        self.quick = quick
        let initial = existing ?? prefill
        _kind = State(initialValue: initial?.kind ?? .expense)
        _amount = State(initialValue: initial.flatMap { $0.amount > 0 ? Money.input($0.amount) : nil } ?? "")
        _categoryID = State(initialValue: initial?.categoryID)
        _method = State(initialValue: initial?.cardID.map { "c:\($0.uuidString)" } ?? initial?.accountID.map { "a:\($0.uuidString)" } ?? "")
        _paymentAccount = State(initialValue: initial?.accountID)
        _paymentCard = State(initialValue: initial?.cardID)
        _destination = State(initialValue: initial?.destinationID)
        _date = State(initialValue: initial?.date ?? .now)
        _note = State(initialValue: initial?.note ?? "")
        _monthly = State(initialValue: (initial?.months ?? 1) > 1)
        _interest = State(initialValue: (initial?.amount ?? 0) > (initial?.price ?? 0) && (initial?.months ?? 1) > 1)
        _price = State(initialValue: initial.map { Money.input($0.price) } ?? "")
        _months = State(initialValue: initial?.months ?? 3)
        _first = State(initialValue: initial?.firstPayment ?? .now)
    }
    private var selectedCard: Card? {
        store.ledger.cards.first { method == "c:" + $0.id.uuidString }
    }
    private var allowsMonths: Bool { kind.consumesBudget && selectedCard?.credit == true }
    var body: some View {
        Form {
            if store.ledger.accounts.isEmpty && store.ledger.cards.filter(\.credit).isEmpty {
                Section { Text("Puedes elegir Efectivo abajo y registrar tu saldo inicial, o añadir una cuenta o tarjeta desde Inicio.").foregroundStyle(.secondary) }
            }
            if let captureID, let draft = store.ledger.capture?.drafts.first(where: { $0.id == captureID }) {
                Section("Compra detectada · revisar antes de guardar") {
                    Text(draft.source.label)
                    Text("Todos los importes de Numa se registran en MXN. Comprueba comercio, tarjeta, categoría e importe.").font(.caption)
                    if draft.currencyNeedsReview { Label("La fuente no indicó la moneda: confirma que sea MXN.", systemImage: "exclamationmark.triangle").font(.caption) }
                }
            }
            Section("Movimiento") {
                Picker("Tipo", selection: $kind) { ForEach(EntryKind.allCases, id: \.self) { Text($0.label).tag($0) } }.accessibilityIdentifier("movement.kind").disabled(quick)
                AmountInput(title: monthly && interest && allowsMonths ? "Total final a pagar" : "Importe", text: $amount, autofocus: quick)
                DatePicker("Fecha", selection: $date, in: ...Date.now, displayedComponents: .date)
                if kind.consumesBudget || kind == .income {
                    Picker("Categoría", selection: $categoryID) {
                        Text("Selecciona").tag(nil as UUID?)
                        ForEach(store.ledger.categories.filter { !$0.archived || $0.id == existing?.categoryID }.sorted { $0.name < $1.name }) {
                            Text($0.name).tag(Optional($0.id))
                        }
                    }
                    .accessibilityIdentifier("movement.category")
                }
                TextField("Nota (opcional)", text: $note, axis: .vertical).lineLimit(1...3)
            }
            Section(kind == .cardPayment ? "Origen y tarjeta" : "Método") {
                if kind == .cardPayment {
                    accountPicker("Pagar desde", selection: $paymentAccount)
                    Picker("Tarjeta de crédito", selection: $paymentCard) {
                        Text("Selecciona").tag(nil as UUID?)
                        ForEach(store.ledger.cards.filter(\.credit)) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .accessibilityIdentifier("payment.card")
                    if let paymentCard { LabeledContent("Deuda registrada") { Amount(value: store.ledger.debt(paymentCard)) } }
                    Text("Puedes registrar un pago parcial o total, hasta el importe de la deuda registrada.").font(.caption)
                } else {
                    Picker(kind == .income ? "Recibir en" : "Pagar desde", selection: $method) {
                        Text("Selecciona").tag("")
                        ForEach(store.ledger.accounts.filter(\.cash)) { Text($0.paymentLabel).tag("a:" + $0.id.uuidString) }
                        if !store.ledger.accounts.contains(where: \.cash) { Text("Efectivo").tag("new-cash") }
                        ForEach(store.ledger.accounts.filter { !$0.cash }) { Text($0.name + " · Cuenta").tag("a:" + $0.id.uuidString) }
                        if kind.consumesBudget {
                            ForEach(store.ledger.cards) { Text($0.name + ($0.credit ? " · Crédito" : " · Débito")).tag("c:" + $0.id.uuidString) }
                        }
                    }
                    .accessibilityIdentifier("movement.method")
                    if kind == .transfer { accountPicker("Enviar a", selection: $destination) }
                }
            }
            if allowsMonths {
                Section("Financiamiento") {
                    Toggle("Compra a meses", isOn: $monthly)
                    if monthly {
                        Toggle("Con intereses", isOn: $interest)
                        if interest { AmountInput(title: "Precio original", text: $price) }
                        Stepper("\(months) mensualidades", value: $months, in: 2...120)
                        DatePicker("Primera fecha de pago", selection: $first, displayedComponents: .date)
                        Text("El total final se registra como gasto de esta semana. Las mensualidades son un calendario previsto. En meses cortos se usa el último día disponible.").font(.caption).foregroundStyle(.secondary)
                        if let preview = try? buildEntry() {
                            ForEach(store.ledger.installments(preview).prefix(3)) { item in
                                LabeledContent("\(item.id) · \(FinanceDates.label(item.date))", value: Money.format(item.amount))
                            }
                            if months > 3 { Text("Y \(months - 3) mensualidades más. El calendario completo aparecerá en el detalle.").font(.caption) }
                        }
                    }
                }
            }
            InlineError(message: error)
        }
        .navigationTitle(existing == nil ? "Nuevo movimiento" : "Editar movimiento")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: prepareSave).fontWeight(.semibold) }
        }
        .financeKeyboard()
        .sheet(isPresented: $creatingCash, onDismiss: {
            if method == "new-cash" { method = "" }
        }) {
            NavigationStack {
                AccountEditor(cash: true) { id in method = "a:" + id.uuidString }
            }.accountingDates()
        }
        .onChange(of: method) { _, value in
            if value == "new-cash" { creatingCash = true }
            suggestFirst()
        }
        .onChange(of: date) { _, _ in suggestFirst() }
        .onChange(of: kind) { _, new in
            if !new.consumesBudget && method.hasPrefix("c:") { method = "" }
        }
        .formError($error)
        .alert("Confirma el registro", isPresented: $confirming) {
            Button("Cancelar", role: .cancel) { pending = nil; warning = nil }
            Button("Registrar de todos modos") { if let value = pending { save(value) }; warning = nil; pending = nil }
        } message: { Text(warning ?? "") }
    }
    private func accountPicker(_ title: String, selection: Binding<UUID?>) -> some View {
        Picker(title, selection: selection) {
            Text("Selecciona").tag(nil as UUID?)
            ForEach(store.ledger.accounts) { Text($0.paymentLabel).tag(Optional($0.id)) }
        }
        .accessibilityIdentifier("accountPicker." + title)
    }
    private func suggestFirst() {
        guard existing == nil, let card = selectedCard, card.credit else { return }
        first = FinanceDates.next(day: card.payDay, after: date)
    }
    private func buildEntry() throws -> Entry {
        let total = try Money.parse(amount)
        var entry = Entry(kind: kind, amount: total, date: date, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        if let existing { entry.id = existing.id }
        else if let captureID { entry.id = captureID }
        if kind.consumesBudget || kind == .income { entry.categoryID = categoryID }
        if kind == .cardPayment { entry.accountID = paymentAccount; entry.cardID = paymentCard }
        else if let card = selectedCard, kind.consumesBudget {
            entry.cardID = card.id
            entry.accountID = card.credit ? nil : card.accountID
        } else {
            entry.accountID = method.hasPrefix("a:") ? UUID(uuidString: String(method.dropFirst(2))) : nil
        }
        if kind == .transfer { entry.destinationID = destination }
        if allowsMonths && monthly {
            entry.months = months; entry.price = interest ? try Money.parse(price) : total; entry.firstPayment = first
            if interest && entry.price >= total { throw FinanceError.invalid("Con intereses, el total final debe ser mayor al precio original.") }
        }
        try store.ledger.validate(entry)
        return entry
    }
    private func prepareSave() {
        do {
            let entry = try buildEntry()
            var base = store.ledger
            base.entries.removeAll { $0.id == entry.id }
            var messages = base.warnings(for: entry)
            if let captureID, let draft = store.ledger.capture?.drafts.first(where: { $0.id == captureID }),
               store.ledger.capture?.hasPossibleDuplicate(draft, in: store.ledger) == true {
                messages.append("Esta compra podría estar repetida en Wallet, Santander o tus movimientos. Revisa antes de registrar otra salida.")
            }
            if messages.isEmpty { save(entry) }
            else { pending = entry; warning = messages.joined(separator: "\n\n"); confirming = true }
        } catch { self.error = error.localizedDescription }
    }
    private func save(_ value: Entry) {
        if store.change({ state in
            if let captureID {
                try state.saveCapturedExpense(value, captureID: captureID)
            } else { try state.saveEntry(value) }
        }) { dismiss() }
        else { error = store.errorMessage; store.errorMessage = nil }
    }
}
