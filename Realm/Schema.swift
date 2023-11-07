import realmCxx
import Cxx

extension bridge.object_schema {
    public init(name: String, properties: [Property]) {
        self.init()
        set_name(std.string(name))
        properties.forEach { property in
            add_property(property)
        }
    }
    
    var name: String {
        String(self.get_name())
    }
}
public typealias ObjectSchema = bridge.object_schema

extension bridge.schema {
    public init(objectSchemas: [ObjectSchema]) {
        self = bridge.schema(objectSchemas.reduce(into: CxxVectorOfObjectSchema(),
                                                  { $0.push_back($1) }))
    }
}
public typealias Schema = bridge.schema
