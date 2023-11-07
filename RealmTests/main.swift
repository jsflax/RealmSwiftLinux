import Foundation
import Realm

//struct Person : Object {
//    enum Change : ObjectChangeKind {
//        init(name: String, oldValue: (any Persistable)?, newValue: (any Persistable)?) {
//            self = .name(oldValue: oldValue as? String, newValue: newValue as? String)
//        }
//        case name(oldValue: String?, newValue: String?)
//    }
//    
//    static var objectSchema: ObjectSchema {
//        ObjectSchema(name: "Person", properties: [
//            Property(name: "name", keyPath: \Person._name),
//            Property(name: "age", keyPath: \Person._age),
//        ])
//    }
//    
//    var object: bridge.object? = nil
//    
//    private var _name: PropertyStorage<String> = .unmanaged("")
//    var name: String {
//        get {
//            switch _name {
//            case .unmanaged(let value): 
//                return value
//            case .managed(let colKey): 
//                return object!.swift_get(colKey)
//            }
//        }
//        set {
//            if var object = object, case let .managed(colKey) = _name {
//                object.swift_set(colKey, newValue)
//            } else {
//                _name = .unmanaged(newValue)
//            }
//        }
//    }
//    
//    private var _age: PropertyStorage<Int> = .unmanaged(0)
//    var age: Int {
//        get {
//            switch _age {
//            case .unmanaged(let value): return value
//            case .managed(let colKey): return object!.swift_get(colKey)
//            }
//        }
//        set {
//            if var object = object, case let .managed(colKey) = _age {
//                object.swift_set(colKey, newValue)
//            } else {
//                _age = .unmanaged(newValue)
//            }
//        }
//    }
//}

@Object struct Person {
    var name: String
    var age: Int
    var dog: Dog?
}

@Object struct Dog {
    var name: String
}

var realm = Realm(Person.self, Dog.self)
var person = Person(name: "Jason", age: 33, dog: Dog(name: "Fido"))

realm.write {
    realm.add(&person)
}

precondition(person.name == "Jason")
precondition(person.age == 33)

let token = person.observe { changes in
    for change in changes {
        switch change {
        case .name(_, let newValue): precondition(newValue == "Meghna")
        case .age(_, let newValue): precondition(newValue == 30)
        case .dog(_, _): preconditionFailure()
        }
    }
}

realm.write {
    person.name = "Meghna"
    person.age = 30
}

let results = realm.objects(Person.self)
precondition(results.count == 1)

for person in results {
    precondition(person.name == "Meghna")
    precondition(person.age == 30)
}

realm.write {
    realm.delete(person)
}

precondition(results.count == 0)

realm.close()
realm.deleteFiles()

print("Done")
