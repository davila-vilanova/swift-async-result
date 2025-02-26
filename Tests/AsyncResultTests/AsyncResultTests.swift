import Testing

@testable import AsyncResult

struct ErrorType1: Error, Equatable {
    let message: String
}

// ErrorType1s are transformed into this, which tries to parse the message as an int error code.
struct ErrorType2: Error, Equatable {
    let code: Int?

    static func fromErrorType1(_ errorType1: ErrorType1) -> Self {
        .init(code: Int(errorType1.message))
    }
}

struct ErrorType3: Error, Equatable {  // To be removed
    let message: String
}

// MARK: map

/// "Craftily converts" a regular, synchronous function with one argument
/// into an analogous, async counterpart.
private func makeAsync<I: Sendable, O: Sendable>(
    _ syncFunc: @escaping @Sendable (I) -> O
) -> @Sendable (I) async -> O {
    return { input in
        await Task.detached { syncFunc(input) }.value
    }
}

@Test(
    arguments: zip(
        [
            Result<String, ErrorType1>.success("12"),
            .success("not a number"),
            .failure(.init(message: "error should be left unchanged ")),
        ],
        [
            Result<Int?, ErrorType1>.success(12),
            .success(nil),
            .failure(.init(message: "error should be left unchanged ")),
        ]
    )
)
func testMap(input: Result<String, ErrorType1>, expectedOutput: Result<Int?, ErrorType1>) async {
    let transform: @Sendable (String) -> Int? = Int.init

    let syncMapped: Result<Int?, ErrorType1> = input.map(transform)
    let asyncMapped = await input.map(makeAsync(transform))

    #expect(
        asyncMapped == syncMapped, "Async map should produce result values identical to sync map")
    #expect(
        asyncMapped == expectedOutput,
        "Async map should produce the expected output value")
}

// MARK: - mapError

@Test(
    arguments: zip(
        [
            Result<String, ErrorType1>.failure(.init(message: "24")),
            .failure(.init(message: "not a number")),
            .success("Success case to be left unchanged"),
        ],
        [
            Result<String, ErrorType2>.failure(.init(code: 24)),
            .failure(.init(code: nil)),
            .success("Success case to be left unchanged"),
        ]
    )
)
func testMapError(
    input: Result<String, ErrorType1>,
    expectedOutput: Result<String, ErrorType2>
) async {
    let transform: @Sendable (ErrorType1) -> (ErrorType2) = ErrorType2.fromErrorType1
    let syncMapped = input.syncMapError { (errortype1: ErrorType1) -> ErrorType2 in
        ErrorType2.fromErrorType1(errortype1)
    }
    let asyncMapped = await input.mapError(makeAsync(transform))
    #expect(
        asyncMapped == syncMapped,
        "Async mapError should produce result values identical to sync mapError")
    #expect(
        asyncMapped == expectedOutput,
        "Async mapError should produce the expected output value")

}

// MARK: - flatMap

@Test func testAsyncFlatMapTransformsSuccess() async throws {
    // Asynchronously tries to parse a string into an integer.
    // Note that it returns a Result, so flatMap can extract its success value or failure error.
    @Sendable func asyncTransform(input: String) async -> Result<Int, ErrorType1> {
        await Task {
            guard let parsed = Int(input) else {
                return .failure(ErrorType1(message: "Could not convert to int"))
            }
            return .success(parsed)
        }.value
    }

    let parseableSuccess = Result<String, ErrorType1>.success("12")
    #expect(try await parseableSuccess.flatMap(asyncTransform).get() == 12)

    let unparseableSuccess = Result<String, ErrorType1>.success("not a number")
    #expect(
        await unparseableSuccess.flatMap(asyncTransform)
            == Result<Int, ErrorType1>.failure(ErrorType1(message: "Could not convert to int"))
    )
}

@Test func testAsyncFlatMapLeavesFailureUnchanged() async throws {
    let original = Result<String, ErrorType1>.failure(ErrorType1(message: "error"))
    let mapped = await original.flatMap { _ in
        await Task { .success("this should never run") }.value
    }
    #expect(original == mapped, "Expected failure to be unchanged")
}

@Test func testSyncFlatMapStillAvailable() throws {
    let original = Result<String, ErrorType1>.success("12")
    let mapped = original.flatMap { input -> Result<Int, ErrorType1> in
        guard let parsed = Int(input) else {
            return .failure(ErrorType1(message: "Could not convert to int"))
        }
        return .success(parsed)
    }
    #expect(try mapped.get() == 12)
}

// MARK: - flatMapError

@Test func testAsyncFlatMapErrorTransformsFailure() async throws {
    let original = Result<String, ErrorType1>.failure(.init(message: "error"))
    let mapped = await original.flatMapError { error in
        await Task { .failure(ErrorType3(message: "transformed \(error.message)")) }.value
    }
    guard case let .failure(error) = mapped else {
        Issue.record("Expected a transformed failure")
        return
    }
    #expect(error.message == "transformed error", "Expected failure to be transformed")
}

@Test func testAsyncFlatMapErrorTransformsFailureToSuccess() async throws {
    let original = Result<String, ErrorType1>.failure(.init(message: "error"))
    let mapped: Result<String, ErrorType3> = await original.flatMapError { error in
        await Task { .success("turn an \(error.message) into a success!") }.value
    }
    #expect(
        try mapped.get() == "turn an error into a success!",
        "Expected failure to be transformed into a success")
}

@Test func testAsyncFlatMapErrorLeavesSuccessUnchanged() async throws {
    let original = Result<String, ErrorType1>.success("a success value")
    let mapped: Result<String, ErrorType3> = await original.flatMapError { error in
        await Task { .failure(ErrorType3(message: "this should never run")) }.value
    }
    #expect(try mapped.get() == "a success value", "Expected failure to be unchanged")
}

@Test func testSyncFlatMapErrorStillAvailable() throws {
    let original = Result<String, ErrorType1>.failure(ErrorType1(message: "error"))
    let mapped: Result<String, ErrorType3> = original.flatMapError { error in
        .failure(ErrorType3(message: "transformed \(error.message)"))
    }
    guard case let .failure(error) = mapped else {
        Issue.record("Expected a transformed failure")
        return
    }
    #expect(error.message == "transformed error", "Expected failure to be transformed")
}

// MARK: - Catching initializer

@Test func testConvertAsyncThrowingExpression() async throws {
    let success = await Result {
        await Task { "this worked out" }.value
    }
    #expect(
        try success.get() == "this worked out",
        "Expected success value for successfully async initialized result"
    )

    let failure = await Result<String, any Error> {
        return try await Task {
            throw ErrorType1(message: "but this didn't")
        }.value
    }
    guard case let .failure(error) = failure else {
        Issue.record("Expected a failure from initializer")
        return
    }
    let errorType1 = try #require(
        error as? ErrorType1, "Expected the same kind of error that was thrown in the initializer"
    )
    #expect(errorType1.message == "but this didn't")
}

@Test func testConvertSyncThrowingExpressionStillAvailable() throws {
    let success = Result { "this worked out" }
    #expect(
        try success.get() == "this worked out",
        "Expected success value for successfully initialized result"
    )
}
