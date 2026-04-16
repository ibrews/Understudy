//
//  MultipeerTransport.swift
//  Understudy
//
//  MultipeerConnectivity implementation of `Transport`. Devices on the same
//  LAN / Bluetooth auto-advertise and browse for the same `roomCode` service.
//

import Foundation
import MultipeerConnectivity

public final class MultipeerTransport: NSObject, Transport {
    public var onMessage: ((Envelope) -> Void)?
    public var onPeerCountChanged: ((Int) -> Void)?

    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var peerID: MCPeerID?
    private var localID: ID = ID()
    // MPC service type: 1-15 chars, lowercase alphanumeric + hyphen, no leading/trailing hyphen.
    // Room code is appended as discovery-info so service type stays stable.
    private let serviceType = "und-stage"
    private var roomCode: String = "default"

    public func start(roomCode: String, localID: ID, displayName: String) {
        self.localID = localID
        self.roomCode = roomCode.lowercased()
        let peer = MCPeerID(displayName: displayName)
        self.peerID = peer
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let adv = MCNearbyServiceAdvertiser(
            peer: peer,
            discoveryInfo: ["room": self.roomCode],
            serviceType: serviceType
        )
        adv.delegate = self
        adv.startAdvertisingPeer()
        self.advertiser = adv

        let brw = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        brw.delegate = self
        brw.startBrowsingForPeers()
        self.browser = brw
    }

    public func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
    }

    public func send(_ message: NetMessage, from senderID: ID) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        let envelope = Envelope(senderID: senderID, message: message)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func notifyCount() {
        let count = session?.connectedPeers.count ?? 0
        onPeerCountChanged?(count)
    }
}

extension MultipeerTransport: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        notifyCount()
    }
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data) else { return }
        guard env.version == Envelope.currentVersion else { return } // drop mismatched
        onMessage?(env)
    }
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Only invite peers in the same room.
        guard (info?["room"] ?? "default") == roomCode, let session else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        notifyCount()
    }
}
