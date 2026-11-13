import SwiftUI

private enum MainSheet: Identifiable {
    case entry, accounts, settings, quickInbox, quickEntry(Entry, UUID?)
    var id: String {
        switch self {
        case .entry: "entry"
        case .accounts: "accounts"
        case .settings: "settings"
        case .quickInbox: "quickInbox"
        case .quickEntry(let entry, _): "quick-" + entry.id.uuidString
        }
    }
}
struct RootView: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hideAmounts") private var hidden = false
    @AppStorage("theme") private var theme = "system"
    @State private var sheet: MainSheet?
    private let titles = ["Inicio", "Movimientos", "Presupuestos", "Ahorro", "Reportes"]
    private let icons = ["house", "list.bullet.rectangle", "chart.pie", "target", "chart.xyaxis.line"]
    var body: some View {
        Group {
            if store.ready {
                TabView {
                    ForEach(0..<5) { tab in
                        NavigationStack {
                            Group {
                                switch tab {
                                case 0: HomeView(openAccounts: { sheet = .accounts }, addEntry: { sheet = .entry })
                                case 1: MovementsView()
                                case 2: BudgetsView()
                                case 3: GoalsView()
                                default: ReportsView()
                                }
                            }
                            .navigationTitle(titles[tab])
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button { hidden.toggle() } label: { Image(systemName: hidden ? "eye.slash" : "eye") }
                                        .accessibilityLabel(hidden ? "Mostrar importes" : "Ocultar importes")
                                }
                                ToolbarItemGroup(placement: .topBarTrailing) {
                                    Button { sheet = .settings } label: { Image(systemName: "gearshape") }.accessibilityLabel("Ajustes")
                                    Button { sheet = .entry } label: { Image(systemName: "plus.circle.fill") }.accessibilityLabel("Registrar movimiento").accessibilityIdentifier("movement.add")
                                }
                            }
                        }.tabItem { Label(titles[tab], systemImage: icons[tab]) }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Archivo no disponible", systemImage: "lock.doc")
                } description: {
                    Text("No se eliminaron tus registros. Reintenta cuando el iPhone esté desbloqueado.")
                } actions: { Button("Reintentar") { store.open() }.buttonStyle(.borderedProminent) }
            }
        }
        .tint(NumaStyle.accent)
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .sheet(item: $sheet) { route in
            NavigationStack {
                switch route {
                case .entry: EntryEditor()
                case .accounts: AccountsView()
                case .settings: SettingsView()
                case .quickInbox: QuickCaptureInbox()
                case .quickEntry(let seed, let captureID): EntryEditor(prefill: seed, captureID: captureID, quick: true)
                }
            }.accountingDates().storeError(store)
        }
        .storeError(store, enabled: sheet == nil)
        .privacyCover()
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            store.suspendProtectedData()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            store.resumeProtectedData()
        }
        .task { openQuickIfPossible() }
        .onChange(of: store.quickRequest) { _, _ in openQuickIfPossible() }
        .onChange(of: sheet?.id) { _, value in if value == nil { openQuickIfPossible() } }
        .onChange(of: store.ready) { _, ready in
            if !ready { sheet = nil } else { openQuickIfPossible() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.resumeProtectedData(); Task { await store.refreshNotifications() } }
        }
    }
    private func openQuickIfPossible() {
        guard store.ready, store.quickRequest != nil, sheet == nil else { return }
        store.quickRequest = nil
        let drafts = store.pendingCaptures
        if drafts.count > 1 { sheet = .quickInbox }
        else { sheet = .quickEntry(store.quickSeed(drafts.first), drafts.first?.id) }
    }

}

