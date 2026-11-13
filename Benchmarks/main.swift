import Foundation
import FinanceCore
import FinanceFixtures

struct Measurement: Encodable {
    var samplesMS: [Double]
    var medianMS: Double { samplesMS.sorted()[samplesMS.count / 2] }
    var maximumMS: Double { samplesMS.max() ?? 0 }
    enum CodingKeys: CodingKey { case samplesMS, medianMS, maximumMS }
    func encode(to encoder: any Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(samplesMS, forKey: .samplesMS)
        try box.encode(medianMS, forKey: .medianMS)
        try box.encode(maximumMS, forKey: .maximumMS)
    }
}
struct Result: Encodable {
    var dataset = "seed-42-v1"
    var entries: Int
    var accounts: Int
    var cards: Int
    var goals: Int
    var os = ProcessInfo.processInfo.operatingSystemVersionString
    var processors = ProcessInfo.processInfo.processorCount
    var physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
    var measurements: [String: Measurement]
    var invariants: [String: Cents]
}
var sink: Cents = 0
@MainActor func measure(_ operation: () throws -> Cents) rethrows -> Measurement {
    sink &+= try operation() // One warmup, not included.
    var times: [Double] = []
    for _ in 0..<7 {
        let start = ContinuousClock.now
        sink &+= try operation()
        let duration = start.duration(to: .now).components
        times.append(Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15)
    }
    return Measurement(samplesMS: times)
}
let ledger = try SyntheticLedger.make()
let index = LedgerReadIndex(ledger)
let month = FinanceDates.calendar.dateInterval(of: .month, for: SyntheticLedger.reference)!
let report = index.report(in: month, through: SyntheticLedger.reference)
var measurements: [String: Measurement] = [:]
measurements["validate_10000"] = try measure { try ledger.validateIntegrity(); return Cents(ledger.entries.count) }
measurements["build_read_index"] = measure { LedgerReadIndex(ledger).summary.available }
measurements["monthly_report"] = measure {
    let report = index.report(in: month, through: SyntheticLedger.reference)
    return report.income + report.expense + report.outflow + report.timeline.reduce(0) { $0 + $1.balance }
}
measurements["search_history"] = measure { Cents(index.matching(EntryFilter(search: "Transporte")).count) }
measurements["format_50_amounts"] = measure { Cents(ledger.entries.prefix(50).map { Money.format($0.amount).count }.reduce(0, +)) }
measurements["save_entry_domain"] = try measure {
    var candidate = ledger
    let entry = Entry(kind: .expense, amount: 1234, date: SyntheticLedger.reference,
                      categoryID: ledger.categories[0].id, accountID: ledger.accounts[0].id)
    try candidate.saveEntry(entry)
    return candidate.total
}
let result = Result(entries: ledger.entries.count, accounts: ledger.accounts.count, cards: ledger.cards.count, goals: ledger.goals.count,
                    measurements: measurements,
                    invariants: ["total": ledger.total, "available": ledger.available, "debt": ledger.totalDebt,
                                 "reserved": ledger.reserved(), "report_income": report.income, "report_expense": report.expense,
                                 "report_outflow": report.outflow, "timeline_checksum": report.timeline.reduce(0) { $0 + $1.balance },
                                 "search_count": Cents(index.matching(EntryFilter(search: "Transporte")).count)])
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(result)
if CommandLine.arguments.count > 1 { try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic) }
print(String(decoding: data, as: UTF8.self))
