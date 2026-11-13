import XCTest
@testable import FinanceCore

final class CaptureTests: XCTestCase {
    func testSantanderSampleExtractsOnlyMerchantAndDoesNotGuessMoney() throws {
        for source in [CaptureSource.santanderEmail, .santanderNotification] {
            let draft = try CaptureParser.draft(source: source, text: "Haz realizado una compra en Mercado Libre", merchant: nil, amount: nil, currency: nil, cardID: nil, eventID: nil)
            XCTAssertEqual(draft.merchant, "Mercado Libre")
            XCTAssertNil(draft.amount)
            XCTAssertTrue(draft.currencyNeedsReview)
        }
    }
    func testRejectsUnknownTextForeignCurrencyAmbiguousMoneyAndFutureDate() {
        XCTAssertThrowsError(try CaptureParser.draft(source: .santanderEmail, text: "Código privado 123456", merchant: nil, amount: nil, currency: nil, cardID: nil, eventID: nil))
        for (amount, currency) in [("1,234.56", "MXN"), ("12.00", "USD"), ("-12", "MXN")] {
            XCTAssertThrowsError(try CaptureParser.draft(source: .wallet, text: nil, merchant: "Tienda", amount: amount, currency: currency, cardID: nil, eventID: nil))
        }
        XCTAssertThrowsError(try CaptureParser.draft(source: .wallet, text: nil, merchant: "Tienda", amount: nil, currency: nil, cardID: nil, eventID: nil, date: .distantFuture))
    }
    func testWalletUsesExactCentsAndDoesNotStoreOriginalMessage() throws {
        let draft = try CaptureParser.draft(source: .wallet, text: "Dato que no debe persistirse", merchant: "Tienda", amount: "12.34", currency: "mxn", cardID: nil, eventID: "event-test")
        XCTAssertEqual(draft.amount, 1234)
        XCTAssertFalse(draft.currencyNeedsReview)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(draft), as: UTF8.self).contains("Dato que no debe persistirse"))
    }
    func testRulesAreExactNormalizedAndExcludeArchivedCategories() throws {
        var ledger = Ledger.initial
        var config = CaptureSettings()
        config.rules = [MerchantRule(merchant: "Mercado Líbre", categoryID: ledger.categories[0].id)]
        XCTAssertEqual(config.category(for: "  MERCADO  LIBRE ", in: ledger), ledger.categories[0].id)
        XCTAssertNil(config.category(for: "Mercado Libre Plus", in: ledger))
        ledger.categories[0].archived = true
        XCTAssertNil(config.category(for: "Mercado Libre", in: ledger))
        config.rules.append(MerchantRule(merchant: "mercado libre", categoryID: ledger.categories[1].id))
        XCTAssertThrowsError(try config.validate())
    }
    func testSourceIDReplaysAreIdempotentButSimilarPurchasesRemainDistinct() throws {
        var config = CaptureSettings()
        let first = CaptureDraft(source: .wallet, merchant: "Tienda", amount: 100, eventID: "same")
        try config.receive(first)
        var replay = first; replay.id = UUID()
        XCTAssertEqual(try config.receive(replay), first.id)
        XCTAssertEqual(config.drafts.count, 1)
        let similar = CaptureDraft(source: .santanderEmail, merchant: "Tienda")
        try config.receive(similar)
        XCTAssertEqual(config.drafts.count, 2)
        XCTAssertTrue(config.hasPossibleDuplicate(similar, in: .initial))
    }
    func testDraftHasNoFinancialEffectAndOldLedgerDecodesWithoutCapture() throws {
        var ledger = Ledger.initial
        ledger.accounts = [Account(name: "Prueba", cash: true, opening: 10000)]
        let total = ledger.total
        var config = CaptureSettings()
        try config.receive(CaptureDraft(source: .wallet, merchant: "Tienda", amount: 1500))
        ledger.capture = config
        XCTAssertEqual(ledger.total, total)
        XCTAssertTrue(ledger.entries.isEmpty)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
        json.removeValue(forKey: "capture")
        let old = try JSONDecoder().decode(Ledger.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.capture)
        XCTAssertEqual(old.total, total)
    }
    func testCapacityFailsWithoutDroppingExistingPendingDrafts() throws {
        var config = CaptureSettings()
        for _ in 0..<200 { try config.receive(CaptureDraft(source: .wallet, merchant: "Tienda")) }
        XCTAssertThrowsError(try config.receive(CaptureDraft(source: .wallet, merchant: "Otra")))
        XCTAssertEqual(config.drafts.count, 200)
    }
}
