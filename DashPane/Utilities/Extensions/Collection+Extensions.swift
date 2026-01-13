import Foundation

extension Collection {

    /// Safe subscript that returns nil if index is out of bounds
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Array {

    /// Move element from one index to another
    mutating func move(from source: Int, to destination: Int) {
        guard source != destination,
              source >= 0 && source < count,
              destination >= 0 && destination < count else {
            return
        }

        let element = remove(at: source)
        insert(element, at: destination)
    }
}

extension String {

    /// Four character code for Carbon APIs
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        for char in utf8.prefix(4) {
            result = result << 8 + FourCharCode(char)
        }
        return result
    }
}
