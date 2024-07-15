import Foundation

/// Provides each request with optional URLCredentials.
public final class CredentialsPlugin: PluginType {

    public typealias CredentialClosure = (any TargetType) -> URLCredential?
    let credentialsClosure: CredentialClosure

    /// Initializes a CredentialsPlugin.
    public init(credentialsClosure: @escaping CredentialClosure) {
        self.credentialsClosure = credentialsClosure
    }

    // MARK: Plugin

    public func willSend(_ request: any RequestType, target: any TargetType) {
        if let credentials = credentialsClosure(target) {
            _ = request.authenticate(with: credentials)
        }
    }
}
