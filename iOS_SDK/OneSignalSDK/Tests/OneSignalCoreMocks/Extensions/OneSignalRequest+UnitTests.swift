import OneSignalCore

extension OneSignalRequest {
    /// Returns alphabetically ordered string representation of request's parameters
    public func stringifyParams() -> String {
        guard let dict = self.parameters as? NSDictionary else {
            return "[:]"
        }
        return dict.toSortedString()
    }
}
