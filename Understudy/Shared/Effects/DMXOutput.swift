//
//  DMXOutput.swift
//  Understudy
//
//  Streaming ACN (sACN / ANSI E1.31) sender over UDP. Parallel to OSCBridge —
//  when a performer steps on a mark, the same light cue that goes out as OSC
//  can also push DMX512 values to the lighting network so a real par can or
//  moving head actually responds. No third-party deps; we hand-roll the
//  E1.31 packet the same way OSCBridge hand-rolls OSC.
//
//  Packet layout (E1.31 2018):
//    Root Layer (38 bytes):
//      0x0010  Preamble Size (UInt16 BE)            = 0x0010
//      0x0000  Post-amble Size (UInt16 BE)          = 0x0000
//      "ASC-E1.17\0\0\0"  (12 bytes, null-padded)   ACN Packet Identifier
//      UInt16 BE  Flags+Length (0x7 in top nibble + total-len-from-offset-16)
//      UInt32 BE  Vector                            = 0x00000004 (VECTOR_ROOT_E131_DATA)
//      16 bytes   CID (UUID)
//
//    E1.31 Framing Layer (77 bytes):
//      UInt16 BE  Flags+Length (0x7 + frame-len-from-offset-38)
//      UInt32 BE  Vector                            = 0x00000002 (VECTOR_E131_DATA_PACKET)
//      64 bytes   Source Name (UTF-8, null-padded)
//      UInt8      Priority                          = 100 (default)
//      UInt16 BE  Synchronization Universe          = 0
//      UInt8      Sequence Number (wraps 0..255)
//      UInt8      Options                           = 0
//      UInt16 BE  Universe                          = 1..63999
//
//    DMP Layer (10 + slot-count bytes):
//      UInt16 BE  Flags+Length (0x7 + dmp-len-from-offset-115)
//      UInt8      Vector                            = 0x02 (VECTOR_DMP_SET_PROPERTY)
//      UInt8      Address Type & Data Type          = 0xa1
//      UInt16 BE  First Property Address            = 0x0000
//      UInt16 BE  Address Increment                 = 0x0001
//      UInt16 BE  Property Value Count              = slot_count + 1 (+1 for DMX start code)
//      UInt8      DMX Start Code                    = 0x00 (null start)
//      N bytes    DMX slot values                   (up to 512)
//
//  Multicast destination: port 5568 (0x15C4), address
//  239.255.{universe>>8}.{universe&0xFF}. Unicast destination: any host.
//

import Foundation
import Network

/// Where to send sACN packets.
public enum DMXDestination: Equatable, Sendable {
    /// Standard E1.31 multicast: 239.255.x.y derived from the universe number.
    case multicast
    /// Point-to-point to a specific node (e.g. a USB-DMX gateway running
    /// sACN-to-DMX, or a lighting desk with a hard-coded IP).
    case unicast(ip: String)
}

public final class DMXOutput: @unchecked Sendable {
    // MARK: - Tunables (public so callers can override before configure)

    /// Human-readable source name, shown in lighting consoles that inspect
    /// sACN streams. Clamped to 63 UTF-8 bytes.
    public var sourceName: String = "Understudy"

    /// sACN priority byte (0..200). Default 100 per spec. Higher priority
    /// sources override lower ones when multiple transmitters share a
    /// universe.
    public var priority: UInt8 = 100

    /// Standard sACN UDP port.
    public static let port: UInt16 = 5568

    // MARK: - State

    private var universe: UInt16 = 1
    private var destination: DMXDestination = .multicast
    private(set) public var enabled: Bool = false

    /// One reusable UDP connection. Rebuilt when universe / destination /
    /// enabled flag changes.
    private var connection: NWConnection?
    private var currentKey: String?
    private let queue = DispatchQueue(label: "agilelens.understudy.dmx")

