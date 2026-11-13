import SwiftUI
import Charts

struct ReportsView: View {
    @Environment(FinanceStore.self) private var store
    @AppStorage("hideAmounts") private var hidden = false
    @State private var period = 1
    @State private var reference = Date.now
    @State private var report = LedgerReport()
    @State private var loading = true
    private struct Request: Hashable { var revision: UUID; var period: Int; var reference: Date }
    private var interval: DateInterval {
        let component: Calendar.Component = period == 0 ? .day : period == 1 ? .weekOfYear : .month
        return FinanceDates.calendar.dateInterval(of: component, for: reference)!
    }
    private var categoryTotals: [(category: Category, total: Cents)] {
        store.ledger.categories.compactMap { category in
            guard let total = report.categoryTotals[category.id] else { return nil }
            return (category, total)
        }.sorted { $0.total == $1.total ? $0.category.name < $1.category.name : $0.total > $1.total }
    }
    var body: some View {
        List {
            Section {
                Picker("Periodo", selection: $period) { Text("Día").tag(0); Text("Semana").tag(1); Text("Mes").tag(2) }.pickerStyle(.segmented)
                DatePicker("Fecha de referencia", selection: $reference, in: ...Date.now, displayedComponents: .date)
                Text("\(FinanceDates.label(interval.start)) — \(FinanceDates.label(FinanceDates.addDays(-1, to: interval.end)))").font(.caption).foregroundStyle(.secondary)
            }
            if loading { Section { ProgressView("Preparando reporte…") } }
            else { reportContent }
        }
        .task(id: Request(revision: store.revision, period: period, reference: reference)) {
            loading = true
            let index = store.index
            let selected = interval
            let now = Date.now
            let result = await Task.detached(priority: .userInitiated) { index.report(in: selected, through: now) }.value
            guard !Task.isCancelled else { return }
            report = result
            loading = false
        }
    }
    @ViewBuilder private var reportContent: some View {
        Section("Ingresos y salidas") {
            LabeledContent("Ingresos") { Amount(value: report.income) }
            LabeledContent("Gastos de consumo") { Amount(value: report.expense) }
            LabeledContent("Otros egresos") { Amount(value: report.outflow) }
            LabeledContent("Diferencia de ingresos y egresos") { Amount(value: report.income - report.expense - report.outflow) }
            Text("Los pagos de crédito, transferencias y reservas no duplican gastos. La diferencia no equivale al cambio de efectivo si hubo compras a crédito.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Por categoría · gastos y otros egresos") {
            if categoryTotals.isEmpty { Text("Sin egresos en este periodo.").foregroundStyle(.secondary) }
            if !hidden && !categoryTotals.isEmpty {
                Chart(categoryTotals, id: \.category.id) { item in
                    BarMark(x: .value("Pesos", Double(item.total) / 100), y: .value("Categoría", item.category.name)).foregroundStyle(.blue.gradient)
                }.frame(height: CGFloat(max(120, categoryTotals.count * 42))).accessibilityHidden(true)
            }
            ForEach(categoryTotals, id: \.category.id) { item in LabeledContent(item.category.name) { Amount(value: item.total) } }
        }
        Section("Evolución del dinero total") {
            if hidden { Label("Gráfica oculta", systemImage: "eye.slash").foregroundStyle(.secondary) }
            else {
                Chart(report.timeline) { item in
                    LineMark(x: .value("Fecha", item.date), y: .value("Pesos", Double(item.balance) / 100)).foregroundStyle(.blue)
                    PointMark(x: .value("Fecha", item.date), y: .value("Pesos", Double(item.balance) / 100)).foregroundStyle(.blue)
                }.frame(height: 180).accessibilityHidden(true)
            }
            DisclosureGroup("Consultar saldos por día") {
                ForEach(report.timeline) { item in LabeledContent(FinanceDates.label(item.date)) { Amount(value: item.balance) } }
            }
            Text("Saldo al terminar cada día: efectivo y cuentas, sin restar deuda de crédito ni ahorro reservado. Parte de los saldos iniciales registrados; no reconstruye periodos anteriores al inicio del registro.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Por método de pago · mismo periodo") {
            LabeledContent("Total en efectivo") { Amount(value: report.cash) }
            LabeledContent("Total con débito") { Amount(value: report.debit) }
            LabeledContent("Total con crédito") { Amount(value: report.credit) }
            ForEach(store.ledger.accounts) { account in
                LabeledContent(account.cash ? account.paymentLabel : account.name + " · Cuenta") { Amount(value: report.methodTotals[account.id, default: 0]) }
            }
            ForEach(store.ledger.cards) { card in
                LabeledContent(card.name + (card.credit ? " · Crédito" : " · Débito")) { Amount(value: report.methodTotals[card.id, default: 0]) }
            }
        }
    }
}
