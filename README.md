If you have xcode, simply double click the Package.swift file or open that file in xcode and wait for package resolution to complete.

If you are using the vscode swift extension, I believe you just need to open up the repo in vscode.

The final code in the repo differs slightly from what is being presented (it is more streamlined– the presentation has a few "mistakes" in it for teaching purposes)– but it's a nice little Realm SDK playground.

Macro modification can be added to the RealmMacros target, SDK modification can be added to the Realm target, the main file in the RealmTests target is our executable, and bridging code is contained in the realmCxx target (and the realm-cpp branch reference in the Package.swift file).

```swift
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
```