//
//  OSCBridge.swift
//  Understudy
//
//  One-way OSC sender over UDP. When a cue fires (or a performer enters a
//  mark), broadcast a structured OSC message so QLab, Max/MSP, TouchDesigner,
//  vvvv, Isadora, Ableton (via Max for Live), or any other OSC-listening tool
//  can react. This is what turns Understudy from a toy into something a
//  stage manager can actually run a show from.
//
//  Message schema (fires from the device hosting the director, or any iPhone
//  that has OSC broadcasting on):
//
//    /understudy/mark/enter <markName: String> <seqIndex: Int>
//    /understudy/cue/line <character: String> <text: String>
//    /understudy/cue/sfx <name: String>
//    /understudy/cue/light <color: String> <intensity: Float>
//    /understudy/cue/wait <seconds: Float>
//    /understudy/cue/note <text: String>
//
//  Plus a convenience for QLab users who want to trigger a specific cue list
//  number, configurable as an SFX-name → QLab number map (future work).
//
//  OSC 1.0 packet format:
//    - Address pattern: null-terminated ASCII, padded to 4-byte boundary
//    - Type tag string: starts with ',', then one char per arg ('s', 'i', 'f')
//    - Arguments in order, each zero-padded to 4-byte boundary
//
//  No bundles, no ints-as-time-tags, no OSC-over-TCP — just simple UDP
//  messages. ~80 lines including the encoder.
//

import Foundation
import Network

public final class OSCBridge: @unchecked Sendable {
    // MARK: - Configuration

    /// Destination host. nil disables the bridge.
    public var host: String?
    /// Destination port. Standard QLab OSC port is 53000.
    public var port: UInt16 = 53000
    /// Master enable flag. When false, `send(...)` no-ops immediately.
    public var enabled: Bool = false

    // MARK: - Connection

    /// Single reusable UDP connection. Recreated when host/port change.
    private var connection: NWConnection?
    private var currentEndpoint: (host: String, port: UInt16)?
    private let queue = DispatchQueue(label: "agilelens.understudy.osc")

    public init() {}

    public func configure(host: String?, port: UInt16, enabled: Bool) {
        self.host = host
        self.port = port
        self.enabled = enabled
        rebuildIfNeeded()
    }

    private func rebuildIfNeeded() {
        guard enabled, let host, !host.isEmpty else {
            connection?.cancel()
            connection = nil
            currentEndpoint = nil
            return
        }
        if currentEndpoint?.host == host, currentEndpoint?.port == port, connection != nil {
            return
        }
        connection?.cancel()
        let c = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port),
            using: .udp
        )
        c.start(queue: queue)
        connection = c
        currentEndpoint = (host, port)
    }

    // MARK: - Public API

    /// Mark entry — fires once per performer entry.
    public func sendMarkEnter(name: String, sequenceIndex: Int) {
        sendMessage(address: "/understudy/mark/enter",
                    args: [.string(name), .int(Int32(sequenceIndex))])
    }

    /// A cue fired by the engine. Translates each Cue case to an OSC message.
    public func sendCue(_ cue: Cue) {
        switch cue {
        case .line(_, let text, let character):
            sendMessage(address: "/understudy/cue/line",
                        args: [.string(character ?? ""), .string(text)])
        case .sfx(_, let name):
            sendMessage(address: "/understudy/cue/sfx", args: [.string(name)])
        case .light(_, let color, let intensity):
            sendMessage(address: "/understudy/cue/light",
                        args: [.string(color.rawValue), .float(intensity)])
        case .wait(_, let seconds):
            sendMessage(address: "/understudy/cue/wait", args: [.float(Float(seconds))])
        case .note(_, let text):
            sendMessage(address: "/understudy/cue/note", args: [.string(text)])
        }
    }

    // MARK: - Encoder

    public enum OSCValue {
        case string(String)
        case int(Int32)
        case float(Float)
    }

    /// Encode and send one OSC 1.0 message.
    public func sendMessage(address: String, args: [OSCValue]) {
        guard enabled else { return }
        rebuildIfNeeded()
        guard let connection else { return }
        let packet = Self.encode(address: address, args: args)
        connection.send(content: packet, completion: .contentProcessed { _ in
            // Best-effort — ignore errors. OSC over UDP is fire-and-forget.
        })
    }

    /// Pure encoder — exposed for testing and debugging.
    public static func encode(address: String, args: [OSCValue]) -> Data {
        var out = Data()
        out.append(paddedOSCString(address))
        var typeTag = ","
        for v in args {
            switch v {
            case .string: typeTag.append("s")
            case .int: typeTag.append("i")
            case .float: typeTag.append("f")
            }
        }
        out.append(paddedOSCString(typeTag))
        for v in args {
            switch v {
            case .string(let s):
                out.append(paddedOSCString(s))
            case .int(let i):
                var be = i.bigEndian
                withUnsafeBytes(of: &be) { out.append(contentsOf: $0) }
            case .float(let f):
                var be = f.bitPattern.bigEndian
                withUnsafeBytes(of: &be) { out.append(contentsOf: $0) }
            }
        }
        return out
    }

    private static func paddedOSCString(_ s: String) -> Data {
        var bytes = Array(s.utf8)
        bytes.append(0) // null terminator
        // Pad to 4-byte boundary.
        let padding = (4 - (bytes.count % 4)) % 4
        bytes.append(contentsOf: repeatElement(0, count: padding))
        return Data(bytes)
    }

}
