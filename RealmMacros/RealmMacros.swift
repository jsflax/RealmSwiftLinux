import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: ObjectMacro

var objectIdentifiers: [String] = []

struct Declaration {
    let name: String
    let type: String
    let isOptional: Bool
}

extension MemberBlockItemListSyntax.Element {
    var declaration: Declaration {
        guard let decl = self.decl.as(VariableDeclSyntax.self),
              let binding = decl.bindings.compactMap({
                  $0.pattern.as(IdentifierPatternSyntax.self)
              }).first else {
            fatalError()
        }
        let name = binding.identifier
        
        guard let decl = self.decl.as(VariableDeclSyntax.self),
              let type = decl.bindings.compactMap({
                  $0.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name
              }).first ?? decl.bindings.compactMap({
                  $0.typeAnnotation?.type.as(OptionalTypeSyntax.self)?.wrappedType.as(IdentifierTypeSyntax.self)?.name
              }).first else {
                fatalError()
            }
        let declType: String
        let isOptional: Bool
        if decl.bindings.compactMap({
            $0.typeAnnotation?.type.as(OptionalTypeSyntax.self)?.wrappedType.as(IdentifierTypeSyntax.self)?.name
        }).first != nil {
            declType = "\(type)?".trimmingCharacters(in: .whitespaces)
            isOptional = true
        } else {
            declType = "\(type)".trimmingCharacters(in: .whitespaces)
            isOptional = false
        }
        return Declaration(name: name.text, type: declType, isOptional: isOptional)
    }
}

struct PersistedMacro : AccessorMacro {
    static func expansion(of node: SwiftSyntax.AttributeSyntax,
                          providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                          in context: some SwiftSyntaxMacros.MacroExpansionContext)
    throws -> [SwiftSyntax.AccessorDeclSyntax] {
        guard let name = declaration.as(VariableDeclSyntax.self)?.bindings.first?.as(PatternBindingSyntax.self)?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            return []
        }
        return [
            """
            get {
                switch _\(raw: name) {
                    case .unmanaged(let value): return value
                    case .managed(let colKey): return object!.swift_get(colKey)
                }
            }
            set {
                var newValue = newValue
                if var object = self.object, case let .managed(key) = _\(raw: name) {
                    object.swift_set(key, &newValue)
                } else {
                    _\(raw: name) = .unmanaged(newValue)
                }
            }
            """
        ]
    }
}

struct ObjectMacro : MemberMacro, MemberAttributeMacro, ExtensionMacro {
    static func expansion(of node: SwiftSyntax.AttributeSyntax, attachedTo declaration: some SwiftSyntax.DeclGroupSyntax, providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol, conformingTo protocols: [SwiftSyntax.TypeSyntax], in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        [
            .init(extendedType: type,
                  inheritanceClause: .init(inheritedTypes: .init(arrayLiteral: .init(type: TypeSyntax(stringLiteral: "Object")))), memberBlock: "{}")
        ]
    }
    
    static func expansion(of node: SwiftSyntax.AttributeSyntax,
                          attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                          providingAttributesFor member: some SwiftSyntax.DeclSyntaxProtocol,
                          in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.AttributeSyntax] {
        return [
            """
            @Persisted
            """
        ]
    }

    private static func declName(_ member: MemberBlockItemListSyntax.Element) -> String {
        guard let decl = member.decl.as(VariableDeclSyntax.self),
            let binding = decl.bindings.compactMap({
                $0.pattern.as(IdentifierPatternSyntax.self)
            }).first else {
                fatalError()
            }
        return "\(binding.identifier)".trimmingCharacters(in: .whitespaces)
    }
    private static func declType(_ member: MemberBlockItemListSyntax.Element) -> String {
        guard let decl = member.decl.as(VariableDeclSyntax.self),
              let type = decl.bindings.compactMap({
                  $0.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name
              }).first ?? decl.bindings.compactMap({
                  $0.typeAnnotation?.type.as(OptionalTypeSyntax.self)?.wrappedType.as(IdentifierTypeSyntax.self)?.name
              }).first else {
                fatalError()
            }
        if decl.bindings.compactMap({
            $0.typeAnnotation?.type.as(OptionalTypeSyntax.self)?.wrappedType.as(IdentifierTypeSyntax.self)?.name
        }).first != nil {
            return "\(type)?".trimmingCharacters(in: .whitespaces)
        } else {
            return "\(type)".trimmingCharacters(in: .whitespaces)
        }
    }
    
