package agilelens.understudy.cuefx

import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

/**
 * Streaming ACN (sACN / ANSI E1.31-2018) sender over UDP.
 *
 * Kotlin port of Swift's DMXOutput.swift. Hand-rolls the same E1.31 packet;
 * uses [DatagramSocket] for both multicast and unicast — no need for
 * [java.net.MulticastSocket] since we're only sending, not receiving.
 *
 * Call [configure] once from the settings screen, then [send] on every
 * `.light` cue. All networking happens on the calling thread's coroutine
 * context — callers should dispatch from an IO dispatcher.
 *
 * Packet layout matches DMXOutput.swift exactly (see that file for field
 * offsets and E1.31 spec references).
 */
class DMXOutput {

    companion object {
        const val SACN_PORT = 5568

        /** E1.31 multicast address: 239.255.{hi}.{lo}. */
        fun multicastAddress(universe: Int): String {
            val hi = (universe shr 8) and 0xFF
            val lo = universe and 0xFF
            return "239.255.$hi.$lo"
        }
    }

    /** Human-readable source name embedded in the sACN packet (max 63 bytes). */
    var sourceName: String = "Understudy"

    /** sACN source priority (0..200; default 100 per spec). */
    var priority: Byte = 100

    var enabled: Boolean = false
        private set

    private var universe: Int = 1
    private var destinationIp: String = multicastAddress(1) // re-derived on configure

    private val cid: ByteArray = UUID.randomUUID().let { u ->
        val bb = java.nio.ByteBuffer.allocate(16)
        bb.putLong(u.mostSignificantBits)
        bb.putLong(u.leastSignificantBits)
        bb.array()
    }

    // Wraps 0..255. AtomicInteger for thread safety even though we expect
    // single-threaded callers in practice.
    private val sequenceNumber = AtomicInteger(0)
    private var socket: DatagramSocket? = null

    /** Call from the settings screen whenever DMX prefs change. */
    fun configure(universe: Int, destinationIp: String?, enabled: Boolean) {
        this.universe = universe.coerceIn(1, 63999)
        this.destinationIp = destinationIp?.takeIf { it.isNotBlank() }
            ?: multicastAddress(this.universe)
        this.enabled = enabled
        if (!enabled) {
            socket?.close()
            socket = null
        }
    }

    /**
     * Send a full 512-slot DMX frame. Channels beyond 512 are ignored; shorter
     * arrays are zero-padded. Does nothing if [enabled] is false.
     */
    fun send(channels: ByteArray) {
        if (!enabled) return
        val slots = when {
            channels.size >= 512 -> channels.copyOf(512)
            else -> channels.copyOf(512) // copyOf pads with zeros
        }
        val seq = (sequenceNumber.getAndIncrement() and 0xFF).toByte()
        val packet = encode(
            cid = cid,
            sourceName = sourceName,
            priority = priority,
            sequenceNumber = seq,
            universe = universe.toShort(),
            slots = slots,
        )
        try {
            val sock = socket ?: DatagramSocket().also { socket = it }
            val addr = InetAddress.getByName(destinationIp)
            sock.send(DatagramPacket(packet, packet.size, addr, SACN_PORT))
        } catch (_: Exception) {
            // sACN is fire-and-forget UDP; ignore individual send errors.
        }
    }

    // ── Encoder (pure, testable) ───────────────────────────────────────────

    /**
     * Build one sACN E1.31 data packet. Mirrors Swift's DMXOutput.encode(...)
     * byte-for-byte; see that function for field documentation.
     */
    fun encode(
        cid: ByteArray,
        sourceName: String,
        priority: Byte,
        sequenceNumber: Byte,
        universe: Short,
        slots: ByteArray,
    ): ByteArray {
        require(cid.size == 16) { "CID must be 16 bytes" }
        require(slots.size <= 512) { "DMX universe is 512 slots max" }

        val slotCount = slots.size
        val propValueCount = (slotCount + 1).toShort()          // +1 for start code
        val dmpLen = (10 + slotCount).toShort()
        val framingLen = (77 + dmpLen).toShort()
        val rootPDULen = (22 + framingLen).toShort()

        fun flagsLen(len: Short): Short = (0x7000 or (len.toInt() and 0x0FFF)).toShort()

        val out = java.io.ByteArrayOutputStream(38 + 77 + 10 + slotCount)
        fun putU16(v: Short) { out.write((v.toInt() ushr 8) and 0xFF); out.write(v.toInt() and 0xFF) }
        fun putU32(v: Int) {
            out.write((v ushr 24) and 0xFF); out.write((v ushr 16) and 0xFF)
            out.write((v ushr 8) and 0xFF); out.write(v and 0xFF)
        }

        // Root Layer
        putU16(0x0010)                                      // Preamble Size
        putU16(0x0000)                                      // Post-amble Size
        out.write(byteArrayOf(0x41,0x53,0x43,0x2d,0x45,0x31,0x2e,0x31,0x37,0x00,0x00,0x00)) // ACN PID
        putU16(flagsLen(rootPDULen))
        putU32(0x00000004)                                  // VECTOR_ROOT_E131_DATA
        out.write(cid)                                      // 16-byte CID

        // E1.31 Framing Layer
        putU16(flagsLen(framingLen))
        putU32(0x00000002)                                  // VECTOR_E131_DATA_PACKET
        out.write(paddedSourceName(sourceName))             // 64 bytes
        out.write(priority.toInt() and 0xFF)                // priority
        putU16(0)                                           // Sync Universe (none)
        out.write(sequenceNumber.toInt() and 0xFF)          // sequence
        out.write(0)                                        // options
        putU16(universe)                                    // universe number

        // DMP Layer
        putU16(flagsLen(dmpLen))
        out.write(0x02)                                     // VECTOR_DMP_SET_PROPERTY
        out.write(0xa1)                                     // Address+Data Type
        putU16(0x0000)                                      // First Property Address
        putU16(0x0001)                                      // Address Increment
        putU16(propValueCount)                              // Property Value Count
        out.write(0x00)                                     // DMX null start code
        out.write(slots)                                    // slot data

        return out.toByteArray()
    }

    private fun paddedSourceName(s: String): ByteArray {
        val bytes = s.toByteArray(Charsets.UTF_8).copyOf(63)
        return ByteArray(64).also { buf -> bytes.copyInto(buf) }
    }
}
