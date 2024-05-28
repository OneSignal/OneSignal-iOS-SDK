extension NSDictionary {
    /*
     This method goes one level deep into dictionaries
     */
    private func contains(key: String, value: Any) -> Bool {
        guard let dictVal = self[key] else {
            return false
        }
        if let value = value as? [String: Any],
           let dictVal = dictVal as? NSDictionary {
            return dictVal.contains(value)
        } else {
            return equals(dictVal, value)
        }
    }

    /*
     let parent = [
         "apple": [
             "type": "fruit",
             "count": 5,
             "fresh": true
         ],
         "orange": [
             "type": "color"
         ],
         "cactus": "error"
     ]
     
     // 1. Example 1 -
     let child1 = [
        "apple": [
            "type": "fruit",
            "fresh": true
         ]
     ]
     parent.contains(child1) = true
     
     // 2. Example 2 -
     let child2 = [
         "apple": [
             "type": "fruit"
         ],
         "orange": [
             "type": "fruit"
         ]
     ]
     parent.contains(child2) = false
     
     // 3. Example 3 -
     let child3 = [
         "orange": [
             "type": "color"
         ],
         "cactus": "error"
     ]
     parent.contains(child3) = true
     */
    public func contains(_ dict: [String: Any]) -> Bool {
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

    /**
     Returns a string representation of a dictionary in alphabetical order by key.
     If there are dictionaries within this dictionary, those will also be stringified in alphabetical order by key.
     This method is motivated by the need to compare two requests whose payloads may be unordered dictionaries.
     */
    public func toSortedString() -> String {
        guard let dict = self as? [String: Any] else {
            return "[:]"
        }
        var result = "["
        let sortedKeys = Array(dict.keys).sorted(by: <)
        for key in sortedKeys {
            if let value = dict[key] as? NSDictionary {
                result += " \(key): \(value.toSortedString()),"
            } else {
                result += " \(key): \(String(describing: dict[key])),"
            }
        }
        // drop the last comma within a dictionary's items
        result = String(result.dropLast())
        result += "]"
        return result
    }
}
