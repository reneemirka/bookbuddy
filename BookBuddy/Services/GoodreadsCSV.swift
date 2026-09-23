import Foundation

struct GoodreadsRow {
    let id, title, author, isbn, shelf, review: String
    let rating: Double?
    let dateRead, dateAdded: Date?
}

enum GoodreadsCSVError: LocalizedError { case invalidFile
    var errorDescription: String? { "This file is not a valid Goodreads CSV export." }
}

enum GoodreadsCSV {
    static func parse(_ data: Data) throws -> [GoodreadsRow] {
        guard let text = String(data: data, encoding: .utf8) else { throw GoodreadsCSVError.invalidFile }
        let rows = parseRows(text)
        guard let header = rows.first else { throw GoodreadsCSVError.invalidFile }
        let keys = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element.lowercased(), $0.offset) })
        guard keys["title"] != nil, keys["author"] != nil else { throw GoodreadsCSVError.invalidFile }
        func value(_ row: [String], _ key: String) -> String { guard let i = keys[key], row.indices.contains(i) else { return "" }; return row[i].trimmingCharacters(in: .whitespacesAndNewlines) }
        return rows.dropFirst().compactMap { row in
            let title = value(row, "title"); guard !title.isEmpty else { return nil }
            let rating = Double(value(row, "my rating")).flatMap { $0 == 0 ? nil : $0 }
            return GoodreadsRow(id: value(row, "book id"), title: title, author: value(row, "author"), isbn: value(row, "isbn13").isEmpty ? value(row, "isbn") : value(row, "isbn13"), shelf: value(row, "exclusive shelf"), review: value(row, "my review"), rating: rating, dateRead: date(value(row, "date read")), dateAdded: date(value(row, "date added")))
        }
    }
    static func parseRows(_ text: String) -> [[String]] {
        var rows = [[String]](), row = [String](), field = "", quoted = false; var i = text.startIndex
        while i < text.endIndex { let c = text[i]; if c == "\"" { let n = text.index(after: i); if quoted && n < text.endIndex && text[n] == "\"" { field.append(c); i = n } else { quoted.toggle() } } else if c == "," && !quoted { row.append(field); field = "" } else if (c == "\n" || c == "\r") && !quoted { if c == "\r", text.index(after: i) < text.endIndex, text[text.index(after: i)] == "\n" { i = text.index(after: i) }; row.append(field); rows.append(row); row = []; field = "" } else { field.append(c) }; i = text.index(after: i) }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }; return rows
    }
    static func date(_ value: String) -> Date? { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy/MM/dd"; return f.date(from: value) }
}
