---
name: hbg-douyin-code-explainer-video
description: Create and quality-gate Chinese 9:16 Douyin explainer videos using deterministic HTML/CSS/SVG/GSAP in HyperFrames, dialogue-aware local Qwen or Edge TTS, global Whisper alignment, speech-synced visuals, continuous transitions, stable instrumental BGM, and final encoded-media inspection. Use for commentary, educational formulas, workplace or growth scripts, faceless code-generated videos, or fixing portrait sizing, element alignment, premature reveals, blank transitions, narration sync, BGM pumping, or visual-continuity defects.
---

# Douyin Code Explainer Video

Produce a complete vertical explainer from copy to final MP4. Treat visual QA as a delivery gate, not an optional polish pass.

## Required companion skills

Read and apply the available HyperFrames authoring, HyperFrames CLI, GSAP, and code-video visual QA skills before editing a composition. Read HyperFrames typography, captions, motion, and transition references when required by those skills.

## 1. Normalize and analyze the copy

1. Preserve the author's argument and conversational tone.
2. Correct obvious ASR errors, malformed terms, punctuation, formulas, units, and factual prerequisites before TTS.
3. For mathematics, distinguish spoken text from display notation. Example: speak “P，在失败的条件下，你不行” while displaying `P(不行 | 失败)`.
4. Identify every voice turn. Assign audience questions, quoted objections, and conversational prompts to the female voice when appropriate; assign explanation and synthesis to the male voice. Do not mechanically alternate voices.
5. Default voices: Qwen CustomVoice `Vivian` for female and `Uncle_Fu` for male. Do not show the word “旁白”.
6. Split into one semantic unit per segment. A segment should normally support one visual claim and one caption/progress interval.
7. Create a storyboard before HTML. Record the spoken line, display copy, speaker, visual metaphor, geometry risks, and intended scene duration.

## 2. Generate continuous dialogue TTS

Read [references/audio-pipeline.md](references/audio-pipeline.md) before generating or mixing audio.

1. Prefer the user's local Qwen CustomVoice model when it is healthy. Default voices are `Vivian` for female prompts and `Uncle_Fu` for male explanation. Use Edge TTS when the user requests it or Qwen long-block generation exceeds the measured guard.
2. Generate complete semantic speaker turns, not visual-shot clips. Keep female/male turns as hard boundaries. Split only at genuine argument or chapter boundaries.
3. Export a block manifest containing backend, voice, text, generation mode, duration, and speaker gaps. Never label stitched fallback audio as continuously synthesized.
4. Apply the requested speed exactly once. Defaults: Qwen final track `1.3×`; Edge `+20%`. Do not scale planned scene boundaries and assume they are final.
5. Run one global open-source Whisper pass on the actual final-speed narration with word timestamps. Prefer `whisper-large-v3-turbo`, `condition_on_previous_text=false`, and an initial prompt containing names, formulas, and critical numbers.
6. Align Whisper back to the complete scene list, regardless of scene count. Keep the corrected source script as display text; use Whisper for timing and spoken-content verification.
7. Perform an explicit LLM review of every scene, speaker boundary, missing/repeated/truncated phrase, critical number, technical term, and probability direction. A high global similarity never overrides a failed scene.

## 3. Define the visual system

Create and read a project-local `DESIGN.md` before HTML. Unless the user specifies otherwise, use a warm editorial teaching-note aesthetic: warm paper background, charcoal structure, one orange accent, bold Chinese type, monospaced numbers, simple SVG diagrams, and no photographs or generated imagery.

Hard format requirements:

- Canvas: `1080 × 1920`, `24 fps`, 9:16.
- Critical safe area: at least 72px left, 120px right, 130px top, and 300px bottom.
- Keep formulas, subtitles, labels, and small data away from platform controls.
- Use code-only HTML/CSS/SVG/Canvas/GSAP. Do not use image or video generation tools.

## 4. Build layout before animation

1. Build and inspect the fully visible hero frame for every scene first.
2. Use a full-size flex/grid content container with padding. Reserve absolute positioning for decoratives and tightly controlled diagrams.
3. Put coupled geometry in one SVG or one common positioned parent. Declare exact invariants for shared centers, baselines, arrow endpoints, chart baselines, contact surfaces, and contained labels.
4. Never accept “looks close” for a relationship that carries meaning.
5. Add entrances with `gsap.from()` after the static layout is correct.

## 5. Synchronize motion to speech

1. Start each scene shortly before its first spoken word.
2. Keep at least one meaningful visual action alive throughout each spoken segment: drawing, counting, highlighting, moving a marker, filling a bar, tracing an arrow, or advancing a bottom progress line.
3. Do not let the main action finish early and leave a long static hold. Do not reveal conclusions, final numbers, or later-scene elements before the related words.
4. Treat every result-bearing text component as a semantic reveal, including takeaway pills, badges, labels, headers, footnotes, and captions. If it contains a conclusion or final number, remove it from the generic scene entrance and assign it the same explicit phase as the matching visual payoff.
5. Do not rely on a future `gsap.from()` tween to keep payoff elements hidden before its start. At scene preparation time, explicitly set phased elements to `opacity: 0`, then reveal with deterministic `fromTo()` tweens. Capture a frame immediately before and after every payoff phase.
6. Use one visual per sentence or logical unit. If a line changes subject, change or recompose the visual.
7. Caption only the current segment. Keep one caption group visible at a time and hard-kill it at segment end.
8. Never add a visible “旁白” label.

## 6. Preserve continuous scene handoffs

Use a continuous horizontal page-push as the primary transition. At every transition midpoint, outgoing and incoming pages must jointly fill the canvas.

- Never place a full-screen blank mask above both scenes.
- Never fade the outgoing content away before the transition.
- Never allow black, empty paper, or decorative-only frames between semantic scenes.
- Ensure the incoming scene already contains valid background and content while entering.
- Use one primary transition for 60–70% of changes and restrained accents only for real topic shifts.

## 7. Add audible instrumental BGM

Use a project-local instrumental track. It should remain clearly audible without pumping louder and quieter around every phrase. Reuse `scripts/mix_bgm.sh` unless the project has a tested equivalent. Its default `stable` mode uses equal-power crossfaded loops and constant whole-track gain; use optional `ducked` mode only when the music masks speech. Keep `alimiter` with `level=false`.

Before mixing, run edge-silence detection on the source music. Trim padded or unsuitable edges with `BGM_TRIM_START_SECONDS` and `BGM_TRIM_END_SECONDS`, then choose a musically coherent loop section. Re-run silence detection and loudness inspection on the final MP4 and reject unexplained gaps or level jumps.

## 8. Run the mandatory QA gates

Read [references/qa-checklist.md](references/qa-checklist.md) and complete every applicable check.

1. Automated pass: run HyperFrames lint/check/inspect/animation-map and fix errors; review warnings and dead zones.
2. Source-frame pass: capture one hero frame per scene, every transition midpoint, and before/mid/after frames for each high-risk relationship. Open suspicious frames at full resolution.
3. Final-media pass: render the encoded MP4, then repeat high-risk frame inspection from that MP4. Run `scripts/final_media_qa.sh` for resolution, fps, duration, blank frames, silence, loudness, peak, hashes, and full-resolution extraction of optional named risk timestamps.
4. Verify the full video stream at accelerated playback for content continuity. Every spoken segment must have a matching visual with no interruption.

Do not declare completion if only automated checks passed, if only source frames were inspected, or if the final encoded video was not checked.

## Revision rule

When a defect is found, invalidate the previous render, fix the source, recapture neighboring frames, rerender, and write a new revision filename. Never overwrite an older review render.
