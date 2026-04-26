import Foundation

enum PlanGenerationError: Error, LocalizedError {
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
        case .apiKeyNotConfigured:
            return "API key not configured. Please contact support."
        case .networkUnreachable:
            return "No internet connection. Please check your network and try again."
        case .networkFailure:
            return "Could not reach the server. Please try again."
        case .unauthorized:
            return "Invalid API key. Please contact support."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .nonSuccessResponse(let code, _):
            return "Something went wrong (error \(code)). Please try again."
        case .invalidJSON:
            return "We got an unexpected response. Please try again."
        case .decodingFailure:
            return "We couldn't understand the response. Please try again."
        }
    }
}

class PlanGenerationService {
    private static let systemPrompt = """
        You are DirectorSeat, an AI filmmaking planner for beginners. Given a film idea, return a structured JSON filmmaking plan. Respond with ONLY valid JSON, no markdown fences, no commentary.

        ENVIRONMENT PHILOSOPHY:
        Avoid hard environmental dependencies by default. Weather (rain, snow, fog), darkness, crowds, traffic, pets, and unpredictable public spaces are all friction. If the user's idea inherently requires weather or outdoor conditions, propose an indoor or simulated alternative as the primary plan. For example, "rain" can be a running faucet over a window, a spray bottle, or sound effects; "night" can be a dimmed room with curtains drawn.

        The JSON must follow this exact schema:
        {
          "logline": "One-sentence summary of the film",
          "estimated_duration_minutes": <number>,
          "estimated_total_shoot_minutes": <number>,
          "scenes": [
            {
              "scene_number": <number>,
              "description": "What happens in this scene",
              "location_description": "Where this scene takes place",
              "cast_count": <number>,
              "shots": [
                {
                  "shot_number": <number>,
                  "shot_type": "wide | medium | close-up | over-shoulder | pov",
                  "direction_text": "Max 2 sentences describing the shot",
                  "camera_placement": "Physical instruction using household items with OPTIONS, e.g. 'on any surface at face height — stool, stack of books, kitchen counter'",
                  "actor_direction": "What the actor(s) should do",
                  "dialogue": "Line of dialogue or null",
                  "estimated_duration_seconds": <number>,
                  "solo_shootable": <boolean>,
                  "audio_risk": "low | medium | high"
                }
              ]
            }
          ],
          "cast": [
            {
              "role_name": "Character name",
              "description": "Brief character description"
            }
          ],
          "required_story_props": ["max 3 — items essential to the narrative"],
          "optional_setup_helpers": ["max 2 — items that help shoot the film, e.g. surfaces, simulators, spray bottles"],
          "location_requirements": ["list of location requirements"],
          "music_mood": "Suggested mood for the soundtrack"
        }

        BEGINNER CONSTRAINTS — you must follow all of these:
        - Maximum 8 shots total across all scenes.
        - Maximum 3 scenes.
        - Maximum 2 actors unless the user explicitly requests more.
        - All camera positions must be STATIONARY. No handheld tracking, no dollies, no gimbals. The camera (phone) must rest on or lean against a fixed surface.
        - Every shot must be achievable with: a phone, common household supports (books, mugs, shelves, counters, chairs), and 1–2 people. No tripods, no rigs, no special gear.
        - Camera placement language must give OPTIONS, not a single specific item. e.g. "on any surface at face height — stool, stack of books, kitchen counter."
        - required_story_props: maximum 3 items, everyday household items only.
        - optional_setup_helpers: maximum 2 items, things that help with shooting (surfaces, simulators).
        - Locations must be achievable in any home or ordinary indoor space.
        - Total estimated shoot time (estimated_total_shoot_minutes) must be under 45 minutes.
        - estimated_duration_seconds for each shot should be realistic for beginners (include setup time).

        AUDIO-AWARE DIALOGUE RULES:
        - Each shot must include "solo_shootable" (boolean: can one person capture this alone?) and "audio_risk" ("low" | "medium" | "high" — likelihood of phone-mic audio problems).
        - Shots flagged audio_risk "high" must have minimal or NO essential dialogue. Use visual storytelling, gestures, or post-dubbed narration instead.
        - Critical dialogue must be placed in shots flagged audio_risk "low" — quiet indoor settings with the actor close to the camera.
        - Shots flagged audio_risk "medium" should keep dialogue short and simple.
        - audio_risk must reflect real reasoning per shot, not be rubber-stamped. Use these guidelines: close-ups with actors near the phone = low. Medium shots at conversational distance = low-medium depending on environment. Wide shots with actors 6+ feet from the phone = medium. Any shot with significant actor movement or outdoor elements = medium-high. A plan where every shot is "low" is a failure — variation is expected across different framings and distances.

        NARRATIVE CONTINUITY:
        - If a scene is reframed due to environmental friction (e.g. rain moved indoors, outdoor moved inside), you must update the story fiction to match. A character cannot "enter soaked from rain" if the entire scene takes place indoors. Either establish an exterior briefly (phone pointed at a window + door opening) or rewrite the action to fit the actual setting (e.g. both characters were already indoors, waiting out a storm together).

        DIALOGUE REALISM:
        - Write dialogue for amateur performers, not trained actors. Avoid poetic, screenplay-flowery lines. Prefer natural, mundane, slightly awkward exchanges that real people would say. "I was hoping it would rain today" is too literary. "Thanks, that came out of nowhere" is better.

        FRAMING WITHOUT A CAMERA OPERATOR:
        - When a shot does not have a designated camera operator (i.e. solo_shootable is true or no third person is available), bias toward framings that work from a static phone position. Prefer two-shots (both actors in one frame) over over-shoulder reverses. Over-shoulder should only be used when the user has confirmed a camera operator is available.
        """

