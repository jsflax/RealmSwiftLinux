import Foundation
@_exported import realmCxx

public protocol ObjectChangeKind {
    init(name: String, oldValue: (any Persistable)?, newValue: (any Persistable)?)
}

public protocol Object : Persistable {
    associatedtype Change : ObjectChangeKind
    static var objectSchema: ObjectSchema { get }
    var object: realmCxx.bridge.object? { get set }
    init()
    init(_ cxxValue: realmCxx.bridge.object)
    mutating func _manage(_ object: inout bridge.object)
}

extension Object {
    public static var propertyType: PropertyType {
        .object
    }
    public var cxxValue: bridge.object {
        object!
    }
    
    public func observe(_ block: @escaping ([Change]) -> Void) -> NotificationToken {
        object!.swift_observe { change in
            block(change.propertyChanges.map { propertyChange in
                Change(name: propertyChange.name, oldValue: propertyChange.oldValue,
                       newValue: propertyChange.newValue)
            })
        }
    }
}