struct HomeView: View {
    @Environment(FinanceStore.self) private var store
    var openAccounts: () -> Void
    var addEntry: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    NumaLogo()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Numa").font(.title2.weight(.semibold))
                        Text("Tu dinero, paso a paso.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.bottom, 4)
                VStack(alignment: .leading, spacing: 12) {
                    Label("Disponible para gastar", systemImage: "wallet.bifold").font(.subheadline.weight(.medium))
                    Amount(value: store.index.summary.available)
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .minimumScaleFactor(0.6)
                    Text("Dinero total menos lo reservado para tus metas. La deuda de crédito se muestra aparte.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(action: addEntry) {
                        Label("Registrar movimiento", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 4)
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("home.addMovement")
                }
                .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .background(NumaStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: NumaStyle.cardRadius))
                if store.ledger.budget(.now) != nil {
                    Metric(title: "Presupuesto restante · esta semana", value: store.ledger.remaining(.now), icon: "calendar")
                } else {
                    Label("Define tu límite semanal en Presupuestos.", systemImage: "calendar.badge.plus").font(.callout).padding()
                }
                ViewThatFits(in: .horizontal) {
                    HStack { Metric(title: "Ahorro reservado", value: store.index.summary.held, icon: "target"); Metric(title: "Deuda de crédito", value: store.index.summary.totalDebt, icon: "creditcard") }
                    VStack { Metric(title: "Ahorro reservado", value: store.index.summary.held, icon: "target"); Metric(title: "Deuda de crédito", value: store.index.summary.totalDebt, icon: "creditcard") }
                }
                Button(action: openAccounts) {
                    HStack { Label("Efectivo, cuentas y tarjetas", systemImage: "wallet.bifold"); Spacer(); Image(systemName: "chevron.right") }.padding()
                }.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier("accounts.open")
                Button("Gasto rápido", systemImage: "bolt") { store.quickRequest = UUID() }.accessibilityIdentifier("quick.open")
                if store.ledger.accounts.isEmpty {
                    ContentUnavailableView {
                        Label("Empecemos por tu saldo", systemImage: "wallet.bifold")
                    } description: { Text("Añade efectivo o una cuenta bancaria. Tus registros se guardan en este iPhone, sin sincronización ni recuperación.") }
                    actions: { Button("Añadir mi saldo", action: openAccounts).buttonStyle(.borderedProminent) }
                } else {
                    if let goal = store.ledger.goals.first(where: { store.ledger.reserved(goal: $0.id) < $0.target }) {
                        NavigationLink { GoalDetail(goalID: goal.id) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Paso a paso hacia tu meta", systemImage: "target").font(.caption).foregroundStyle(.secondary)
                                Text(goal.name).font(.headline)
                                GoalProgress(saved: store.ledger.reserved(goal: goal.id), target: goal.target)
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: NumaStyle.cardRadius))
                        }.foregroundStyle(.primary)
                    }
                    Text("Movimientos recientes").font(.headline)
                    if store.ledger.entries.isEmpty { Text("Pulsa + para registrar tu primer ingreso o egreso.").foregroundStyle(.secondary) }
                    ForEach(store.index.orderedEntries.prefix(5)) { entry in
                        NavigationLink { EntryDetail(entryID: entry.id) } label: { EntryRow(entry: entry) }.foregroundStyle(.primary)
                        Divider()
                    }
                }
            }.padding()
        }.background(Color(uiColor: .systemGroupedBackground))
    }
}

