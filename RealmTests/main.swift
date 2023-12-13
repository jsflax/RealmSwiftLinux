import Foundation
import Realm

@Object struct Person {
    var name: String
    var age: Int
    var dog: Dog?
}

@Object struct Dog {
    var name: String
}

var realm = try Realm(Person.self, Dog.self)
var jack = Person(name: "Jack", age: 33, dog: Dog(name: "Fido"))
var jill = Person(name: "Jill", age: 30, dog: nil)

realm.write {
    realm.add(&jack)
    realm.add(&jill)
}

precondition(jack.name == "Jack")
precondition(jack.age == 33)

let token = jack.observe { changes in
    for change in changes {
        switch change {
        case .name(_, let newValue): precondition(newValue == "Jill")
        case .age(_, let newValue): precondition(newValue == 30)
        case .dog(_, _): preconditionFailure()
        }
    }
}

//realm.write {
//    person.name = "Jill"
//    person.age = 30
//}

let results = realm.objects(Person.self)
precondition(results.count == 2)

precondition(results.filter {
    $0.name == "Jack"
}.count == 1)

precondition(results.filter {
    $0.name == "Jill"
}.count == 1)

precondition(results.filter {
    $0.name == "John"
}.count == 0)
//for person in results {
//    precondition(person.name == "Jill")
//    precondition(person.age == 30)
//}

realm.write {
    realm.delete(jack)
    realm.delete(jill)
}

precondition(results.count == 0)

realm.close()
realm.deleteFiles()

//let app = App(appId: "car-zxny")
//let user = try await app.login()
//
//var syncedRealm = try Realm(config: user.flexibleSyncConfiguration,
//                            Person.self,
//                            Dog.self)
//
