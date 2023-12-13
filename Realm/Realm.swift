import realmCxx

public extension realmCxx.bridge.realm.config {
    var schema: Schema? {
        get {
            var cpy = self
            return Optional(fromCxx: cpy.get_schema())
        }
        set {
            if let newValue = newValue {
                set_schema(newValue)
            }
        }
    }
    
    init(path: String, schema: Schema? = nil) {
        self = realmCxx.bridge.realm.config()
        if let schema = schema {
            self.set_schema(schema)
        }
        self.set_path(std.string(path))
    }
}
extension realm.Exception : Error, CustomStringConvertible {
    public var description: String {
        String(string_view_to_string(self.reason()))
    }
}

public typealias Config = realmCxx.bridge.realm.config

//func cxx_try<T>(_ block: () -> T) throws -> T {
//    return try_catch {
//        return block()
//    }
//}

public struct Realm {
    public let sharedSchema: [any Object.Type]
    package var _realm: realmCxx.bridge.realm
    
    public init(config: Config = Config(path: "default.realm"),
                _ types: any Object.Type...) throws {
        self.sharedSchema = types
        var config = config
        if config.schema == nil {
            config.schema = Schema(objectSchemas: sharedSchema.map { $0.objectSchema })
        }

        let variant = get_realm(config)
        if realmCxx.holds_exception(variant) {
            let error: realm.Exception = variant_get(variant)
            throw error
        }
        _realm = variant_get(variant)
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
@freestanding(expression)
macro cxxTry<T>(_ block: () -> T) -> T = #externalMacro(module: "RealmMacros", type: "CxxTry")
