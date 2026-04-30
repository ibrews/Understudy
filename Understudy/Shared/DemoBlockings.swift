//
//  DemoBlockings.swift
//  Understudy
//
//  Seed content. Three curated demos so a director can walk into a room and
//  show what Understudy does in 60–90 seconds:
//
//    • theaterShowcase  — Hamlet's Ghost: 8-beat scene with thunder,
//                         lightning, blue/amber lights and four characters.
//                         The flagship theatre demo.
//    • filmShowcase     — Coverage of a single actor from four camera
//                         positions with real lens specs (24/50/85/135mm).
//                         Demonstrates the film pre-viz workflow.
//    • gallerySiteSpec  — A six-stop site-specific walking piece.
//                         Audience-mode-friendly — the visitor IS the performer.
//
//  hamletOpening is the first-launch default — minimal, fits a small room.
//  The showcase blockings are dropped from the "Run Demo" launcher.
//

import Foundation

public enum DemoBlockings {
    // MARK: - First-launch demo (minimal, fits a 3 × 3m living room)

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

    // MARK: - Showcase 1: Theater (Hamlet's Ghost — full version)

    /// The flagship theatre demo. Eight beats from "You come most carefully"
    /// through the ghost's first appearance, with full lighting + SFX.
    /// Designed for ~6 × 4 m of clear floor — a typical rehearsal room.
    /// Pre-loaded character names show range; lighting tells the story.
    public static var theaterShowcase: Blocking {
        var b = Blocking(
            id: ID("demo-theater-showcase"),
            title: "Hamlet — The Ghost (Showcase)",
            authorName: "William Shakespeare",
            origin: Pose()
        )

        // 1. Francisco on watch — cold blue wash, wind beat.
        b.marks.append(Mark(
            id: ID("demo-th-1"),
            name: "Francisco's Watch",
            pose: Pose(x: 0, y: 0, z: -2.4, yaw: 0),
            radius: 0.7,
            cues: [
                .light(id: ID(), color: .cool, intensity: 0.45),
                .wait(id: ID(), seconds: 1.5),
                .line(id: ID(), text: "Who's there?",
                      character: "FRANCISCO"),
            ],
            sequenceIndex: 0
        ))

        // 2. Bernardo enters — challenge.
        b.marks.append(Mark(
            id: ID("demo-th-2"),
            name: "Bernardo Enters",
            pose: Pose(x: -1.8, y: 0, z: -1.2, yaw: 0),
            radius: 0.6,
            cues: [
                .sfx(id: ID(), name: "knock"),
                .line(id: ID(), text: "Nay, answer me. Stand and unfold yourself.",
                      character: "FRANCISCO"),
                .line(id: ID(), text: "Long live the king!",
                      character: "BERNARDO"),
                .line(id: ID(), text: "Bernardo?",
                      character: "FRANCISCO"),
                .line(id: ID(), text: "He.",
                      character: "BERNARDO"),
            ],
            sequenceIndex: 1
        ))

        // 3. Changing of the guard — center stage.
        b.marks.append(Mark(
            id: ID("demo-th-3"),
            name: "Changing of the Guard",
            pose: Pose(x: 0, y: 0, z: 0, yaw: 0),
            radius: 0.6,
            cues: [
                .line(id: ID(), text: "'Tis now struck twelve. Get thee to bed, Francisco.",
                      character: "BERNARDO"),
                .line(id: ID(), text: "For this relief much thanks. 'Tis bitter cold, and I am sick at heart.",
                      character: "FRANCISCO"),
                .wait(id: ID(), seconds: 1.0),
                .line(id: ID(), text: "Have you had quiet guard?",
                      character: "BERNARDO"),
                .line(id: ID(), text: "Not a mouse stirring.",
                      character: "FRANCISCO"),
            ],
            sequenceIndex: 2
        ))

        // 4. Horatio + Marcellus arrive — bell tolls.
        b.marks.append(Mark(
            id: ID("demo-th-4"),
            name: "Horatio Arrives",
            pose: Pose(x: 1.8, y: 0, z: 0.8, yaw: 0),
            radius: 0.6,
            cues: [
                .sfx(id: ID(), name: "bell"),
                .light(id: ID(), color: .cool, intensity: 0.55),
                .line(id: ID(), text: "Friends to this ground.",
                      character: "HORATIO"),
                .line(id: ID(), text: "And liegemen to the Dane.",
                      character: "MARCELLUS"),
                .line(id: ID(), text: "Welcome, Horatio. Welcome, good Marcellus.",
                      character: "BERNARDO"),
            ],
            sequenceIndex: 3
        ))

        // 5. Skeptic Horatio — the night Two before.
        b.marks.append(Mark(
            id: ID("demo-th-5"),
            name: "Horatio's Doubt",
            pose: Pose(x: 0.9, y: 0, z: 1.0, yaw: 0),
            radius: 0.55,
            cues: [
                .line(id: ID(), text: "What, has this thing appear'd again to-night?",
                      character: "HORATIO"),
                .line(id: ID(), text: "I have seen nothing.",
                      character: "BERNARDO"),
                .line(id: ID(), text: "Horatio says 'tis but our fantasy, And will not let belief take hold of him.",
                      character: "MARCELLUS"),
                .note(id: ID(), text: "Horatio: skeptical scholar. Marcellus: working soldier."),
            ],
            sequenceIndex: 4
        ))

        // 6. Bernardo's tale — the build, the wait.
        b.marks.append(Mark(
            id: ID("demo-th-6"),
            name: "The Tale Begins",
            pose: Pose(x: -0.8, y: 0, z: 0.5, yaw: 0),
            radius: 0.55,
            cues: [
                .line(id: ID(), text: "Sit down awhile, And let us once again assail your ears.",
                      character: "BERNARDO"),
                .line(id: ID(), text: "Last night of all, When yond same star that's westward from the pole...",
                      character: "BERNARDO"),
                .wait(id: ID(), seconds: 1.5),
                .light(id: ID(), color: .cool, intensity: 0.35),
            ],
            sequenceIndex: 5
        ))

        // 7. THE GHOST — thunder, blue wash, lightning.
        b.marks.append(Mark(
            id: ID("demo-th-7"),
            name: "The Ghost",
            pose: Pose(x: 1.4, y: 0, z: -2.0, yaw: 0),
            radius: 0.8,
            cues: [
                .sfx(id: ID(), name: "thunder"),
                .light(id: ID(), color: .blue, intensity: 0.95),
                .wait(id: ID(), seconds: 1.5),
                .line(id: ID(), text: "Peace, break thee off. Look, where it comes again!",
                      character: "BERNARDO"),
                .line(id: ID(), text: "In the same figure, like the king that's dead.",
                      character: "HORATIO"),
                .line(id: ID(), text: "Thou art a scholar. Speak to it, Horatio.",
                      character: "MARCELLUS"),
                .light(id: ID(), color: .amber, intensity: 0.5),
                .wait(id: ID(), seconds: 1.0),
                .line(id: ID(), text: "What art thou, that usurp'st this time of night?",
                      character: "HORATIO"),
            ],
            sequenceIndex: 6
        ))

        // 8. The Ghost departs — blackout, distant thunder, final word.
        b.marks.append(Mark(
            id: ID("demo-th-8"),
            name: "It is Offended",
            pose: Pose(x: 0.4, y: 0, z: -2.4, yaw: 0),
            radius: 0.7,
            cues: [
                .line(id: ID(), text: "It is offended.",
                      character: "BERNARDO"),
                .line(id: ID(), text: "See, it stalks away.",
                      character: "MARCELLUS"),
                .sfx(id: ID(), name: "thunder"),
                .wait(id: ID(), seconds: 1.5),
                .light(id: ID(), color: .blackout, intensity: 1.0),
                .note(id: ID(), text: "Curtain on Act I, Scene I."),
            ],
            sequenceIndex: 7
        ))

        b.createdAt = Date(timeIntervalSince1970: 0)
        b.modifiedAt = Date(timeIntervalSince1970: 0)
        return b
    }

