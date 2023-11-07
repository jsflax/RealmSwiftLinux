import realmCxx

public struct NotificationToken {
    fileprivate let token: Any
}

public struct ObjectChange {
    /// The object being observed.
    public let object: bridge.object
    /// The object has been deleted from the Realm.
    public let isDeleted: Bool
    /**
     If an error occurs, notification blocks are called one time with an `error`
     result and an `std::exception` containing details about the error. Currently the
     only errors which can occur are when opening the Realm on a background
     worker thread to calculate the change set. The callback will never be
     called again after `error` is delivered.
     */
    public let error: Error?
    /**
     One or more of the properties of the object have been changed.
     */
    public let propertyChanges: [PropertyChange]
}

public struct PropertyChange {
    /**
     The name of the property which changed.
    */
    public let name: String

    /**
     Value of the property before the change occurred. This is not supplied if
     the change happened on the same thread as the notification and for `List`
     properties.

     For object properties this will give the object which was previously
     linked to, but that object will have its new values and not the values it
     had before the changes. This means that `previousValue` may be a deleted
     object, and you will need to check `isInvalidated` before accessing any
     of its properties.
    */
    public let oldValue: (any Persistable)?

    /**
     The value of the property after the change occurred. This is not supplied
     for `List` properties and will always be nil.
    */
    public let newValue: (any Persistable)?
}

extension bridge.object {
    public func swift_observe(_ block: @escaping (ObjectChange) -> Void) -> NotificationToken {
        let copy = self
        return NotificationToken(token: realmCxx.observe(self, { change in
            let isDeleted = change.is_deleted
            let error = change.error
            if error.__convertToBool() {
                fatalError()
            } else if isDeleted {
                block(ObjectChange(object: copy, isDeleted: true, error: nil, propertyChanges: []))
            } else {
                let changes = change.property_changes.map { change in
                    var oldValue: (any Persistable)? = nil
                    var newValue: (any Persistable)? = nil
                    if change.old_value.__convertToBool() {
                        let pointee = change.old_value.pointee
                        switch pointee.type() {
                        case .Int:
                            let int: std.int64_t = bridge_cast(pointee)
                            oldValue = Int(int)
                        case .String:
                            let str: std.string = bridge_cast(pointee)
                            oldValue = String(str)
                        default: break
                        }
                    }
                    if change.new_value.__convertToBool() {
                        let pointee = change.new_value.pointee
                        switch pointee.type() {
                        case .Int:
                            let int: std.int64_t = bridge_cast(pointee)
                            newValue = Int(int)
                        case .String:
                            let str: std.string = bridge_cast(pointee)
                            newValue = String(str)
                        default: break
                        }
                    }
                    return PropertyChange(name: String(change.name),
                                                 oldValue: oldValue,
                                                 newValue: newValue)
                }
                block(ObjectChange(object: copy, isDeleted: true, error: nil, propertyChanges: changes))
            }
        }))
    }
}
