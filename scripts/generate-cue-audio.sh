#!/usr/bin/env bash
# generate-cue-audio.sh — Synthesize the bundled cue audio catalog via ffmpeg.
#
# Produces 12 new WAVs in two categories:
#   sfx/   — short theatrical FX: door-slam, glass-break, footsteps, wind,
#            crickets, drone-low, orchestral-hit
#   music/ — short cues used as scoring beats: swell-strings, tense-drone,
#            sad-cello, triumphant-brass, finale
#
# All files are CC0 — generated from sine/noise/lavfi sources, no samples
# from copyrighted material.
#
# Usage:  bash scripts/generate-cue-audio.sh
#         (re-runs idempotently; overwrites existing files)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SFX="$REPO_ROOT/Understudy/Resources/Audio/sfx"
MUSIC="$REPO_ROOT/Understudy/Resources/Audio/music"
mkdir -p "$SFX" "$MUSIC"

FF="ffmpeg -hide_banner -loglevel error -y"

echo "▶ Generating SFX catalog…"

# door-slam — quick low thud + brief noise burst.
$FF -f lavfi -i "sine=frequency=80:duration=0.4,volume=2.0" \
    -af "afade=t=in:st=0:d=0.005,afade=t=out:st=0.06:d=0.34" \
    -ac 1 -ar 44100 "$SFX/door-slam.wav"

# wind — pink noise filtered to a low rumble, 6 sec, gentle envelope.
$FF -f lavfi -i "anoisesrc=color=pink:duration=6:amplitude=0.4" \
    -af "highpass=f=80,lowpass=f=600,afade=t=in:st=0:d=1,afade=t=out:st=5:d=1" \
    -ac 1 -ar 44100 "$SFX/wind.wav"

# crickets — multi-tone pulses (chirpy bursts) for ~6 sec.
$FF -f lavfi -i "sine=frequency=4500:beep_factor=8:duration=6:sample_rate=44100,volume=0.3" \
    -af "tremolo=f=8:d=0.9,afade=t=in:st=0:d=0.5,afade=t=out:st=5.5:d=0.5" \
    -ac 1 -ar 44100 "$SFX/crickets.wav"

# drone-low — 60 Hz with slow LFO modulation, 8 sec.
$FF -f lavfi -i "sine=frequency=55:duration=8" \
    -af "tremolo=f=0.5:d=0.4,afade=t=in:st=0:d=1,afade=t=out:st=7:d=1,volume=0.7" \
    -ac 1 -ar 44100 "$SFX/drone-low.wav"

# footsteps — series of low pulses every 0.5s, 4 footsteps total.
$FF -f lavfi -i "sine=frequency=140:duration=2" \
    -af "tremolo=f=2:d=1.0,afade=t=in:st=0:d=0.02,afade=t=out:st=1.95:d=0.05,volume=0.8" \
    -ac 1 -ar 44100 "$SFX/footsteps.wav"

# glass-break — short noise burst with high-frequency emphasis.
$FF -f lavfi -i "anoisesrc=color=white:duration=0.6:amplitude=0.6" \
    -af "highpass=f=2000,afade=t=in:st=0:d=0.005,afade=t=out:st=0.2:d=0.4" \
    -ac 1 -ar 44100 "$SFX/glass-break.wav"

# orchestral-hit — sharp tonal sting (sine + noise burst), 0.9 sec.
$FF -f lavfi -i "sine=frequency=220:duration=0.9" \
    -f lavfi -i "anoisesrc=color=white:duration=0.15:amplitude=0.5" \
    -filter_complex "[0:a]afade=t=in:st=0:d=0.005,afade=t=out:st=0.4:d=0.5[tone]; \
                     [1:a]highpass=f=1500,afade=t=in:st=0:d=0.005,afade=t=out:st=0.05:d=0.10[noise]; \
                     [tone][noise]amix=inputs=2:weights=1.4 0.7[mix]" \
    -map "[mix]" -ac 1 -ar 44100 "$SFX/orchestral-hit.wav"

echo "▶ Generating Music catalog…"