struct MovementsView: View {
    @Environment(FinanceStore.self) private var store
    @State private var search = ""
    @State private var kind: EntryKind?
    @State private var category: UUID?
    @State private var method = ""
    @State private var period = "all"
    @State private var date = Date.now
    @State private var matches: [Entry] = []
    @State private var visibleLimit = 50
    @State private var loading = true
    private struct Request: Hashable { var revision: UUID; var filter: EntryFilter }
    @State private var completedRequest: Request?
    private var filter: EntryFilter {
        let calendar = FinanceDates.calendar
        let interval: DateInterval?
        switch period {
        case "day": interval = calendar.dateInterval(of: .day, for: date)
        case "week": interval = calendar.dateInterval(of: .weekOfYear, for: date)
        case "month": interval = calendar.dateInterval(of: .month, for: date)
        default: interval = nil
        }
        return EntryFilter(search: search, kind: kind, category: category, method: UUID(uuidString: method), interval: interval)
    }
    var body: some View {
        List {
            Section {
                DisclosureGroup("Filtros") {
                    Picker("Tipo", selection: $kind) {
                        Text("Todos").tag(nil as EntryKind?)
                        ForEach(EntryKind.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                    }
                    Picker("Categoría", selection: $category) {
                        Text("Todas").tag(nil as UUID?)
                        ForEach(store.ledger.categories.sorted { $0.name < $1.name }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .accessibilityIdentifier("history.category")
                    Picker("Método", selection: $method) {
                        Text("Todos").tag("")
                        ForEach(store.ledger.accounts) { Text($0.paymentLabel).tag($0.id.uuidString) }
                        ForEach(store.ledger.cards) { Text($0.name + ($0.credit ? " · Crédito" : " · Débito")).tag($0.id.uuidString) }
                    }
                    Picker("Periodo", selection: $period) {
                        Text("Todo").tag("all"); Text("Día").tag("day"); Text("Semana").tag("week"); Text("Mes").tag("month")
                    }
                    if period != "all" { DatePicker("Fecha de referencia", selection: $date, displayedComponents: .date) }
                    if filter != EntryFilter() {
                        Button("Restablecer filtros") { search = ""; kind = nil; category = nil; method = ""; period = "all" }
                    }
                }
                Text("\(matches.count) movimientos · \(min(visibleLimit, matches.count)) cargados")
                    .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("history.count")
            }
            if loading { ProgressView("Buscando movimientos…") }
            else if matches.isEmpty { ContentUnavailableView("Sin movimientos", systemImage: "list.bullet.rectangle", description: Text("Registra uno con + o ajusta los filtros.")) }
            ForEach(matches.prefix(visibleLimit)) { entry in
                NavigationLink { EntryDetail(entryID: entry.id) } label: { EntryRow(entry: entry) }
                    .onAppear {
                        if entry.id == matches.prefix(visibleLimit).last?.id { visibleLimit = min(matches.count, visibleLimit + 50) }
                    }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar concepto, categoría o método")
        .task(id: Request(revision: store.revision, filter: filter)) {
            let request = Request(revision: store.revision, filter: filter)
            if completedRequest == request { return }
            completedRequest = nil
            loading = true
            matches = []
            visibleLimit = 50
            let selected = filter
            if !selected.search.isEmpty {
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            }
            let index = store.index
            let result = await Task.detached(priority: .userInitiated) { index.matching(selected) }.value
            guard !Task.isCancelled else { return }
            matches = result
            completedRequest = request
            loading = false
        }
    }
}

struct EntryDetail: View {
    @Environment(FinanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var entryID: UUID
    @State private var editing = false
    @State private var deleting = false
    var entry: Entry? { store.ledger.entries.first { $0.id == entryID } }
    var body: some View {
        List {
            if let entry {
                Section {
                    LabeledContent("Tipo", value: entry.kind.label)
                    LabeledContent("Total") { Amount(value: entry.amount) }
                    LabeledContent("Fecha", value: FinanceDates.label(entry.date))
                    LabeledContent("Método", value: store.ledger.displayMethod(entry))
                    if let category = store.ledger.categories.first(where: { $0.id == entry.categoryID }) { LabeledContent("Categoría", value: category.name) }
                    if let target = store.ledger.accounts.first(where: { $0.id == entry.destinationID }) { LabeledContent("Destino", value: target.name) }
                    if !entry.note.isEmpty { Text(entry.note) }
                }
                if entry.months > 1 {
                    Section("\(entry.months) mensualidades · calendario previsto") {
                        LabeledContent("Condición", value: entry.amount > entry.price ? "Con intereses" : "Sin intereses")
                        LabeledContent("Precio original") { Amount(value: entry.price) }
                        ForEach(store.ledger.installments(entry)) { item in
                            LabeledContent("\(item.id) · \(FinanceDates.label(item.date))") { Amount(value: item.amount) }
                        }
                        Text("Los pagos reducen la deuda total. Este calendario no confirma qué mensualidades están pagadas.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Editar movimiento") { editing = true }
                    Button("Eliminar movimiento", role: .destructive) { deleting = true }
                }
            }
        }
        .navigationTitle("Movimiento")
        .sheet(isPresented: $editing) { if let entry { NavigationStack { EntryEditor(existing: entry) }.accountingDates() } }
        .confirmationDialog("¿Eliminar este movimiento? Se recalcularán los saldos, reportes y presupuestos relacionados.", isPresented: $deleting, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { if store.change({ try $0.deleteEntry(entryID) }) { dismiss() } }
        }
    }
}
