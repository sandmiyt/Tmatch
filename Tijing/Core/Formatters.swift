import Foundation

nonisolated enum TijingFormat {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        let normalized = value <= 1 ? value * 100 : value
        return "\(Int(normalized.rounded()))%"
    }

    static func dateTime(_ iso: String?) -> String {
        guard let iso else { return "" }
        let raw = iso.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }

        // The backend commonly emits UTC timestamps with microseconds but no
        // explicit zone (for example 2026-08-21T03:46:49.123456). Treat those
        // as UTC, matching the web client, and support both fractional and
        // non-fractional ISO-8601 values before falling back to plain text.
        let hasZone = raw.range(of: #"(?:Z|[+-]\d{2}:?\d{2})$"#, options: .regularExpression) != nil
        let normalized = hasZone ? raw : "\(raw)Z"

        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: normalized) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        parser.formatOptions = [.withInternetDateTime]
        if let date = parser.date(from: normalized) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        // Never leak raw database microseconds into the UI if a legacy value
        // cannot be parsed. Keep the readable date/time portion only.
        return raw
            .replacingOccurrences(of: "T", with: " ")
            .replacingOccurrences(
                of: #"\.\d+(?=(?:Z|[+-]\d{2}:?\d{2})?$)"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "Z", with: "")
    }

    static func duration(milliseconds: Int) -> String {
        String(format: "%.1fs", Double(milliseconds) / 1000)
    }

    static func optionLetter(_ index: Int, fallback: String = "?") -> String {
        guard index >= 0, index < 26, let scalar = UnicodeScalar(65 + index) else { return fallback }
        return String(scalar)
    }
}
