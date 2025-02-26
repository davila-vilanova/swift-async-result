/// Extensions for `Swift.Result` to support mapping and initialization
/// with async functions.

extension Result {

    // MARK: - map

    /// Like the regular `map`, but for async transform functions.
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

    @inlinable
    public func syncMap<NewSuccess: ~Copyable>(
        _ transform: (Success) -> NewSuccess
    ) -> Result<NewSuccess, Failure> {
        map(transform)
    }

    @inlinable
    @_disfavoredOverload
    public func map<NewSuccess: ~Copyable>(
        _ transform: @Sendable (Success) async -> NewSuccess
    ) async -> Result<NewSuccess, Failure> {
        await asyncMap(transform)
    }

    // MARK: - mapError

    /// Like the regular `mapError`, but for async transform functions
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

    @inlinable
    public consuming func syncMapError<NewFailure>(
        _ transform: (Failure) -> NewFailure
    ) -> Result<Success, NewFailure> {
        mapError(transform)
    }

    @inlinable
    public consuming func mapError<NewFailure>(
        _ transform: (Failure) async -> NewFailure
    ) async -> Result<Success, NewFailure> {
        await asyncMapError(transform)
    }

    // MARK: - flatMap

    /// Like the regular `flatMap`, but for async transform functions.
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

    @inlinable
    public func syncFlatMap<NewSuccess: ~Copyable>(
        _ transform: (Success) -> Result<NewSuccess, Failure>
    ) -> Result<NewSuccess, Failure> {
        flatMap(transform)
    }

    @inlinable
    @_disfavoredOverload
    public func flatMap<NewSuccess: ~Copyable>(
        _ transform: @Sendable (Success) async -> Result<NewSuccess, Failure>
    ) async -> Result<NewSuccess, Failure> {
        await asyncFlatMap(transform)
    }

    // MARK: - flatMapError

    /// Like the regular `flatMapError`, but for async transform functions.
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

    public consuming func syncFlatMapError<NewFailure>(
        _ transform: (Failure) -> Result<Success, NewFailure>
    ) -> Result<Success, NewFailure> {
        flatMapError(transform)
    }

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
