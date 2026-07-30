# Audio pipeline

## Backend selection

- Use local Qwen CustomVoice when it returns stable long semantic blocks within the measured time guard.
- Use Edge TTS when the user requests Edge, local Qwen is unavailable, or a long Qwen block repeatedly stalls.
- Preserve speaker-turn boundaries with either backend. Do not split narration into one file per visual scene.
- Do not normalize every block independently by default; it can exaggerate voice-level changes. First inspect the raw assembled dialogue and correct only actual backend inconsistencies.

## Continuous-turn generation

Create one block per natural speaker turn. A block manifest should record:

```json
{
  "backend": "qwen|edge",
  "voice": "voice-id",
  "speaker": "female|male",
  "text": "complete semantic turn",
  "mode": "continuous|fallback-stitched",
  "duration": 12.34
}
```

On Apple MPS, keep one long-lived Qwen process unless benchmarking proves parallel processes are faster. Guard long blocks by both text length and wall-clock time. If generation becomes pathological, stop that block, retain completed continuous blocks, and fall back at a real semantic boundary.

Trim leading and trailing silence only. Preserve intentional internal pauses. Use short gaps between speakers and shorter breaths between same-speaker fallback pieces.

## Speed and alignment

- Qwen default: assemble first, then apply `1.3×` once to the complete narration.
- Edge default: request `+20%` once during synthesis unless the user specifies another rate.
- Never accelerate in both TTS and post-processing.
- Run global Whisper only after the final speed and assembly are complete.
- Align Whisper timestamps back to the corrected source scene list. Do not replace display copy with ASR homophones.
- Review names, formulas, numbers, units, probability directions, speaker turns, repetitions, omissions, and truncated endings with an LLM after alignment.

## Stable BGM

Use `scripts/mix_bgm.sh` with `BGM_MODE=stable` by default. It builds an equal-power crossfaded loop bed, applies constant gain, and fades only the beginning and end of the whole video.

Useful environment variables:

```bash
BGM_MODE=stable                 # stable or ducked
BGM_VOLUME=0.46                 # linear gain
BGM_CROSSFADE_SECONDS=5         # equal-power loop overlap
BGM_FADE_IN_SECONDS=2.5
BGM_FADE_OUT_SECONDS=3
BGM_TRIM_START_SECONDS=96
BGM_TRIM_END_SECONDS=143
```

Use `BGM_MODE=ducked` only if the music masks speech. Its release must be slow enough that gaps between clauses do not create obvious pumping. Re-run silence and loudness checks on the final encoded MP4.
