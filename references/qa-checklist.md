# QA checklist

## Source and format

- Confirm root composition, body, and viewport are exactly 1080×1920.
- Confirm 24fps, deterministic timelines, finite repeats, local assets, and no network-dependent visuals.
- Confirm no image-generation or video-generation output is used.
- Confirm the latest revision path is the file under inspection.

## Static hero frames

- Check every scene at its maximum-content frame.
- Check Chinese wrapping, isolated punctuation, formula spacing, fraction alignment, tabular numbers, and safe areas.
- Check chart baselines, shared centers, arrow tips, connectors, support/contact points, and label containment.
- Check that future conclusions and final numbers are absent before their narration. Inspect takeaway pills, badges, labels, headers, footnotes, and captions separately from the main visual; none may reveal the payoff early.

## Motion

- Check before/mid/after frames for every coupled or moving relationship.
- Check that coupled visuals animate as a common group or remain mathematically aligned.
- Check that motion continues meaningfully across the spoken interval.
- Check that captions and progress indicators end exactly with their segment.
- Check every transition midpoint for full-frame valid content and no blank mask, black flash, empty page, clipping, or overlap.

## Audio

- Check the intended backend and voice for every turn: Qwen `Vivian` / `Uncle_Fu` by default, or the explicitly selected Edge voices.
- Check pronunciation, repeated or missing words, truncated ends, long silence, and role errors.
- Check that speed was applied exactly once and that timings came from the final-speed audio.
- Check BGM is instrumental, audible, crossfaded cleanly, faded at both ends, and free of phrase-by-phrase pumping.
- Prefer stable whole-track gain. If ducking is necessary, verify slow, unobtrusive gain recovery.
- Check the limiter uses `level=false` and peak remains below the delivery ceiling.

## Final encoded MP4

- Verify H.264, yuv420p, 1080×1920, 24fps, AAC stereo 48kHz, and faststart.
- Run black-frame and silence detection.
- Record integrated loudness, true/estimated peak, duration, frame count, and video stream hash.
- Confirm the `moov` atom precedes `mdat` when MP4 faststart is required.
- Extract the same hero, transition, and relationship timestamps from the final MP4 and inspect them at full resolution.
- Watch the entire final file at accelerated playback for semantic continuity and missing visuals.
