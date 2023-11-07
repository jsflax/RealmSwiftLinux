import realmCxx

public struct Config {
    fileprivate var config = realmCxx.bridge.realm.config()
    public var schema: Schema? {
        get {
            var config = config
            return Optional(fromCxx: config.get_schema())
        }
        set {
            if let newValue = newValue {
                config.set_schema(newValue)
            }
        }
    }
    
    public init(path: String, schema: Schema? = nil) {
        self.schema = schema
        config.set_path(std.string(path))
    }
}

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
}

public struct Realm {
    public let sharedSchema: [any Object.Type]
    package var _realm: realmCxx.bridge.realm
    
    public init(config: Config = Config(path: "default.realm"),
                _ types: any Object.Type...) {
        self.sharedSchema = types
        var config = config
        if config.schema == nil {
            config.schema = Schema(objectSchemas: sharedSchema.map { $0.objectSchema })
        }
        _realm = realmCxx.bridge.realm(config.config)
    }
    
    public func write(_ block: () -> Void) {
        _realm.begin_transaction()
        block()
        _realm.commit_transaction()
    }
    
    public mutating func add<T : Object>(_ object: inout T) {
        let table = _realm.table_for_object_type(std.string(T.objectSchema.name))
        var obj = bridge.object(_realm, table.create_object(bridge.obj_key()))
        object._manage(&obj)
    }
    
    public mutating func objects<T : Object>(_ type: T.Type) -> Results<T> {
        Results(results: bridge.results(_realm,
                                        bridge.query(_realm.table_for_object_type(std.string(T.objectSchema.name)))),
                realm: self)
    }
    
    public mutating func delete<T : Object>(_ object: consuming T) {
        let object = consume object
        let table = _realm.table_for_object_type(std.string(T.objectSchema.name))
        table.remove_object(object.object!.get_obj().get_key())
    }
    
    public mutating func close() {
        self._realm.close()
    }
    public mutating func deleteFiles() {
        self._realm.delete_files()
    }
}

@attached(extension, conformances: Object, names: named(Object), arbitrary)
@attached(member, names: named(objectSchema), arbitrary)
@attached(memberAttribute)
@available(swift 5.9)
public macro Object() = #externalMacro(module: "RealmMacros", type: "ObjectMacro")
@attached(accessor)
@available(swift 5.9)
public macro Persisted() = #externalMacro(module: "RealmMacros", type: "PersistedMacro")
