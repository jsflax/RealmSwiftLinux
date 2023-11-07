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

var realm = Realm(Person.self, Dog.self)
var person = Person(name: "Jack", age: 33, dog: Dog(name: "Fido"))

realm.write {
    realm.add(&person)
}

precondition(person.name == "Jack")
precondition(person.age == 33)

let token = person.observe { changes in
    for change in changes {
        switch change {
        case .name(_, let newValue): precondition(newValue == "Jill")
        case .age(_, let newValue): precondition(newValue == 30)
        case .dog(_, _): preconditionFailure()
        }
    }
}

realm.write {
    person.name = "Jill"
    person.age = 30
}

let results = realm.objects(Person.self)
precondition(results.count == 1)

for person in results {
    precondition(person.name == "Jill")
    precondition(person.age == 30)
}

realm.write {
    realm.delete(person)
}

precondition(results.count == 0)

realm.close()
realm.deleteFiles()

print("Done")
