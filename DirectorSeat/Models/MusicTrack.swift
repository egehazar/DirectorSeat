import Foundation

struct MusicTrack: Identifiable {
    let id: String
    let name: String
    let mood: String
    let durationSeconds: Int
    let fileName: String?

    static let library: [MusicTrack] = [
        MusicTrack(id: "warm_piano", name: "Quiet Reflection", mood: "melancholy", durationSeconds: 60, fileName: nil),
        MusicTrack(id: "tense_strings", name: "On Edge", mood: "suspense", durationSeconds: 60, fileName: nil),
        MusicTrack(id: "playful_acoustic", name: "Easy Days", mood: "comedy", durationSeconds: 60, fileName: nil),
        MusicTrack(id: "cinematic_swell", name: "Big Moment", mood: "drama", durationSeconds: 60, fileName: nil),
        MusicTrack(id: "ambient_loop", name: "Quiet Mood", mood: "ambient", durationSeconds: 60, fileName: nil),
    ]
}
