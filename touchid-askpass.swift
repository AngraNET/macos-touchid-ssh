import Foundation
import LocalAuthentication

let context = LAContext()
var error: NSError?

guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
    fputs("Touch ID not available: \(error?.localizedDescription ?? "unknown error")\n", stderr)
    exit(1)
}

let semaphore = DispatchSemaphore(value: 0)
var authenticated = false

context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "SSH key access") { success, _ in
    authenticated = success
    semaphore.signal()
}

semaphore.wait()

if authenticated {
    // For "confirm" mode, just need to exit 0
    print("yes")
    exit(0)
} else {
    exit(1)
}
