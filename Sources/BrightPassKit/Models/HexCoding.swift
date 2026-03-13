import Foundation

extension Data {
    /// Initializes `Data` from a hex-encoded string (e.g. "0a1b2c").
    /// Returns `nil` if the string contains non-hex characters or has odd length.
    init?(hexString: String) {
        let hex = hexString.lowercased()
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
