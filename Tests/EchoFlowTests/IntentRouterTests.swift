import XCTest
@testable import EchoFlow
@testable import Shared

final class IntentRouterTests: XCTestCase {
    
    var router: IntentRouter!

    override func setUpWithError() throws {
        // Setup router before each test. In a real scenario we would inject a MockGeminiProvider here.
        router = IntentRouter()
    }

    override func tearDownWithError() throws {
        router = nil
    }

    func testDictationRouting() async throws {
        // We simulate a dictation input. Since we don't have a mocked GeminiProvider here yet
        // and we don't want to burn API tokens on unit tests, this is a structure test.
        // In a full enterprise proxy, `textAnalyzer` would be a protocol.
        
        let transcription = "this is a test of the dictation system"
        
        // This will attempt an actual network call if Keys are present, or fallback securely to raw text.
        // The fallback behavior of IntentRouter ensures it never crashes.
        let result = await router.route(transcription: transcription)
        
        switch result {
        case .dictation(let text):
            // Fallback text should equal input if API fails, or Gemini should capitalize it.
            // We just ensure it routes to the correct enum case.
            XCTAssertFalse(text.isEmpty)
        case .command, .unknown:
            XCTFail("Should have been routed as Dictation.")
        }
    }
    
    func testLocalFallbackCommandRouting() async throws {
        // Without an API key, this will immediately fall back to CoreMLLocalInferenceService.
        // We verify that the simulated ML inference correctly identifies the "open" intent.
        let transcription = "open safari please"
        let result = await router.route(transcription: transcription)
        
        switch result {
        case .command(let action, let params):
            XCTAssertEqual(action, "open_app")
            XCTAssertEqual(params["app_name"], "Safari Please") // Because our local heuristic splits
        case .dictation, .unknown:
            XCTFail("Should have been routed as Command 'open_app'.")
        }
    }
    
    func testEmptyStringRouting() async throws {
        // Edge case: ensure it handles empty audio cleanly via fallback
        let transcription = "   "
        let result = await router.route(transcription: transcription)
        
        switch result {
        case .dictation(let text):
            // Fallback should just return the empty string
            XCTAssertEqual(text, "   ")
        case .command, .unknown:
            XCTFail("Empty strings should route to Dictation silently.")
        }
    }
}
