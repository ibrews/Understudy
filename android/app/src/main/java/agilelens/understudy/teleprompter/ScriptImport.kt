package agilelens.understudy.teleprompter

import agilelens.understudy.model.Cue
import agilelens.understudy.model.Id
import agilelens.understudy.model.Mark

/** Add a complete practice script without replacing existing cues or spatial settings. */
fun Mark.withAppendedScript(script: PlayScript): Mark = copy(
    cues = cues + script.allLines.map { line ->
        Cue.Line(Id(), line.text, line.character)
    }
)
