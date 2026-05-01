import Foundation

// MARK: - Monitoring Envelope

/// A self-contained monitoring message sent from game devices to passive observers.
/// Wraps game events with device/session metadata so observers don't need
/// to join SharePlay or know about GroupActivity internals.
public struct MonitoringEnvelope: Codable, Sendable {
    public let gameType: String      // "laserTag", "whoAmI", "sharedScanner"
    public let sessionID: String     // Groups devices in the same session
    public let sourceDeviceID: String
    public let sourceDeviceName: String
    public let sourcePlatform: String
    public let timestamp: TimeInterval
    public let event: MonitoringEvent

    public init(
        gameType: String,
        sessionID: String,
        sourceDeviceID: String,
        sourceDeviceName: String,
        sourcePlatform: String,
        event: MonitoringEvent
    ) {
        self.gameType = gameType
        self.sessionID = sessionID
        self.sourceDeviceID = sourceDeviceID
        self.sourceDeviceName = sourceDeviceName
        self.sourcePlatform = sourcePlatform
        self.timestamp = Date().timeIntervalSince1970
        self.event = event
    }
}

// MARK: - Event Types

public enum MonitoringEvent: Codable, Sendable {
    case poseUpdate(MonitoringPoseUpdate)
    case blast(MonitoringBlast)
    case scoreUpdate(MonitoringScoreUpdate)
    case hit(MonitoringHit)
    case playerJoined(MonitoringPlayerJoined)
    case playerLeft(MonitoringPlayerLeft)
    case gameState(MonitoringGameState)
    case confetti(MonitoringConfetti)
    case colorChange(MonitoringColorChange)
    case claim(MonitoringClaim)
    case shieldToggle(MonitoringShieldToggle)
    case meshChunk(MonitoringMeshChunk)
    case heartbeat
}

// MARK: - Event Payloads

public struct MonitoringPoseUpdate: Codable, Sendable {
    public let peerID: UUID
    public let x: Float
    public let y: Float
    public let z: Float
    public let yawAngle: Float
    public let colorComponents: [Float]?
    public let platform: String?
    public let displayName: String?
    public let isShielding: Bool?

    public init(peerID: UUID, x: Float, y: Float, z: Float, yawAngle: Float,
                colorComponents: [Float]? = nil, platform: String? = nil,
                displayName: String? = nil, isShielding: Bool? = nil) {
        self.peerID = peerID
        self.x = x; self.y = y; self.z = z
        self.yawAngle = yawAngle
        self.colorComponents = colorComponents
        self.platform = platform
        self.displayName = displayName
        self.isShielding = isShielding
    }
}

public struct MonitoringBlast: Codable, Sendable {
    public let ballID: UUID
    public let positionX: Float
    public let positionY: Float
    public let positionZ: Float
    public let directionX: Float
    public let directionY: Float
    public let directionZ: Float
    public let team: String // "red" or "blue"

    public init(ballID: UUID, position: SIMD3<Float>, direction: SIMD3<Float>, team: String) {
        self.ballID = ballID
        self.positionX = position.x; self.positionY = position.y; self.positionZ = position.z
        self.directionX = direction.x; self.directionY = direction.y; self.directionZ = direction.z
        self.team = team
    }
}

public struct MonitoringScoreUpdate: Codable, Sendable {
    public let redScore: Int
    public let blueScore: Int

    public init(redScore: Int, blueScore: Int) {
        self.redScore = redScore
        self.blueScore = blueScore
    }
}

public struct MonitoringHit: Codable, Sendable {
    public let ballID: UUID
    public let hitPositionX: Float
    public let hitPositionY: Float
    public let hitPositionZ: Float
    public let wasBlocked: Bool

    public init(ballID: UUID, hitPosition: SIMD3<Float>, wasBlocked: Bool) {
        self.ballID = ballID
        self.hitPositionX = hitPosition.x
        self.hitPositionY = hitPosition.y
        self.hitPositionZ = hitPosition.z
        self.wasBlocked = wasBlocked
    }
}

public struct MonitoringPlayerJoined: Codable, Sendable {
    public let peerID: UUID
    public let displayName: String
    public let colorHex: String?
    public let platform: String?
    public let team: String?

    public init(peerID: UUID, displayName: String, colorHex: String? = nil,
                platform: String? = nil, team: String? = nil) {
        self.peerID = peerID
        self.displayName = displayName
        self.colorHex = colorHex
        self.platform = platform
        self.team = team
    }
}

public struct MonitoringPlayerLeft: Codable, Sendable {
    public let peerID: UUID

    public init(peerID: UUID) {
        self.peerID = peerID
    }
}

public struct MonitoringGameState: Codable, Sendable {
    public let peerID: UUID
    public let name: String
    public let colorHex: String

    public init(peerID: UUID, name: String, colorHex: String) {
        self.peerID = peerID
        self.name = name
        self.colorHex = colorHex
    }
}

public struct MonitoringConfetti: Codable, Sendable {
    public let peerID: UUID

    public init(peerID: UUID) {
        self.peerID = peerID
    }
}

public struct MonitoringColorChange: Codable, Sendable {
    public let peerID: UUID
    public let colorHex: String

    public init(peerID: UUID, colorHex: String) {
        self.peerID = peerID
        self.colorHex = colorHex
    }
}

public struct MonitoringClaim: Codable, Sendable {
    public let peerID: UUID
    public let name: String
    public let colorHex: String

    public init(peerID: UUID, name: String, colorHex: String) {
        self.peerID = peerID
        self.name = name
        self.colorHex = colorHex
    }
}

public struct MonitoringShieldToggle: Codable, Sendable {
    public let peerID: UUID
    public let isActive: Bool

    public init(peerID: UUID, isActive: Bool) {
        self.peerID = peerID
        self.isActive = isActive
    }
}

/// A chunk of 3D mesh geometry from a device's ARKit scene reconstruction.
/// Uses binary-packed Data for vertices/indices (matching SharedScanner's approach)
/// for ~3x better bandwidth than JSON float arrays.
public struct MonitoringMeshChunk: Codable, Sendable {
    public let chunkID: UUID
    public let ownerID: UUID         // Which device sent this
    public let vertexData: Data      // Binary packed Float32: [x0,y0,z0, x1,y1,z1, ...]
    public let indexData: Data       // Binary packed UInt32: triangle indices
    public let vertexCount: Int
    public let indexCount: Int
    public let transform: [Float]    // 16-element column-major 4x4 transform
    public let classification: String?

    public init(chunkID: UUID, ownerID: UUID, vertices: [Float], indices: [UInt32],
                transform: [Float], classification: String? = nil) {
        self.chunkID = chunkID
        self.ownerID = ownerID
        self.vertexData = vertices.withUnsafeBufferPointer { Data(buffer: $0) }
        self.indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        self.vertexCount = vertices.count / 3
        self.indexCount = indices.count
        self.transform = transform
        self.classification = classification
    }

    /// Unpack binary vertex data to flat Float array.
    public func unpackVertices() -> [Float] {
        vertexData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    /// Unpack binary index data to UInt32 array.
    public func unpackIndices() -> [UInt32] {
        indexData.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }
    }
}

// MARK: - Service Constants

public enum MonitoringConstants {
    /// Bonjour service type for AgileLens monitoring.
    public static let serviceType = "_agilelens-mon._tcp"

    /// TXT record keys used in Bonjour advertisement.
    public enum TXTKey {
        public static let gameType = "game"
        public static let sessionID = "session"
        public static let platform = "platform"
        public static let playerName = "player"
    }
}