    // MARK: - Showcase 2: Film (single actor + four camera positions)

    /// Coverage of a one-actor monologue from four camera positions with
    /// real lens specs. Demonstrates the film pre-viz model: drop the
    /// actor, drop the cameras, walk the room, see exactly what each lens
    /// frames from each spot before the gear arrives.
    public static var filmShowcase: Blocking {
        var b = Blocking(
            id: ID("demo-film-showcase"),
            title: "Film — Coverage of a Monologue",
            authorName: "Understudy / Agile Lens",
            origin: Pose()
        )

        // Actor mark — center stage, three lines that get covered.
        b.marks.append(Mark(
            id: ID("demo-film-actor"),
            name: "Actor — CS",
            pose: Pose(x: 0, y: 0, z: 0, yaw: 0),
            radius: 0.6,
            cues: [
                .light(id: ID(), color: .warm, intensity: 0.7),
                .line(id: ID(), text: "I should have been a pair of ragged claws…",
                      character: "PRUFROCK"),
                .line(id: ID(), text: "Scuttling across the floors of silent seas.",
                      character: "PRUFROCK"),
                .wait(id: ID(), seconds: 1.0),
                .line(id: ID(), text: "I have heard the mermaids singing, each to each.",
                      character: "PRUFROCK"),
                .note(id: ID(), text: "Eliot, abridged. Coverage demo."),
            ],
            sequenceIndex: 0,
            kind: .actor
        ))

        // Cam 1 — Wide 24mm front, the establishing shot.
        b.marks.append(Mark(
            id: ID("demo-film-cam1"),
            name: "Cam 1 · Wide",
            pose: Pose(x: 0, y: 0, z: 3.0, yaw: 0),
            radius: 0.4,
            cues: [
                .note(id: ID(), text: "Establishing wide. 24mm full-frame, eye-line at 1.5m."),
            ],
            sequenceIndex: -1,
            kind: .camera,
            camera: CameraSpec(focalLengthMM: 24, sensorWidthMM: 36, sensorHeightMM: 24,
                              heightM: 1.5, tiltRadians: 0)
        ))

        // Cam 2 — 50mm 3/4 front-left, the listener's POV.
        b.marks.append(Mark(
            id: ID("demo-film-cam2"),
            name: "Cam 2 · 50mm 3/4 L",
            pose: Pose(x: -1.8, y: 0, z: 1.8, yaw: -.pi / 6),
            radius: 0.4,
            cues: [
                .note(id: ID(), text: "Medium 3/4 left. 50mm — the natural listener's POV."),
            ],
            sequenceIndex: -1,
            kind: .camera,
            camera: CameraSpec(focalLengthMM: 50, sensorWidthMM: 36, sensorHeightMM: 24,
                              heightM: 1.55, tiltRadians: 0)
        ))

        // Cam 3 — 85mm tight 3/4 right, the intimate.
        b.marks.append(Mark(
            id: ID("demo-film-cam3"),
            name: "Cam 3 · 85mm Tight 3/4 R",
            pose: Pose(x: 1.6, y: 0, z: 1.4, yaw: .pi / 6),
            radius: 0.4,
            cues: [
                .note(id: ID(), text: "Tight 3/4 right. 85mm — chest-up, intimate."),
            ],
            sequenceIndex: -1,
            kind: .camera,
            camera: CameraSpec(focalLengthMM: 85, sensorWidthMM: 36, sensorHeightMM: 24,
                              heightM: 1.6, tiltRadians: 0.05)
        ))

        // Cam 4 — 135mm extreme close, the eye.
        b.marks.append(Mark(
            id: ID("demo-film-cam4"),
            name: "Cam 4 · 135mm ECU",
            pose: Pose(x: 0.4, y: 0, z: 2.6, yaw: 0),
            radius: 0.4,
            cues: [
                .note(id: ID(), text: "Extreme close-up. 135mm — held eye contact, the kicker."),
            ],
            sequenceIndex: -1,
            kind: .camera,
            camera: CameraSpec(focalLengthMM: 135, sensorWidthMM: 36, sensorHeightMM: 24,
                              heightM: 1.62, tiltRadians: 0.08)
        ))

        b.createdAt = Date(timeIntervalSince1970: 0)
        b.modifiedAt = Date(timeIntervalSince1970: 0)
        return b
    }