    // MARK: Expansion
    static func expansion(of node: SwiftSyntax.AttributeSyntax,
                          providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
                          in context: some SwiftSyntaxMacros.MacroExpansionContext)
    throws -> [SwiftSyntax.DeclSyntax] {
        let properties = declaration.memberBlock.members.map(\.declaration).map {
            """
            Property(name: "\($0.name)",
                     keyPath: \\Self._\($0.name))
            """
        }.joined(separator: ",")
        return [
            """
            var object: realmCxx.bridge.object? = nil
            """,
            """
            static var objectSchema: ObjectSchema {
                ObjectSchema(name: "\(raw: declaration.as(StructDeclSyntax.self)!.name.trimmed)", properties: [
                    \(raw: properties)
                ])
            }
            """,
            """
            enum Change : ObjectChangeKind {
                \(raw: declaration.memberBlock.members.map(\.declaration).map { decl in
                    """
                    case \(decl.name)(oldValue: \(decl.type)?, newValue: \(decl.type)?)
                    """
                }.joined(separator: "\n"))
            
                init(name: String, oldValue: (any Persistable)?, newValue: (any Persistable)?) {
                    switch name {
                        \(raw: declaration.memberBlock.members.map(\.declaration).map { decl in
                            """
                            case "\(decl.name)": self = .\(decl.name)(oldValue: oldValue as? \(decl.type), newValue: newValue as? \(decl.type))
                            """
                        }.joined(separator: "\n"))
                        default: fatalError("Impossible property key")
                    }
                    
                }
            }
            """,
            """
            init() {
                \(raw: declaration.memberBlock.members.map {
                    "self._\(declName($0)) = .unmanaged(\(declType($0)).init())"
                }.joined(separator: "\n"))
            }
            """,
            """
            init(\(raw: declaration.memberBlock.members.map { "\(declName($0)): \(declType($0))" }.joined(separator: ","))) {
                \(raw: declaration.memberBlock.members.map {
                    "self._\(declName($0)) = .unmanaged(\(declName($0)))"
                }.joined(separator: "\n"))
            }
            """,
            """
            mutating func _manage(_ object: inout bridge.object) {
                let table = object.get_obj().get_table()
                \(raw: declaration.memberBlock.members.map(\.declaration).map {
                    """
                    var \($0.name)Str = "\($0.name)".cxxValue
                    var \($0.name)ColKey = table.get_column_key(std.string_view(&\($0.name)Str))
                    object.swift_set(\($0.name)ColKey, &\($0.name))
                    _\($0.name) = .managed(\($0.name)ColKey)
                    """
                }.joined(separator: "\n"))
                self.object = object
            }
            """,
            """
            public init(_ cxxValue: realmCxx.bridge.object) {
                self.init()
                self.object = cxxValue
                let table = cxxValue.get_obj().get_table()
                \(raw: declaration.memberBlock.members.map(\.declaration).map {
                    """
                    var \($0.name)Str = "\($0.name)".cxxValue
                    var \($0.name)ColKey = table.get_column_key(std.string_view(&\($0.name)Str))
                    _\($0.name) = .managed(\($0.name)ColKey)
                    """
                }.joined(separator: "\n"))
            }
            """
        ] + declaration.memberBlock.members.map {
            "private var _\(raw: declName($0)): PropertyStorage<\(raw: declType($0))>"
        }
    }
}

@main
struct RealmMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ObjectMacro.self, PersistedMacro.self
    ]
}

