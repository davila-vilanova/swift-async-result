# Async Result

AsyncResult is a microlibrary that extends Swift's `Result` type with async transform methods (versions of `map`, `mapError`, `flatMap` and `flatMapError` that accept async transform functions as arguments) and an async error catching initializer, so whoever doesn't want to keep doing it by hand has an alternative in a small dependency that is documented and tested.