    // MARK: - Showcase 3: Gallery (site-specific walk)

    /// A six-stop site-specific walking piece — designed to feel like
    /// a museum or installation visit. Audience-mode-friendly: the
    /// visitor IS the performer, and the show comes to them as they walk.
    public static var gallerySiteSpec: Blocking {
        var b = Blocking(
            id: ID("demo-gallery-sitespec"),
            title: "A Walk in the Gallery",
            authorName: "Understudy",
            origin: Pose()
        )

        // 1. Welcome.
        b.marks.append(Mark(
            id: ID("demo-g-1"),
            name: "Welcome",
            pose: Pose(x: 0, y: 0, z: -2.5, yaw: 0),
            radius: 0.7,
            cues: [
                .light(id: ID(), color: .warm, intensity: 0.6),
                .sfx(id: ID(), name: "chime"),
                .line(id: ID(), text: "You are entering a memory. Walk slowly.",
                      character: "GUIDE"),
                .wait(id: ID(), seconds: 1.5),
            ],
            sequenceIndex: 0
        ))

        // 2. First image — water.
        b.marks.append(Mark(
            id: ID("demo-g-2"),
            name: "First Image — Water",
            pose: Pose(x: -2.0, y: 0, z: -1.0, yaw: 0),
            radius: 0.6,
            cues: [
                .light(id: ID(), color: .cool, intensity: 0.5),
                .line(id: ID(), text: "She remembered the sea before she remembered her own name.",
                      character: "NARRATOR"),
            ],
            sequenceIndex: 1
        ))

        // 3. Second image — the chair.
        b.marks.append(Mark(
            id: ID("demo-g-3"),
            name: "Second Image — The Chair",
            pose: Pose(x: 0, y: 0, z: 0, yaw: 0),
            radius: 0.6,
            cues: [
                .light(id: ID(), color: .amber, intensity: 0.55),
                .line(id: ID(), text: "It had been her grandmother's. Now it sat empty.",
                      character: "NARRATOR"),
                .wait(id: ID(), seconds: 1.0),
            ],
            sequenceIndex: 2
        ))

        // 4. Third image — fire.
        b.marks.append(Mark(
            id: ID("demo-g-4"),
            name: "Third Image — Fire",
            pose: Pose(x: 2.0, y: 0, z: -0.5, yaw: 0),
            radius: 0.6,
            cues: [
                .light(id: ID(), color: .red, intensity: 0.7),
                .sfx(id: ID(), name: "thunder"),
                .line(id: ID(), text: "And then the house was burning.",
                      character: "NARRATOR"),
            ],
            sequenceIndex: 3
        ))

        // 5. Fourth image — silence.
        b.marks.append(Mark(
            id: ID("demo-g-5"),
            name: "Fourth Image — Silence",
            pose: Pose(x: 0.8, y: 0, z: 1.6, yaw: 0),
            radius: 0.6,
            cues: [
                .light(id: ID(), color: .blue, intensity: 0.4),
                .wait(id: ID(), seconds: 2.0),
                .line(id: ID(), text: "Years of nothing. Then a knock at the door.",
                      character: "NARRATOR"),
                .sfx(id: ID(), name: "knock"),
            ],
            sequenceIndex: 4
        ))

        // 6. Exit.
        b.marks.append(Mark(
            id: ID("demo-g-6"),
            name: "Exit",
            pose: Pose(x: -1.4, y: 0, z: 1.8, yaw: 0),
            radius: 0.7,
            cues: [
                .light(id: ID(), color: .warm, intensity: 0.65),
                .sfx(id: ID(), name: "applause"),
                .line(id: ID(), text: "Thank you for walking with us.",
                      character: "GUIDE"),
                .wait(id: ID(), seconds: 1.0),
                .light(id: ID(), color: .blackout, intensity: 1.0),
            ],
            sequenceIndex: 5
        ))

        b.createdAt = Date(timeIntervalSince1970: 0)
        b.modifiedAt = Date(timeIntervalSince1970: 0)
        return b
    }

