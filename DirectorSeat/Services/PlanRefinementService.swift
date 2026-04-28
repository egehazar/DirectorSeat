import Foundation

enum RefinementError: Error, LocalizedError {
    case apiKeyNotConfigured
    case networkUnreachable
    case networkFailure(Error)
    case unauthorized
    case rateLimited
    case nonSuccessResponse(Int, String)
    case invalidJSON
    case decodingFailure(Error)

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured: "API key not configured."
        case .networkUnreachable: "No internet connection. Check your network and try again."
        case .networkFailure: "Could not reach the server. Try again."
        case .unauthorized: "Invalid API key."
        case .rateLimited: "Too many requests. Wait a moment and try again."
        case .nonSuccessResponse(let code, _): "Something went wrong (error \(code)). Try again."
        case .invalidJSON: "Got an unexpected response. Try again."
        case .decodingFailure: "Couldn't understand the response. Try again."
        }
    }
}

class PlanRefinementService {

    private struct APIResponse: Decodable {
        let content: [ContentBlock]
    }

    private struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    private struct RefinementResponse: Decodable {
        let message: String
        let revision: ShotRevision?
    }

    // MARK: - Public

    func refineShot(
        plan: FilmmakingPlan,
        targetShotNumber: Int,
        conversationHistory: [ConversationMessage],
        userMessage: String
    ) async throws -> ConversationMessage {
        let apiKey = Secrets.anthropicAPIKey
        guard !apiKey.isEmpty, apiKey != "REPLACE_ME" else {
            throw RefinementError.apiKeyNotConfigured
        }

        let systemPrompt = buildSystemPrompt(plan: plan, targetShotNumber: targetShotNumber)
        let apiMessages = buildAPIMessages(from: conversationHistory)

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 1500,
            "temperature": 0.7,
            "system": systemPrompt,
            "messages": apiMessages,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            throw RefinementError.networkUnreachable
        } catch {
            throw RefinementError.networkFailure(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RefinementError.invalidJSON
        }

        switch httpResponse.statusCode {
        case 200: break
        case 401: throw RefinementError.unauthorized
        case 429: throw RefinementError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RefinementError.nonSuccessResponse(httpResponse.statusCode, body)
        }

        let apiResponse: APIResponse
        do {
            apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            throw RefinementError.invalidJSON
        }

        guard let text = apiResponse.content.first(where: { $0.type == "text" })?.text else {
            throw RefinementError.invalidJSON
        }

        // Strip markdown fences if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw RefinementError.invalidJSON
        }

        let refinement: RefinementResponse
        do {
            refinement = try JSONDecoder().decode(RefinementResponse.self, from: jsonData)
        } catch {
            throw RefinementError.decodingFailure(error)
        }

