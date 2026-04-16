# Sound Asset Licenses

All WAV files shipped under `android/app/src/main/res/raw/` are safe to
redistribute royalty-free. They were synthesized locally from scratch via
`ffmpeg`'s `lavfi` synth nodes — no samples from third-party libraries are
used. Because the inputs are algorithmic (`sine`, `anoisesrc`, filter
graphs) and the output contains no copyrightable recording, the files are
placed into the **public domain** (equivalent to CC0 1.0).

## Files

| File                 | Cue name   | Duration | Size   | License | Source |
|----------------------|------------|----------|--------|---------|--------|
| `bell.wav`           | `bell`     | 1.2 s    | 52 KB  | CC0 / Public Domain | Self-generated via `ffmpeg` — 880 Hz sine with exponential decay envelope |
| `chime.wav`          | `chime`    | 1.5 s    | 65 KB  | CC0 / Public Domain | Self-generated via `ffmpeg` — stacked sines at 698.46 / 880 / 1046.5 Hz (F5/A5/C6 triad) with exponential decay |
| `knock.wav`          | `knock`    | 0.25 s   | 11 KB  | CC0 / Public Domain | Self-generated via `ffmpeg` — brown-noise burst bandpassed at ~180 Hz with fast decay envelope |
| `thunder.wav`        | `thunder`  | 2.5 s    | 108 KB | CC0 / Public Domain | Self-generated via `ffmpeg` — brown noise lowpassed at 120 Hz with attack/sustain/release rumble envelope |
| `applause.wav`       | `applause` | 2.0 s    | 86 KB  | CC0 / Public Domain | Self-generated via `ffmpeg` — bandpassed white noise (500–5000 Hz) with tremolo modulation to fake crackle and slow attack/release |

Total: ~328 KB.

## Reproducibility

The exact `ffmpeg` commands used to generate each file are documented below
so future contributors can rebuild the assets identically. All commands
target 22.05 kHz / mono / 16-bit PCM to keep APK footprint minimal.

### bell.wav

```
ffmpeg -f lavfi -i "sine=frequency=880:duration=1.2:sample_rate=22050" \
  -af "volume='exp(-4*t)':eval=frame,acompressor" \
  -ac 1 -ar 22050 -sample_fmt s16 bell.wav
```

### chime.wav

```
ffmpeg -f lavfi -i "sine=frequency=698.46:duration=1.5:sample_rate=22050" \
       -f lavfi -i "sine=frequency=880:duration=1.5:sample_rate=22050" \
       -f lavfi -i "sine=frequency=1046.5:duration=1.5:sample_rate=22050" \
  -filter_complex "[0][1][2]amix=inputs=3:duration=longest,volume='exp(-3*t)':eval=frame,volume=2.0" \
  -ac 1 -ar 22050 -sample_fmt s16 chime.wav
```

### knock.wav

```
ffmpeg -f lavfi -i "anoisesrc=duration=0.25:amplitude=0.9:color=brown:sample_rate=22050" \
  -af "bandpass=f=180:w=120,volume='exp(-25*t)':eval=frame,volume=3.5" \
  -ac 1 -ar 22050 -sample_fmt s16 knock.wav
```

### thunder.wav

```
ffmpeg -f lavfi -i "anoisesrc=duration=2.5:amplitude=1.0:color=brown:sample_rate=22050" \
  -af "lowpass=f=120,volume='if(lt(t,0.3),t*3.3,if(lt(t,0.6),1,exp(-1.5*(t-0.6))))':eval=frame,volume=3.0" \
  -ac 1 -ar 22050 -sample_fmt s16 thunder.wav
```

### applause.wav

```
ffmpeg -f lavfi -i "anoisesrc=duration=2.0:amplitude=0.9:color=white:sample_rate=22050" \
  -af "highpass=f=500,lowpass=f=5000,tremolo=f=18:d=0.4,volume='if(lt(t,0.2),t*5,if(lt(t,1.5),1,exp(-4*(t-1.5))))':eval=frame" \
  -ac 1 -ar 22050 -sample_fmt s16 applause.wav
```

## Adding new cue sounds

Drop the WAV in `android/app/src/main/res/raw/` using a lowercase
snake_case filename matching the cue name, then extend the catalog map in
`android/app/src/main/java/agilelens/understudy/cuefx/CueAudioPlayer.kt`
to point the cue name at `R.raw.<filename>`. Cue names with no matching
WAV fall back to the [ToneGenerator] dial-tone placeholder so runtime-
authored custom names still produce audible feedback.

Any third-party sound added later **must** be CC0 or public domain —
anything requiring attribution breaks redistribution. Log the source URL,
license, and any required attribution block in the table above.
