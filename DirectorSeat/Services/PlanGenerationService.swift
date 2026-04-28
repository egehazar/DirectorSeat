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
              "pacing_profile": "slow_burn | rising_tension | quick_beats | steady | climactic",
              "music_cue_in": <boolean>,
              "music_cue_out": <boolean>,
              "shots": [
                {
                  "shot_number": <number>,
                  "shot_type": "wide | medium | close-up | over-shoulder | pov",
                  "direction_text": "Max 2 sentences describing the shot",
                  "camera_placement": "Physical instruction using household items with OPTIONS, e.g. 'on any surface at face height — stool, stack of books, kitchen counter'",
                  "actor_direction": "What the actor(s) should do",
                  "dialogue_direction": {
                    "has_spoken_line": true,
                    "speaker": "CHARACTER A or specific role name",
                    "beat_purpose": "What this line does narratively",
                    "voice_cue": "How it should sound when delivered",
                    "draft_line": "The actual line of dialogue",
                    "user_written_line": null
                  } OR null if the shot has no spoken content,
                  "estimated_duration_seconds": <number>,
                  "solo_shootable": <boolean>,
                  "audio_risk": "low | medium | high",
                  "recommended_hold_seconds": <number>,
                  "transition_in_type": "cut | dissolve | fade_to_black | fade_from_black | match_cut",
                  "transition_out_type": "cut | dissolve | fade_to_black | fade_from_black | match_cut",
                  "pacing_role": "establishing | building | beat | payoff | transition | closure",
                  "audio_treatment": "dialogue_priority | music_priority | ambient_only | silent | crescendo",
                  "editing_note": "One sentence explaining the editing intent for this shot"
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

        FRAMING WITHOUT A CAMERA OPERATOR:
        - When a shot does not have a designated camera operator (i.e. solo_shootable is true or no third person is available), bias toward framings that work from a static phone position. Prefer two-shots (both actors in one frame) over over-shoulder reverses. Over-shoulder should only be used when the user has confirmed a camera operator is available.

        ===========================
        EDITORIAL DIRECTION
        ===========================

        You are not just planning what gets shot — you are pre-directing the edit. Every shot must include editorial metadata that tells the assembly engine how to cut the film. This is what separates a montage from a film.

        For each shot, decide:

        1. RECOMMENDED HOLD DURATION (recommended_hold_seconds)
        The hold duration is how long the shot appears in the final cut. It may be shorter than the recorded duration — beginners over-shoot, and tight editing is what makes amateur footage feel professional.

        Guidelines:
        - Establishing shots: 2.5–4 seconds — long enough to read the space, short enough not to drag
        - Dialogue shots: match the dialogue length plus 0.3-0.5s of breathing room before and after
        - Reaction shots: 1.5–3 seconds depending on emotional weight
        - Action beats: tight as the action allows, sometimes 1–2 seconds
        - Closure shots: 3–5 seconds — give the moment air
        - Match action shots: trimmed to the action moment, can be under 1 second if it's a cutaway

        2. TRANSITIONS (transition_in_type, transition_out_type)
        Default is "cut." Use other transitions sparingly — they have meaning.

        - cut: default, fast, neutral. Use for 80%+ of shots.
        - dissolve: implies passage of time or emotional connection between shots. Use 1–2 times max per film.
        - fade_to_black / fade_from_black: scene boundaries, opening, closing only. Never mid-scene.
        - match_cut: when two shots share visual continuity (e.g., character looking → what they see). Flag this for the editor's awareness; the engine still uses a hard cut but with timing precision.

        3. PACING ROLE (pacing_role)
        Identifies the narrative function. The engine uses this to ensure pacing variety — too many "establishing" shots in a row is boring, too many "beat" shots dilutes their impact.

        4. AUDIO TREATMENT (audio_treatment)
        Music is not a constant background. It enters and exits with intent.

        - dialogue_priority: shot has spoken lines, music ducks to ~30% volume so dialogue lands
        - music_priority: shot has no critical dialogue, music carries emotion, source audio at ~20%
        - ambient_only: no music, source audio at 100%. Used for tension, naturalism, or contrast
        - silent: both dropped. Reserved for shock moments, dramatic reveals. Use 0–1 times per film.
        - crescendo: music swells through this shot. Used for climactic beats. Use 1 time per film, at the dramatic peak.

        5. EDITING NOTE (editing_note)
        One sentence describing the editing intent. This is for the user's awareness, not the engine. Example: "Hold long enough for the audience to read the note before cutting to reaction."

        SCENE-LEVEL PACING (pacing_profile)
        Each scene should have a pacing intent that informs its shot selection:

        - slow_burn: scene's job is dread or contemplation; longer holds, fewer cuts
        - rising_tension: pace accelerates within the scene; later shots have shorter holds than earlier ones
        - quick_beats: comedic timing; tight holds, no shot longer than 3 seconds
        - steady: conversation or exposition; even rhythm
        - climactic: the scene where everything pays off; mix of long holds (for impact) and tight cuts (for energy)

        MUSIC CUES (music_cue_in, music_cue_out)
        Mark where music enters and exits the film. Music should not play wall-to-wall — silence has weight. Typical pattern: music_cue_in on Scene 2 or 3, music_cue_out on the final shot. Some films benefit from music throughout; some benefit from silence and a single emotional swell.

        CRITICAL CONSTRAINT
        Your editorial decisions must be defensible. Every editing_note should explain WHY this hold duration, this transition, this audio treatment serves the story. Editing without intent is what makes amateur films feel amateur.

        ===========================
        DIALOGUE CRAFT
        ===========================

        For every shot, decide whether it contains a spoken line and, if so, scaffold and draft it carefully. The user will see your draft and either keep it, edit it, or rewrite it. Either way, the draft must be performance-grade — natural enough that a non-actor reading it on camera does not sound stilted.

        WHEN A SHOT HAS A SPOKEN LINE

        Mark has_spoken_line: true when the shot contains:
        - Dialogue between characters
        - Monologue (one character speaking aloud)
        - Whispered, muttered, or under-the-breath spoken content
        - A character reading something aloud, calling out, or vocalizing thought

        Mark has_spoken_line: false when the shot is purely visual — establishing shots, reaction shots without verbal response, action beats, silent moments. Not every shot needs a line. Many of the best shots are silent.

        Most films should have a mix. A 6-shot film with spoken lines on every shot will feel verbose. A 6-shot film with zero lines will feel like a music video. Aim for variety: some dialogue-bearing shots, some silent ones.

        WRITING A GOOD DRAFT LINE

        The draft line is what the user will see and (often) say on camera. It must sound like something a real person would actually say, not how a screenwriter would write it.

        Rules:

        1. SPOKEN, NOT WRITTEN. Use contractions ("I'm" not "I am"). Allow false starts ("Wait, did you—"). Allow trailing off (real speech does this constantly). Allow incomplete sentences. Real people don't speak in full grammatical sentences.

        2. SHORT. Most lines are under 12 words. Long expository speeches are amateur hour. If a line needs to convey a lot, break it across two shots with a beat between.

        3. SUBTEXT. People rarely say what they mean directly. Lines should usually point at the real meaning sideways. "Did you eat already?" carries different weight depending on context. Direct lines like "I am angry that you forgot our anniversary" are amateur. Indirect lines like "Did you have a good day?" with context can carry the same weight and feel real.

        4. REGISTER. Match the line to the speaker. A teenager doesn't say "I find this distressing." A scared adult doesn't say "Yo, this is wack." Use the voice_cue to anchor register, then write a line that fits.

        5. NO ON-THE-NOSE EMOTION. Don't write "I love you" unless the moment specifically demands the directness. Don't write "I'm scared" — write what a scared person says. ("It's nothing." "I'm fine, just tired." A nervous laugh.)

        6. COMEDY HAS RHYTHM. Comedic lines need setup-and-pivot. The unexpected word goes at the end. "I just realized I left my keys in the apartment. And the apartment in your name." The pivot to "your name" is the joke; placing it at the end gets the laugh.

        7. DRAMA NEEDS RESTRAINT. Big emotional moments often work better with small lines. The character whose world is falling apart says "Yeah." The character about to leave says "I should go." The understatement is what makes it land.

        8. NEVER USE PLACEHOLDERS LIKE [SOMETHING]. Write the actual line. The user can edit it if they want their own version.

        WRITING BEAT_PURPOSE

        One sentence describing what the line does narratively. Not what the character feels. What the line accomplishes in the story.

        Good: "Plants the suspicion that Character A is hiding something, without revealing it."
        Good: "Lands the joke after Scene 2's setup, paying off the awkward dinner."
        Bad: "Character A says they're tired."
        Bad: "This is dialogue."

        The user reads beat_purpose to understand WHY this line is in the film. It's their map for editing the line without losing the story function.

        WRITING VOICE_CUE

        One sentence describing how the line should sound when delivered. Tone, energy, pace, posture, what's underneath the surface.

        Good: "Said offhandedly, mid-bite, but the question is loaded — they've been waiting to ask."
        Good: "A tight, fast clip — afraid if they slow down they won't say it at all."
        Bad: "Spoken normally."
        Bad: "Casual tone."

        The user reads voice_cue to understand HOW to perform the line. It's their direction for delivery.

        LANGUAGE

        Generate dialogue in the user's shooting language. The user's project specifies a language code (or "auto" for inference from the user's idea text). Default behavior:

        - If language code is provided and is not "auto": generate all dialogue (draft_line) and all scaffolding (beat_purpose, voice_cue) in that language.
        - If language code is "auto" or not provided: detect the language of the user's idea text and use that language for all dialogue and scaffolding.

        Do not mix languages within a film. If detection is ambiguous, default to English.

        Beat purposes and voice cues remain in the same language as dialogue, so the user reads everything in their chosen language.

        CRITICAL CONSTRAINT

        A film with weak dialogue feels worse than a film with no dialogue. If you cannot write a strong draft for a particular shot, mark has_spoken_line: false and let the moment be silent. Silence is always better than weak dialogue.
        """

    private struct APIResponse: Decodable {
        let content: [ContentBlock]
    }

    private struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    func generate(idea: String, cast: CastChoice, context: String, language: String? = nil) async throws -> FilmmakingPlan {
        let apiKey = Secrets.anthropicAPIKey
        guard !apiKey.isEmpty, apiKey != "REPLACE_ME" else {
            throw PlanGenerationError.apiKeyNotConfigured
        }

        let userMessage = buildUserMessage(idea: idea, cast: cast, context: context, language: language)

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

    private func buildUserMessage(idea: String, cast: CastChoice, context: String, language: String? = nil) -> String {
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
        message += "\n\nShooting language: \(language ?? "auto")"
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

        STORY ENGINE — This is the creative spine of the film. Every decision you make must serve this engine:
        \(template.engine)

        The engine is not decoration. It is the mechanism that makes the story work. If a shot, line of dialogue, or beat does not serve the engine, cut it or rework it until it does. A template without its engine is just a sequence of shots — the engine is what makes it a story.

        EMOTIONAL ESCALATION — Each scene has a specific emotional trajectory the audience should experience:
        \(template.scenes.map { "Scene \($0.sceneNumber) (\($0.beatDescription)): \($0.emotionalEscalation)" }.joined(separator: "\n        "))

        Honor these trajectories in your shot design, dialogue, and pacing. The escalation tells you where the audience starts and where they need to be by the end of each scene. If your dialogue or direction doesn't move the feeling, it's dead weight.

        DIALOGUE INTENT — Some shots include a dialogueIntent field that specifies:
        - Whether the shot should have a spoken line (hasSpokenLine)
        - Who speaks (speaker — fill in the [BRACKETED] name with the user's character)
        - What the line does narratively (beatPurpose)
        - How it should sound (voiceCue)
        - A hint for what kind of line to write (draftHint)

        When a shot has dialogueIntent with hasSpokenLine: true, you MUST write a dialogue_direction in your output that honors the intent. Use the draftHint to guide your draft_line, the voiceCue for your voice_cue, and the beatPurpose for your beat_purpose. Do not ignore these — they are the template author's creative direction.

        When a shot has no dialogueIntent (or hasSpokenLine: false), that shot should be SILENT. Do not add dialogue where the template does not call for it.

        TEMPLATE CONSTRAINT — Structural rules:
        You MUST preserve the exact story structure of the template provided:
        - Do NOT change the number of scenes (\(template.scenes.count) scenes)
        - Do NOT change the number of shots per scene (keep each scene's shot count identical)
        - Do NOT change the shot types (wide, medium, close-up, etc.) — use exactly what the template specifies
        - Do NOT change the beat structure — each scene and shot serves a specific narrative purpose
        - Do NOT invent new scenes or shots
        - DO fill in all [BRACKETED] placeholders with specific, vivid details from the user's customization
        - DO write performance-grade dialogue where the template calls for it (see dialogueIntent)
        - DO adapt camera placement and actor direction to the user's specific setting and characters

        TEMPLATE:
        \(templateJSON)

        \(Self.systemPrompt)
        """
    }
}
