/// Extensions for `Swift.Result` to support mapping and initialization
/// with async functions.

extension Result {

    // MARK: - map

    /// Returns a new result, mapping any success value using the given
    /// asynchronous transformation.
    ///
    /// Use this method when you need to transform the value of a `Result`
    /// instance when it represents a success, and the transform function is
    /// async. The following example transforms the integer success value of a
    /// result into a string, making a call to an asynchronous function:
    ///
    ///     func getNextInteger() -> Result<Int, Error> { /* ... */ }
    ///     func getNumberFact(for number: Int) async -> String { /* ... */ }
    ///
    ///     let integerResult = getNextInteger()
    ///     // integerResult == .success(5)
    ///     let factResult = integerResult.asyncMap { await getNumberFact(for: $0) }
    ///     // factResult == .success("5 is the number of platonic solids.")
    ///
    /// - Parameter transform: An async closure that takes the success value of
    ///   this instance.
    /// - Returns: A `Result` instance with the result of evaluating `transform`
    ///   as the new success value if this instance represents a success.
    @inlinable
    public func asyncMap<NewSuccess: ~Copyable>(
        _ transform: @Sendable (Success) async -> NewSuccess
    ) async -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return .success(await transform(success))
        case let .failure(failure):
            return .failure(failure)
        }
    }

    /// Forwards the call to the built-in, synchronous version of `Result.map`,
    /// which returns a new result, mapping any success value using the given
    /// transformation.
    ///
    /// Use this method when you need to transform the value of a `Result`
    /// instance when it represents a success. The following example transforms
    /// the integer success value of a result into a string:
    ///
    ///     func getNextInteger() -> Result<Int, Error> { /* ... */ }
    ///
    ///     let integerResult = getNextInteger()
    ///     // integerResult == .success(5)
    ///     let stringResult = integerResult.syncMap { String($0) }
    ///     // stringResult == .success("5")
    ///
    /// - Parameter transform: A closure that takes the success value of this
    ///   instance.
    /// - Returns: A `Result` instance with the result of evaluating `transform`
    ///   as the new success value if this instance represents a success.
    @inlinable
    public func syncMap<NewSuccess: ~Copyable>(
        _ transform: (Success) -> NewSuccess
    ) -> Result<NewSuccess, Failure> {
        map(transform)
    }

    /// Returns a new result, mapping any success value using the given
    /// asynchronous transformation.
    ///
    /// Use this method when you need to transform the value of a `Result`
    /// instance when it represents a success, and the transform function is
    /// async. The following example transforms the integer success value of a
    /// result into a string, making a call to an asynchronous function:
    ///
    ///     func getNextInteger() -> Result<Int, Error> { /* ... */ }
    ///     func getNumberFact(for number: Int) async -> String { /* ... */ }
    ///
    ///     let integerResult = getNextInteger()
    ///     // integerResult == .success(5)
    ///     let factResult = integerResult.map { await getNumberFact(for: $0) }
    ///     // factResult == .success("5 is the number of platonic solids.")
    ///
    /// - Parameter transform: An async closure that takes the success value of
    ///   this instance.
    /// - Returns: A `Result` instance with the result of evaluating `transform`
    ///   as the new success value if this instance represents a success.
    @inlinable
    @_disfavoredOverload  // Match the disfavored status of the original, sync method
    public func map<NewSuccess: ~Copyable>(
        _ transform: @Sendable (Success) async -> NewSuccess
    ) async -> Result<NewSuccess, Failure> {
        await asyncMap(transform)
    }

    // MARK: - mapError

    /// Returns a new result, mapping any failure value using the given
    /// asynchronous transformation.
    ///
    /// Use this method when you need to transform the value of a `Result`
    /// instance when it represents a failure, and the transform function is
    /// async. The following example transforms the error value of a result by
    /// wrapping it in a custom `Error` type:
    ///
    ///     struct SequencedError: Error {
    ///         let error: Error
    ///         let sequenceNumber: Int
    ///     }
    ///
    ///     actor ErrorSequencer {
    ///         private var nextSequenceNumber = 0
    ///
    ///         func sequenceError(_ error: Error) -> Error {
    ///             defer { sequence += 1 }
    ///             return SequencedError(error: error, sequenceNumber: nextSequenceNumber)
    ///         }
    ///     }
    ///
    ///     let sequencer = ErrorSequencer()
    ///     let result: Result<Int, Error> = // ...
    ///     // result == .failure(<error value>)
    ///     let resultWithSequencedError = await result.asyncMapError {
    ///         await sequencer.sequenceError($0)
    ///     }
    ///     // result == .failure(DatedError(error: <error value>, sequenceNumber: 0))
    ///
    /// - Parameter transform: An async closure that takes the failure value of
    ///   the instance.
    /// - Returns: A `Result` instance with the result of evaluating `transform`
    ///   as the new failure value if this instance represents a failure.
    @inlinable
    public consuming func asyncMapError<NewFailure>(
        _ transform: (Failure) async -> NewFailure
    ) async -> Result<Success, NewFailure> {
        switch consume self {
        case let .success(success):
            return .success(consume success)
        case let .failure(failure):
            return .failure(await transform(failure))
        }
    }

    /// Forwards the call to the built-in, synchronous version of `Result.mapError`,
    /// which returns a new result, mapping any failure value using the given
    /// transformation.
    ///
    /// Use this method when you need to transform the value of a `Result`
    /// instance when it represents a failure. The following example transforms
    /// the error value of a result by wrapping it in a custom `Error` type:
    ///
    ///     struct DatedError: Error {
    ///         var error: Error
    ///         var date: Date
    ///
    ///         init(_ error: Error) {
    ///             self.error = error
    ///             self.date = Date()
    ///         }
    ///     }
    ///
    ///     let result: Result<Int, Error> = // ...
    ///     // result == .failure(<error value>)
    ///     let resultWithDatedError = result.syncMapError { DatedError($0) }
    ///     // result == .failure(DatedError(error: <error value>, date: <date>))
    ///
    /// - Parameter transform: A closure that takes the failure value of the
    ///   instance.
    /// - Returns: A `Result` instance with the result of evaluating `transform`
    ///   as the new failure value if this instance represents a failure.
    @inlinable
    public consuming func syncMapError<NewFailure>(
        _ transform: (Failure) -> NewFailure
    ) -> Result<Success, NewFailure> {
        mapError(transform)
    }

    /// Returns a new result, mapping any failure value using the given
    /// asynchronous transformation.
    ///
    /// Use this method when you need to transform the value of a `Result`
    /// instance when it represents a failure, and the transform function is
    /// async. The following example transforms the error value of a result by
    /// wrapping it in a custom `Error` type:
    ///
    ///     struct SequencedError: Error {
    ///         let error: Error
    ///         let sequenceNumber: Int
    ///     }
    ///
    ///     actor ErrorSequencer {
    ///         private var nextSequenceNumber = 0
    ///
    ///         func sequenceError(_ error: Error) -> Error {
    ///             defer { sequence += 1 }
    ///             return SequencedError(error: error, sequenceNumber: nextSequenceNumber)
    ///         }
    ///     }
    ///
    ///     let sequencer = ErrorSequencer()
    ///     let result: Result<Int, Error> = // ...
    ///     // result == .failure(<error value>)
    ///     let resultWithSequencedError = await result.mapError {
    ///         await sequencer.sequenceError($0)
    ///     }
    ///     // result == .failure(DatedError(error: <error value>, sequenceNumber: 0))
    ///
    /// - Parameter transform: An async closure that takes the failure value of
    ///   the instance.
    /// - Returns: A `Result` instance with the result of evaluating `transform`
    ///   as the new failure value if this instance represents a failure.
    @inlinable
    public consuming func mapError<NewFailure>(
        _ transform: (Failure) async -> NewFailure
    ) async -> Result<Success, NewFailure> {
        await asyncMapError(transform)
    }

    // MARK: - flatMap

    /// Returns a new result, mapping any success value using the given
    /// asynchronous transformation and unwrapping the produced result.
    ///
    /// Use this method to avoid a nested result when your transformation
    /// produces another `Result` type.
    ///
    /// In this example, note the difference in the result of using `asyncMap` and
    /// `ayncFlatMap` with a transformation that returns a result type.
    ///
    ///    func getNextInteger() async -> Result<Int, Error> {
    ///        await Task { .success(4) }.value
    ///    }
    ///
    ///    @Sendable
    ///    func getNextAfterInteger(_ n: Int) async -> Result<Int, Error> {
    ///        await Task { .success(n + 1) }.value
    ///    }
    ///
    ///    let result = await getNextInteger().asyncMap {
    ///        await getNextAfterInteger($0)
    ///    }
    ///    // result == .success(.success(5))
    ///
    ///    let result = await getNextInteger().asyncFlatMap {
    ///        await getNextAfterInteger($0)
    ///    }
    ///    // result == .success(5)
    ///
    /// - Parameter transform: An async closure that takes the success value of
    ///   the instance.
    /// - Returns: A `Result` instance, either from the closure or the previous
    ///   `.failure`.
    @inlinable
    public func asyncFlatMap<NewSuccess: ~Copyable>(
        _ transform: @Sendable (Success) async -> Result<NewSuccess, Failure>
    ) async -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return await transform(success)
        case let .failure(failure):
            return .failure(failure)
        }
    }

    /// Forwards the call to the built-in, synchronous version of `Result.flatMap`,
    /// which returns a new result, mapping any success value using the given
    /// transformation and unwrapping the produced result.
    ///
    /// Use this method to avoid a nested result when your transformation
    /// produces another `Result` type.
    ///
    /// In this example, note the difference in the result of using `syncMap` and
    /// `syncFlatMap` with a transformation that returns a result type.
    ///
    ///     func getNextInteger() -> Result<Int, Error> {
    ///         .success(4)
    ///     }
    ///     func getNextAfterInteger(_ n: Int) -> Result<Int, Error> {
    ///         .success(n + 1)
    ///     }
    ///
    ///     let result = getNextInteger().syncMap { getNextAfterInteger($0) }
    ///     // result == .success(.success(5))
    ///
    ///     let result = getNextInteger().syncFlatMap { getNextAfterInteger($0) }
    ///     // result == .success(5)
    ///
    /// - Parameter transform: A closure that takes the success value of the
    ///   instance.
    /// - Returns: A `Result` instance, either from the closure or the previous
    ///   `.failure`.
    @inlinable
    public func syncFlatMap<NewSuccess: ~Copyable>(
        _ transform: (Success) -> Result<NewSuccess, Failure>
    ) -> Result<NewSuccess, Failure> {
        flatMap(transform)
    }

    /// Returns a new result, mapping any success value using the given
    /// asynchronous transformation and unwrapping the produced result.
    ///
    /// Use this method to avoid a nested result when your transformation
    /// produces another `Result` type.
    ///
    /// In this example, note the difference in the result of using `map` and
    /// `flatMap` with a transformation that returns a result type.
    ///
    ///    func getNextInteger() async -> Result<Int, Error> {
    ///        await Task { .success(4) }.value
    ///    }
    ///
    ///    @Sendable
    ///    func getNextAfterInteger(_ n: Int) async -> Result<Int, Error> {
    ///        await Task { .success(n + 1) }.value
    ///    }
    ///
    ///    let result = await getNextInteger().map {
    ///        await getNextAfterInteger($0)
    ///    }
    ///    // result == .success(.success(5))
    ///
    ///    let result = await getNextInteger().flatMap {
    ///        await getNextAfterInteger($0)
    ///    }
    ///    // result == .success(5)
    ///
    /// - Parameter transform: An async closure that takes the success value of
    ///   the instance.
    /// - Returns: A `Result` instance, either from the closure or the previous
    ///   `.failure`.
    @inlinable
    @_disfavoredOverload  // Match the disfavored status of the original, sync method
    public func flatMap<NewSuccess: ~Copyable>(
        _ transform: @Sendable (Success) async -> Result<NewSuccess, Failure>
    ) async -> Result<NewSuccess, Failure> {
        await asyncFlatMap(transform)
    }

    // MARK: - flatMapError

    /// Returns a new result, mapping any failure value using the given
    /// asynchronous transformation and unwrapping the produced result.
    ///
    /// - Parameter transform: An async closure that takes the failure value of
    ///   the instance.
    /// - Returns: A `Result` instance, either from the closure or the previous
    ///   `.success`.
    @inlinable
    public consuming func asyncFlatMapError<NewFailure>(
        _ transform: (Failure) async -> Result<Success, NewFailure>
    ) async -> Result<Success, NewFailure> {
        switch consume self {
        case let .success(success):
            return .success(success)
        case let .failure(failure):
            return await transform(failure)
        }
    }

    /// Forwards the call to the built-in, synchronous version of `Result.flatMapError`,
    /// which returns a new result, mapping any failure value using the given
    /// transformation and unwrapping the produced result.
    ///
    /// - Parameter transform: A closure that takes the failure value of the
    ///   instance.
    /// - Returns: A `Result` instance, either from the closure or the previous
    ///   `.success`.
    @inlinable
    public consuming func syncFlatMapError<NewFailure>(
        _ transform: (Failure) -> Result<Success, NewFailure>
    ) -> Result<Success, NewFailure> {
        flatMapError(transform)
    }

    /// Returns a new result, mapping any failure value using the given
    /// asynchronous transformation and unwrapping the produced result.
    ///
    /// - Parameter transform: An async closure that takes the failure value of
    ///   the instance.
    /// - Returns: A `Result` instance, either from the closure or the previous
    ///   `.success`.
    @inlinable
    public consuming func flatMapError<NewFailure>(
        _ transform: (Failure) async -> Result<Success, NewFailure>
    ) async -> Result<Success, NewFailure> {
        await asyncFlatMapError(transform)
    }
}

/// Like the regular `Result.init(catching:)`, but for async functions.
extension Result where Failure == Swift.Error {
    @_transparent
    init(catching body: @Sendable () async throws -> Success) async {
        do {
            self = .success(try await body())
        } catch {
            self = .failure(error)
        }
    }
}
