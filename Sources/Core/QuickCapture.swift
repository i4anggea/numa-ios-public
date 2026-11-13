import Foundation

public enum CaptureSource: String, Codable, CaseIterable, Sendable {
    case wallet, santanderNotification, santanderEmail
    public var label: String {
        switch self {
        case .wallet: "Wallet"
        case .santanderNotification: "Santander · notificación"
        case .santanderEmail: "Santander · correo"
        }
    }
}
public struct MerchantRule: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var merchant: String
    public var categoryID: UUID
    public init(merchant: String, categoryID: UUID) { self.merchant = merchant; self.categoryID = categoryID }
}
public struct CaptureDraft: Identifiable, Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case pending, saved, discarded }
    public var id = UUID()
    public var source: CaptureSource
    public var merchant: String
    public var amount: Cents?
    public var cardID: UUID?
    public var date: Date
    public var currencyNeedsReview: Bool
    public var eventID: String?
    public var status: Status = .pending
    public init(source: CaptureSource, merchant: String, amount: Cents? = nil, cardID: UUID? = nil,
                date: Date = .now, currencyNeedsReview: Bool = true, eventID: String? = nil) {
        self.source = source; self.merchant = merchant; self.amount = amount; self.cardID = cardID
        self.date = date; self.currencyNeedsReview = currencyNeedsReview; self.eventID = eventID
    }
}
public struct CaptureSettings: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID(uuidString: "DF42E7C3-231E-49EA-B69B-B136D00A5901")!
    public var cashID: UUID?
    public var categoryID: UUID?
    public var santanderCardID: UUID?
    public var rules: [MerchantRule] = []
    public var drafts: [CaptureDraft] = []
    public init() {}
    public static func key(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_MX"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)
    }
    public func category(for merchant: String, in ledger: Ledger) -> UUID? {
        guard let rule = rules.first(where: { Self.key($0.merchant) == Self.key(merchant) }),
              ledger.categories.contains(where: { $0.id == rule.categoryID && !$0.archived }) else { return nil }
        return rule.categoryID
    }
    // Replays with a real source event ID are idempotent; similar text alone is never discarded.
    @discardableResult public mutating func receive(_ draft: CaptureDraft) throws -> UUID {
        if let eventID = draft.eventID, let previous = drafts.first(where: { $0.source == draft.source && $0.eventID == eventID }) { return previous.id }
        guard drafts.count < 200 else { throw FinanceError.invalid("Hay 200 capturas. Revisa los pendientes y limpia el historial procesado en Atajos de Numa.") }
        drafts.append(draft)
        return draft.id
    }
    public func hasPossibleDuplicate(_ draft: CaptureDraft, in ledger: Ledger) -> Bool {
        let pendingMatch = drafts.contains {
            $0.id != draft.id && $0.status != .discarded && Self.key($0.merchant) == Self.key(draft.merchant)
            && $0.cardID == draft.cardID && abs($0.date.timeIntervalSince(draft.date)) <= 300
            && ($0.amount == nil || draft.amount == nil || $0.amount == draft.amount)
        }
        return pendingMatch || ledger.entries.contains {
            $0.id != draft.id && $0.kind == .expense && Self.key($0.note) == Self.key(draft.merchant)
            && $0.cardID == draft.cardID && abs($0.date.timeIntervalSince(draft.date)) <= 300
            && (draft.amount == nil || draft.amount == $0.amount)
        }
    }
    public func validate() throws {
        guard id == CaptureSettings().id, drafts.count <= 200, rules.count <= 100,
              Set(drafts.map(\.id)).count == drafts.count, Set(rules.map(\.id)).count == rules.count,
              Set(rules.map { Self.key($0.merchant) }).count == rules.count,
              rules.allSatisfy({ !Self.key($0.merchant).isEmpty && $0.merchant.count <= 160 }),
              drafts.allSatisfy({ !$0.merchant.isEmpty && $0.merchant.count <= 160 && ($0.amount.map { $0 > 0 && $0 <= Money.maximum } ?? true) && ($0.eventID?.count ?? 0) <= 128 && $0.date.timeIntervalSince1970.isFinite }) else {
            throw FinanceError.invalid("La configuración de Atajos contiene datos inválidos. No se modificó el archivo.")
        }
    }
}
public enum CaptureParser {
    public static func draft(source: CaptureSource, text: String?, merchant: String?, amount: String?,
                             currency: String?, cardID: UUID?, eventID: String?, date: Date = .now) throws -> CaptureDraft {
        guard (text?.count ?? 0) <= 4096, (eventID?.count ?? 0) <= 128 else { throw FinanceError.invalid("La entrada del atajo es demasiado larga.") }
        guard date.timeIntervalSince1970.isFinite, date >= .distantPast, date <= Date.now else { throw FinanceError.invalid("Revisa la fecha de la compra; no puede estar en el futuro.") }
        let currency = currency?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard currency == nil || currency == "" || currency == "MXN" else { throw FinanceError.invalid("Numa registra MXN. Revisa la moneda y captura el importe manualmente; no se convirtió ni guardó el gasto.") }
        var name = merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty, source != .wallet, let text,
           let range = text.range(of: #"(?im)^[ \t]*(?:has|haz) realizado una compra en[ \t]+[^\r\n]+"#, options: .regularExpression) {
            let line = String(text[range])
            if let prefix = line.range(of: #"(?i)^(?:\s*)(?:has|haz) realizado una compra en\s+"#, options: .regularExpression) {
                name = String(line[prefix.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        guard !name.isEmpty, name.count <= 160 else { throw FinanceError.invalid("No se identificó el comercio. Envía Comercio desde Atajos o abre el gasto manual. No se guardó ninguna compra.") }
        let value = amount?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cents = value.isEmpty ? nil : try Money.parse(value)
        let reference = eventID?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CaptureDraft(source: source, merchant: name, amount: cents, cardID: cardID, date: date,
                            currencyNeedsReview: currency != "MXN", eventID: reference?.isEmpty == false ? reference : nil)
    }
}

extension Ledger {
    // The repository persists the expense and receipt together via FinanceStore.change.
    public mutating func saveCapturedExpense(_ entry: Entry, captureID: UUID) throws {
        guard entry.kind == .expense, entry.id == captureID,
              let index = capture?.drafts.firstIndex(where: { $0.id == captureID }),
              capture?.drafts[index].status == .pending,
              !entries.contains(where: { $0.id == captureID }) else {
            throw FinanceError.invalid("La captura ya fue registrada o descartada. No se guardó un segundo movimiento.")
        }
        try saveEntry(entry)
        capture?.drafts[index].status = .saved
    }
}
