import Foundation

extension FilmTemplate {
    static let library: [FilmTemplate] = [
        // MARK: 1. Bad First Date
        FilmTemplate(
            id: "bad_first_date",
            title: "The Bad First Date",
            description: "A first date that starts with hope and spirals into wonderful awkwardness. Classic comedy structure with a punchline exit.",
            mood: "comedy",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 25,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "MEET-CUTE",
                    placeholderDescription: "[CHARACTER A] arrives at [LOCATION] for a first date with [CHARACTER B]. First impressions are formed and expectations are set.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "wide", beatPurpose: "Establish setting and character A's arrival", placeholderDirection: "[CHARACTER A] walks into [LOCATION], scanning the room, slightly nervous."),
                        TemplateShot(shotNumber: 2, shotType: "medium", beatPurpose: "First eye contact and greeting", placeholderDirection: "[CHARACTER A] spots [CHARACTER B] and approaches. [INITIAL GREETING] — it's either too much or not enough."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "AWKWARD ESCALATION",
                    placeholderDescription: "The date takes an uncomfortable turn. What starts as small talk spirals into genuine awkwardness through [AWKWARD TOPIC OR INCIDENT].",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "Conversation goes off the rails", placeholderDirection: "[CHARACTER A] and [CHARACTER B] sit together. [AWKWARD TOPIC OR INCIDENT] makes things visibly uncomfortable."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "Internal realization this is going badly", placeholderDirection: "Close-up of [CHARACTER A]'s face as they realize this date is not recoverable."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "BAIL-OUT PUNCHLINE",
                    placeholderDescription: "One of them makes an obvious excuse to leave. The getaway is the punchline.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "The excuse", placeholderDirection: "[CHARACTER A OR B] suddenly stands up and delivers [THE OBVIOUS EXCUSE]. The other person's face says everything."),
                        TemplateShot(shotNumber: 2, shotType: "wide", beatPurpose: "The exit — the punchline lands", placeholderDirection: "[CHARACTER A OR B] rushes out of [LOCATION]. The other sits alone, stunned."),
                    ]
                ),
            ]
        ),

        // MARK: 2. The Wrong Text
        FilmTemplate(
            id: "the_wrong_text",
            title: "The Wrong Text",
            description: "One regrettable text message to the wrong person sets off a chain of increasingly desperate damage control.",
            mood: "comedy",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 15,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "THE SEND",
                    placeholderDescription: "[CHARACTER] sends [MESSAGE TYPE] to the wrong person. The mistake is immediately apparent.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "close-up", beatPurpose: "The send moment", placeholderDirection: "Close-up of phone screen. [CHARACTER] types [MESSAGE CONTENT] and hits send."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "The realization", placeholderDirection: "Close-up of [CHARACTER]'s face freezing. They just sent it to [WRONG RECIPIENT]."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "SPIRAL OF CONSEQUENCES",
                    placeholderDescription: "[CHARACTER] scrambles to undo the damage, only to make things progressively worse.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "Panic mode", placeholderDirection: "[CHARACTER] paces around [LOCATION], frantically trying to fix the situation."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "Making it worse", placeholderDirection: "Close-up of phone as [CHARACTER] sends a follow-up that [MAKES THINGS WORSE]."),
                        TemplateShot(shotNumber: 3, shotType: "medium", beatPurpose: "Consequences arrive", placeholderDirection: "[CHARACTER] faces the fallout. [THE CONSEQUENCE] lands."),
                    ]
                ),
            ]
        ),

        // MARK: 3. Mysterious Object
        FilmTemplate(
            id: "mysterious_object",
            title: "The Mysterious Object",
            description: "An ordinary day interrupted by the discovery of something that shouldn't be there. Curiosity leads to a revelation that reframes everything.",
            mood: "mystery",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 30,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "DISCOVERY",
                    placeholderDescription: "[CHARACTER] finds [OBJECT] in an unexpected place at [LOCATION]. It shouldn't be there.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "wide", beatPurpose: "Establish normalcy before the disruption", placeholderDirection: "Wide shot of [LOCATION]. Everything looks ordinary. [CHARACTER] goes about [MUNDANE ACTIVITY]."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "Reveal the object", placeholderDirection: "Close-up of [OBJECT] sitting where it shouldn't be — [SPECIFIC UNEXPECTED PLACEMENT]."),
                        TemplateShot(shotNumber: 3, shotType: "medium", beatPurpose: "Character notices and reacts", placeholderDirection: "[CHARACTER] stops what they're doing. They've noticed [OBJECT]. Confusion."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "INVESTIGATION",
                    placeholderDescription: "[CHARACTER] examines [OBJECT] closely, searching for meaning or origin.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "Hands-on examination", placeholderDirection: "[CHARACTER] picks up [OBJECT], turning it over, inspecting it from every angle."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "A telling detail", placeholderDirection: "Close-up of a specific detail on [OBJECT] — [UNUSUAL MARKING, INSCRIPTION, OR FEATURE]."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "REVELATION",
                    placeholderDescription: "The meaning behind [OBJECT] becomes clear. The ordinary becomes extraordinary.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "close-up", beatPurpose: "The realization hits", placeholderDirection: "Close-up of [CHARACTER]'s face as they understand what [OBJECT] means. [THE EMOTION]."),
                        TemplateShot(shotNumber: 2, shotType: "wide", beatPurpose: "The world reframed", placeholderDirection: "Wide shot of [LOCATION]. Same room, but everything feels different now."),
                    ]
                ),
            ]
        ),

        // MARK: 4. The Argument
        FilmTemplate(
            id: "the_argument",
            title: "The Argument",
            description: "A disagreement between two people that starts controlled and escalates until something is said that can't be taken back.",
            mood: "drama",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 25,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "BUILDING TENSION",
                    placeholderDescription: "[CHARACTER A] and [CHARACTER B] are in [LOCATION]. A disagreement about [TOPIC] starts small and grows.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "wide", beatPurpose: "Establish both characters and the tension", placeholderDirection: "Wide shot of [CHARACTER A] and [CHARACTER B] in [LOCATION]. The mood is tense but controlled."),
                        TemplateShot(shotNumber: 2, shotType: "medium", beatPurpose: "Person A's position", placeholderDirection: "[CHARACTER A] makes their point about [TOPIC]. Body language shows rising frustration."),
                        TemplateShot(shotNumber: 3, shotType: "medium", beatPurpose: "Person B pushes back", placeholderDirection: "[CHARACTER B] responds. Composure slipping. They disagree and they're not hiding it anymore."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "BREAKING POINT",
                    placeholderDescription: "The argument crosses a line. Something is said that can't be taken back.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "close-up", beatPurpose: "The line is crossed", placeholderDirection: "Close-up of [CHARACTER A OR B] as they say [THE LINE THAT GOES TOO FAR]."),
                        TemplateShot(shotNumber: 2, shotType: "medium", beatPurpose: "The impact", placeholderDirection: "The other character absorbs the blow. [VISIBLE REACTION — hurt, shock, withdrawal]."),
                        TemplateShot(shotNumber: 3, shotType: "wide", beatPurpose: "Aftermath — the distance between them", placeholderDirection: "Wide shot of both characters in silence. The physical distance between them says everything."),
                    ]
                ),
            ]
        ),

        // MARK: 5. The Reunion
        FilmTemplate(
            id: "the_reunion",
            title: "The Reunion",
            description: "Two people see each other again after a long time apart. The gap between expectation and reality carries the emotion.",
            mood: "drama",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 25,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "ANTICIPATION",
                    placeholderDescription: "[CHARACTER A] waits at [LOCATION] to see [CHARACTER B] for the first time in [TIME PERIOD]. The waiting is its own scene.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "The wait", placeholderDirection: "[CHARACTER A] at [LOCATION], checking the time, adjusting their clothes, rehearsing what to say."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "Inner state — anticipation and anxiety", placeholderDirection: "Close-up of [CHARACTER A]'s face. [ANTICIPATION, NERVOUSNESS, HOPE] in their expression."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "ENCOUNTER",
                    placeholderDescription: "They see each other. The first moment reveals what has and hasn't changed.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "wide", beatPurpose: "They see each other", placeholderDirection: "Wide shot: [CHARACTER B] appears. [CHARACTER A] turns. A beat of mutual recognition."),
                        TemplateShot(shotNumber: 2, shotType: "medium", beatPurpose: "The first interaction", placeholderDirection: "They come together. [THE FIRST WORDS OR GESTURE]. The tone is [WARM / AWKWARD / BITTERSWEET]."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "AFTERMATH",
                    placeholderDescription: "After [CHARACTER B] leaves, the real feelings surface.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "What lingers when they're alone again", placeholderDirection: "[CHARACTER A] alone again after [CHARACTER B] is gone. Their expression reveals [THE REAL EMOTION THEY WERE HOLDING BACK]."),
                    ]
                ),
            ]
        ),

        // MARK: 6. The Chase
        FilmTemplate(
            id: "the_chase",
            title: "The Chase",
            description: "Something triggers a chase. Obstacles, improvisation, and escalating stakes build to a resolution that's either triumph or comedy.",
            mood: "action",
            estimatedDurationMinutes: 4,
            estimatedShootMinutes: 35,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "TRIGGER",
                    placeholderDescription: "[TRIGGERING EVENT] forces [CHARACTER] to move — now. No time to think.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "Inciting incident", placeholderDirection: "[CHARACTER] is at [LOCATION] when [TRIGGERING EVENT] happens."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "Oh-no reaction, the decision to run", placeholderDirection: "Close-up of [CHARACTER]'s face: realization hits. They need to go. Now."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "PURSUIT",
                    placeholderDescription: "[CHARACTER] races through [LOCATION(S)], hitting obstacles that test their resourcefulness.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "wide", beatPurpose: "The chase begins", placeholderDirection: "Wide shot: [CHARACTER] takes off running through [LOCATION]."),
                        TemplateShot(shotNumber: 2, shotType: "medium", beatPurpose: "First obstacle — resourcefulness", placeholderDirection: "[CHARACTER] encounters [OBSTACLE] and has to [IMPROVISED SOLUTION] to get past it."),
                        TemplateShot(shotNumber: 3, shotType: "close-up", beatPurpose: "Determination or exhaustion", placeholderDirection: "Close-up of [CHARACTER] mid-stride. [EXHAUSTION / DETERMINATION / PANIC] on their face."),
                        TemplateShot(shotNumber: 4, shotType: "wide", beatPurpose: "Stakes visual — gaining or losing", placeholderDirection: "Wide shot: [CHARACTER] is [GAINING / LOSING] ground. The goal feels [CLOSER / FURTHER]."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "OUTCOME",
                    placeholderDescription: "The chase reaches its conclusion. Was it worth the run?",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "Arrival or confrontation", placeholderDirection: "[CHARACTER] finally [REACHES / CATCHES / CONFRONTS] [THE GOAL]."),
                        TemplateShot(shotNumber: 2, shotType: "wide", beatPurpose: "Resolution — catch breath, take stock", placeholderDirection: "Wide shot: [THE OUTCOME]. [CHARACTER] catches their breath. [TRIUMPH / COMEDY / IRONY]."),
                    ]
                ),
            ]
        ),

        // MARK: 7. Silent Confession
        FilmTemplate(
            id: "silent_confession",
            title: "The Silent Confession",
            description: "One person wants to say something important to another but can't find the words. A small gesture says what speech cannot.",
            mood: "romance",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 20,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "HESITATION",
                    placeholderDescription: "[CHARACTER A] and [CHARACTER B] are together at [LOCATION]. [CHARACTER A] wants to say [THE UNSPOKEN THING] but keeps holding back.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "wide", beatPurpose: "Together but with unspoken distance", placeholderDirection: "Wide shot: [CHARACTER A] and [CHARACTER B] at [LOCATION], doing [ACTIVITY] together. Comfortable silence."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "The unspoken thought visible on their face", placeholderDirection: "Close-up of [CHARACTER A] watching [CHARACTER B]. Something unsaid behind their eyes."),
                        TemplateShot(shotNumber: 3, shotType: "medium", beatPurpose: "Almost saying it — pulling back", placeholderDirection: "[CHARACTER A] opens their mouth to speak, hesitates, then says something ordinary instead."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "UNSPOKEN MOMENT",
                    placeholderDescription: "Words fail, but a small gesture communicates everything.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "close-up", beatPurpose: "The gesture that replaces words", placeholderDirection: "Close-up of [THE SMALL GESTURE] — [A HAND ON A SHOULDER / FINGERS BRUSHING / A LINGERING LOOK]."),
                        TemplateShot(shotNumber: 2, shotType: "medium", beatPurpose: "It's understood without words", placeholderDirection: "[CHARACTER B] reacts. A small [SMILE / NOD / RETURN GESTURE]. The feeling is understood."),
                    ]
                ),
            ]
        ),

        // MARK: 8. The Decision
        FilmTemplate(
            id: "the_decision",
            title: "The Decision",
            description: "A person alone with a choice that matters. The weight of deciding is the drama. Minimal action, maximum internal conflict.",
            mood: "drama",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 15,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "WEIGHING OPTIONS",
                    placeholderDescription: "[CHARACTER] faces a choice about [DECISION]. Both paths have real consequences.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "The dilemma made physical", placeholderDirection: "[CHARACTER] sits at [LOCATION] with [PHYSICAL REPRESENTATIONS OF THE CHOICE] in front of them."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "Internal conflict on display", placeholderDirection: "Close-up of [CHARACTER]'s face. Indecision, weight, pressure."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "CHOICE",
                    placeholderDescription: "[CHARACTER] commits. The decision is made and there's no taking it back.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "close-up", beatPurpose: "The decisive action", placeholderDirection: "Close-up of [CHARACTER]'s hand as they [PHYSICAL ACTION OF CHOOSING — picking up, putting down, writing, deleting]."),
                        TemplateShot(shotNumber: 2, shotType: "medium", beatPurpose: "Living with it — relief or regret", placeholderDirection: "[CHARACTER] after the choice. Their posture and expression show [RELIEF / REGRET / QUIET RESOLVE]."),
                    ]
                ),
            ]
        ),

        // MARK: 9. Strange Noise
        FilmTemplate(
            id: "strange_noise",
            title: "The Strange Noise",
            description: "Alone and quiet, then a sound that doesn't belong. The investigation builds tension shot by shot until the source is revealed.",
            mood: "suspense",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 25,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "HEAR IT",
                    placeholderDescription: "[CHARACTER] is alone at [LOCATION] when they hear [NOISE]. It does not belong here.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "wide", beatPurpose: "Establish quiet normalcy", placeholderDirection: "Wide shot of [CHARACTER] alone in [LOCATION], doing [MUNDANE ACTIVITY]. Everything is calm."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "The freeze — they heard something", placeholderDirection: "Close-up of [CHARACTER] mid-action, suddenly still. Head tilted. They heard [NOISE]."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "INVESTIGATE",
                    placeholderDescription: "[CHARACTER] moves toward the source. Every step raises the stakes.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "Cautious approach", placeholderDirection: "[CHARACTER] moves slowly toward [DIRECTION OF SOUND], eyes scanning, body tense."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "Confirmation — the noise repeats", placeholderDirection: "Close-up of [CHARACTER] paused at [THRESHOLD — a door, a corner, a hallway]. [NOISE] repeats."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "SOURCE",
                    placeholderDescription: "The source is revealed. It's [BETTER / WORSE / STRANGER] than expected.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "wide", beatPurpose: "The reveal", placeholderDirection: "Wide shot: [CHARACTER] rounds the corner and finds [THE SOURCE OF THE NOISE]."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "Final reaction — punchline or dread", placeholderDirection: "Close-up of [CHARACTER]'s face: [RELIEF / SHOCK / NERVOUS LAUGHTER] as they process what they found."),
                    ]
                ),
            ]
        ),

        // MARK: 10. The Letter
        FilmTemplate(
            id: "the_letter",
            title: "The Letter",
            description: "A letter arrives, is opened, is read. The words on the page change something inside the reader. Pure reaction acting.",
            mood: "drama",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 20,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "RECEIVE",
                    placeholderDescription: "[CHARACTER] receives [LETTER / NOTE / MESSAGE] unexpectedly. The physical object carries weight before it's even opened.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "The letter arrives", placeholderDirection: "[CHARACTER] finds [THE LETTER] at [WHERE THEY FIND IT — mailbox, doorstep, tucked in a book]."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "The physical object", placeholderDirection: "Close-up of [CHARACTER]'s hands holding [THE LETTER]. [DETAIL — the handwriting, the seal, the wear on the paper]."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "READ AND REACT",
                    placeholderDescription: "[CHARACTER] reads the contents. Each line changes their expression. The words reshape something.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "close-up", beatPurpose: "Reading — expression shifting", placeholderDirection: "Close-up of [CHARACTER]'s eyes moving across the page. Expression slowly shifts as the words land."),
                        TemplateShot(shotNumber: 2, shotType: "medium", beatPurpose: "Emotion builds beyond the page", placeholderDirection: "[CHARACTER] lowers the letter. [THE EMOTION] takes over — [PHYSICAL MANIFESTATION: hand to mouth, looking away, standing up]."),
                        TemplateShot(shotNumber: 3, shotType: "close-up", beatPurpose: "Final moment — what the letter meant", placeholderDirection: "Close-up of [CHARACTER]'s face after finishing. [THE FINAL EMOTION]. The letter meant [THE MEANING]."),
                    ]
                ),
            ]
        ),

        // MARK: 11. Forgotten Thing
        FilmTemplate(
            id: "forgotten_thing",
            title: "The Forgotten Thing",
            description: "That sinking feeling when you realize you forgot something important — followed by increasingly creative improvisation to fix it.",
            mood: "comedy",
            estimatedDurationMinutes: 2,
            estimatedShootMinutes: 20,
            castSize: 1,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "REALIZE",
                    placeholderDescription: "[CHARACTER] suddenly realizes they forgot [IMPORTANT THING] and it's [TOO LATE TO GO BACK / NEEDED RIGHT NOW].",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "The moment of realization", placeholderDirection: "[CHARACTER] is [DOING SOMETHING] at [LOCATION] when they freeze — they forgot [THE THING]."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "Panic face — the comedy beat", placeholderDirection: "Close-up of [CHARACTER]'s face cycling through denial, panic, and desperate determination."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "IMPROVISED SOLUTION",
                    placeholderDescription: "[CHARACTER] has to solve the problem with whatever's available. The solution gets increasingly creative.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "Scrambling for alternatives", placeholderDirection: "[CHARACTER] frantically searches [LOCATION] for anything that could replace [THE THING]."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "The makeshift version", placeholderDirection: "Close-up of [CHARACTER]'s hands assembling [A RIDICULOUS IMPROVISED VERSION OF THE THING]."),
                        TemplateShot(shotNumber: 3, shotType: "wide", beatPurpose: "The result — comedy payoff", placeholderDirection: "Wide shot: [CHARACTER] presents [THE IMPROVISED SOLUTION]. It [WORKS BADLY / WORKS SURPRISINGLY WELL / FALLS APART IMMEDIATELY]."),
                    ]
                ),
            ]
        ),

        // MARK: 12. The Small Kindness
        FilmTemplate(
            id: "the_small_kindness",
            title: "The Small Kindness",
            description: "Someone notices a need and makes a quiet, deliberate choice to help. No grand gestures — just a small act that shifts the day.",
            mood: "drama",
            estimatedDurationMinutes: 3,
            estimatedShootMinutes: 25,
            castSize: 2,
            scenes: [
                TemplateScene(
                    sceneNumber: 1,
                    beatDescription: "NOTICE NEED",
                    placeholderDescription: "[CHARACTER A] going about their day at [LOCATION] when they notice [CHARACTER B / A SITUATION] that calls for a small act of help.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "wide", beatPurpose: "Everyday life — nothing special yet", placeholderDirection: "Wide shot of [LOCATION]. [CHARACTER A] is going about their day. [CHARACTER B] is visible nearby."),
                        TemplateShot(shotNumber: 2, shotType: "medium", beatPurpose: "The noticing — compassion activates", placeholderDirection: "[CHARACTER A] pauses, noticing [THE NEED] — [WHAT THEY SEE THAT CALLS THEM TO ACT]."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 2,
                    beatDescription: "ACT",
                    placeholderDescription: "[CHARACTER A] makes a small, deliberate choice to help. It costs them almost nothing but means something.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "The kind act — quiet and specific", placeholderDirection: "[CHARACTER A] does [THE KIND THING]. It's small, quiet, deliberate. No fanfare."),
                        TemplateShot(shotNumber: 2, shotType: "close-up", beatPurpose: "The impact on the receiver", placeholderDirection: "Close-up of [CHARACTER B]'s face. [THE REACTION — surprise, gratitude, relief, a small smile]."),
                    ]
                ),
                TemplateScene(
                    sceneNumber: 3,
                    beatDescription: "AFTERMATH",
                    placeholderDescription: "Life continues. But something small has shifted.",
                    shots: [
                        TemplateShot(shotNumber: 1, shotType: "medium", beatPurpose: "The ripple effect", placeholderDirection: "[CHARACTER B] carries the kindness forward — or [CHARACTER A] is quietly affected by what they chose to do."),
                        TemplateShot(shotNumber: 2, shotType: "wide", beatPurpose: "Life goes on, but lighter", placeholderDirection: "Wide shot of [LOCATION]. Both characters continue their day. Something small has shifted."),
                    ]
                ),
            ]
        ),
    ]
}
