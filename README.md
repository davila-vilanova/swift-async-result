# Async Result

AsyncResult is a microlibrary that extends Swift's `Result` type with async transform methods (versions of `map`, `mapError`, `flatMap` and `flatMapError` that accept async transform functions as arguments) and an async error catching initializer, so whoever doesn't want to keep doing it by hand has an alternative in a small dependency that is documented and tested.

This is a work in progress as of February 2025.

The async `map` function shipped by this library is marked as `@_disfavoredOverload` because the original `map` is too, see
https://github.com/swiftlang/swift/blob/ac698a14ec3745235786fbcc99a749d699fa702a/stdlib/public/core/Result.swift#L55, copied below. This would make it impossible to use the original `map` in an async context unless their relative priorities were equalized by lowering the async map overload priority.


```swift
  @_disfavoredOverload // FIXME: Workaround for source compat issue with
                       // functions that used to shadow the original map
                       // (rdar://125016028)
  public func map<NewSuccess: ~Copyable>(
    _ transform: (Success) -> NewSuccess
  ) -> Result<NewSuccess, Failure>
```

Async `mapError` is marked as `@_disfavoredOverload` to avoid ambiguous use errors when attempting to perform synchronous error mappings from asynchronous contexts.
