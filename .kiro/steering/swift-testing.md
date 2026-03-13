---
inclusion: fileMatch
fileMatchPattern: "Tests/**/*.swift"
---

# Swift Testing Rules for BrightPassKit

## CRITICAL: No MainActor Deadlocks in Tests

This project uses `@Observable @MainActor` view models. When writing tests — especially property tests with SwiftCheck — you MUST avoid the following deadlock pattern:

```swift
// ❌ DEADLOCK — NEVER DO THIS
let semaphore = DispatchSemaphore(value: 0)
Task.detached { @MainActor in
    // This needs the main thread, but semaphore.wait() below blocks it
    let vm = SomeViewModel(...)
    await vm.someMethod()
    semaphore.signal()
}
semaphore.wait() // Blocks main thread → Task can never execute → HANG
```

### Safe Patterns

**For synchronous @MainActor logic (property setting, lockVault, returnToVaultList, etc.):**
Mark the test method `@MainActor` and call directly — no Task, no semaphore:

```swift
@MainActor
func testSomething() {
    let vm = SomeViewModel(...)
    vm.someProperty = value
    vm.lockVault()
    XCTAssertNil(vm.vault)
}
```

**For async methods in unit tests:**
Use `async` test methods with `@MainActor`:

```swift
@MainActor
func testAsyncMethod() async {
    let vm = SomeViewModel(apiClient: mock)
    await vm.generate()
    XCTAssertNotNil(vm.result)
}
```

**For property tests (SwiftCheck) that need async calls:**
Call the mock API directly on a background thread, bypassing the @MainActor view model:

```swift
func generateSync(options: PasswordOptions) -> String {
    let mock = MockAPIClient()
    nonisolated(unsafe) var result: String?
    let semaphore = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        Task {
            // Call mock directly — NOT through @MainActor view model
            let r = try await mock.generatePassword(options: options)
            result = r.password
            semaphore.signal()
        }
    }
    semaphore.wait()
    return result!
}
```

**For property tests with synchronous @MainActor logic:**
Use manual iteration with `@MainActor` on the test method instead of SwiftCheck's `forAll`:

```swift
@MainActor
func testProperty() {
    for _ in 0..<200 {
        let value = someGenerator.generate
        let vm = SomeViewModel(...)
        vm.doSomething(value)
        XCTAssert(vm.result == expected)
    }
}
```

## Also: @Observable + didSet Infinite Recursion

Never use unconditional self-assignment in `didSet` on `@Observable` properties:

```swift
// ❌ INFINITE LOOP with @Observable
public var length: Int = 20 {
    didSet { length = min(128, max(8, length)) }
}

// ✅ Guard against no-op reassignment
public var length: Int = 20 {
    didSet {
        let clamped = min(128, max(8, length))
        if length != clamped { length = clamped }
    }
}
```
