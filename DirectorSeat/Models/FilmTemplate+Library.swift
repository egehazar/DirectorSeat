import Foundation

extension FilmTemplate {
    static let library: [FilmTemplate] = [

        // MARK: - 1. The Bad First Date

        FilmTemplate(
            id: "bad_first_date",
            title: "The Bad First Date",
            description: "A first date between two people who want completely different things from the evening. The mismatches start small and accumulate into one glorious bail-out.",
            mood: "comedy",
            engine: "Two people want incompatible things from this date and only realize it gradually as small mismatches accumulate into one spectacular bail-out.",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 25,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "ARRIVAL & FIRST MISMATCH",
                    emotionalEscalation: "Audience starts at hopeful curiosity and shifts to amused suspicion as the first incompatibility surfaces beneath polite smiles.",
                    placeholderDescription: "[CHARACTER A] arrives for a first date with [CHARACTER B]. Both have dressed for completely different evenings — one thought casual, the other thought formal — and the mismatch sets the tone before a word is spoken.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "wide",
                            beatPurpose: "Establish the date setting and the visual mismatch between both characters",
                            placeholderDirection: "[CHARACTER A] walks into [LOCATION] looking like they're heading to a job interview. [CHARACTER B] is already seated in a hoodie, scrolling their phone with the posture of someone who was promised tacos.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "The overeager greeting that already feels wrong",
                                voiceCue: "Bright, rehearsed, trying too hard",
                                draftHint: "A greeting that overshoots — too formal, too enthusiastic, or weirdly specific for a first meeting"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "medium",
                            beatPurpose: "Show the first concrete incompatibility through a specific detail",
                            placeholderDirection: "[CHARACTER B] slides a menu across the table with the confidence of a regular. [CHARACTER A] opens it and their face does something involuntary — this is not the kind of place they expected."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "AWKWARD ESCALATION",
                    emotionalEscalation: "Audience starts at gentle cringe and shifts to delighted secondhand embarrassment as each attempt at connection reveals a deeper incompatibility.",
                    placeholderDescription: "The conversation lurches from topic to topic. Every time one person finds something they think is common ground, the other's response makes it clear they live on different planets.",
                    shots: [
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "medium",
                            beatPurpose: "The conversation that reveals they have nothing in common",
                            placeholderDirection: "[CHARACTER A] leans in to share something they clearly think is fascinating. [CHARACTER B]'s smile is the kind you give a coworker who won't stop talking about their cat's diet.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "Reveal what Character A thinks makes them interesting — and watch it land nowhere",
                                voiceCue: "Earnest, slightly too passionate about something niche",
                                draftHint: "A deeply specific hobby or opinion that the other person clearly does not share — the more specific, the funnier"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "close-up",
                            beatPurpose: "The internal realization that this is not recoverable",
                            placeholderDirection: "Close-up of [CHARACTER B]'s face doing the math. Their eyes drift to the exit, then back. They take a very long sip of their drink — the kind of sip that buys time to plan an escape."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "THE BAIL-OUT",
                    emotionalEscalation: "Audience starts at peak cringe and shifts to cathartic laughter as the worst excuse in dating history gets delivered with full commitment.",
                    placeholderDescription: "One of them breaks. The excuse they give is so transparently fake that it circles back around to almost dignified. The other sits alone with the check.",
                    shots: [
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "medium",
                            beatPurpose: "The excuse — delivered with the conviction of someone who knows they're caught",
                            placeholderDirection: "[CHARACTER B] suddenly stands, knocking the table slightly, and delivers the most obvious fake emergency of all time. [CHARACTER A]'s face is a masterclass in pretending to believe something.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER B]",
                                beatPurpose: "The bail-out line that's so bad it becomes the punchline",
                                voiceCue: "Urgent, performative, not even slightly convincing",
                                draftHint: "An excuse so specific and implausible that it's clearly invented on the spot — the more elaborate, the funnier"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 6,
                            shotType: "wide",
                            beatPurpose: "The visual punchline — one person gone, one person stuck",
                            placeholderDirection: "Wide shot of the table. [CHARACTER B]'s chair is still rocking from how fast they left. [CHARACTER A] sits alone, the two untouched drinks in front of them telling the whole story."
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 2. The Wrong Text

        FilmTemplate(
            id: "the_wrong_text",
            title: "The Wrong Text",
            description: "One regrettable text to the wrong person triggers a chain of small wrong decisions, each made to fix the last one, each making it spectacularly worse.",
            mood: "comedy",
            engine: "A regrettable text triggers a chain of small wrong decisions, each made to fix the last one, each making it worse.",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 20,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE SEND & THE FREEZE",
                    emotionalEscalation: "Audience starts at casual amusement and shifts to gleeful dread as the realization hits that this cannot be unsent.",
                    placeholderDescription: "[CHARACTER] fires off a text meant for one person and watches in horror as it delivers to exactly the wrong person. The phone becomes a live grenade.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "close-up",
                            beatPurpose: "Show the text being sent — the audience sees the mistake before the character does",
                            placeholderDirection: "Close-up of a phone screen. Thumbs flying. The message is [MESSAGE CONTENT] — the kind of thing you'd only say to one specific person. The send animation plays. Then the contact name at the top comes into focus: [WRONG RECIPIENT]."
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "close-up",
                            beatPurpose: "The physical freeze — comedy lives in the delay between send and realization",
                            placeholderDirection: "Close-up of [CHARACTER]'s face. A half-smile still lingering from the joke they thought they were making. Then the smile dies. The eyes widen. The mouth opens but nothing comes out.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The panicked verbalization that makes it real",
                                voiceCue: "Whispered, horrified, talking to themselves",
                                draftHint: "A short burst of self-directed panic — swearing, denial, or a frantic narration of their own doom"
                            )
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "THE SPIRAL",
                    emotionalEscalation: "Audience starts at sympathetic panic and shifts to helpless laughter as each fix creates a bigger problem than the one before it.",
                    placeholderDescription: "[CHARACTER] tries to fix it. The follow-up text makes it worse. The phone call to explain makes it worse than that. The final attempt to salvage things is the killing blow.",
                    shots: [
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "medium",
                            beatPurpose: "First fix attempt — the one that seems reasonable but backfires",
                            placeholderDirection: "[CHARACTER] paces their room, typing furiously, deleting, typing again. They hit send on a follow-up that was supposed to be a save. They read it back. It is not a save.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The muttered self-coaching that precedes a bad decision",
                                voiceCue: "Fast, breathless, bargaining with themselves",
                                draftHint: "Talking themselves into the follow-up text — convincing themselves it'll work when it clearly won't"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "close-up",
                            beatPurpose: "The second fix makes it catastrophically worse",
                            placeholderDirection: "Close-up of the phone screen. The response from [WRONG RECIPIENT] arrives. It's worse than anything [CHARACTER] imagined. The read receipt is a death sentence."
                        ),
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "medium",
                            beatPurpose: "The surrender — comedy payoff in the acceptance of total defeat",
                            placeholderDirection: "[CHARACTER] sets the phone face-down on the table with the gentleness of someone placing flowers on a grave. They stare at the ceiling. There is nothing left to fix.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The resigned final line that serves as the punchline",
                                voiceCue: "Flat, defeated, almost peaceful in its hopelessness",
                                draftHint: "A single line of total surrender — either accepting the consequences or making one last absurd observation about their situation"
                            )
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 3. The Strange Noise

        FilmTemplate(
            id: "strange_noise",
            title: "The Strange Noise",
            description: "Alone and quiet, then a sound that doesn't belong. The investigation builds tension shot by shot as curiosity overrides every instinct to leave it alone.",
            mood: "suspense",
            engine: "A small unexplained sound expands into existential dread through the character's escalating willingness to investigate what they should leave alone.",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 25,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "HEAR IT",
                    emotionalEscalation: "Audience starts at comfortable stillness and shifts to prickling alertness as the ordinary silence is punctured by something that doesn't fit.",
                    placeholderDescription: "[CHARACTER] is alone at [LOCATION], doing nothing important, when a sound cuts through the quiet. It's wrong — not loud, not dramatic, just wrong.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "wide",
                            beatPurpose: "Establish the quiet normalcy that the noise will shatter",
                            placeholderDirection: "Wide shot of [CHARACTER] alone in [LOCATION]. The light is ordinary. They're doing something forgettable — scrolling their phone, making tea, folding laundry. The kind of moment nobody remembers."
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "close-up",
                            beatPurpose: "The freeze — the body registers the sound before the mind does",
                            placeholderDirection: "Close-up of [CHARACTER] mid-motion, suddenly still. Their head tilts slightly. Eyes unfocus. The hands stop. They heard [THE NOISE] and every muscle has an opinion about it.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The whispered self-reassurance that convinces no one",
                                voiceCue: "Barely audible, talking to themselves, trying to sound casual",
                                draftHint: "A muttered rationalization — what they tell themselves the sound probably was, delivered without any real conviction"
                            )
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "INVESTIGATE",
                    emotionalEscalation: "Audience starts at nervous anticipation and shifts to full dread as the character moves toward the sound despite every signal to stop.",
                    placeholderDescription: "[CHARACTER] moves toward the source. They should not be doing this and they know it, and they do it anyway, because the not-knowing is worse.",
                    shots: [
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "medium",
                            beatPurpose: "The approach — each step is a decision to keep going",
                            placeholderDirection: "[CHARACTER] moves slowly toward [DIRECTION OF SOUND]. Their weight shifts carefully with each step. One hand trails the wall. They're listening so hard their jaw is tight."
                        ),
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "close-up",
                            beatPurpose: "The threshold — the point of no return",
                            placeholderDirection: "Close-up of [CHARACTER]'s hand reaching for [A DOOR HANDLE / A LIGHT SWITCH / A CURTAIN EDGE]. Their fingers hover. [THE NOISE] comes again — closer now, or different somehow. The hand doesn't pull back.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The call into the dark that makes the audience grip their seat",
                                voiceCue: "Whispered, tight, the voice of someone who doesn't want an answer",
                                draftHint: "A single tentative word or question directed at whatever might be there — 'hello?' but with the specific dread of someone who's already imagining what might respond"
                            )
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "THE SOURCE",
                    emotionalEscalation: "Audience starts at peak tension and shifts to either shock, relief, or lingering unease depending on whether the reveal answers the question or deepens it.",
                    placeholderDescription: "The source of the noise is revealed. It explains everything — or it explains nothing and leaves a worse question hanging in the air.",
                    shots: [
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "wide",
                            beatPurpose: "The reveal — what was making the sound",
                            placeholderDirection: "Wide shot: [CHARACTER] rounds the corner and finds [THE SOURCE]. The room holds for a beat. The audience processes what they're seeing before the character does."
                        ),
                        TemplateShot(
                            shotNumber: 6,
                            shotType: "close-up",
                            beatPurpose: "The final reaction — what the discovery means to this person",
                            placeholderDirection: "Close-up of [CHARACTER]'s face. The expression is [RELIEF / CONFUSION / A NEW KIND OF FEAR]. They exhale — or they don't. The noise has stopped, but something else hasn't."
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 4. The Argument

        FilmTemplate(
            id: "the_argument",
            title: "The Argument",
            description: "Two people who care about each other disagree about something small that turns out to represent something neither of them can say directly — until one of them does.",
            mood: "drama",
            engine: "Two people who care about each other disagree about something that sounds small but represents something neither of them can say directly — until one of them does.",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 25,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE SURFACE ARGUMENT",
                    emotionalEscalation: "Audience starts at mild tension and shifts to growing unease as they sense the argument is about something bigger than what's being said.",
                    placeholderDescription: "[CHARACTER A] and [CHARACTER B] disagree about [SMALL TOPIC]. It sounds manageable. Both are still being polite. But the politeness is doing work — it's holding back something heavier.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "wide",
                            beatPurpose: "Establish both characters and the physical tension between them",
                            placeholderDirection: "Wide shot of [CHARACTER A] and [CHARACTER B] in [LOCATION]. They're facing each other but the space between them feels loaded. The air in the room is doing something.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "Open the disagreement on the surface level — sounds reasonable, hides the real wound",
                                voiceCue: "Controlled, measured, the voice of someone who thinks they're being rational",
                                draftHint: "A calm statement about the surface topic that carries an undertone of something personal — the words are about dishes or schedules but the subtext is about feeling unseen"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "medium",
                            beatPurpose: "Character B's position — the pushback that raises the temperature",
                            placeholderDirection: "[CHARACTER B] responds and their body shifts. Arms cross or hands go to hips. The politeness is thinning. They make their point and it lands harder than the words suggest.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER B]",
                                beatPurpose: "The counter-argument that starts revealing what this is really about",
                                voiceCue: "Firm, slightly clipped, the patience is audibly finite",
                                draftHint: "A response that addresses the surface topic but lets slip a hint of the deeper grievance — a word choice or a reference to a pattern that signals this has happened before"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "medium",
                            beatPurpose: "The escalation — the surface cracks and the real issue starts bleeding through",
                            placeholderDirection: "[CHARACTER A] steps forward or leans in. The composure is slipping. A hand gesture gets bigger than intended. The volume hasn't risen but the intensity has.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "The moment the argument shifts from the topic to the relationship",
                                voiceCue: "Rising heat, the controlled exterior beginning to fracture",
                                draftHint: "A line that starts about the surface topic and veers into what's actually wrong — the sentence that makes both characters realize this isn't about what they said it was about"
                            )
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "THE REAL THING",
                    emotionalEscalation: "Audience starts at painful recognition and shifts to raw vulnerability as someone finally says the quiet part out loud.",
                    placeholderDescription: "The surface topic falls away. One of them says the thing underneath — the real hurt, the real fear, the real need. The room changes when truth enters it.",
                    shots: [
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "close-up",
                            beatPurpose: "The line that crosses from argument into truth",
                            placeholderDirection: "Close-up of [CHARACTER B]. Something breaks open in their expression. The mask drops. What comes out of their mouth is not about [SURFACE TOPIC] anymore — it's about [THE REAL THING].",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER B]",
                                beatPurpose: "The vulnerable truth that the entire argument was protecting",
                                voiceCue: "Cracked, raw, the voice of someone who didn't plan to say this",
                                draftHint: "The real grievance — not angry anymore but honest. The sentence that makes the other person stop arguing because there's nothing to argue with, only something to hear"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "medium",
                            beatPurpose: "The impact — the truth lands and changes the room",
                            placeholderDirection: "[CHARACTER A] absorbs it. The fight posture dissolves. Their shoulders drop. Their mouth opens to respond and then closes. The argument is over but not because anyone won.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "The response to vulnerability — whatever comes after honesty",
                                voiceCue: "Quiet, stripped of performance, meeting the other person where they are",
                                draftHint: "A response that acknowledges what was said — not a fix, not a counter, just recognition. Could be an apology, a confession, or a simple 'I didn't know that's what this was'"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 6,
                            shotType: "wide",
                            beatPurpose: "The aftermath — two people in a room where something true was said",
                            placeholderDirection: "Wide shot of both characters. The distance between them is the same but the quality of it has changed. Neither moves. The silence after honesty is different from the silence before it."
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 5. The Small Kindness

        FilmTemplate(
            id: "the_small_kindness",
            title: "The Small Kindness",
            description: "One person notices a need that everyone else walks past, and makes a quiet choice that costs them almost nothing but shifts the other person's entire day.",
            mood: "drama",
            engine: "One person notices a need that everyone else walks past, and makes a quiet choice that costs them almost nothing but shifts the other person's entire day.",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 25,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE NEED",
                    emotionalEscalation: "Audience starts at neutral observation and shifts to quiet empathy as they notice what Character A notices — a small struggle that everyone else is ignoring.",
                    placeholderDescription: "[CHARACTER A] is going about their day at [LOCATION] when they spot [CHARACTER B] dealing with [A SMALL STRUGGLE]. Other people pass by without looking. [CHARACTER A] looks.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "wide",
                            beatPurpose: "Establish the world where the need exists and is being ignored",
                            placeholderDirection: "Wide shot of [LOCATION]. Life moves at its usual speed. [CHARACTER B] is visible in the frame, dealing with [THE SMALL STRUGGLE] — not dramatically, just the quiet way people deal with things when they think nobody's watching."
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "medium",
                            beatPurpose: "The noticing — Character A sees what others don't",
                            placeholderDirection: "[CHARACTER A] pauses mid-stride. Their eyes catch on [CHARACTER B]. Something in their expression shifts — not pity, but recognition. They see the need because they've been there, or because they're the kind of person who looks."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "THE ACT",
                    emotionalEscalation: "Audience starts at hopeful anticipation and shifts to a warm ache as the kindness lands — small enough to be nothing, precise enough to be everything.",
                    placeholderDescription: "[CHARACTER A] does something small. It takes ten seconds. It costs nothing. But the specificity of it — the fact that someone noticed — is what makes [CHARACTER B]'s face change.",
                    shots: [
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "medium",
                            beatPurpose: "The kind act — quiet, specific, unheroic",
                            placeholderDirection: "[CHARACTER A] steps toward [CHARACTER B] and does [THE KIND THING]. No announcement, no performance. Just a hand that helps, or a word that acknowledges, or a gesture that says 'I see you and this is fixable.'",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "If the kindness is verbal (reading something aloud, giving information, naming what's needed), this is the line that does the work. If the kindness is purely physical (carrying a bag, opening a door, offering a seat), this shot is silent — leave dialogueIntent's draft_line empty in the generated plan and set has_spoken_line to false on the resulting dialogue_direction.",
                                voiceCue: "Practical, unheroic, the tone of someone reading a grocery list or stating a fact — not warm, not performative. The kindness is in the doing, not the saying.",
                                draftHint: "Either no line at all (set has_spoken_line: false on the generated dialogue_direction), OR a single short factual line that delivers the help — reading information aloud, giving directions, telling time, naming what's needed. Default to silent unless the user's idea makes the kindness inherently verbal."
                            )
                        ),
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "close-up",
                            beatPurpose: "The impact on Character B — the surprise of being seen",
                            placeholderDirection: "Close-up of [CHARACTER B]'s face. The surprise comes first — not that someone helped, but that someone noticed. Then something softer. A breath they didn't know they were holding.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER B]",
                                beatPurpose: "The single line that carries the weight of unexpected grace",
                                voiceCue: "Quiet, slightly unsteady, the voice of someone caught off guard by kindness",
                                draftHint: "A simple thank you that means more than thank you — or a small question like 'how did you know?' that reveals how long they've been handling it alone"
                            )
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "AFTER",
                    emotionalEscalation: "Audience starts at gentle warmth and shifts to a quiet, lasting feeling — the kind that stays with you after the screen goes dark.",
                    placeholderDescription: "Both characters return to their lives. The world hasn't changed. But something in the texture of the day is different — lighter in a way that's hard to name but impossible to miss.",
                    shots: [
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "medium",
                            beatPurpose: "The quiet aftermath for each person",
                            placeholderDirection: "[CHARACTER A] walks away without looking back — not because they don't care, but because the act was never about being seen doing it. Their pace is the same but something in their posture has settled.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "A throwaway line that reveals the giver was changed too",
                                voiceCue: "Under their breath, almost to themselves, a small surprised warmth",
                                draftHint: "A muttered observation or a quiet laugh — the sound of someone who did something small and felt it land bigger than they expected"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 6,
                            shotType: "wide",
                            beatPurpose: "The world continues — but the audience carries the warmth forward",
                            placeholderDirection: "Wide shot of [LOCATION]. Both characters have moved on. The same space, the same light, the same ordinary life — but the audience knows something happened here that mattered."
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 6. The Silent Confession

        FilmTemplate(
            id: "silent_confession",
            title: "The Silent Confession",
            description: "One person carries an unspoken feeling toward another. No words are spoken. The weight of it lives in every glance, gesture, and almost-moment until a single physical action says everything.",
            mood: "romance",
            engine: "One person carries an unspoken feeling toward another, and the audience watches the weight of it in every glance, gesture, and almost-moment until a single physical action says what words could not.",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 20,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE WEIGHT OF NOT SAYING IT",
                    emotionalEscalation: "Audience starts at quiet awareness and shifts to aching recognition as every small gesture from [CHARACTER A] reveals the enormity of what they're holding back.",
                    placeholderDescription: "[CHARACTER A] and [CHARACTER B] share a space at [LOCATION]. They do ordinary things side by side. But [CHARACTER A] watches [CHARACTER B] with the kind of attention that gives everything away — to the audience, never to [CHARACTER B].",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "wide",
                            beatPurpose: "Establish both characters sharing space — the closeness that makes the silence louder",
                            placeholderDirection: "Wide shot: [CHARACTER A] and [CHARACTER B] at [LOCATION], doing [ORDINARY ACTIVITY] together. They're comfortable. It looks like nothing. But [CHARACTER A]'s awareness of [CHARACTER B] fills every frame."
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "close-up",
                            beatPurpose: "The look that says everything the character cannot",
                            placeholderDirection: "Close-up of [CHARACTER A]'s eyes following [CHARACTER B]. Not staring — just drawn. The way a person watches someone they've memorized without meaning to. [CHARACTER B] doesn't notice."
                        ),
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "medium",
                            beatPurpose: "The almost-moment — the closest they come to saying it, and the retreat",
                            placeholderDirection: "[CHARACTER A] reaches toward [CHARACTER B] — to touch their shoulder, to fix their collar, to hand them something — and stops. The hand hovers, then redirects to something mundane. The moment passes. [CHARACTER B] never knew it was there."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "THE GESTURE",
                    emotionalEscalation: "Audience starts at tender suspense and shifts to a full-body ache as one physical action communicates what an entire conversation could not.",
                    placeholderDescription: "The opportunity arrives — [CHARACTER B] is about to leave, or fall asleep, or turn away — and [CHARACTER A] makes a single physical choice. Not a word. Just an action. And it says everything.",
                    shots: [
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "close-up",
                            beatPurpose: "The gesture itself — the confession without language",
                            placeholderDirection: "Close-up of [THE GESTURE]. [CHARACTER A]'s hand [PLACING A BLANKET OVER THEM / BRUSHING HAIR FROM THEIR FACE / LEAVING SOMETHING WHERE THEY'LL FIND IT]. The movement is slow and careful, like handling something that might break."
                        ),
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "medium",
                            beatPurpose: "Whether the confession was received — ambiguity is the point",
                            placeholderDirection: "[CHARACTER B]'s response — or non-response. Maybe their eyes are closed but their expression shifts. Maybe they were awake the whole time. Maybe they'll never know. The camera holds on both of them, and the silence says what it says."
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 7. The Forgotten Thing

        FilmTemplate(
            id: "forgotten_thing",
            title: "The Forgotten Thing",
            description: "That sinking realization that you forgot something important — followed by an increasingly desperate improvised replacement that's funnier the further it gets from adequate.",
            mood: "comedy",
            engine: "The gap between how important the forgotten thing is and how absurd the improvised replacement is creates the comedy — the more desperate the fix, the funnier.",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 20,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE REALIZATION",
                    emotionalEscalation: "Audience starts at casual ease and shifts to delighted anticipation as the character's face cycles through denial, panic, and desperate ingenuity.",
                    placeholderDescription: "[CHARACTER] is at [LOCATION] when the realization hits: they forgot [THE THING]. It's too late to go back. It's needed right now. The clock is ticking and the options are terrible.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "medium",
                            beatPurpose: "The moment the realization lands — comedy is in the physical reaction",
                            placeholderDirection: "[CHARACTER] is mid-[ACTIVITY] when their body freezes. You can see the exact moment the memory fires — their hand goes to their pocket, their bag, the spot where [THE THING] should be. It is not there. It is very much not there.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The vocalized panic that makes the internal external",
                                voiceCue: "Hissed, frantic, the whisper-yell of someone trying not to make a scene",
                                draftHint: "A rapid-fire internal monologue spoken aloud — cycling through 'no no no' to 'okay okay okay' to a specific panicked inventory of where it could possibly be"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "close-up",
                            beatPurpose: "The face — denial to panic to deranged determination",
                            placeholderDirection: "Close-up of [CHARACTER]'s face doing speedruns through the five stages of grief. Denial. Anger. Bargaining with God. And then — the eyes narrow. A plan is forming. It is not a good plan."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "THE FIX",
                    emotionalEscalation: "Audience starts at curious amusement and shifts to howling disbelief as the improvised solution gets more committed and less adequate.",
                    placeholderDescription: "[CHARACTER] builds a replacement out of whatever's available. Each addition makes it worse and their commitment to it makes it funnier. The final presentation is a monument to human desperation.",
                    shots: [
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "medium",
                            beatPurpose: "The scavenger hunt — finding materials for the worst version",
                            placeholderDirection: "[CHARACTER] tears through [LOCATION] like a raccoon with a deadline. Drawers open, shelves get raided, unlikely objects get held up and evaluated with the seriousness of a surgeon choosing instruments."
                        ),
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "close-up",
                            beatPurpose: "The assembly — watching the disaster take shape",
                            placeholderDirection: "Close-up of [CHARACTER]'s hands constructing [THE IMPROVISED REPLACEMENT]. Tape, rubber bands, optimism, and a complete divorce from reality. They hold it up. They tilt their head. It is objectively terrible.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The self-delusion that it might actually work",
                                voiceCue: "Manic confidence, the voice of someone who has fully committed to a bad idea",
                                draftHint: "A line of totally unearned confidence — talking to the improvised thing like it's going to save them, or psyching themselves up for the presentation"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "wide",
                            beatPurpose: "The reveal — comedy payoff in the gap between need and solution",
                            placeholderDirection: "Wide shot: [CHARACTER] presents [THE IMPROVISED REPLACEMENT] in the context where [THE REAL THING] was needed. The gap between what's required and what's being offered is the entire joke. It [FAILS SPECTACULARLY / WORKS FOR EXACTLY TWO SECONDS / IS MET WITH A STARE THAT COULD PEEL PAINT].",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The presentation line — total commitment to the bit",
                                voiceCue: "Bright, presentational, the confidence of someone in deep denial",
                                draftHint: "The line you say when you hand someone something terrible with a straight face — either overselling it or underselling it with deadly calm"
                            )
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 8. The Thing You Find In Their Pocket

        FilmTemplate(
            id: "pocket_discovery",
            title: "The Thing You Find In Their Pocket",
            description: "Finding something in someone else's pocket — a receipt, a note, a key — forces a choice between ignorance and confrontation. What the finder does next reveals more about them than the owner.",
            mood: "drama",
            engine: "Finding something in someone else's pocket — a receipt, a note, a key — forces the finder to choose between ignorance and confrontation, and the choice reveals more about the finder than the owner.",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 30,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE FIND",
                    emotionalEscalation: "Audience starts at idle curiosity and shifts to creeping unease as the object's implications unfold in the finder's expression.",
                    placeholderDescription: "[CHARACTER A] reaches into [CHARACTER B]'s pocket for something innocent — a car key, a stick of gum — and their fingers find [THE OBJECT] instead. It shouldn't be there. Or it should, and that's worse.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "medium",
                            beatPurpose: "Establish the innocence of the moment before the discovery",
                            placeholderDirection: "[CHARACTER A] is alone with [CHARACTER B]'s jacket, bag, or coat at [LOCATION]. They reach into a pocket for a mundane reason — looking for keys, or a receipt, or nothing in particular. Their hand stops."
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "close-up",
                            beatPurpose: "Reveal the object — the audience and character discover it simultaneously",
                            placeholderDirection: "Close-up of [CHARACTER A]'s hand withdrawing [THE OBJECT] from the pocket. They hold it in the light. The camera holds on it long enough for the audience to understand what it means."
                        ),
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "close-up",
                            beatPurpose: "The emotional processing — the face tells the story",
                            placeholderDirection: "Close-up of [CHARACTER A]'s face as the implications land. Not anger — not yet. Something quieter. The look of a person re-reading a familiar story and finding a sentence they missed."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "THE CHOICE",
                    emotionalEscalation: "Audience starts at tense anticipation and shifts to anxious investment as the finder decides — put it back and pretend, or hold it out and ask.",
                    placeholderDescription: "[CHARACTER A] stands in [LOCATION] holding [THE OBJECT] and the two versions of what happens next. They can slide it back into the pocket. Or they can be holding it when [CHARACTER B] walks in.",
                    shots: [
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "medium",
                            beatPurpose: "The decision moment — the physical choice between ignorance and truth",
                            placeholderDirection: "[CHARACTER A] looks at the pocket, then at [THE OBJECT], then at the door [CHARACTER B] will come through. Their hand moves toward the pocket — to put it back — and stops. They set it on the table instead. Decision made."
                        ),
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "wide",
                            beatPurpose: "Character B arrives — the confrontation begins in body language before words",
                            placeholderDirection: "Wide shot: [CHARACTER B] enters [LOCATION]. They see [CHARACTER A]. Then they see [THE OBJECT] on the table. The room's temperature drops ten degrees in the space between their steps."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "THE CONFRONTATION",
                    emotionalEscalation: "Audience starts at held breath and shifts to raw exposure as the conversation strips both characters down to what they actually need from each other.",
                    placeholderDescription: "The conversation that follows is not about [THE OBJECT]. It's about trust, and what finding it revealed about the finder's willingness to look, and the owner's need to hide.",
                    shots: [
                        TemplateShot(
                            shotNumber: 6,
                            shotType: "medium",
                            beatPurpose: "The confrontation — what gets said when there's nowhere to hide",
                            placeholderDirection: "[CHARACTER A] and [CHARACTER B] face each other across the table with [THE OBJECT] between them. The space between them is small but it contains everything.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "The question that's really about something bigger than the object",
                                voiceCue: "Steady, controlled, the voice of someone who's already decided how they feel and is giving the other person one chance",
                                draftHint: "Not 'what is this?' but a more specific question that reveals what finding it meant to them — what it confirmed or contradicted about the relationship"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 7,
                            shotType: "close-up",
                            beatPurpose: "The response — or the silence that is the response",
                            placeholderDirection: "Close-up of [CHARACTER B]. They could explain. They could lie. They could say nothing. Whatever they do, their face arrives at the truth before their mouth does.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER B]",
                                beatPurpose: "The answer that reveals what they were protecting and why",
                                voiceCue: "Caught, stripped of preparation, the voice of someone speaking without a script for the first time",
                                draftHint: "An explanation that's either more innocent or more complicated than expected — the truth is never the first thing Character A imagined"
                            )
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 9. The Awkward Run-In

        FilmTemplate(
            id: "awkward_run_in",
            title: "The Awkward Run-In",
            description: "You spot someone you absolutely do not want to talk to, and every attempt to avoid them makes the eventual encounter more spectacularly unavoidable.",
            mood: "comedy",
            engine: "You spot someone you absolutely do not want to talk to, and every attempt to avoid them makes the eventual encounter more spectacularly unavoidable.",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 20,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE SPOT & THE DODGE",
                    emotionalEscalation: "Audience starts at casual amusement and shifts to gleeful anticipation as the evasion tactics get increasingly absurd and increasingly doomed.",
                    placeholderDescription: "[CHARACTER] is at [LOCATION] when they spot [THE PERSON THEY'RE AVOIDING] across the space. The exit is right there. They just need to walk normally. They do not walk normally.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "medium",
                            beatPurpose: "The spot — the body reacts before the brain",
                            placeholderDirection: "[CHARACTER] is mid-stride at [LOCATION] when their whole body seizes. They've spotted [THE PERSON] and the avoidance instinct hits like voltage. They pivot, duck, or freeze in a position that makes them look like a broken mannequin.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The whispered panic that the audience shares",
                                voiceCue: "Hissed under their breath, pure adrenaline, talking to no one",
                                draftHint: "A frantic sotto voce reaction — naming the person, assessing escape routes, or making a desperate deal with the universe"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "wide",
                            beatPurpose: "The first avoidance attempt — it looks worse than just saying hello would have",
                            placeholderDirection: "Wide shot: [CHARACTER] executes their avoidance strategy. They [HIDE BEHIND SOMETHING / TAKE A SUDDEN INTEREST IN A WALL / REVERSE DIRECTION WITH THE SUBTLETY OF A CAR ALARM]. The irony: nobody was looking at them before, but they're very visible now."
                        ),
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "medium",
                            beatPurpose: "The second attempt — escalation of absurdity",
                            placeholderDirection: "[CHARACTER] thinks they're clear. They peek around [THEIR HIDING SPOT]. [THE PERSON] has moved — directly into the path of the only remaining exit. [CHARACTER]'s face does the math. The math is bad."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "THE INEVITABLE",
                    emotionalEscalation: "Audience starts at peak anticipation and shifts to cathartic laughter as the collision happens in the worst possible way.",
                    placeholderDescription: "After all that effort, the run-in happens anyway — and because of all the dodging, it's ten times more awkward than a simple hello would have been.",
                    shots: [
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "medium",
                            beatPurpose: "The collision — the universe wins",
                            placeholderDirection: "[CHARACTER] turns a corner, backs into an aisle, or stands up from their hiding spot and comes face-to-face with [THE PERSON]. The proximity is obscene. There is no escape route that doesn't involve climbing furniture.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The greeting that's ten times more awkward because of the failed avoidance",
                                voiceCue: "Overcompensating brightness, the sound of a person pretending they haven't been army-crawling between shelves",
                                draftHint: "A greeting so forced and enthusiastic that it confirms every suspicion — the voice of someone who was absolutely hiding thirty seconds ago and is now pretending they just arrived"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "wide",
                            beatPurpose: "The aftermath — stuck in the conversation they tried to avoid",
                            placeholderDirection: "Wide shot: [CHARACTER] is now trapped in exactly the conversation they spent five minutes trying to prevent. Their body language is a masterpiece of polite suffering. This will go on for a while."
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 10. The Sketch Bit

        FilmTemplate(
            id: "sketch_bit",
            title: "The Sketch Bit",
            description: "A single comedic premise, stated plainly, then pushed past the audience's expectation exactly twice. The second push is the button that ends the sketch.",
            mood: "comedy",
            engine: "A single comedic premise stated plainly, then pushed past the audience's expectation exactly twice — the second push is the button that ends the sketch.",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 15,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "PREMISE & FIRST ESCALATION",
                    emotionalEscalation: "Audience starts at 'oh this is funny' and shifts to 'oh no they're going further' as the premise gets its first push past reasonable.",
                    placeholderDescription: "[CHARACTER] establishes [THE COMEDIC PREMISE] with complete sincerity. It's funny because they mean it. Then they take it one step further than the audience expected — the first escalation that signals this is going somewhere unhinged.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "medium",
                            beatPurpose: "State the premise — the funnier it is played straight, the better the sketch",
                            placeholderDirection: "[CHARACTER] faces the camera or goes about [ACTIVITY] at [LOCATION]. They establish [THE PREMISE] through action or statement. It's absurd, but they treat it as the most natural thing in the world.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "Establish the comedic premise with deadpan sincerity",
                                voiceCue: "Matter-of-fact, casual, as if what they're saying is completely normal",
                                draftHint: "A statement or observation that establishes the absurd premise — the key is total commitment. The character doesn't think this is funny. They think this is Tuesday."
                            )
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "medium",
                            beatPurpose: "First escalation — push the premise past where the audience thought it was going",
                            placeholderDirection: "[CHARACTER] continues and reveals [THE FIRST ESCALATION]. What seemed like a simple bit now has layers. The premise isn't just absurd — it's a lifestyle.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "Deepen the premise — reveal it goes further than expected",
                                voiceCue: "Same casual register, no acknowledgment that this is escalating",
                                draftHint: "A detail or action that reveals the premise goes deeper than it first appeared — the audience thought they understood the joke and now they're recalibrating"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "close-up",
                            beatPurpose: "The pivot — the moment that sets up the final escalation",
                            placeholderDirection: "Close-up of [CHARACTER]. A beat. Something shifts in their expression — not breaking character, but arriving at the edge of the second escalation. The audience can feel it coming.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The bridge line between escalations — sets up the button",
                                voiceCue: "A slight shift in energy — could be more intense, more thoughtful, or more eerily calm",
                                draftHint: "A transitional line that makes the audience think 'wait, are they about to—' and the answer is yes"
                            )
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "THE BUTTON",
                    emotionalEscalation: "Audience starts at 'they wouldn't' and shifts to explosive laughter as the second escalation lands and the sketch ends at peak absurdity.",
                    placeholderDescription: "The second escalation hits. It's the logical extreme of the premise — the place you could see it going but hoped it wouldn't. It ends the sketch at the exact moment the bit is at its funniest.",
                    shots: [
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "medium",
                            beatPurpose: "The second escalation — the button that ends the sketch at peak funny",
                            placeholderDirection: "[CHARACTER] delivers [THE SECOND ESCALATION]. It's the logical endpoint of everything before it — the premise taken to its most committed extreme. The audience knew it was coming and it's still funnier than they expected.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The button — the final line or action that ends the sketch at peak absurdity",
                                voiceCue: "Full commitment. The tone should match the premise — deadpan, manic, tender, whatever the bit requires",
                                draftHint: "The punchline that the entire sketch was building toward — it works because the audience can see the logic of how they got here, even though where they are is insane"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "wide",
                            beatPurpose: "The hold — the beat after the button where the audience processes",
                            placeholderDirection: "Wide shot: [CHARACTER] in the aftermath of [THE BUTTON]. The camera holds for two beats longer than comfortable. They continue as if nothing happened — or they finally break — or they just walk out of frame. End on the funniest option."
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 11. Piece to Camera

        FilmTemplate(
            id: "piece_to_camera",
            title: "Piece to Camera",
            description: "One person speaks directly to the camera about something they care about. The shift from composed opening to vulnerable middle to resolved ending creates a complete emotional arc in under two minutes.",
            mood: "drama",
            engine: "One person speaks directly to the camera about something they care about, and the shift from composed opening to vulnerable middle to resolved ending creates a complete emotional arc in under two minutes.",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 15,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE ARC — COMPOSED TO VULNERABLE TO RESOLVED",
                    emotionalEscalation: "Audience starts at attentive distance and shifts through empathetic connection to quiet resolution as the speaker's armor comes off and goes back on, changed.",
                    placeholderDescription: "[CHARACTER] sits facing the camera at [LOCATION] and speaks about [THE SUBJECT]. They start in control. By the middle, the control has slipped. By the end, they've found something — not the control again, but something better.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "medium",
                            beatPurpose: "The composed opening — the version of themselves they planned to present",
                            placeholderDirection: "[CHARACTER] faces the camera. The framing is simple — just them, at [LOCATION], with whatever's behind them. They've thought about what to say. They begin, and they sound like someone who has it together.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "Establish the subject and the speaker's apparent composure",
                                voiceCue: "Rehearsed, steady, the voice of someone who wrote this in their head first",
                                draftHint: "An opening statement about [THE SUBJECT] that sounds prepared — articulate, clear, maybe even slightly performative. The kind of thing you'd say if you were trying to sound like you've processed something"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "close-up",
                            beatPurpose: "The crack — the moment the rehearsed version fails and the real one starts",
                            placeholderDirection: "Close-up of [CHARACTER]. They hit a word, a memory, a thought they didn't plan to reach — and the composure wobbles. Not a breakdown. Just the moment you can hear the script end and the real voice begin.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The vulnerable middle — what they actually feel beneath the composed version",
                                voiceCue: "Unscripted, searching, the pauses are as important as the words",
                                draftHint: "The thing they didn't plan to say — a specific memory, a fear, an admission. The sentences get shorter. The eye contact with the camera wavers. This is the part they'll think about deleting."
                            )
                        ),
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "medium",
                            beatPurpose: "The recovery — not returning to composure but arriving somewhere new",
                            placeholderDirection: "[CHARACTER] steadies. Not back to the rehearsed version — that's gone. Something else takes its place. They look at the camera with a clarity that wasn't there at the start.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The resolution — what they understand now that they've said the hard part",
                                voiceCue: "Quieter, grounded, the voice of someone who just heard themselves say something true",
                                draftHint: "A concluding thought that could only exist because the vulnerable middle happened — not a neat bow, but a real landing. What they know now that they've said it out loud."
                            )
                        ),
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "close-up",
                            beatPurpose: "The hold — the face after the last word, where the audience sits with what was said",
                            placeholderDirection: "Close-up of [CHARACTER] after the last word. They don't look away from the camera. The expression is [PEACE / EXHAUSTION / A SMALL SMILE / SOMETHING UNNAMEABLE]. Hold for three beats. Then cut to black.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The final beat — a single closing thought or the silence that says more",
                                voiceCue: "Almost a whisper, or a breath, or nothing at all — whatever the piece needs to land",
                                draftHint: "Either one last quiet line that puts a period on everything — or just a breath and a nod. Sometimes the best ending is the face of someone who's said enough."
                            )
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 12. The Voicemail

        FilmTemplate(
            id: "the_voicemail",
            title: "The Voicemail",
            description: "A character records a voice message they may or may not send. The tension is in watching them decide whether honesty is worth the consequences.",
            mood: "drama",
            engine: "A character records a voice message they may or may not send — the dramatic tension is in watching them decide whether honesty is worth the consequences, and the final shot reveals their choice.",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 20,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE RECORDING",
                    emotionalEscalation: "Audience starts at curious attention and shifts to invested empathy as the character's message evolves from rehearsed to raw.",
                    placeholderDescription: "[CHARACTER] sits alone at [LOCATION] with their phone. They start recording a voice message to [THE RECIPIENT]. The first attempt is careful. Then they delete it and try again. And again. Each version gets closer to what they actually want to say.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "medium",
                            beatPurpose: "The setup — a person alone with a phone and something to say",
                            placeholderDirection: "[CHARACTER] holds their phone at [LOCATION]. The room is quiet. They take a breath, tap record, and begin speaking with the careful cadence of someone who's been thinking about this for days."
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "close-up",
                            beatPurpose: "The first attempt — too safe, too rehearsed",
                            placeholderDirection: "Close-up of [CHARACTER] speaking into the phone. The words come out polished and empty. They stop. Delete. The expression says 'that's not it.' They try again.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The rehearsed version — what they think they should say",
                                voiceCue: "Controlled, diplomatic, the voice of someone managing their image",
                                draftHint: "The safe version of the message — polite, reasonable, emotionally distant. The kind of voicemail you'd leave if you wanted to say something without actually saying it."
                            )
                        ),
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "close-up",
                            beatPurpose: "The real version — the message that costs something to say",
                            placeholderDirection: "Close-up of [CHARACTER]. They hit record one more time. This time the words don't come out clean. They come out true. Pauses where composure catches up. A sentence that surprises even them.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The honest version — what they need the other person to hear",
                                voiceCue: "Unpolished, real, the voice breaks in the places where the truth is sharpest",
                                draftHint: "The version they're afraid to send — specific, vulnerable, and impossible to take back. The sentence that starts with 'the truth is' or 'what I should have said was' and goes somewhere they can't retreat from."
                            )
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "THE CHOICE",
                    emotionalEscalation: "Audience starts at breathless suspense and shifts to emotional resolution as the finger hovers over send or delete — and the choice reveals who this person is.",
                    placeholderDescription: "The message is recorded. It's honest. It's terrifying. [CHARACTER] stares at the phone. Send or delete. The choice is the story.",
                    shots: [
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "close-up",
                            beatPurpose: "The deliberation — send or delete, the weight of honesty",
                            placeholderDirection: "Close-up of [CHARACTER]'s face. Eyes on the phone screen. The thumb hovers. The face of a person calculating whether the truth is worth what it costs. Every second the thumb doesn't move is its own sentence.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The final thought before the choice — what tips the scale",
                                voiceCue: "Murmured, almost inaudible, the last negotiation with themselves",
                                draftHint: "A single muttered line — either talking themselves into pressing send or talking themselves out of it. The last thought before the finger moves."
                            )
                        ),
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "medium",
                            beatPurpose: "The choice — revealed in action, not words",
                            placeholderDirection: "[CHARACTER]'s thumb moves. The screen responds. We see their face after — not the screen. The expression tells us what they chose. They set the phone down with the finality of someone who can't undo what they just did — or didn't do."
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 13. The Apology

        FilmTemplate(
            id: "the_apology",
            title: "The Apology",
            description: "One person apologizes to another. The drama comes from the gap between what the apologizer says and what the receiver's face reveals they actually feel.",
            mood: "drama",
            engine: "The type of apology — sincere, defensive, manipulative, or performative — is specified by the user's customization, and the drama comes from the gap between what the apologizer says and what the receiver's face reveals they actually feel.",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 25,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE APPROACH",
                    emotionalEscalation: "Audience starts at wary attention and shifts to tense investment as the apologizer's opening moves reveal what kind of apology this is going to be.",
                    placeholderDescription: "[CHARACTER A] comes to [CHARACTER B] at [LOCATION] to apologize for [THE OFFENSE]. The way they approach — the body language, the timing, the first words — already tells the audience whether this is real.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "wide",
                            beatPurpose: "Establish the physical dynamic — who approaches, who waits, what the space between them says",
                            placeholderDirection: "Wide shot of [LOCATION]. [CHARACTER B] is already there. [CHARACTER A] enters or approaches with the posture of someone carrying something they want to put down. The distance between them is the distance of the offense."
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "medium",
                            beatPurpose: "The opening gambit — the first words reveal the type of apology",
                            placeholderDirection: "[CHARACTER A] faces [CHARACTER B]. A breath. Then they begin. The way they start — eyes down or eyes locked, hands open or hands defensive — sets the terms for everything that follows.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "The opening line of the apology — it establishes whether this is sincere, defensive, or performative",
                                voiceCue: "The tone depends on the type of apology — could be heavy with genuine remorse, or careful with self-protection, or suspiciously smooth",
                                draftHint: "The first sentence of the apology. A sincere one starts with the harm done. A defensive one starts with context. A manipulative one starts with the relationship. A performative one starts with 'I know I should say—'"
                            )
                        ),
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "close-up",
                            beatPurpose: "The receiver's face — what the apology is actually doing to them",
                            placeholderDirection: "Close-up of [CHARACTER B] listening. Their face is the lie detector. Every word from [CHARACTER A] registers — as landing or missing, as real or performed. The audience reads the apology through the receiver's eyes."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "THE RECKONING",
                    emotionalEscalation: "Audience starts at held breath and shifts to catharsis as the receiver finally speaks — and what they say redefines the conversation entirely.",
                    placeholderDescription: "The apology is out. Now [CHARACTER B] holds the power. They can accept, reject, complicate, or reframe everything [CHARACTER A] just said. The receiver's response is the real drama.",
                    shots: [
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "medium",
                            beatPurpose: "The heart of the apology — the apologizer goes deeper or doubles down",
                            placeholderDirection: "[CHARACTER A] continues. Maybe they go deeper — saying the harder, more specific thing. Maybe they loop back to self-justification. The middle of an apology is where it reveals itself.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "The core of the apology — the sentence that either reaches the other person or misses them entirely",
                                voiceCue: "The voice shifts — either toward more genuine vulnerability or toward more careful self-protection",
                                draftHint: "The specific acknowledgment — naming what they did, not in general terms but in the exact detail that hurt. Or, if the apology is hollow, the moment they accidentally reveal they're apologizing for getting caught, not for the harm."
                            )
                        ),
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "close-up",
                            beatPurpose: "The receiver speaks — their response reframes everything",
                            placeholderDirection: "Close-up of [CHARACTER B]. The silence after [CHARACTER A] finishes is a held breath. Then [CHARACTER B] speaks. What they say is not what [CHARACTER A] expected — it's either harder or softer or sideways from anything prepared for.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER B]",
                                beatPurpose: "The response that redefines the entire exchange — acceptance, rejection, or a truth that shifts the ground",
                                voiceCue: "Measured, coming from a place of genuine feeling — not reactive but considered",
                                draftHint: "The line that tells the apologizer — and the audience — what this relationship is now. Could be forgiveness, could be a boundary, could be 'I believe you mean it but I'm not there yet.' The specificity matters."
                            )
                        ),
                        TemplateShot(
                            shotNumber: 6,
                            shotType: "wide",
                            beatPurpose: "The aftermath — what the space between them looks like now",
                            placeholderDirection: "Wide shot of both characters. The apology is over. The distance between them is [SMALLER / THE SAME / DIFFERENT IN QUALITY]. Neither moves for a beat. The room holds what was said.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER A]",
                                beatPurpose: "The final beat — whatever comes after the reckoning",
                                voiceCue: "Quiet, stripped, whatever remains after the performance is gone",
                                draftHint: "A last line — could be as small as 'okay' or as loaded as 'I'll be here.' The word that acknowledges the receiver's response and accepts whatever comes next."
                            )
                        ),
                    ]
                ),
            ]
        ),

        // MARK: - 14. A Day In

        FilmTemplate(
            id: "a_day_in",
            title: "A Day In",
            description: "A single emotional through-line stitches together mundane moments of one day until the accumulation reveals what the day was actually about.",
            mood: "drama",
            engine: "A single emotional through-line stitches together mundane moments of one day until the accumulation reveals what the day was actually about — not the events, but the feeling underneath them.",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 30,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "MORNING — THE SURFACE",
                    emotionalEscalation: "Audience starts at neutral observation and shifts to quiet attentiveness as small details suggest something beneath the routine.",
                    placeholderDescription: "[CHARACTER] begins their day at [LOCATION]. Everything is ordinary. But the way they do ordinary things — the pace, the pauses, the things they look at — carries a weight the audience can feel before they can name.",
                    shots: [
                        TemplateShot(
                            shotNumber: 1,
                            shotType: "wide",
                            beatPurpose: "Establish the day — the character and their space in morning light",
                            placeholderDirection: "Wide shot of [LOCATION] in morning light. [CHARACTER] moves through the opening of their day — [MAKING COFFEE / GETTING DRESSED / LOOKING OUT A WINDOW]. The movements are familiar. Practiced. The kind of thing a body does while the mind is somewhere else."
                        ),
                        TemplateShot(
                            shotNumber: 2,
                            shotType: "close-up",
                            beatPurpose: "The first hint — a small moment that carries the emotional through-line",
                            placeholderDirection: "Close-up of [CHARACTER]'s hands doing something small — [HOLDING A MUG / TOUCHING AN OBJECT / PAUSING ON A PHOTO]. The gesture lingers half a beat longer than function requires. Something underneath the morning."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "MIDDAY — THE ACCUMULATION",
                    emotionalEscalation: "Audience starts at growing awareness and shifts to emotional investment as the through-line becomes undeniable — every mundane moment is connected by the same feeling.",
                    placeholderDescription: "The day continues. [CHARACTER] does ordinary things. But the emotional through-line is visible now — in what they avoid, what they're drawn to, how they hold themselves when they think nobody's watching.",
                    shots: [
                        TemplateShot(
                            shotNumber: 3,
                            shotType: "medium",
                            beatPurpose: "A mundane activity that the emotional through-line transforms",
                            placeholderDirection: "[CHARACTER] does [A MIDDAY ACTIVITY] at [LOCATION]. It should be unremarkable. But the way they do it — [A SPECIFIC PHYSICAL DETAIL] — reveals the feeling running underneath everything. They're carrying something today.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The only spoken line — small, almost accidental, but it names the through-line",
                                voiceCue: "Offhand, under the breath, the kind of thing you say to yourself without realizing",
                                draftHint: "A single murmured line — not a monologue, just a word or half-sentence that slips out. The kind of thing that tells the audience what this day is really about without the character meaning to say it."
                            )
                        ),
                        TemplateShot(
                            shotNumber: 4,
                            shotType: "close-up",
                            beatPurpose: "The emotional weight made visible in a physical detail",
                            placeholderDirection: "Close-up of [A SPECIFIC DETAIL] — [CHARACTER]'s reflection in a window, their hand resting on a surface, an object they keep coming back to. The camera holds. The feeling is here, in this frame, in this stillness."
                        ),
                        TemplateShot(
                            shotNumber: 5,
                            shotType: "medium",
                            beatPurpose: "The moment the through-line almost breaks through to the surface",
                            placeholderDirection: "[CHARACTER] stops what they're doing. Something has caught them — a sound, a memory, a mundane trigger that connects to [THE FEELING]. They stand still for a beat too long. Then they resume, but the audience saw it."
                        ),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "EVENING — THE REVEAL",
                    emotionalEscalation: "Audience starts at quiet emotional fullness and shifts to a deep, still feeling as the accumulation of the day resolves into a single image that says what the day was about.",
                    placeholderDescription: "The day ends. [CHARACTER] arrives at the evening version of their space. One final action — small, specific, and quiet — reveals what the entire day was about. Not the events. The feeling underneath them.",
                    shots: [
                        TemplateShot(
                            shotNumber: 6,
                            shotType: "medium",
                            beatPurpose: "The final action — the gesture that completes the day's emotional arc",
                            placeholderDirection: "[CHARACTER] does [THE FINAL ACTION] — something small that connects every moment of the day into a single through-line. [PUTTING SOMETHING AWAY / TAKING SOMETHING OUT / SITTING IN A SPECIFIC SPOT]. The action is quiet but it carries everything.",
                            dialogueIntent: TemplateDialogueIntent(
                                hasSpokenLine: true,
                                speaker: "[CHARACTER]",
                                beatPurpose: "The closing line — if spoken, it's barely there. If silent, the action speaks.",
                                voiceCue: "A whisper, or a sigh, or nothing — whatever the day needs to end",
                                draftHint: "A single word or exhale. Not a summary. Not a lesson. Just the sound a person makes at the end of a day that meant something they couldn't quite say."
                            )
                        ),
                        TemplateShot(
                            shotNumber: 7,
                            shotType: "wide",
                            beatPurpose: "The final frame — the character in their space, the day complete, the feeling named by everything that came before",
                            placeholderDirection: "Wide shot of [LOCATION] in evening light. [CHARACTER] is still. The same space as the morning but the light has changed, and so has the person in it. Hold for three beats. The day is over. The feeling stays."
                        ),
                    ]
                ),
            ]
        ),
    ]
}
