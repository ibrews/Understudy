//
//  DemoBlockings.swift
//  Understudy
//
//  Seed content so the first launch isn't a blank stage. One real scene
//  from Hamlet Act 1 Scene 1 — Bernardo, Francisco, Horatio on the
//  battlements of Elsinore — arranged as a small 5-mark walk that fits
//  in a living room (positions within ~3m × 3m).
//

import Foundation

public enum DemoBlockings {
    /// Elsinore battlements, 1am. Bernardo relieves Francisco; Horatio arrives.
    /// Abridged. Fits a ~3m × 3m rehearsal space.
    public static var hamletOpening: Blocking {
        var b = Blocking(
            id: ID("demo-hamlet-opening"),
            title: "Hamlet — Elsinore Battlements",
            authorName: "William Shakespeare (arr.)",
            origin: Pose()
        )
        b.authorName = "William Shakespeare (arr.)"

        // 1. Francisco on watch, upstage center.
        b.marks.append(Mark(
            id: ID("demo-mark-1"),
            name: "Francisco's Post",
            pose: Pose(x: 0, y: 0, z: -2.0, yaw: 0),
            radius: 0.7,
            cues: [
                .note(id: ID(), text: "Dead of night. Cold."),
                .light(id: ID(), color: .cool, intensity: 0.4),
                .wait(id: ID(), seconds: 2.0),
                .line(id: ID(), text: "You come most carefully upon your hour.",
                      character: "FRANCISCO"),
            ],
            sequenceIndex: 0
        ))

        // 2. Bernardo enters from downstage left.
        b.marks.append(Mark(
            id: ID("demo-mark-2"),
            name: "Bernardo Enters",
            pose: Pose(x: -1.5, y: 0, z: -0.5, yaw: 0),
            radius: 0.6,
            cues: [
                .sfx(id: ID(), name: "knock"),
                .line(id: ID(), text: "'Tis now struck twelve. Get thee to bed, Francisco.",
                      character: "BERNARDO"),
                .line(id: ID(), text: "For this relief much thanks. 'Tis bitter cold, and I am sick at heart.",
                      character: "FRANCISCO"),
            ],
            sequenceIndex: 1
        ))

        // 3. Center stage — the changing of the guard.
        b.marks.append(Mark(
            id: ID("demo-mark-3"),
            name: "Center",
            pose: Pose(x: 0, y: 0, z: 0, yaw: 0),
            radius: 0.6,
            cues: [
                .wait(id: ID(), seconds: 1.0),
                .line(id: ID(), text: "Have you had quiet guard?",
                      character: "BERNARDO"),
                .line(id: ID(), text: "Not a mouse stirring.",
                      character: "FRANCISCO"),
            ],
            sequenceIndex: 2
        ))

        // 4. Downstage right — Horatio and Marcellus approach.
        b.marks.append(Mark(
            id: ID("demo-mark-4"),
            name: "Horatio Arrives",
            pose: Pose(x: 1.6, y: 0, z: 0.6, yaw: 0),
            radius: 0.6,
            cues: [
                .sfx(id: ID(), name: "bell"),
                .line(id: ID(), text: "Friends to this ground.",
                      character: "HORATIO"),
                .line(id: ID(), text: "And liegemen to the Dane.",
                      character: "MARCELLUS"),
                .note(id: ID(), text: "Scholar + soldier. Tension."),
            ],
            sequenceIndex: 3
        ))

        // 5. The ghost appears, upstage right — the scene turns.
        b.marks.append(Mark(
            id: ID("demo-mark-5"),
            name: "The Ghost",
            pose: Pose(x: 1.2, y: 0, z: -1.8, yaw: 0),
            radius: 0.7,
            cues: [
                .light(id: ID(), color: .blue, intensity: 0.9),
                .sfx(id: ID(), name: "thunder"),
                .wait(id: ID(), seconds: 1.5),
                .line(id: ID(), text: "Look, where it comes again.",
                      character: "BERNARDO"),
                .line(id: ID(), text: "In the same figure, like the king that's dead.",
                      character: "HORATIO"),
                .line(id: ID(), text: "Speak to it, Horatio.",
                      character: "MARCELLUS"),
                .wait(id: ID(), seconds: 2.0),
                .light(id: ID(), color: .blackout, intensity: 1.0),
            ],
            sequenceIndex: 4
        ))

        b.createdAt = Date(timeIntervalSince1970: 0)
        b.modifiedAt = Date(timeIntervalSince1970: 0)
        return b
    }
}