# swell-strings — sine harmonics with slow envelope, ~5 sec, A major triad.
$FF -f lavfi -i "sine=frequency=220:duration=5" \
    -f lavfi -i "sine=frequency=277.18:duration=5" \
    -f lavfi -i "sine=frequency=329.63:duration=5" \
    -filter_complex "[0:a][1:a][2:a]amix=inputs=3:weights=1 1 1, \
                     afade=t=in:st=0:d=2.0,afade=t=out:st=4:d=1.0,volume=0.6[mix]" \
    -map "[mix]" -ac 1 -ar 44100 "$MUSIC/swell-strings.wav"

# tense-drone — minor third with beat, 8 sec.
$FF -f lavfi -i "sine=frequency=110:duration=8" \
    -f lavfi -i "sine=frequency=130.81:duration=8" \
    -filter_complex "[0:a][1:a]amix=inputs=2:weights=1 0.85, \
                     tremolo=f=2:d=0.3, \
                     afade=t=in:st=0:d=1,afade=t=out:st=7:d=1,volume=0.5[mix]" \
    -map "[mix]" -ac 1 -ar 44100 "$MUSIC/tense-drone.wav"

# sad-cello — descending minor (A→G→F→E), each held 1.5 sec.
$FF -f lavfi -i "sine=frequency=110:duration=1.5" \
    -f lavfi -i "sine=frequency=98:duration=1.5" \
    -f lavfi -i "sine=frequency=87.31:duration=1.5" \
    -f lavfi -i "sine=frequency=82.41:duration=1.5" \
    -filter_complex "[0:a]afade=t=in:st=0:d=0.05,afade=t=out:st=1.3:d=0.2[a0]; \
                     [1:a]afade=t=in:st=0:d=0.05,afade=t=out:st=1.3:d=0.2[a1]; \
                     [2:a]afade=t=in:st=0:d=0.05,afade=t=out:st=1.3:d=0.2[a2]; \
                     [3:a]afade=t=in:st=0:d=0.05,afade=t=out:st=1.3:d=0.2[a3]; \
                     [a0][a1][a2][a3]concat=n=4:v=0:a=1,volume=0.55[mix]" \
    -map "[mix]" -ac 1 -ar 44100 "$MUSIC/sad-cello.wav"

# triumphant-brass — major triad + fanfare, 3 sec.
$FF -f lavfi -i "sine=frequency=261.63:duration=3" \
    -f lavfi -i "sine=frequency=329.63:duration=3" \
    -f lavfi -i "sine=frequency=392.00:duration=3" \
    -filter_complex "[0:a][1:a][2:a]amix=inputs=3:weights=1 1 1, \
                     afade=t=in:st=0:d=0.05,afade=t=out:st=2.5:d=0.5,volume=0.55[mix]" \
    -map "[mix]" -ac 1 -ar 44100 "$MUSIC/triumphant-brass.wav"

# finale — IV-V-I cadence in C major (F-G-C), each chord 2 sec, 6 sec total.
$FF -f lavfi -i "sine=frequency=174.61:duration=2" \
    -f lavfi -i "sine=frequency=220.00:duration=2" \
    -f lavfi -i "sine=frequency=261.63:duration=2" \
    -f lavfi -i "sine=frequency=196.00:duration=2" \
    -f lavfi -i "sine=frequency=246.94:duration=2" \
    -f lavfi -i "sine=frequency=293.66:duration=2" \
    -f lavfi -i "sine=frequency=261.63:duration=2" \
    -f lavfi -i "sine=frequency=329.63:duration=2" \
    -f lavfi -i "sine=frequency=392.00:duration=2" \
    -filter_complex "[0:a][1:a][2:a]amix=inputs=3:weights=1 1 1[F]; \
                     [3:a][4:a][5:a]amix=inputs=3:weights=1 1 1[G]; \
                     [6:a][7:a][8:a]amix=inputs=3:weights=1 1 1[C]; \
                     [F][G][C]concat=n=3:v=0:a=1, \
                     afade=t=in:st=0:d=0.1,afade=t=out:st=5.4:d=0.6,volume=0.5[mix]" \
    -map "[mix]" -ac 1 -ar 44100 "$MUSIC/finale.wav"

echo "✓ Generated $(ls $SFX | wc -l | tr -d ' ') SFX, $(ls $MUSIC | wc -l | tr -d ' ') music tracks."
echo "  Total bundled audio: $(du -ck $SFX/*.wav $MUSIC/*.wav | grep total$ | awk '{print $1}') KB"
