import Foundation
import Network

/// Advertises this device's multiplayer session via Bonjour and streams
/// monitoring events to any connected observers (e.g., Mission Control).
///
/// Game apps create a broadcaster when entering a SharePlay session and
/// forward game events to it. Observers discover the service automatically
/// and connect to receive a real-time event stream.
///
/// Usage:
/// ```swift
/// let broadcaster = MonitoringBroadcaster(
///     gameType: "laserTag",
///     sessionID: session.id.uuidString,
///     deviceName: UIDevice.current.name,
///     platform: "iOS"
/// )
/// broadcaster.start()
///
/// // Forward events as they happen:
/// broadcaster.send(.poseUpdate(MonitoringPoseUpdate(...)))
/// ```
public final class MonitoringBroadcaster: Sendable {
    private let listener: NWListener
    private let gameType: String
    private let sessionID: String
    private let deviceID: String
    private let deviceName: String
    private let platform: String
    private let encoder = JSONEncoder()

    nonisolated(unsafe) private var connections: [NWConnection] = []
    nonisolated(unsafe) private var _isRunning = false

    private let lock = NSLock()

    public var isRunning: Bool {
        lock.withLock { _isRunning }
    }

    public init(
        gameType: String,
        sessionID: String,
        deviceName: String,
        platform: String,
        deviceID: String = UUID().uuidString
    ) {
        self.gameType = gameType
        self.sessionID = sessionID
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.platform = platform

        let params = NWParameters.tcp
        params.includePeerToPeer = true
        self.listener = try! NWListener(using: params)

        // Bonjour advertisement with metadata in TXT record
        var txtRecord = NWTXTRecord()
        txtRecord[MonitoringConstants.TXTKey.gameType] = gameType
        txtRecord[MonitoringConstants.TXTKey.sessionID] = sessionID
        txtRecord[MonitoringConstants.TXTKey.platform] = platform
        txtRecord[MonitoringConstants.TXTKey.playerName] = deviceName
        let serviceName = "\(deviceName)-\(gameType)"
        listener.service = NWListener.Service(
            name: serviceName,
            type: MonitoringConstants.serviceType,
            txtRecord: txtRecord
        )
    }

    public func start() {
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let port = self?.listener.port {
                    print("[MonitoringBroadcaster] Advertising on port \(port)")
                }
            case .failed(let error):
                print("[MonitoringBroadcaster] Listener failed: \(error)")
            case .cancelled:
                print("[MonitoringBroadcaster] Listener cancelled")
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener.start(queue: .main)
        lock.withLock { _isRunning = true }
    }

    public func stop() {
        listener.cancel()
        lock.withLock {
            for conn in connections {
                conn.cancel()
            }
            connections.removeAll()
            _isRunning = false
        }
    }

    /// Send a monitoring event to all connected observers.
    public func send(_ event: MonitoringEvent) {
        let envelope = MonitoringEnvelope(
            gameType: gameType,
            sessionID: sessionID,
            sourceDeviceID: deviceID,
            sourceDeviceName: deviceName,
            sourcePlatform: platform,
            event: event
        )

        guard let jsonData = try? encoder.encode(envelope) else { return }

        // Length-prefixed framing: 4 bytes (UInt32 big-endian) + JSON payload
        var length = UInt32(jsonData.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(jsonData)

        lock.withLock {
            for connection in connections {
                connection.send(content: frame, completion: .contentProcessed { error in
                    if let error {
                        print("[MonitoringBroadcaster] Send error: \(error)")
                    }
                })
            }
        }
    }

    /// Send a heartbeat to keep connections alive and signal presence.
    public func sendHeartbeat() {
        send(.heartbeat)
    }

    // MARK: - Private

    private func handleNewConnection(_ connection: NWConnection) {
        print("[MonitoringBroadcaster] Observer connected")
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[MonitoringBroadcaster] Observer connection ready")
            case .failed, .cancelled:
                self?.removeConnection(connection)
            default:
                break
            }
        }
        connection.start(queue: .main)
        lock.withLock { connections.append(connection) }
    }

    private func removeConnection(_ connection: NWConnection) {
        lock.withLock {
            connections.removeAll { $0 === connection }
        }
        connection.cancel()
        print("[MonitoringBroadcaster] Observer disconnected (\(lock.withLock { connections.count }) remaining)")
    }
}
