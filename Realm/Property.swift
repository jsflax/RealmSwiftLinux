import Foundation
import realmCxx
import Cxx

public struct PropertyType : OptionSet {
    public var rawValue: UInt32
    public static let int = PropertyType([])
    public static let bool = PropertyType(rawValue: 1)
    public static let string = PropertyType(rawValue: 2)
    public static let data = PropertyType(rawValue: 3)
    public static let date = PropertyType(rawValue: 4)
    public static let float = PropertyType(rawValue: 5)
    public static let double = PropertyType(rawValue: 6)
    public static let object = PropertyType(rawValue: 7)
    public static let linkingObjects = PropertyType(rawValue: 8)

    public static let mixed = PropertyType(rawValue: 9)
    public static let objectId = PropertyType(rawValue: 10)
    public static let decimal = PropertyType(rawValue: 11)
    public static let uuid = PropertyType(rawValue: 12)

    // Flags which can be combined with any of the above types except as noted
    public static let required = PropertyType([])
    public static let nullable = PropertyType(rawValue: 64)
    public static let array = PropertyType(rawValue: 128)
    public static let set = PropertyType(rawValue: 256)
    public static let dictionary = PropertyType(rawValue: 512)
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

public protocol Persistable {
    associatedtype CxxValue
    static var propertyType: PropertyType { get }
    init(_ cxxValue: CxxValue)
    var cxxValue: CxxValue { get }
}

extension String : Persistable {
    public static var propertyType: PropertyType {
        .string
    }
    public var cxxValue: std.string {
        std.string(self)
    }
}

extension Int : Persistable {
    public typealias CxxValue = Int64
    public static var propertyType: PropertyType {
        .int
    }
    public var cxxValue: std.int64_t {
        std.int64_t(self)
    }
}

extension Optional : Persistable, CxxOptional where Wrapped : Persistable {
    public func __convertToBool() -> Bool {
        return self != nil
    }
    public var pointee: Wrapped.CxxValue {
        return self!.cxxValue
    }
    public static var propertyType: PropertyType {
        [Wrapped.propertyType, .nullable]
    }
    public init() {
        self = .none
    }
    public var cxxValue: Self {
        self
    }
    public init(_ cxxValue: Self) {
        self = cxxValue
    }
}

public extension bridge.property {
    init<V, T>(name: String,
               keyPath: KeyPath<V, PropertyStorage<T>>) where T : Persistable {
        let type = T.propertyType
        if T.propertyType.contains(.object) {
            let objectClassName = String("\(T.self)"
                .replacingOccurrences(of: "Optional<", with: "")
                .dropLast())
            self = bridge.property(std.string(name),
                            bridge.property.type(rawValue: Int32(type.rawValue))!,
                            std.string(objectClassName))
        } else {
            self = bridge.property(std.string(name),
                            bridge.property.type(rawValue: Int32(type.rawValue))!,
                            false)
        }
    }
}

public typealias Property = bridge.property

public enum PropertyStorage<T : Persistable> {
    case unmanaged(T)
    case managed(realmCxx.bridge.col_key)
}

public protocol BridgingObject {
    func swift_get(_ key: bridge.col_key) -> String
    func swift_get(_ key: bridge.col_key) -> Int
    func swift_get<T>(_ key: bridge.col_key) -> T where T : Object
    func swift_get<T>(_ key: bridge.col_key) -> Optional<T> where T : Persistable
    mutating func swift_set(_ key: bridge.col_key, _ value: inout Int)
    mutating func swift_set(_ key: bridge.col_key, _ value: inout String)
    mutating func swift_set<T>(_ key: bridge.col_key, _ value: inout T?) where T : Object
    func swift_observe(_ block: @escaping (ObjectChange) -> Void) -> NotificationToken
}

extension realmCxx.bridge.object : BridgingObject {
    public func swift_get(_ key: bridge.col_key) -> String {
        let ret: String.CxxValue = self.get_obj().get(key)
        return String(ret)
    }
    public func swift_get_any(_ key: bridge.col_key) -> bridge.mixed {
        return self.get_obj().get(key)
    }
    public func swift_get(_ key: bridge.col_key) -> Int {
        let obj = self.get_obj()
        let ret: std.int64_t = obj.get(key)
        let retVal = Int(ret)
        return retVal
    }
    public func swift_get<T : Persistable>(_ key: bridge.col_key) -> Optional<T> {
        if self.get_obj().is_null(key) {
            return nil
        } else {
            return swift_get(key)
        }
    }
    public func swift_get<T : Object>(_ key: bridge.col_key) -> T {
        var copy = self.get_obj()
        let ret: bridge.obj = copy.get_linked_object(key)
        return T(bridge.object(self.get_realm(), ret))
    }
    public mutating func swift_set(_ key: bridge.col_key, _ value: inout Int) {
        var obj = self.get_obj()
        obj.set(key, std.int64_t(value))
    }
    public mutating func swift_set(_ key: bridge.col_key, _ value: inout String) {
        var obj = self.get_obj()
        obj.set(key, std.string(value))
    }
    public mutating func swift_set<T>(_ key: bridge.col_key, _ value: inout T?) where T : Object {
        if let object = value?.object {
            var obj = self.get_obj()
            obj.set(key, object.get_obj().get_key())
        } else {
            let table = get_obj().get_target_table(key)
            let obj = table.create_object(bridge.obj_key())
            precondition(table.is_valid(obj.get_key()))
            var object = bridge.object(self.get_realm(), obj)
            value?._manage(&object)
            var this = get_obj()
            this.set(key, obj.get_key())
        }
    }
}