    private struct APIResponse: Decodable {
        let content: [ContentBlock]
    }

    private struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    func generate(idea: String, cast: CastChoice, context: String) async throws -> FilmmakingPlan {
        let apiKey = Secrets.anthropicAPIKey
        guard !apiKey.isEmpty, apiKey != "REPLACE_ME" else {
            throw PlanGenerationError.apiKeyNotConfigured
        }

        let userMessage = buildUserMessage(idea: idea, cast: cast, context: context)

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-opus-4-6",
            "max_tokens": 4096,
            "system": Self.systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            throw PlanGenerationError.networkUnreachable
        } catch {
            throw PlanGenerationError.networkFailure(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlanGenerationError.invalidJSON
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw PlanGenerationError.unauthorized
        case 429:
            throw PlanGenerationError.rateLimited
        default:
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw PlanGenerationError.nonSuccessResponse(httpResponse.statusCode, responseBody)
        }

        let apiResponse: APIResponse
        do {
            apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            throw PlanGenerationError.invalidJSON
        }

        guard let text = apiResponse.content.first(where: { $0.type == "text" })?.text else {
            throw PlanGenerationError.invalidJSON
        }

        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw PlanGenerationError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(FilmmakingPlan.self, from: jsonData)
        } catch {
            throw PlanGenerationError.decodingFailure(error)
        }
    }

    private func buildUserMessage(idea: String, cast: CastChoice, context: String) -> String {
        let castLabel: String
        switch cast {
        case .solo: castLabel = "Just me (solo filmmaker)"
        case .pair: castLabel = "Me and 1 other person"
        case .group: castLabel = "A group"
        case .decideLater: castLabel = "Decide later"
        }

        var message = "Idea: \(idea)\n\nCast: \(castLabel)"
        if !context.isEmpty {
            message += "\n\nAdditional context: \(context)"
        }
        return message
    }

    // MARK: - Template-Based Generation

    func generateFromTemplate(template: FilmTemplate, customization: String, cast: CastChoice) async throws -> FilmmakingPlan {
        let apiKey = Secrets.anthropicAPIKey
        guard !apiKey.isEmpty, apiKey != "REPLACE_ME" else {
            throw PlanGenerationError.apiKeyNotConfigured
        }

        let templateSystemPrompt = buildTemplateSystemPrompt(template: template)
        let userMessage = buildUserMessage(idea: customization, cast: cast, context: "")

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-opus-4-6",
            "max_tokens": 4096,
            "system": templateSystemPrompt,
            "messages": [
                ["role": "user", "content": userMessage],
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            throw PlanGenerationError.networkUnreachable
        } catch {
            throw PlanGenerationError.networkFailure(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlanGenerationError.invalidJSON
        }

        switch httpResponse.statusCode {
        case 200: break
        case 401: throw PlanGenerationError.unauthorized
        case 429: throw PlanGenerationError.rateLimited
        default:
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw PlanGenerationError.nonSuccessResponse(httpResponse.statusCode, responseBody)
        }

        let apiResponse: APIResponse
        do {
            apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            throw PlanGenerationError.invalidJSON
        }

        guard let text = apiResponse.content.first(where: { $0.type == "text" })?.text else {
            throw PlanGenerationError.invalidJSON
        }

        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw PlanGenerationError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(FilmmakingPlan.self, from: jsonData)
        } catch {
            throw PlanGenerationError.decodingFailure(error)
        }
    }

    private func buildTemplateSystemPrompt(template: FilmTemplate) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let templateJSON = (try? encoder.encode(template)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        return """
        You are DirectorSeat, an AI filmmaking planner for beginners. You are generating a plan from a story template. Respond with ONLY valid JSON, no markdown fences, no commentary.

        TEMPLATE CONSTRAINT — This is critical:
        You MUST preserve the exact story structure of the template provided:
        - Do NOT change the number of scenes (\(template.scenes.count) scenes)
        - Do NOT change the number of shots per scene (keep each scene's shot count identical)
        - Do NOT change the shot types (wide, medium, close-up, etc.) — use exactly what the template specifies
        - Do NOT change the beat structure — each scene and shot serves a specific narrative purpose
        - Do NOT invent new scenes or shots
        - DO fill in all [BRACKETED] placeholders with specific, vivid details from the user's customization
        - DO write natural dialogue where shots call for it
        - DO adapt camera placement and actor direction to the user's specific setting and characters

        TEMPLATE:
        \(templateJSON)

        \(Self.systemPrompt)
        """
    }
}
