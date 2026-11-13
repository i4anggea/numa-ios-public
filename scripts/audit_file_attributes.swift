import Foundation
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let urls = [directory] + (try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))
var results: [[String: String]] = []
for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
    results.append(["file":url == directory ? "audit-directory" : url.lastPathComponent,
                    "fileProtection":String(describing: attributes[.protectionKey] ?? "unavailable"),
                    "excludedFromBackup":String(describing: values.isExcludedFromBackup)])
}
let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted,.sortedKeys])
print(String(decoding: data, as: UTF8.self))
