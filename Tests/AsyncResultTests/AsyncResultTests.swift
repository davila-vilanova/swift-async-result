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
            .failure(.init(message: "error should be left unchanged")),
        ],
        [
            Result<Int?, ErrorType1>.success(12),
            .success(nil),
            .failure(.init(message: "error should be left unchanged")),
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

@Test(
    arguments: zip(
        [
            Result<String, ErrorType1>.failure(.init(message: "24")),
            .failure(.init(message: "not a number")),
            .success("success should be left unchanged"),
        ],
        [
            Result<String, ErrorType2>.failure(.init(code: 24)),
            .failure(.init(code: nil)),
            .success("success should be left unchanged"),
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

@Test(
    arguments: zip(
        [
            Result<String, ErrorType1>.success("12"),
            .success("not a number"),
            .failure(.init(message: "error should be left unchanged")),
        ],
        [
            Result<Int, ErrorType1>.success(12),
            .failure(.init(message: "could not convert to int")),
            .failure(.init(message: "error should be left unchanged")),

        ]
    )
)
func testFlatMap(
    input: Result<String, ErrorType1>, expectedOutput: Result<Int, ErrorType1>
) async throws {
    // Tries to parse a string into an integer.
    // Note that it returns a Result, so flatMap can extract its success value or failure error.
    @Sendable func attemptTransform(input: String) -> Result<Int, ErrorType1> {
        guard let parsed = Int(input) else {
            return .failure(ErrorType1(message: "could not convert to int"))
        }
        return .success(parsed)
    }

    let syncMapped = input.flatMap(attemptTransform)
    let asyncMapped = await input.flatMap(makeAsync(attemptTransform))

    #expect(
        asyncMapped == syncMapped,
        "Async flatMap should produce result values identical to sync flatMap")
    #expect(
        asyncMapped == expectedOutput,
        "Async flatMap should produce the expected output value")
}

@Test(
    arguments: zip(
        [
            Result<String, ErrorType1>.success("success should be left unchanged"),
            .failure(.init(message: "12")),
            .failure(.init(message: "save me!")),
        ],
        [
            Result<String, ErrorType2>.success("success should be left unchanged"),
            .failure(.init(code: 12)),
            .success("you were saved!"),
        ]
    )
)
func testFlatMapError(
    input: Result<String, ErrorType1>, expectedOutput: Result<String, ErrorType2>
) async throws {
    // It's complicated.
    @Sendable func transform(input: ErrorType1) -> Result<String, ErrorType2> {
        if input.message == "save me!" {
            return .success("you were saved!")
        }
        return .failure(ErrorType2.fromErrorType1(input))
    }

    let syncMapped = input.syncFlatMapError(transform)
    let asyncMapped = await input.flatMapError(makeAsync(transform))

    #expect(
        asyncMapped == syncMapped,
        "Async flatMapError should produce result values identical to sync flatMapError")
    #expect(
        asyncMapped == expectedOutput,
        "Async flatMapError should produce the expected output value")
}

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
