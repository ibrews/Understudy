//
//  OSCReceiver.swift
//  Understudy
//
//  The INBOUND half of the OSC bridge. Listens for UDP OSC 1.0 messages
//  on a configurable port and dispatches them to a handler closure. Used
//  for stage-manager / show-control integrations: QLab (or TouchDesigner,
//  Max, etc.) sends `/understudy/go` and Understudy advances the cue stack.
//
//  Minimal OSC parser — just enough to read our own outbound shape back:
//    - address pattern (null-terminated ASCII, 4-byte boundary)
//    - type tag string (leading ','; chars 's', 'i', 'f', 'T', 'F')
//    - arguments aligned to 4-byte boundaries
//
//  No bundles, no blobs, no OSC-over-TCP. Errors are swallowed silently
//  because UDP packets can be garbage and we don't want to die.
//
//  Addresses we understand:
//    /understudy/go                 — advance one step in the cue stack
//    /understudy/next               — alias for /go
//    /understudy/back               — go back one step
//    /understudy/mark/<index: int>  — jump to mark with that sequence index
//    /understudy/reset              — reset cue cursor to the first mark
//
//  Handler is called on MainActor so it can mutate the observable store.
//

import Foundation
import Network

@MainActor
public final class OSCReceiver {

    /// Message received from the network. Parsed but not yet routed.
    public struct Message: Sendable {
        public let address: String
        public let args: [Argument]

        public enum Argument: Sendable {
            case int(Int32)
            case float(Float)
            case string(String)
            case bool(Bool)
        }

        public var firstInt: Int32? {
            for a in args { if case .int(let v) = a { return v } }
            return nil
        }
        public var firstString: String? {
            for a in args { if case .string(let v) = a { return v } }
            return nil
        }
    }

    public var onMessage: ((Message) -> Void)?
    /// Called on MainActor when `start(port:)` fails (most likely: port in use).
    public var onBindError: ((Error) -> Void)?
    public private(set) var isRunning: Bool = false
    public private(set) var port: UInt16 = 53001

    private var listener: NWListener?

    public init() {}

    /// Start listening on the given port. Idempotent — if we're already
    /// bound to that port, no-op. If the port is different, rebind.
    public func start(port: UInt16) {
        if isRunning && self.port == port { return }
        stop()
        self.port = port
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))
            l.newConnectionHandler = { [weak self] conn in
                Task { @MainActor in self?.handle(connection: conn) }
            }
            l.start(queue: .main)
            self.listener = l
            self.isRunning = true
        } catch {
            self.isRunning = false
            onBindError?(error)
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .main)
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        // Each UDP datagram = one OSC message. We keep the connection open
        // and loop.
        connection.receiveMessage { [weak self] data, _, _, error in
            Task { @MainActor in
                guard let self else { return }
                if let data, let msg = Self.parse(data) {
                    self.onMessage?(msg)
                }
                if error == nil {
                    self.receive(on: connection)
                }
            }
        }
    }

    // MARK: - OSC 1.0 parsing

    /// Parse one OSC message. Returns nil if the packet is malformed.
    public static func parse(_ data: Data) -> Message? {
        guard let (address, afterAddr) = readOSCString(data, at: 0) else { return nil }
        guard let (typeTag, afterTypes) = readOSCString(data, at: afterAddr) else {
            // No type tag is technically valid OSC (args-less) but we
            // treat as empty.
            return Message(address: address, args: [])
        }
        guard typeTag.first == "," else {
            return Message(address: address, args: [])
        }
        let types = typeTag.dropFirst()
        var cursor = afterTypes
        var args: [Message.Argument] = []
        for t in types {
            switch t {
            case "s":
                guard let (s, next) = readOSCString(data, at: cursor) else { return nil }
                args.append(.string(s))
                cursor = next
            case "i":
                guard cursor + 4 <= data.count else { return nil }
                let be: UInt32 = data.withUnsafeBytes { raw in
                    raw.load(fromByteOffset: cursor, as: UInt32.self)
                }
                let hostOrder = Int32(bitPattern: UInt32(bigEndian: be))
                args.append(.int(hostOrder))
                cursor += 4
            case "f":
                guard cursor + 4 <= data.count else { return nil }
                let beBits: UInt32 = data.withUnsafeBytes { raw in
                    raw.load(fromByteOffset: cursor, as: UInt32.self)
                }
                let value = Float(bitPattern: UInt32(bigEndian: beBits))
                args.append(.float(value))
                cursor += 4
            case "T":
                args.append(.bool(true))
            case "F":
                args.append(.bool(false))
            default:
                // Unknown type — skip the rest since we can't know sizes.
                break
            }
        }
        return Message(address: address, args: args)
    }

    /// Read a null-terminated OSC string aligned to 4-byte boundary.
    /// Returns (string, cursor-after-padding) or nil if malformed.
    private static func readOSCString(_ data: Data, at start: Int) -> (String, Int)? {
        guard start < data.count else { return nil }
        var end = start
        while end < data.count, data[end] != 0 { end += 1 }
        guard end < data.count else { return nil } // no null
        let string = String(data: data[start..<end], encoding: .utf8) ?? ""
        // Pad so (end+1 - start) is multiple of 4.
        let contentLength = end - start + 1 // include null
        let padding = (4 - (contentLength % 4)) % 4
        return (string, end + 1 + padding)
    }
}
