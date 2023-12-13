import Foundation
import realmCxx

extension realm.app_error : Error, CustomStringConvertible {
    public var description: String {
        String(string_view_to_string(self.message()))
    }
}

public typealias App = realmCxx.realm.App
public extension App {
    init(appId: String) {
        var config = realm.App.configuration()
        config.app_id = std.string(appId)
        self = realm.App(config)
    }
    
    func login() async throws -> realmCxx.realm.user {
        try await withCheckedThrowingContinuation { continuation in
            realmCxx.login(self, realm.App.credentials.anonymous()) { user, error in
                if error.__convertToBool() {
                    continuation.resume(throwing: error.pointee)
                } else {
                    continuation.resume(returning: user)
                }
            }
        }
    }
}

public typealias User = realmCxx.realm.user
public extension User {
    var flexibleSyncConfiguration: Config {
        self.flexible_sync_configuration()
    }
}
