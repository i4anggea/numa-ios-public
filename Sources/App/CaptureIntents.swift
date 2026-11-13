import AppIntents
import UIKit

extension CaptureSource: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Origen de compra" }
    public static var caseDisplayRepresentations: [CaptureSource: DisplayRepresentation] {
        [.wallet: "Wallet", .santanderNotification: "Santander · notificación", .santanderEmail: "Santander · correo"]
    }
}

struct ShortcutCard: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Tarjeta de Numa" }
    static var defaultQuery: ShortcutCardQuery { ShortcutCardQuery() }
    var id: UUID
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct ShortcutCardQuery: EntityQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [ShortcutCard] {
        try cards().filter { identifiers.contains($0.id) }
    }
    @MainActor func suggestedEntities() async throws -> [ShortcutCard] { try cards() }
    @MainActor private func cards() throws -> [ShortcutCard] {
        try FinanceStore.shared.requireCaptureAccess()
        return FinanceStore.shared.ledger.cards.map { ShortcutCard(id: $0.id, name: $0.name + ($0.credit ? " · Crédito" : " · Débito")) }
    }
}

struct OpenQuickExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Abrir gasto rápido" }
    static var description: IntentDescription { "Abre los pendientes o un gasto en efectivo. Revisa y pulsa Guardar en Numa." }
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    @MainActor func perform() async throws -> some IntentResult {
        try FinanceStore.shared.requireCaptureAccess()
        FinanceStore.shared.quickRequest = UUID()
        return .result()
    }
}

struct CapturePurchaseIntent: AppIntent {
    static var title: LocalizedStringResource { "Preparar compra detectada" }
    static var description: IntentDescription { "Recibe datos de Wallet o un aviso de Santander como borrador local. No registra un gasto ni modifica saldos." }
    static var supportedModes: IntentModes { .background }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
    @Parameter(title: "Origen", default: .wallet) var source: CaptureSource
    @Parameter(title: "Comercio") var merchant: String?
    @Parameter(title: "Importe sin separadores de miles") var amount: String?
    @Parameter(title: "Moneda (MXN)") var currency: String?
    @Parameter(title: "Texto del aviso") var text: String?
    @Parameter(title: "Tarjeta de Numa") var card: ShortcutCard?
    @Parameter(title: "Fecha de la compra") var date: Date?
    @Parameter(title: "Identificador del evento (opcional)") var eventID: String?
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = FinanceStore.shared
        try store.requireCaptureAccess()
        try store.prepareCapture(source: source, text: text, merchant: merchant, amount: amount, currency: currency,
                                 cardID: card?.id, eventID: eventID, date: date ?? .now)
        return .result(dialog: "Solicitud procesada. Abre Numa para revisar; esta acción no registra gastos.")
    }
}
struct NumaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenQuickExpenseIntent(), phrases: ["Abrir gasto rápido en \(.applicationName)"],
                    shortTitle: "Gasto rápido", systemImageName: "plus.circle")
        AppShortcut(intent: CapturePurchaseIntent(), phrases: ["Preparar compra en \(.applicationName)"],
                    shortTitle: "Preparar compra", systemImageName: "tray.and.arrow.down")
    }
    static var shortcutTileColor: ShortcutTileColor { .blue }
}
extension FinanceStore {
    func prepareCapture(source: CaptureSource, text: String?, merchant: String?, amount: String?, currency: String?,
                        cardID: UUID?, eventID: String?, date: Date) throws {
        try requireCaptureAccess()
        let selected = cardID ?? (source == .wallet ? nil : ledger.capture?.santanderCardID)
        if let selected {
            guard let card = ledger.cards.first(where: { $0.id == selected }), source == .wallet || !card.credit else {
                throw FinanceError.invalid("Revisa la tarjeta del atajo. Santander requiere una tarjeta de débito registrada en Numa.")
            }
        }
        let draft = try CaptureParser.draft(source: source, text: text, merchant: merchant, amount: amount,
                                            currency: currency, cardID: selected, eventID: eventID, date: date)
        guard change({ state in
            var settings = state.capture ?? CaptureSettings()
            try settings.receive(draft)
            state.capture = settings
        }) else { throw FinanceError.invalid(errorMessage ?? "No se pudo preparar la compra.") }
    }
    func requireCaptureAccess() throws {
        guard UIApplication.shared.isProtectedDataAvailable else {
            throw FinanceError.invalid("Desbloquea el iPhone y vuelve a ejecutar el atajo. No se guardaron datos con el dispositivo bloqueado.")
        }
        if !ready { open() }
        guard ready else { throw FinanceError.invalid("Abre Numa y comprueba el archivo local antes de ejecutar el atajo.") }
    }
}
