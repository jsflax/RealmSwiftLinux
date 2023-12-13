#ifndef realmCxx_h
#define realmCxx_h

#include <memory>
#include <string>
#include <iostream>
#include <optional>
#include <cpprealm/internal/bridge/obj.hpp>
#include <cpprealm/internal/bridge/object_schema.hpp>
#include <cpprealm/internal/bridge/property.hpp>
#include <cpprealm/internal/bridge/results.hpp>
#include <swift/bridging>
#include <realm/object-store/object_schema.hpp>
#include <realm/object-store/property.hpp>
#include <realm/object-store/shared_realm.hpp>
#include <realm/obj.hpp>
#include <cpprealm/app.hpp>

namespace bridge = realm::internal::bridge;

static std::string string_view_to_string(std::string_view sv) {
    return std::string(sv);
}

using fn_0 = void(^)();
template <typename T>
using ret_fn_0 = T(^)();
template <typename T, typename V>
using ret_fn_1 = T(^)(V);

using ret_any_fn_0 = std::any(^)();

static bridge::results results_filter(const bridge::results& results, bool(^fn)(bridge::obj)) {
    return results.filter(fn);
}

static std::variant<bridge::realm, realm::Exception>  get_realm(bridge::realm::config c) {
    try {
        return bridge::realm(c);
    } catch (realm::Exception e) {
        return e;
    }
}
template <typename T>
static bool holds_exception(T v) {
    return std::holds_alternative<realm::Exception>(v);
}

static realm::SharedRealm get_shared_realm(realm::RealmConfig config) {
    return realm::Realm::get_shared_realm(config);
}

//template <typename T>
static std::variant<std::string, int64_t, bool> my_variant { 42 };

template <typename Variant, typename T>
T variant_get(const Variant& v) {
    return std::get<T>(v);
}
static bridge::obj results_get(bridge::results& r, size_t s) {
    return bridge::get<bridge::obj>(r, s);
}

static std::vector<bridge::object_schema> CxxVectorOfObjectSchema() {
    return std::vector<bridge::object_schema>();
}
static std::vector<bridge::property> CxxVectorOfProperty() {
    return std::vector<bridge::property>();
}

using ChangeCallback = std::function<void(const bridge::collection_change_set&)>;

struct PropertyChange {
    /**
     The name of the property which changed.
    */
    std::string name;

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
    std::optional<bridge::mixed> old_value;

    /**
     The value of the property after the change occurred. This is not supplied
     for `List` properties and will always be nil.
    */
    std::optional<bridge::mixed> new_value;
};

struct object_change {
    /// The object being observed.
    const bridge::object object;
    /// The object has been deleted from the Realm.
    bool is_deleted = false;
    /**
     If an error occurs, notification blocks are called one time with an `error`
     result and an `std::exception` containing details about the error. Currently the
     only errors which can occur are when opening the Realm on a background
     worker thread to calculate the change set. The callback will never be
     called again after `error` is delivered.
     */
    std::exception_ptr error;
    /**
     One or more of the properties of the object have been changed.
     */
    std::vector<PropertyChange> property_changes;
};

using ObjectNotificationCallback = std::function<void(const bridge::object*,
                                                      std::vector<std::string> property_names,
                                                      std::vector<bridge::mixed> old_values,
                                                      std::vector<bridge::mixed> new_values,
                                                      const std::exception_ptr error)>;

