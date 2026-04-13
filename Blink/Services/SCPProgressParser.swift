import Foundation

enum SCPProgressParser {
    private static let progressPattern = try! NSRegularExpression(
        pattern: #"^\s*(\S+)\s+(\d{1,3})%\s+(\S+)\s+(\S+/s)\s+(\S+)"#
    )

    static func parse(line: String) -> TransferProgress? {
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\r", with: "")
        guard !cleaned.isEmpty else { return nil }

        let range = NSRange(cleaned.startIndex..., in: cleaned)
        guard let match = progressPattern.firstMatch(in: cleaned, options: [], range: range),
              match.numberOfRanges >= 6 else { return nil }

        func group(_ i: Int) -> String? {
            let r = match.range(at: i)
            guard r.location != NSNotFound, let sr = Range(r, in: cleaned) else { return nil }
            return String(cleaned[sr])
        }

        guard let filename = group(1),
              let pctStr = group(2), let percentage = Int(pctStr),
              let transferred = group(3),
              let speed = group(4),
              let eta = group(5) else { return nil }

        return TransferProgress(filename: filename, percentage: percentage, transferred: transferred, speed: speed, eta: eta)
    }
}
