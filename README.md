# Async Result

AsyncResult is a microlibrary that extends Swift's `Result` type with async transform methods (versions of `map`, `mapError`, `flatMap` and `flatMapError` which accept async transform functions as arguments) and an async error catching initializer, so whoever doesn't want to keep doing it by hand has an alternative in a small dependency that is documented and tested.

## Additions to `Result`

AsyncResult extends `Result`'s four transform operations with async alternatives, and `Result`'s error catching initializer with an async counterpart.

### Async transform operations:

For each of `Result`'s four basic transforms (`map`, `mapError`, `flatMap` and `flatMapError`), this library adds an equivalent method that takes an asynchronous closure or function to perform the transformation, plus two other methods that call either the synchronous or asynchronous version of the operation. For example, for `map`, the included extension on `Result` adds:

    - `asyncMap`: this is the most important addition to the map operation. It provides an alternative to the original `map` to work with async transform closures.
    - `map`: this is an overload of the original `map` method which matches the signature of `asyncMap`, and in fact just redirects to it. Often, Swift's compiler will be able to infer which flavor of `map` (original sync or this extension's async) you want to use.
    - `syncMap`: if the compiler does not select the right overload, you can call explicitly the desired flavor of the transform method, such as the above `asyncMap` or the added `syncMap`, which just redirects the call to the original `Result.map`.

In my tests, from async contexts, the compiler selects the right overloads for `map` and `flatMap` depending on whether the transform closure argument is sync or async, but it wrongly selects the async overloads for `mapError` and `flatMapError`, even when passed an async function. This results in an error. It's in those cases that the `sync[Flat]Map[Error]` methods may come handy. I haven't found a case yet where the explicitly `async` named counterparts are useful, but they're provided for symmetry and to cover any potential blind spots I may have missed.

### Async error catching initializer

`Result` provides an initializer that creates a new result by evaluating a throwing closure, producing a `failure` case if the closure throws an error when evaluated, or a `success` case if the closure doesn't throw and returns a value. This library adds a similar initializer to `Result` which will evaluate an asynchrous throwing closure or function, and otherwise behaves exactly like its sync counterpart.

## Installation / depending on this library

AsyncResult can be added as a dependency using the Swift [Package Manager](https://www.swift.org/documentation/package-manager/).

To depend on it from another Swift package, add this dependendy to your package manifest (`Package.swift`):

```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/davila-vilanova/swift-async-result.git", "1.0.0"..<"2.0.0")
    ],
    ...
)
```

Alternatively, if adding the dependency directly to an Xcode project, select `File > Add package dependencies...`, then enter the package URL shown above in the search bar, and finally enter the desired dependency rule -- for example, "Up to Next Major Version" with a value of 1.0.0.

Regardless of the method used above, import the library into any source files you may want to use it from like this:

```swift
import AsyncResult
```

## See also

See https://github.com/JohnSundell/CollectionConcurrencyKit for a library that adds async and concurrent versions of `map`, `flatMap`, `compactMap`, and `forEach` APIs to all Swift collections that conform to the `Sequence` protocol.
