import SwiftUI
import AppIntents

extension FinanceStore {
    var pendingCaptures: [CaptureDraft] { (ledger.capture?.drafts ?? []).filter { $0.status == .pending }.sorted { $0.date > $1.date } }
    func quickSeed(_ draft: CaptureDraft? = nil) -> Entry {
        let settings = ledger.capture ?? CaptureSettings()
        let cash = ledger.accounts.first { $0.id == settings.cashID && $0.cash }
        let category: UUID?
        if let draft { category = settings.category(for: draft.merchant, in: ledger) }
        else { category = ledger.categories.first { $0.id == settings.categoryID && !$0.archived }?.id }
        let card = ledger.cards.first { $0.id == draft?.cardID }
        return Entry(kind: .expense, amount: draft?.amount ?? 0, date: draft?.date ?? .now,
                     categoryID: category,
                     accountID: draft == nil ? cash?.id : (card?.credit == false ? card?.accountID : nil),
                     cardID: draft == nil ? nil : card?.id, note: draft?.merchant ?? "")
    }
}

struct QuickCaptureSettingsView: View {
    @Environment(FinanceStore.self) private var store
    @State private var settings = CaptureSettings()
    @State private var merchant = ""
    @State private var category: UUID?
    @State private var error: String?
    @State private var clear = false
    private func save() {
        // Merge configuration only; never overwrite drafts received while this screen is open.
        if !store.change({ state in
            var value = state.capture ?? CaptureSettings()
            value.cashID = settings.cashID; value.categoryID = settings.categoryID
            value.santanderCardID = settings.santanderCardID; value.rules = settings.rules
            state.capture = value
        }) { error = store.errorMessage; store.errorMessage = nil }
    }
    var body: some View {
        Form {
            Section("Acceso rápido") {
                ShortcutsLink().accessibilityLabel("Abrir Atajos de Numa")
                NavigationLink("Compras pendientes (\(store.pendingCaptures.count))") { QuickCaptureInbox() }
                Text("En Atajos, crea un acceso con «Abrir gasto rápido». Asígnalo en Configuración → Accesibilidad → Tocar → Toque posterior → Toque doble. iOS pide desbloquear cuando corresponda.").font(.caption).foregroundStyle(.secondary)
                Text("Guardar siempre requiere revisar el formulario de Numa. Un pendiente no modifica tus saldos.").font(.caption)
            }
            Section("Gasto manual en efectivo") {
                Picker("Efectivo predeterminado", selection: $settings.cashID) {
                    Text("Seleccionar al registrar").tag(nil as UUID?)
                    ForEach(store.ledger.accounts.filter(\.cash)) { Text($0.paymentLabel).tag(Optional($0.id)) }
                }.accessibilityIdentifier("quick.cash")
                Picker("Categoría predeterminada", selection: $settings.categoryID) {
                    Text("Seleccionar al registrar").tag(nil as UUID?)
                    ForEach(store.ledger.categories.filter { !$0.archived }) { Text($0.name).tag(Optional($0.id)) }
                }.accessibilityIdentifier("quick.category")
                Text("Si falta efectivo, puedes añadirlo desde el formulario. La categoría predeterminada solo se usa para el gasto manual.").font(.caption)
            }
            Section("Santander") {
                Picker("Tarjeta de débito", selection: $settings.santanderCardID) {
                    Text("Seleccionar al revisar").tag(nil as UUID?)
                    ForEach(store.ledger.cards.filter { !$0.credit }) { Text($0.name).tag(Optional($0.id)) }
                }.accessibilityIdentifier("quick.santander")
                Text("En una automatización de notificación o correo, envía el mensaje a «Preparar compra detectada» y elige su origen. «Has/Haz realizado una compra en…» permite extraer el comercio; no inventa importe ni moneda.").font(.caption)
            }
            Section("Reglas por comercio · coincidencia exacta") {
                TextField("Comercio, por ejemplo Mercado Libre", text: $merchant).accessibilityIdentifier("quick.merchant")
                Picker("Categoría de la regla", selection: $category) {
                    Text("Selecciona").tag(nil as UUID?)
                    ForEach(store.ledger.categories.filter { !$0.archived }) { Text($0.name).tag(Optional($0.id)) }
                }.accessibilityIdentifier("quick.ruleCategory")
                Button("Añadir regla") {
                    let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty, let category else { error = "Indica comercio y categoría."; return }
                    guard !settings.rules.contains(where: { CaptureSettings.key($0.merchant) == CaptureSettings.key(name) }) else { error = "Ese comercio ya tiene una regla. Elimínala antes de sustituirla."; return }
                    var proposed = settings
                    proposed.rules.append(MerchantRule(merchant: name, categoryID: category))
                    do { try proposed.validate(); settings = proposed; save(); merchant = ""; self.category = nil }
                    catch { self.error = error.localizedDescription }
                }
                ForEach(settings.rules) { rule in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(rule.merchant)
                            Text(store.ledger.categories.first { $0.id == rule.categoryID }?.name ?? "Categoría no disponible").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) { settings.rules.removeAll { $0.id == rule.id }; save() } label: { Image(systemName: "trash") }.accessibilityLabel("Eliminar regla de " + rule.merchant)
                    }
                }
            }
            Section("Historial de capturas") {
                Button("Limpiar capturas registradas y descartadas", role: .destructive) { clear = true }
                Text("Los pendientes se conservan hasta revisarlos o descartarlos. Máximo 200 capturas y 100 reglas. El texto original del aviso no se guarda.").font(.caption)
            }
        }
        .navigationTitle("Atajos y captura rápida")
        .onAppear { settings = store.ledger.capture ?? CaptureSettings() }
        .onChange(of: settings.cashID) { _, _ in save() }
        .onChange(of: settings.categoryID) { _, _ in save() }
        .onChange(of: settings.santanderCardID) { _, _ in save() }
        .formError($error)
        .financeKeyboard()
        .confirmationDialog("Se eliminará el historial procesado de capturas, sin tocar los movimientos. Se perderá la detección de reintentos por sus identificadores.", isPresented: $clear, titleVisibility: .visible) {
            Button("Limpiar historial", role: .destructive) {
                store.change { state in state.capture?.drafts.removeAll { $0.status != .pending } }
            }
        }
    }
}
struct QuickCaptureInbox: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var discarding: CaptureDraft?
    var body: some View {
        List {
            if store.pendingCaptures.isEmpty {
                ContentUnavailableView("Sin compras pendientes", systemImage: "tray", description: Text("El atajo de doble toque abrirá un gasto manual en efectivo."))
            }
            ForEach(store.pendingCaptures) { draft in
                NavigationLink {
                    EntryEditor(prefill: store.quickSeed(draft), captureID: draft.id, quick: true)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(draft.merchant).font(.headline)
                        Text(draft.source.label + " · " + FinanceDates.label(draft.date)).font(.caption).foregroundStyle(.secondary)
                        if let amount = draft.amount { Amount(value: amount) } else { Text("Importe pendiente") }
                        if store.ledger.capture?.hasPossibleDuplicate(draft, in: store.ledger) == true {
                            Label("Posible duplicado · revisar", systemImage: "exclamationmark.triangle").font(.caption)
                        }
                    }
                }
                .accessibilityIdentifier("capture." + draft.source.rawValue)
                .swipeActions { Button("Descartar", role: .destructive) { discarding = draft } }
            }
        }
        .navigationTitle("Compras pendientes")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        .confirmationDialog("¿Descartar esta captura? No se eliminarán movimientos.", isPresented: Binding(get: { discarding != nil }, set: { if !$0 { discarding = nil } }), titleVisibility: .visible) {
            Button("Descartar captura", role: .destructive) {
                if let id = discarding?.id { store.change { state in
                    if let i = state.capture?.drafts.firstIndex(where: { $0.id == id }) { state.capture?.drafts[i].status = .discarded }
                } }
                discarding = nil
            }
        }
    }
}
