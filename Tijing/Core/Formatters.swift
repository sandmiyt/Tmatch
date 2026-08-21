import Foundation

nonisolated enum TijingFormat {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        let normalized = value <= 1 ? value * 100 : value
        return "\(Int(normalized.rounded()))%"
    }

    static func dateTime(_ iso: String?) -> String {
        guard let iso else { return "" }
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: iso) else { return iso.replacingOccurrences(of: "T", with: " ") }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func duration(milliseconds: Int) -> String {
        String(format: "%.1fs", Double(milliseconds) / 1000)
    }

    static func optionLetter(_ index: Int, fallback: String = "?") -> String {
        guard index >= 0, index < 26, let scalar = UnicodeScalar(65 + index) else { return fallback }
        return String(scalar)
    }
}
