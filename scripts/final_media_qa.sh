#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: final_media_qa.sh <final.mp4> <qa-output-dir>" >&2
  echo "Optional: QA_TIMESTAMPS_FILE=<tab-separated seconds and label>" >&2
  exit 2
fi

input_video=$1
qa_dir=$2
timestamps_file=${QA_TIMESTAMPS_FILE:-}

for required in ffmpeg ffprobe awk grep; do
  command -v "$required" >/dev/null 2>&1 || {
    echo "Missing required command: $required" >&2
    exit 2
  }
done

mkdir -p "$qa_dir/frames" "$qa_dir/risk-frames"

ffprobe -v error -show_format -show_streams -of json "$input_video" > "$qa_dir/ffprobe.json"
duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$input_video")

vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$input_video")
profile=$(ffprobe -v error -select_streams v:0 -show_entries stream=profile -of default=nw=1:nk=1 "$input_video")
pix_fmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nw=1:nk=1 "$input_video")
width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$input_video")
height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$input_video")
fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$input_video")
frames=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nw=1:nk=1 "$input_video")
acodec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$input_video")
sample_rate=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "$input_video")
channels=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=nw=1:nk=1 "$input_video")

ffmpeg -hide_banner -i "$input_video" -vf "blackdetect=d=0.12:pix_th=0.02" -an -f null - 2> "$qa_dir/blackdetect.log" || true
ffmpeg -hide_banner -i "$input_video" -af "silencedetect=n=-45dB:d=0.5" -vn -f null - 2> "$qa_dir/silencedetect.log" || true
ffmpeg -hide_banner -nostats -i "$input_video" -map 0:a:0 -af "ebur128=peak=true" -f null - 2> "$qa_dir/loudness.log" || true
ffmpeg -v error -i "$input_video" -map 0:v:0 -c copy -f hash -hash sha256 "$qa_dir/video-stream.sha256"

if command -v shasum >/dev/null 2>&1; then
  LC_ALL=C LANG=C shasum -a 256 "$input_video" > "$qa_dir/file.sha256"
elif command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$input_video" > "$qa_dir/file.sha256"
fi

ffmpeg -y -hide_banner -loglevel error -i "$input_video" \
  -vf "select='isnan(prev_selected_t)+gte(t-prev_selected_t,${duration}/13)',scale=270:480,tile=4x3:padding=8:margin=8" \
  -frames:v 1 "$qa_dir/contact-sheet.jpg"

for fraction in 0.10 0.25 0.50 0.75 0.90; do
  timestamp=$(awk -v d="$duration" -v f="$fraction" 'BEGIN { printf "%.6f", d*f }')
  label=${fraction/./_}
  ffmpeg -y -hide_banner -loglevel error -i "$input_video" -ss "$timestamp" \
    -frames:v 1 -q:v 2 "$qa_dir/frames/${label}.jpg"
done

if [[ -n "$timestamps_file" ]]; then
  if [[ ! -f "$timestamps_file" ]]; then
    echo "QA_TIMESTAMPS_FILE does not exist: $timestamps_file" >&2
    exit 2
  fi
  while IFS=$'\t' read -r timestamp label; do
    [[ -z "${timestamp:-}" || "$timestamp" == \#* ]] && continue
    safe_label=$(printf '%s' "${label:-frame}" | tr -cs 'A-Za-z0-9._-' '_')
    ffmpeg -y -hide_banner -loglevel error -i "$input_video" -ss "$timestamp" \
      -frames:v 1 "$qa_dir/risk-frames/${safe_label}_${timestamp}s.png"
  done < "$timestamps_file"
fi

black_events=$(grep -c 'black_start:' "$qa_dir/blackdetect.log" || true)
silence_events=$(grep -c 'silence_start:' "$qa_dir/silencedetect.log" || true)
integrated_lufs=$(grep -E '^[[:space:]]+I:' "$qa_dir/loudness.log" | tail -1 | awk '{print $2}' || true)
lra_lu=$(grep -E '^[[:space:]]+LRA:' "$qa_dir/loudness.log" | tail -1 | awk '{print $2}' || true)
true_peak_dbfs=$(grep -E '^[[:space:]]+Peak:' "$qa_dir/loudness.log" | tail -1 | awk '{print $2}' || true)

moov_pos=$(LC_ALL=C grep -aob -m1 'moov' "$input_video" | cut -d: -f1 || true)
mdat_pos=$(LC_ALL=C grep -aob -m1 'mdat' "$input_video" | cut -d: -f1 || true)
faststart=unknown
if [[ -n "$moov_pos" && -n "$mdat_pos" ]]; then
  if (( moov_pos < mdat_pos )); then faststart=yes; else faststart=no; fi
fi

issue_count=0
issues_text=""
add_issue() {
  issue_count=$((issue_count + 1))
  issues_text="${issues_text}issue=$1"$'\n'
}

[[ "$vcodec" == "h264" ]] || add_issue "video codec is $vcodec, expected h264"
[[ "$pix_fmt" == "yuv420p" ]] || add_issue "pixel format is $pix_fmt, expected yuv420p"
[[ "$width" == "1080" && "$height" == "1920" ]] || add_issue "canvas is ${width}x${height}, expected 1080x1920"
[[ "$fps" == "24/1" || "$fps" == "24" ]] || add_issue "frame rate is $fps, expected 24fps"
[[ "$acodec" == "aac" ]] || add_issue "audio codec is $acodec, expected aac"
[[ "$sample_rate" == "48000" ]] || add_issue "sample rate is $sample_rate, expected 48000"
[[ "$channels" == "2" ]] || add_issue "audio channels are $channels, expected 2"

{
  echo "input=$input_video"
  echo "duration=$duration"
  echo "video_codec=$vcodec"
  echo "video_profile=$profile"
  echo "pixel_format=$pix_fmt"
  echo "canvas=${width}x${height}"
  echo "fps=$fps"
  echo "frame_count=$frames"
  echo "audio_codec=$acodec"
  echo "sample_rate=$sample_rate"
  echo "channels=$channels"
  echo "integrated_lufs=${integrated_lufs:-unknown}"
  echo "lra_lu=${lra_lu:-unknown}"
  echo "true_peak_dbfs=${true_peak_dbfs:-unknown}"
  echo "faststart=$faststart"
  echo "black_events=$black_events"
  echo "silence_events=$silence_events"
  echo "contact_sheet=$qa_dir/contact-sheet.jpg"
  echo "spec_issues=$issue_count"
  printf '%s' "$issues_text"
} > "$qa_dir/summary.txt"

cat "$qa_dir/summary.txt"

if (( issue_count > 0 )); then
  exit 1
fi