    /// E1.31 Component Identifier. Generated once per process launch; a
    /// stable CID per source is good hygiene (consoles dedupe on it) but
    /// regenerating per launch is within spec. Foundation's `UUID()` is
    /// already a v4 random — use it directly so we don't have to pull in
    /// Security.framework for `SecRandomCopyBytes`.
    private let cid: [UInt8] = {
        let u = UUID().uuid
        return [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
                u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
    }()

    /// Rolling sequence number (0..255). Consoles use this to detect
    /// packet loss / reorder.
    private var sequenceNumber: UInt8 = 0

    public init() {}

    // MARK: - Configuration

    /// Reconfigure output. Clamps universe into the legal 1..63999 range.
    /// Cheap to call; rebuilds the UDP connection only when the endpoint
    /// actually changes.
    public func configure(universe: Int, destination: DMXDestination, enabled: Bool) {
        let clamped = UInt16(max(1, min(63999, universe)))
        self.universe = clamped
        self.destination = destination
        self.enabled = enabled
        rebuildIfNeeded()
    }

    private func endpointKey(for dest: DMXDestination, universe: UInt16) -> String {
        switch dest {
        case .multicast:
            return "mc:\(multicastHost(for: universe))"
        case .unicast(let ip):
            return "uc:\(ip)"
        }
    }

    /// E1.31 multicast address: 239.255.{hi}.{lo} where hi/lo are the two
    /// bytes of the universe number.
    public static func multicastAddress(for universe: UInt16) -> String {
        let hi = (universe >> 8) & 0xFF
        let lo = universe & 0xFF
        return "239.255.\(hi).\(lo)"
    }

    private func multicastHost(for universe: UInt16) -> String {
        Self.multicastAddress(for: universe)
    }

    private func rebuildIfNeeded() {
        guard enabled else {
            connection?.cancel()
            connection = nil
            currentKey = nil
            return
        }
        let key = endpointKey(for: destination, universe: universe)
        if currentKey == key, connection != nil {
            return
        }
        connection?.cancel()

        let host: NWEndpoint.Host
        switch destination {
        case .multicast:
            host = NWEndpoint.Host(multicastHost(for: universe))
        case .unicast(let ip):
            host = NWEndpoint.Host(ip)
        }
        let c = NWConnection(
            host: host,
            port: NWEndpoint.Port(integerLiteral: Self.port),
            using: .udp
        )
        c.start(queue: queue)
        connection = c
        currentKey = key
    }

    // MARK: - Send

    /// Send a full DMX frame. Channels beyond index 511 are ignored; the
    /// frame is zero-padded up to 512 slots if shorter. Sending 512 each
    /// time keeps moving heads that park on high channel numbers happy
    /// and matches how most consoles stream.
    public func send(channels: [UInt8]) {
        guard enabled else { return }
        rebuildIfNeeded()
        guard let connection else { return }

        var slots = channels
        if slots.count > 512 { slots = Array(slots.prefix(512)) }
        if slots.count < 512 { slots.append(contentsOf: repeatElement(0, count: 512 - slots.count)) }

        sequenceNumber = sequenceNumber &+ 1
        let packet = Self.encode(
            cid: cid,
            sourceName: sourceName,
            priority: priority,
            sequenceNumber: sequenceNumber,
            universe: universe,
            slots: slots
        )
        connection.send(content: packet, completion: .contentProcessed { _ in
            // Fire-and-forget — sACN is a streaming UDP protocol, any loss
            // is papered over by the next frame.
        })
    }

    // MARK: - Encoder (pure, testable)

    /// Build one sACN E1.31 data packet. Exposed for testing — if you want
    /// to `hexdump` it side-by-side with a Wireshark capture, this is the
    /// one to call.
    public static func encode(
        cid: [UInt8],
        sourceName: String,
        priority: UInt8,
        sequenceNumber: UInt8,
        universe: UInt16,
        slots: [UInt8]
    ) -> Data {
        precondition(cid.count == 16, "CID must be 16 bytes")
        precondition(slots.count <= 512, "DMX universe is 512 slots max")

        let slotCount = slots.count
        let propertyValueCount = UInt16(slotCount + 1) // +1 for the start code byte
        let dmpLayerLength = UInt16(10 + slotCount)    // DMP header = 10 bytes
        let framingLayerLength = UInt16(77 + Int(dmpLayerLength)) // framing header = 77 bytes
        let rootLayerPDULength = UInt16(22 + Int(framingLayerLength)) // root PDU portion

        // PDU flags+length fields: top nibble always 0x7, low 12 bits = length.
        func flagsAndLength(_ length: UInt16) -> UInt16 {
            return 0x7000 | (length & 0x0FFF)
        }

        var out = Data()
        out.reserveCapacity(38 + 77 + 10 + slotCount)

        // --- Root Layer ---
        out.appendUInt16BE(0x0010)                  // Preamble Size
        out.appendUInt16BE(0x0000)                  // Post-amble Size
        // ACN Packet Identifier: "ASC-E1.17" followed by three null bytes.
        let pid: [UInt8] = [0x41, 0x53, 0x43, 0x2d, 0x45, 0x31, 0x2e, 0x31, 0x37, 0x00, 0x00, 0x00]
        out.append(contentsOf: pid)
        out.appendUInt16BE(flagsAndLength(rootLayerPDULength))
        out.appendUInt32BE(0x0000_0004)             // VECTOR_ROOT_E131_DATA
        out.append(contentsOf: cid)                 // 16-byte CID

        // --- E1.31 Framing Layer ---
        out.appendUInt16BE(flagsAndLength(framingLayerLength))
        out.appendUInt32BE(0x0000_0002)             // VECTOR_E131_DATA_PACKET
        out.append(paddedSourceName(sourceName))    // 64 bytes
        out.append(priority)                        // priority (default 100)
        out.appendUInt16BE(0)                       // Synchronization Universe (0 = none)
        out.append(sequenceNumber)                  // sequence
        out.append(0)                               // options byte
        out.appendUInt16BE(universe)                // universe

        // --- DMP Layer ---
        out.appendUInt16BE(flagsAndLength(dmpLayerLength))
        out.append(0x02)                            // VECTOR_DMP_SET_PROPERTY
        out.append(0xa1)                            // Address+Data Type
        out.appendUInt16BE(0x0000)                  // First Property Address
        out.appendUInt16BE(0x0001)                  // Address Increment
        out.appendUInt16BE(propertyValueCount)      // slots + 1
        out.append(0x00)                            // DMX null start code
        out.append(contentsOf: slots)               // slot data (≤ 512 bytes)

        return out
    }

    /// Source Name must be a 64-byte null-padded UTF-8 field.
    private static func paddedSourceName(_ s: String) -> Data {
        var bytes = Array(s.utf8.prefix(63))        // leave at least one null
        while bytes.count < 64 { bytes.append(0) }
        return Data(bytes)
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func appendUInt16BE(_ v: UInt16) {
        var be = v.bigEndian
        // Qualify the free-function form — inside a `Data` extension, plain
        // `withUnsafeBytes` would resolve to `Data.withUnsafeBytes`.
        Swift.withUnsafeBytes(of: &be) { self.append(contentsOf: $0) }
    }
    mutating func appendUInt32BE(_ v: UInt32) {
        var be = v.bigEndian
        Swift.withUnsafeBytes(of: &be) { self.append(contentsOf: $0) }
    }
}
