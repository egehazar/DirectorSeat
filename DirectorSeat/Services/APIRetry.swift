import Foundation

enum APIRetry {
    /// Runs `op` up to `maxAttempts` times. Retries only when the thrown error
    /// is APIError.isRetryable. Uses exponential backoff: 1s, 2s, 4s, capped.
    /// Caller can supply a per-attempt callback to surface "still trying..." state.
    static func run<T>(
        maxAttempts: Int = 3,
        onAttempt: ((Int) -> Void)? = nil,
        _ op: () async throws -> T
    ) async throws -> T {
        var attempt = 0
        while true {
            attempt += 1
            onAttempt?(attempt)
            do {
                return try await op()
            } catch let api as APIError where api.isRetryable && attempt < maxAttempts {
                let backoff = api.retryDelay * pow(2.0, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(min(backoff, 10.0) * 1_000_000_000))
                continue
            } catch {
                throw error
            }
        }
    }
}