        return ConversationMessage(
            id: UUID(),
            role: .assistant,
            content: refinement.message,
            timestamp: Date(),
            proposedRevision: refinement.revision
        )
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(plan: FilmmakingPlan, targetShotNumber: Int) -> String {
        // Build human-readable shot map with global numbering
        var shotMap = ""
        var globalNum = 0
        for scene in plan.scenes {
            for shot in scene.shots {
                globalNum += 1
                let marker = globalNum == targetShotNumber ? "  <-- DISCUSSING THIS SHOT" : ""
                shotMap += "  Global Shot \(globalNum) (Scene \(scene.sceneNumber), Shot \(shot.shotNumber))"
                shotMap += " — \(shot.shotType): \(shot.directionText)\(marker)\n"
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let planJSON = (try? encoder.encode(plan)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        return """
        You are a filmmaking assistant helping a beginner refine a specific shot in their plan.

        The user is discussing Global Shot \(targetShotNumber).

        SHOT MAP (globally numbered):
        \(shotMap)
        FULL PLAN JSON:
        \(planJSON)

        YOUR JOB:
        1. If the user is asking a question, exploring ideas, or thinking out loud, respond conversationally and helpfully WITHOUT proposing a revision. Not every message needs a change.
        2. If they request a concrete change, propose a structured revision.

        CRITICAL — DEPENDENCY CHECKING (this is non-negotiable):
        Before proposing ANY revision, you MUST mentally walk through every other shot and check:
        - PROPS: Does any other shot reference a prop this change adds, removes, or alters? If Shot 2 uses "the note" and you remove it from Shot 1, Shot 2 is broken.
        - LOCATIONS: If the location changes, do adjacent shots assume the same room/setup? Changing Shot 3's location from "kitchen" to "hallway" may break Shot 4 if it assumes kitchen continuity.
        - CHARACTER STATE: If a character's position or action changes, do later shots depend on the prior state? If Shot 2 has the character sitting, and Shot 3 says "stands up," removing the sitting from Shot 2 breaks the transition.
        - DIALOGUE DEPENDENCIES: If a shot's dialogue changes, do downstream shots reference what was said? Example: "Did you eat already?" in shot 4 sets up "Yeah, I had something at home" in shot 6. If the user changes shot 4's line, shot 6's response may need updating. Walk the full dialogue chain.
        - CAMERA SETUP: If camera placement changes, does the next shot assume the same setup position?

        If dependent changes are needed, you MUST include ALL affected shots in dependent_shot_changes with their complete updated content. If only the target shot changes, dependent_shot_changes MUST be an empty array [].

        EDITORIAL METADATA IN REVISIONS:
        When proposing revisions, you must include all editorial metadata fields (recommended_hold_seconds, transition_in_type, transition_out_type, pacing_role, audio_treatment, editing_note). If the user's change affects pacing — e.g., they want a shot to feel more tense — adjust these fields accordingly. If the original shot has editorial metadata, preserve it unless the change warrants an update. Every revised shot must have complete editorial metadata.

        OUTPUT FORMAT — respond with ONLY valid JSON, no markdown fences, no text outside the JSON:
        {
          "message": "your conversational response, max 80 words, warm and direct like a friendly director",
          "revision": null OR {
            "target_shot_number": <global shot number, 1-indexed>,
            "updated_shot": {
              "shot_number": <same global shot number>,
              "shot_type": "wide | medium | close-up | over-shoulder | pov",
              "direction_text": "max 2 sentences describing the shot",
              "camera_placement": "physical instruction using household items with OPTIONS",
              "actor_direction": "what the actor(s) should do",
              "dialogue_direction": {
                "has_spoken_line": true,
                "speaker": "CHARACTER A or role name",
                "beat_purpose": "what this line does narratively",
                "voice_cue": "how it should sound when delivered",
                "draft_line": "the actual line of dialogue",
                "user_written_line": null
              } OR null,
              "estimated_duration_seconds": <int>,
              "solo_shootable": <bool>,
              "audio_risk": "low | medium | high",
              "recommended_hold_seconds": <number>,
              "transition_in_type": "cut | dissolve | fade_to_black | fade_from_black | match_cut",
              "transition_out_type": "cut | dissolve | fade_to_black | fade_from_black | match_cut",
              "pacing_role": "establishing | building | beat | payoff | transition | closure",
              "audio_treatment": "dialogue_priority | music_priority | ambient_only | silent | crescendo",
              "editing_note": "One sentence explaining the editing intent for this shot"
            },
            "dependent_shot_changes": [
              {
                "shot_number": <global shot number of the dependent shot>,
                "shot_type": "...",
                "direction_text": "...",
                "camera_placement": "...",
                "actor_direction": "...",
                "dialogue_direction": { ... same shape as above ... } OR null,
                "estimated_duration_seconds": <int>,
                "solo_shootable": <bool>,
                "audio_risk": "low | medium | high",
                "recommended_hold_seconds": <number>,
                "transition_in_type": "...",
                "transition_out_type": "...",
                "pacing_role": "...",
                "audio_treatment": "...",
                "editing_note": "..."
              }
            ],
            "summary": "1-sentence human-readable description of the change, shown to user"
          }
        }

        DIALOGUE CRAFT HELP:
        When the user is asking for dialogue-specific help ("make this funnier", "this is too on-the-nose", "give me three alternatives", "how should I say this"), respond conversationally with options or guidance — do NOT necessarily propose a structured revision. Offer alternatives, explain the craft reasoning, and let the user decide. They can request a formal revision afterward if they like one of your suggestions. This conversational mode is for exploration; revisions are for commitment.

        Remember: speak like a friendly director helping a first-timer, not a chatbot. Be warm and direct.
        """
    }

    // MARK: - Message Building

    private func buildAPIMessages(from history: [ConversationMessage]) -> [[String: String]] {
        // Skip leading assistant messages (auto-greeting, etc.)
        // Merge consecutive same-role messages (Claude API requires alternating roles)
        var messages: [[String: String]] = []
        var foundFirstUser = false

        for msg in history {
            if !foundFirstUser {
                if msg.role == .assistant { continue }
                foundFirstUser = true
            }

            if let last = messages.last, last["role"] == msg.role.rawValue {
                messages[messages.count - 1]["content"] = last["content"]! + "\n" + msg.content
            } else {
                messages.append(["role": msg.role.rawValue, "content": msg.content])
            }
        }

        return messages
    }
}