    // MARK: - Catalog

    public struct ShowcaseEntry: Identifiable {
        public let id: String
        public let title: String
        public let blurb: String
        public let systemImage: String
        public let blocking: () -> Blocking
        /// Estimated runtime when auto-played by DemoRunner.
        public let estimatedSeconds: Int
    }

    /// All showcase blockings, in the order they appear in the launcher.
    public static let allShowcases: [ShowcaseEntry] = [
        ShowcaseEntry(
            id: "theater",
            title: "Theater · Hamlet's Ghost",
            blurb: "Eight beats from Act I, Scene I. Thunder, blue wash, four characters, full lights.",
            systemImage: "theatermasks.fill",
            blocking: { theaterShowcase },
            estimatedSeconds: 90
        ),
        ShowcaseEntry(
            id: "film",
            title: "Film · Coverage of a Monologue",
            blurb: "One actor, four camera positions, lens specs from 24mm to 135mm. Lens-to-frame in real space.",
            systemImage: "video.fill",
            blocking: { filmShowcase },
            estimatedSeconds: 60
        ),
        ShowcaseEntry(
            id: "gallery",
            title: "Gallery · Site-Specific Walk",
            blurb: "A six-stop audio walk. Site-specific theatre as a finished product.",
            systemImage: "figure.walk.motion",
            blocking: { gallerySiteSpec },
            estimatedSeconds: 75
        ),
    ]
}
