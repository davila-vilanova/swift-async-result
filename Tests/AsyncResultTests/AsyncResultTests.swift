import Testing

@testable import AsyncResult

struct ErrorType1: Error, Equatable {
    let message: String
}

// `ErrorType1`s are transformed into this, which tries to parse the message as
// an int error code.
struct ErrorType2: Error, Equatable {
    let code: Int?

    static func fromErrorType1(_ errorType1: ErrorType1) -> Self {
        .init(code: Int(errorType1.message))
    }
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
    // Note that it returns a Result, so flatMap can extract its success value
    // or failure error.
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

// MARK: - Test initializers from sync and async throwing expressions

@Sendable func succeedSync() throws -> String {
    "this worked out"
}
@Sendable func succeedAsync() async throws -> String {
    try await Task(operation: succeedSync).value
}
@Sendable func failSync() throws -> String {
    throw ErrorType1(message: "but this didn't")
}
@Sendable func failAsync() async throws -> String {
    try await Task(operation: failSync).value
}

@Test(
    arguments: zip(
        [
            (succeedSync, succeedAsync),
            (failSync, failAsync),
        ],
        [
            Result<String, any Error>.success("this worked out"),
            .failure(ErrorType1(message: "but this didn't")),
        ]
    )
)
func testInitFromThrowingExpression(
    functions: (() throws -> String, @Sendable () async throws -> String),
    expectedOutput: Result<String, any Error>
) async {
    let (syncFunc, asyncFunc) = functions
    let syncInittedResult = Result(catching: syncFunc)
    let asyncInittedResult = await Result(catching: asyncFunc)

    // Ideally this test would rely on typed throw function types to determine
    // error equality, but Swift support for typed errors was introduced only on
    // 6.0. So resort to an inelegant way of determine `Result` equality for two
    // `Results` that fail with `ErrorType1` when the error type is not known by
    // the Swift < 6 compiler:
    func eq<Success: Equatable>(
        _ lhs: Result<Success, any Error>, _ rhs: Result<Success, any Error>
    ) -> Bool {
        switch (lhs, rhs) {
        case let (.success(lhsValue), .success(rhsValue)):
            return lhsValue == rhsValue
        case let (.failure(lhsError), .failure(rhsError)):
            guard let lhsErrorType1 = lhsError as? ErrorType1,
                let rhsErrorType1 = rhsError as? ErrorType1
            else {
                return false
            }
            return lhsErrorType1 == rhsErrorType1
        default:
            return false
        }
    }

    #expect(
        eq(syncInittedResult, asyncInittedResult),
        "Async initialization should produce the same value as sync initialization"
    )
    #expect(
        eq(asyncInittedResult, expectedOutput),
        "Async initialization should produce the expected result"
    )
}
