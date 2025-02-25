/// Extensions for `Swift.Result` to support mapping and initialization
/// with async functions.

extension Result {
    /// Like the regular `map`, but for async transform functions.
    @inlinable
    @_disfavoredOverload
    public func map<NewSuccess: ~Copyable>(
        _ transform: @Sendable (Success) async -> NewSuccess
    ) async -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return .success(await transform(success))
        case let .failure(failure):
            return .failure(failure)
        }
    }

    /// Like the regular `mapError`, but for async transform functions
    @_disfavoredOverload
    public func mapError<NewFailure>(
        _ transform: (Failure) async -> NewFailure
    ) async -> Result<Success, NewFailure> {
        switch self {
        case let .success(success):
            return .success(success)
        case let .failure(failure):
            return .failure(await transform(failure))
        }
    }

    /// Like the regular `flatMap`, but for async transform functions.
    @inlinable
    public func flatMap<NewSuccess>(
        _ transform: @Sendable (Success) async -> Result<NewSuccess, Failure>
    ) async -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return await transform(success)
        case let .failure(failure):
            return .failure(failure)
        }
    }

    /// Like the regular `flatMapError`, but for async transform functions.
    @inlinable
    public func flatMapError<NewFailure>(
        _ transform: (Failure) async -> Result<Success, NewFailure>
    ) async -> Result<Success, NewFailure> {
        switch self {
        case let .success(success):
            return .success(success)
        case let .failure(failure):
            return await transform(failure)
        }
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
