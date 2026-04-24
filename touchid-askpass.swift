import Foundation
import LocalAuthentication
import Security

// Prompt Touch ID first
let context = LAContext()
var error: NSError?

guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
    fputs("Touch ID not available: \(error?.localizedDescription ?? "unknown error")\n", stderr)
    exit(1)
}

let semaphore = DispatchSemaphore(value: 0)
var authenticated = false

context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "SSH key access") { success, authError in
    authenticated = success
    if !success {
        fputs("Touch ID failed: \(authError?.localizedDescription ?? "cancelled")\n", stderr)
    }
    semaphore.signal()
}

semaphore.wait()

guard authenticated else {
    exit(1)
}

// Retrieve the SSH key passphrase from Keychain
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "ssh-passphrase",
    kSecAttrAccount as String: "id_ed25519",
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne
]

var result: AnyObject?
let status = SecItemCopyMatching(query as CFDictionary, &result)

if status == errSecSuccess, let data = result as? Data, let passphrase = String(data: data, encoding: .utf8) {
    print(passphrase)
    exit(0)
} else {
    fputs("Could not retrieve passphrase from Keychain (status: \(status))\n", stderr)
    exit(1)
}
