import Foundation

// Minimal mirrors of the Understudy types — enough to generate wire-format fixtures.
struct ID: Codable { let raw: String }
struct Pose: Codable { let x, y, z, yaw: Float }

enum LightColor: String, Codable { case warm, cool, red, blue, green, amber, blackout }

enum Cue: Codable {
    case line(id: ID, text: String, character: String?)
    case sfx(id: ID, name: String)
    case light(id: ID, color: LightColor, intensity: Float)
    case note(id: ID, text: String)
    case wait(id: ID, seconds: Double)
}

struct Mark: Codable {
    let id: ID; let name: String; let pose: Pose
    let radius: Float; let cues: [Cue]; let sequenceIndex: Int
}

struct Performer: Codable {
    let id: ID; let displayName: String; let role: String
    let pose: Pose; let trackingQuality: Float; let currentMarkID: ID?
}

struct Blocking: Codable {
    let id: ID; let title: String; let authorName: String
    let createdAt: Date; let modifiedAt: Date; let marks: [Mark]
    let origin: Pose; let reference: RecordedWalk?
}

struct RecordedWalk: Codable {
    let performerName: String; let samples: [Sample]; let duration: TimeInterval
    struct Sample: Codable { let t: TimeInterval; let pose: Pose }
}

enum NetMessage: Codable {
    case hello(Performer)
    case goodbye(ID)
    case performerUpdate(Performer)
    case blockingSnapshot(Blocking)
    case markAdded(Mark)
    case markUpdated(Mark)
    case markRemoved(ID)
    case cueFired(markID: ID, cueID: ID, by: ID)
    case playbackState(t: Double?)
}

struct Envelope: Codable {
    let version: Int
    let senderID: ID
    let message: NetMessage
}

let outDir = CommandLine.arguments.dropFirst().first ?? "."
let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601

func write(_ name: String, _ encodable: Encodable) throws {
    let data = try encoder.encode(AnyEncodable(encodable))
    try data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print(name, "→", String(data: data, encoding: .utf8) ?? "")
}

struct AnyEncodable: Encodable {
    let wrapped: Encodable
    init(_ w: Encodable) { wrapped = w }
    func encode(to encoder: Encoder) throws { try wrapped.encode(to: encoder) }
}

let id1 = ID(raw: "11111111-1111")
let id2 = ID(raw: "22222222-2222")
let id3 = ID(raw: "33333333-3333")
let pose = Pose(x: 1, y: 0, z: -2, yaw: 0.5)
let d = Date(timeIntervalSince1970: 1_800_000_000)

let perf = Performer(
    id: id1, displayName: "Alex", role: "performer",
    pose: pose, trackingQuality: 1.0, currentMarkID: nil
)
let cues: [Cue] = [
    .line(id: id2, text: "Something is rotten", character: "MARCELLUS"),
    .sfx(id: id2, name: "thunder"),
    .light(id: id2, color: .amber, intensity: 0.8),
    .note(id: id2, text: "beat here"),
    .wait(id: id2, seconds: 1.5),
]
let mark = Mark(id: id2, name: "Mark 1", pose: pose, radius: 0.6, cues: cues, sequenceIndex: 0)
let blocking = Blocking(
    id: id3, title: "Scene 1", authorName: "Alex",
    createdAt: d, modifiedAt: d, marks: [mark], origin: Pose(x: 0, y: 0, z: 0, yaw: 0),
    reference: nil
)

// Per-cue fixtures
try write("cue-line.json",  cues[0])
try write("cue-sfx.json",   cues[1])
try write("cue-light.json", cues[2])
try write("cue-note.json",  cues[3])
try write("cue-wait.json",  cues[4])
// line with nil character — verifies key omission
try write("cue-line-nochar.json", Cue.line(id: id2, text: "Solo", character: nil))

// NetMessage fixtures — wrapped in Envelope since that's what hits the wire
func env(_ m: NetMessage) -> Envelope { Envelope(version: 1, senderID: id1, message: m) }
try write("netmsg-hello.json",             env(.hello(perf)))
try write("netmsg-goodbye.json",           env(.goodbye(id1)))
try write("netmsg-performerUpdate.json",   env(.performerUpdate(perf)))
try write("netmsg-blockingSnapshot.json",  env(.blockingSnapshot(blocking)))
try write("netmsg-markAdded.json",         env(.markAdded(mark)))
try write("netmsg-markUpdated.json",       env(.markUpdated(mark)))
try write("netmsg-markRemoved.json",       env(.markRemoved(id2)))
try write("netmsg-cueFired.json",          env(.cueFired(markID: id2, cueID: id2, by: id1)))
try write("netmsg-playbackState-t.json",   env(.playbackState(t: 0.42)))
try write("netmsg-playbackState-nil.json", env(.playbackState(t: nil)))