static realm::internal::bridge::notification_token 
observe(bridge::object m_object, std::function<void(object_change)> block, bool queue = false) {
    struct object_changeCallbackWrapper : realm::internal::bridge::collection_change_callback {
        object_changeCallbackWrapper(ObjectNotificationCallback b,
                                    const realm::internal::bridge::object& internal_object)
                : block(b), m_object(internal_object) {}
        ObjectNotificationCallback block;
//        const T* object;
        const realm::internal::bridge::object m_object;

        std::optional<std::vector<std::string>> property_names = std::nullopt;
        std::optional<std::vector<bridge::mixed>> old_values = std::nullopt;
        bool deleted = false;

        void populateProperties(realm::internal::bridge::collection_change_set const& c)
        {
            if (property_names) {
                return;
            }
            if (!c.deletions().empty()) {
                deleted = true;
                return;
            }
            if (c.columns().empty()) {
                return;
            }

            // FIXME: It's possible for the column key of a persisted property
            // to equal the column key of a computed property.
            auto properties = std::vector<std::string>();
            auto table = m_object.get_obj().get_table();
            auto schema = static_cast<realm::ObjectSchema>(m_object.get_object_schema());
            for (auto i = 0; i < schema.persisted_properties.size(); i++) {
                if (c.columns().count(table.get_column_key(schema.persisted_properties[i].name).value())) {
                    properties.push_back(schema.persisted_properties[i].name);
                }
            }

            if (!properties.empty()) {
                property_names = properties;
            }
        }

        std::optional<std::vector<bridge::mixed>> read_values(realm::internal::bridge::collection_change_set const& c) {
            if (c.empty()) {
                return std::nullopt;
            }
            populateProperties(c);
            if (!property_names) {
                return std::nullopt;
            }

            std::vector<bridge::mixed> values;
            auto table = m_object.get_obj().get_table();
            for (auto& name : *property_names) {
                auto value = static_cast<realm::Obj>(m_object.get_obj()).get_any(table.get_column_key(name));
//                auto value = T::schema.property_value_for_name(name, *object);
                values.push_back(value);
            }
            return values;
        }

        void before(realm::internal::bridge::collection_change_set const& c) override
        {
            old_values = read_values(c);
        }

        void after(realm::internal::bridge::collection_change_set const& c) override
        {
            auto new_values = read_values(c);
            if (deleted) {
                block(nullptr, {}, {}, {}, nullptr);
            } else if (new_values) {
                block(&m_object,
                      *property_names,
                      old_values ? *old_values : std::vector<bridge::mixed>{},
                      *new_values,
                      nullptr);
            }
            property_names = std::nullopt;
            old_values = std::nullopt;
        }

        void error(std::exception_ptr err) {
            block(nullptr, {}, {}, {}, err);
        }
    };
//    if (!is_managed()) {
//        throw std::runtime_error("Only objects which are managed by a Realm support change notifications");
//    }
    auto wrapper = object_changeCallbackWrapper {
            [block](const bridge::object*,
                    std::vector<std::string> property_names,
                    std::vector<bridge::mixed> old_values,
                    std::vector<bridge::mixed> new_values,
                    const std::exception_ptr& error) {
                    std::vector<PropertyChange> property_changes;
                for (size_t i = 0; i < property_names.size(); i++) {
                    PropertyChange property;
                    property.name = property_names[i];
                    if (!old_values.empty()) {
                        property.old_value = old_values[i];
                    }
                    if (!new_values.empty()) {
                        property.new_value = new_values[i];
                    }
                    property_changes.push_back(std::move(property));
                }
                block(object_change { .property_changes = property_changes });
            }, m_object};
    return m_object.add_notification_callback(
            std::make_shared<object_changeCallbackWrapper>(wrapper));
}

using fn = void(^)(const object_change&);

template <typename T>
using typed_fn = void(^)(const T&);
using userFn = void(^)(const realm::user&, const std::optional<realm::app_error>&);

static void login(realm::App app, realm::App::credentials credentials, userFn fn) {
    app.login(credentials, [fn](auto user, auto error) {
        fn(user, error);
    });
}

static std::shared_ptr<bridge::notification_token> observe(const bridge::object& object,
                                                           fn f) {
    return std::make_shared<bridge::notification_token>(observe(object, [f](auto change) {
        f(change);
    }));
}
template <typename T>
static T bridge_cast(const bridge::mixed& mixed) {
    return static_cast<T>(mixed);
}
#endif /* realmCxx_h */
