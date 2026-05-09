import Foundation

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
        userMessage: String,
        onRetryAttempt: ((Int) -> Void)? = nil
    ) async throws -> ConversationMessage {
        let apiKey = Secrets.anthropicAPIKey
        guard !apiKey.isEmpty, apiKey != "REPLACE_ME" else {
            throw APIError.invalidAuth
        }

        let systemPrompt = buildSystemPrompt(plan: plan, targetShotNumber: targetShotNumber)
        let apiMessages = buildAPIMessages(from: conversationHistory)

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
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

        return try await APIRetry.run(maxAttempts: 3, onAttempt: onRetryAttempt) {
            try await self.executeRefinementRequest(request)
        }
    }

    /// One attempt of the refinement network call + JSON parse. Throws APIError
    /// on failure. Wrapped by APIRetry so retryable errors trigger a backoff.
    private func executeRefinementRequest(_ request: URLRequest) async throws -> ConversationMessage {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let api as APIError {
            throw api
        } catch {
            throw APIErrorMapper.from(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.malformedResponse("Not an HTTP response")
        }
        if let apiError = APIErrorMapper.fromResponse(httpResponse, data: data) {
            throw apiError
        }

        let apiResponse: APIResponse
        do {
            apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            throw APIError.malformedResponse("Could not decode envelope: \(error.localizedDescription)")
        }

        guard let text = apiResponse.content.first(where: { $0.type == "text" })?.text else {
            throw APIError.malformedResponse("Response had no text block")
        }

        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw APIError.malformedResponse("Refinement text was not valid UTF-8")
        }

        let refinement: RefinementResponse
        do {
            refinement = try JSONDecoder().decode(RefinementResponse.self, from: jsonData)
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
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
        When the user asks for dialogue alternatives, craft help, or tone changes ("make this funnier", "this is too on-the-nose", "three alternatives", "different tone", "how should I say this"):

        1. Respond conversationally with 2-4 alternative versions of the line, each with a brief note on why it lands differently.
        2. Do NOT propose a structured revision automatically — let the user pick their favorite from your alternatives.
        3. After the user expresses preference for one alternative, THEN propose a structured revision with that line as the new draft_line (and user_written_line: null so they can still edit it).
        4. Each alternative should respect the original beat_purpose and voice_cue unless the user explicitly wants to change those too.

        Format alternatives like this in your message field:

        Here are three options:

        1. "Did you eat already?" — Plays the indirect angle, lets the audience read between the lines.
        2. "You hungry or...?" — More casual, slightly more playful, gives the actor more rhythm to work with.
        3. "Have you eaten?" — Blunter, more direct, lands harder if the moment needs weight.

        Which feels closest to what you want?

        This is the dialogue-craft tutoring loop: alternatives first, structured revision only when the user expresses preference.

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
