//
//  AppMode.swift
//  Understudy
//
//  Local UI mode — separate from `Performer.Role` which is the wire-level identity.
//  One device can flip between perform / author / audience without changing what
//  the network sees. Director mode is visionOS-only and implied by the platform.
//

import Foundation

public enum AppMode: String, CaseIterable, Codable, Sendable {
    /// Walk a blocking. Teleprompter + cue firing. No editing.
    case perform
    /// Build a blocking. Tap the AR floor to drop marks, tap a mark to edit.
    case author
    /// Self-paced tour: play back the reference walk with cues, hands-free.
    /// Site-specific theater as a finished product — the audience is the performer.
    case audience

    public var displayName: String {
        switch self {
        case .perform: return "Perform"
        case .author: return "Author"
        case .audience: return "Audience"
        }
    }

    public var tagline: String {
        switch self {
        case .perform: return "Walk the blocking. See cues as you arrive."
        case .author:  return "Build the blocking. Drop marks where you stand."
        case .audience: return "Take the tour. The show finds you."
        }
    }

    public var systemImage: String {
        switch self {
        case .perform: return "figure.walk"
        case .author: return "mappin.and.ellipse"
        case .audience: return "ear.and.waveform"
        }
    }

    /// Wire-level role for this mode.
    public var role: Performer.Role {
        switch self {
        case .perform: return .performer
        case .author: return .performer    // same pose updates, extra powers locally
        case .audience: return .observer   // still tracked, but doesn't affect cueing
        }
    }
}
