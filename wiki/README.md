# Understudy User Guide

This folder is the **user-facing wiki** for Understudy — written for theatre directors, film DPs, performers, stage managers, and audiences who don't read code.

## Reading it

- **In the GitHub Wiki tab:** the wiki is mirrored to <https://github.com/ibrews/Understudy/wiki> (sidebar nav, search, prettier rendering).
- **Right here in the repo:** start at [Home.md](Home.md). All internal links use bare wiki-style names (`[Director-Guide](Director-Guide)`) which work in both contexts.

## Mirroring to the GitHub Wiki tab

The first time you populate a GitHub repo's Wiki, GitHub requires one click in the UI — the wiki repo (`Understudy.wiki.git`) doesn't exist until then. After that, it's just `git clone` + `git push`.

To bootstrap and sync:

```bash
# One-time bootstrap — visit https://github.com/ibrews/Understudy/wiki and
# click "Create the first page" (any content; we'll overwrite it). Save.
# Now the .wiki repo exists.

# Clone it.
cd /tmp
git clone https://github.com/ibrews/Understudy.wiki.git
cd Understudy.wiki

# Copy this folder's contents over.
cp /Users/Shared/Documents/xcodeproj/Understudy/wiki/*.md .

# Commit and push.
git add .
git commit -m "Sync wiki from main repo"
git push
```

Re-sync any time the markdown here changes.

## Pages

- **[Home](Home.md)** — top-level index
- **[Quick-Start](Quick-Start.md)** — 90-second tutorial expanded to 5 minutes
- **[Director-Guide](Director-Guide.md)** — visionOS workflow
- **[Performer-Guide](Performer-Guide.md)** — iPhone workflow
- **[Author-Guide](Author-Guide.md)** — building blockings
- **[Audience-Mode](Audience-Mode.md)** — self-paced AR tour
- **[Camera-and-Film-Mode](Camera-and-Film-Mode.md)** — film pre-viz
- **[Multiple-Devices](Multiple-Devices.md)** — networking + calibration
- **[QLab-and-OSC](QLab-and-OSC.md)** — bidirectional OSC bridge
- **[DMX-Lighting](DMX-Lighting.md)** — sACN output
- **[Room-Scanning](Room-Scanning.md)** — LiDAR capture + alignment
- **[Bundled-Plays](Bundled-Plays.md)** — the 10 included plays
- **[Troubleshooting](Troubleshooting.md)** — common issues
- **[Glossary](Glossary.md)** — terms used throughout

The `_Sidebar.md` is GitHub Wiki's sidebar nav — only used by the Wiki tab, ignored when reading this folder directly.
