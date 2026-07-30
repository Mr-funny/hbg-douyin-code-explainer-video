#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: mix_bgm.sh <voice-video.mp4> <instrumental-bgm> <output.mp4>" >&2
  exit 2
fi

input_video=$1
bgm_file=$2
output_video=$3

bgm_mode=${BGM_MODE:-stable}
bgm_volume=${BGM_VOLUME:-0.46}
crossfade_seconds=${BGM_CROSSFADE_SECONDS:-5}
fade_in_seconds=${BGM_FADE_IN_SECONDS:-2.5}
fade_out_seconds=${BGM_FADE_OUT_SECONDS:-3}
bgm_trim_start=${BGM_TRIM_START_SECONDS:-0}
bgm_trim_end=${BGM_TRIM_END_SECONDS:-}

duck_threshold=${BGM_DUCK_THRESHOLD:-0.06}
duck_ratio=${BGM_DUCK_RATIO:-3}
duck_attack_ms=${BGM_DUCK_ATTACK_MS:-80}
duck_release_ms=${BGM_DUCK_RELEASE_MS:-650}

if [[ "$bgm_mode" != "stable" && "$bgm_mode" != "ducked" ]]; then
  echo "BGM_MODE must be stable or ducked" >&2
  exit 2
fi

for required in ffmpeg ffprobe awk; do
  command -v "$required" >/dev/null 2>&1 || {
    echo "Missing required command: $required" >&2
    exit 2
  }
done

duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$input_video")
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

bgm_source=$bgm_file
if [[ "$bgm_trim_start" != "0" || -n "$bgm_trim_end" ]]; then
  bgm_source="$temp_dir/trimmed-bgm.wav"
  trim_args=(-ss "$bgm_trim_start")
  if [[ -n "$bgm_trim_end" ]]; then
    trim_args+=(-to "$bgm_trim_end")
  fi
  ffmpeg -y -hide_banner -loglevel error \
    "${trim_args[@]}" -i "$bgm_file" -vn -ar 48000 -ac 2 -c:a pcm_s16le "$bgm_source"
fi

bgm_duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$bgm_source")
crossfade_seconds=$(awk -v x="$crossfade_seconds" -v d="$bgm_duration" 'BEGIN {
  if (x < 0) x = 0;
  max = d * 0.45;
  if (x > max) x = max;
  printf "%.6f", x;
}')

step_seconds=$(awk -v d="$bgm_duration" -v x="$crossfade_seconds" 'BEGIN {
  step = d - x;
  if (step <= 0) step = d;
  printf "%.6f", step;
}')
crossfade_enabled=$(awk -v x="$crossfade_seconds" 'BEGIN { print (x > 0.000001) ? 1 : 0 }')
copies=$(awk -v total="$duration" -v first="$bgm_duration" -v step="$step_seconds" 'BEGIN {
  if (total <= first) { print 1; exit }
  n = 1 + int((total - first + step - 0.000001) / step);
  if (n < 1) n = 1;
  print n;
}')

fade_out_start=$(awk -v d="$duration" -v f="$fade_out_seconds" 'BEGIN {
  s = d - f;
  if (s < 0) s = 0;
  printf "%.6f", s;
}')

bed_file="$temp_dir/bgm-bed.wav"
bed_inputs=(-y -hide_banner -loglevel error)
bed_filters=()
for ((i=0; i<copies; i++)); do
  bed_inputs+=(-i "$bgm_source")
  bed_filters+=("[$i:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,atrim=0:${bgm_duration},asetpts=N/SR/TB[b$i]")
done

if (( copies == 1 )); then
  bed_tail="[b0]"
else
  if (( crossfade_enabled == 1 )); then
    bed_filters+=("[b0][b1]acrossfade=d=${crossfade_seconds}:c1=qsin:c2=qsin[x1]")
  else
    bed_filters+=("[b0][b1]concat=n=2:v=0:a=1[x1]")
  fi
  for ((i=2; i<copies; i++)); do
    previous=$((i-1))
    if (( crossfade_enabled == 1 )); then
      bed_filters+=("[x${previous}][b${i}]acrossfade=d=${crossfade_seconds}:c1=qsin:c2=qsin[x${i}]")
    else
      bed_filters+=("[x${previous}][b${i}]concat=n=2:v=0:a=1[x${i}]")
    fi
  done
  bed_tail="[x$((copies-1))]"
fi

bed_filters+=("${bed_tail}atrim=0:${duration},asetpts=N/SR/TB,volume=${bgm_volume},afade=t=in:st=0:d=${fade_in_seconds},afade=t=out:st=${fade_out_start}:d=${fade_out_seconds}[bed]")
filter_graph=$(IFS=';'; echo "${bed_filters[*]}")

ffmpeg "${bed_inputs[@]}" \
  -filter_complex "$filter_graph" -map "[bed]" \
  -ar 48000 -ac 2 -c:a pcm_s16le "$bed_file"

if [[ "$bgm_mode" == "stable" ]]; then
  mix_filter="[0:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[voice];[1:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[bgm];[voice][bgm]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.87:level=false[aout]"
else
  mix_filter="[0:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,asplit=2[voice_sc][voice_mix];[1:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[bgm];[bgm][voice_sc]sidechaincompress=threshold=${duck_threshold}:ratio=${duck_ratio}:attack=${duck_attack_ms}:release=${duck_release_ms}:makeup=1[ducked];[voice_mix][ducked]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.87:level=false[aout]"
fi

ffmpeg -y -hide_banner -loglevel error \
  -i "$input_video" -i "$bed_file" \
  -filter_complex "$mix_filter" \
  -map 0:v:0 -map "[aout]" -t "$duration" \
  -c:v copy -c:a aac -b:a 256k -ar 48000 -ac 2 -movflags +faststart \
  "$output_video"

echo "mode=$bgm_mode"
echo "duration=$duration"
echo "bgm_source_duration=$bgm_duration"
echo "crossfade_seconds=$crossfade_seconds"
echo "loop_copies=$copies"
echo "output=$output_video"
