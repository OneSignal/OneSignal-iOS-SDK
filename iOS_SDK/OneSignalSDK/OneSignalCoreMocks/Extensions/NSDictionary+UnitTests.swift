extension NSDictionary {
    func contains(key: String, value: Any) -> Bool {
        guard let dictVal = self[key] else {
            return false
        }

        return equals(dictVal, value)
    }

    func contains(_ dict: [String: Any]) -> Bool {
        for (key, value) in dict {
            if !contains(key: key, value: value) {
                return false
            }
        }
        return true
    }

    private func equals(_ x: Any, _ y: Any) -> Bool {
        guard x is AnyHashable else { return false }
        guard y is AnyHashable else { return false }
        return (x as! AnyHashable) == (y as! AnyHashable)
    }
}
