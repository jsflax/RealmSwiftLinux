import realmCxx

public struct Results<Element : Object> : Sequence {
    public struct Iterator : IteratorProtocol {
        var i = 0
        var results: bridge.results
        var realm: Realm
        public mutating func next() -> Element? {
            if i >= results.size() {
                return nil
            }
            defer { i += 1 }
            let obj = results_get(&results, i)
            return Element(bridge.object(realm._realm, obj))
        }
    }
    var results: bridge.results
    var realm: Realm
    
    public func makeIterator() -> Iterator {
        Iterator(results: self.results, realm: self.realm)
    }
    
    public var count: Int {
        var results = self.results
        return results.size()
    }
    
    public func filter(_ fn: @escaping (Element) -> Bool) -> Results<Element> {
        Results(results: results_filter(results, {
            let object = bridge.object(realm._realm, $0)
            return fn(Element(object))
        }), realm: realm)
    }
}
