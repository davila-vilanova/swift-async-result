import Testing

@testable import AsyncResult

private struct ErrorType1: Error, Equatable {
    let message: String
}

private struct ErrorType2: Error, Equatable {
    let message: String
}

// MARK: map

@Test func testAsyncMapTransformsSuccess() async throws {
    let original = Result<String, ErrorType1>.success("12")
    let mapped = await original.map { input in
        await Task { Int(input) }.value
    }
    #expect(try mapped.get() == 12, "Expected success to be transformed")
}

@Test func testAsyncMapLeavesFailureUnchanged() async throws {
    let original = Result<String, ErrorType1>.failure(ErrorType1(message: "error"))
    let mapped = await original.map { _ in
        await Task { "this should never run" }.value
    }
    #expect(original == mapped, "Expected failure to be unchanged")
}

@Test func testSyncMapStillAvailable() throws {
    let original = Result<String, ErrorType1>.success("12")
    let mapped = original.map { Int($0) }
    #expect(try mapped.get() == 12)
}

// MARK: - mapError

@Test func testAsyncMapErrorTransformsFailure() async throws {
    let original = Result<String, ErrorType1>.failure(ErrorType1(message: "error"))
    let mapped = await original.mapError { error in
        await Task { ErrorType2(message: "transformed \(error.message)") }.value
    }
    guard case let .failure(error) = mapped else {
        Issue.record("Expected a transformed failure")
        return
    }
    #expect(error.message == "transformed error", "Expected failure to be transformed")
}

@Test func testAsyncMapErrorLeavesSuccessUnchanged() async throws {
    let original = Result<String, ErrorType1>.success("a success value")
    let mapped = await original.mapError { error in
        await Task { ErrorType2(message: "this should never run") }.value
    }
    #expect(try mapped.get() == "a success value", "Expected success to be unchanged")
}

@Test func testSyncMapErrorStillAvailable() throws {
    let original = Result<String, ErrorType1>.failure(ErrorType1(message: "error"))
    let mapped = original.mapError { ErrorType2(message: "transformed \($0.message)") }
    guard case let .failure(error) = mapped else {
        Issue.record("Expected a transformed failure")
        return
    }
    #expect(error.message == "transformed error", "Expected failure to be transformed")
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
        await Task { .failure(ErrorType2(message: "transformed \(error.message)")) }.value
    }
    guard case let .failure(error) = mapped else {
        Issue.record("Expected a transformed failure")
        return
    }
    #expect(error.message == "transformed error", "Expected failure to be transformed")
}

@Test func testAsyncFlatMapErrorTransformsFailureToSuccess() async throws {
    let original = Result<String, ErrorType1>.failure(.init(message: "error"))
    let mapped: Result<String, ErrorType2> = await original.flatMapError { error in
        await Task { .success("turn an \(error.message) into a success!") }.value
    }
    #expect(
        try mapped.get() == "turn an error into a success!",
        "Expected failure to be transformed into a success")
}

@Test func testAsyncFlatMapErrorLeavesSuccessUnchanged() async throws {
    let original = Result<String, ErrorType1>.success("a success value")
    let mapped: Result<String, ErrorType2> = await original.flatMapError { error in
        await Task { .failure(ErrorType2(message: "this should never run")) }.value
    }
    #expect(try mapped.get() == "a success value", "Expected failure to be unchanged")
}

@Test func testSyncFlatMapErrorStillAvailable() throws {
    let original = Result<String, ErrorType1>.failure(ErrorType1(message: "error"))
    let mapped: Result<String, ErrorType2> = original.flatMapError { error in
        .failure(ErrorType2(message: "transformed \(error.message)"))
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
