import SwiftUI

struct Amount: View {
    var value: Cents
    @AppStorage("hideAmounts") private var hidden = false
    var body: some View {
        Text(hidden ? "••••" : Money.format(value))
            .monospacedDigit()
            .accessibilityLabel(hidden ? "Importe oculto" : Money.format(value))
    }
}
struct AmountInput: View {
    var title: String
    @Binding var text: String
    var autofocus = false
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("0.00", text: $text)
                .keyboardType(.decimalPad)
                .focused($focused)
                .accessibilityLabel(title + ", pesos mexicanos")
                .accessibilityIdentifier("money." + title)
                .task { if autofocus { focused = true } }
        }
    }
}
struct InlineError: View {
    var message: String?
    var body: some View {
        if let message { Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout) } }
    }
}
struct Metric: View {
    var title: String
    var value: Cents
    var icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.subheadline).foregroundStyle(.secondary)
            Amount(value: value).font(.title2.weight(.semibold)).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: NumaStyle.cardRadius))
    }
}
struct EntryRow: View {
    @Environment(FinanceStore.self) private var store
    var entry: Entry
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.kind == .income ? "arrow.down.left.circle.fill" : "arrow.up.right.circle")
                .font(.title3).foregroundStyle(entry.kind == .income ? .green : .blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.note.isEmpty ? (store.ledger.categories.first { $0.id == entry.categoryID }?.name ?? entry.kind.label) : entry.note)
                    .font(.body.weight(.medium)).lineLimit(2)
                Text(entry.kind.label + " · " + store.ledger.displayMethod(entry)).font(.caption).foregroundStyle(.secondary)
                Text(FinanceDates.label(entry.date) + (entry.months > 1 ? " · \(entry.months) meses" : "")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Amount(value: entry.amount).font(.subheadline.weight(.semibold))
        }.padding(.vertical, 4)
    }
}
extension View {
    func privacyCover() -> some View { modifier(PrivacyCoverModifier()) }
    func financeKeyboard() -> some View {
        scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
    }
    func formError(_ message: Binding<String?>) -> some View {
        alert("Revisa los datos", isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            Button("Entendido") { message.wrappedValue = nil }
        } message: { Text(message.wrappedValue ?? "Revisa los campos e inténtalo de nuevo.") }
    }
    func storeError(_ store: FinanceStore, enabled: Bool = true) -> some View {
        alert("No se pudo completar", isPresented: Binding(get: { enabled && store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("Entendido") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "Reintenta la operación.") }
    }
    func accountingDates() -> some View {
        self.environment(\.calendar, FinanceDates.calendar).environment(\.timeZone, FinanceDates.calendar.timeZone)
            .privacyCover()
    }
}

private struct PrivacyCoverModifier: ViewModifier {
    @Environment(\.scenePhase) private var phase
    func body(content: Content) -> some View {
        content.overlay {
            if phase != .active {
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    VStack(spacing: 12) { NumaLogo(size: 64); Text("Numa") }
                        .font(.title2.weight(.semibold)).foregroundStyle(.blue)
                }.accessibilityElement(children: .ignore).accessibilityLabel("Contenido privado")
            }
        }
    }
}

// Cash remains an Account internally to preserve balances, links and existing records.
extension Account {
    var paymentLabel: String { cash ? (name == "Efectivo" ? "Efectivo" : "Efectivo · " + name) : name }
}

extension Ledger {
    func displayMethod(_ entry: Entry) -> String {
        if entry.cardID != nil { return method(entry) }
        return accounts.first { $0.id == entry.accountID }?.paymentLabel ?? "Sin método"
    }
}
