import Foundation

/// A small RFC 4180 reader for Google's CSV export: fields may be quoted,
/// quoted fields may contain commas, line breaks and doubled quotes, records
/// end in CRLF, LF or CR, and the file may start with a byte-order mark.
public enum CSV {
    public static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var afterQuotedField = false
        var sawAnything = false

        var scalars = text.unicodeScalars[...]
        if scalars.first == "\u{FEFF}" { scalars.removeFirst() }

        var iterator = scalars.makeIterator()
        var pending: Unicode.Scalar? = nil

        func next() -> Unicode.Scalar? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        func endField() {
            row.append(field)
            field = ""
            afterQuotedField = false
        }

        func endRecord() {
            endField()
            rows.append(row)
            row = []
        }

        while let c = next() {
            sawAnything = true
            if inQuotes {
                if c == "\"" {
                    if let n = next() {
                        if n == "\"" {
                            field.unicodeScalars.append("\"")
                        } else {
                            inQuotes = false
                            afterQuotedField = true
                            pending = n
                        }
                    } else {
                        inQuotes = false
                        afterQuotedField = true
                    }
                } else {
                    field.unicodeScalars.append(c)
                }
                continue
            }
            switch c {
            case "\"":
                if field.isEmpty && !afterQuotedField {
                    inQuotes = true
                } else {
                    // A stray quote inside an unquoted field is kept as text.
                    field.unicodeScalars.append(c)
                }
            case ",":
                endField()
            case "\r":
                if let n = next(), n != "\n" { pending = n }
                endRecord()
            case "\n":
                endRecord()
            default:
                field.unicodeScalars.append(c)
            }
        }

        if !field.isEmpty || !row.isEmpty || afterQuotedField {
            endRecord()
        } else if sawAnything && rows.isEmpty {
            // Only line breaks: no records.
        }
        return rows
    }
}
