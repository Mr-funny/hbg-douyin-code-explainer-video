#!/usr/bin/env bash
set -euo pipefail

repo_url="https://github.com/Mr-funny/hbg-douyin-code-explainer-video.git"
skill_name="hbg-douyin-code-explainer-video"
legacy_skill_name="douyin-code-explainer-video"
install_kind="codex"
custom_target=""

usage() {
  echo "Usage: install.sh [--claude] [--target <skills-directory>]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude)
      install_kind="claude"
      shift
      ;;
    --target)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      custom_target=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for required in git mktemp; do
  command -v "$required" >/dev/null 2>&1 || {
    echo "Missing required command: $required" >&2
    exit 2
  }
done

if [[ -n "$custom_target" ]]; then
  skills_root=$custom_target
elif [[ "$install_kind" == "claude" ]]; then
  skills_root="$HOME/.claude/skills"
elif [[ -n "${CODEX_HOME:-}" ]]; then
  skills_root="$CODEX_HOME/skills"
else
  skills_root="$HOME/.codex/skills"
fi

target_dir="$skills_root/$skill_name"
legacy_dir="$skills_root/$legacy_skill_name"
temp_dir=$(mktemp -d)
cleanup() {
  [[ -d "$temp_dir" ]] && rm -r "$temp_dir"
}
trap cleanup EXIT

git clone --depth 1 "$repo_url" "$temp_dir/repo" >/dev/null

mkdir -p "$skills_root"
if [[ ! -e "$target_dir" && -e "$legacy_dir" ]]; then
  legacy_backup="${legacy_dir}.backup.$(date +%Y%m%d-%H%M%S)"
  mv "$legacy_dir" "$legacy_backup"
  echo "Backed up legacy skill to $legacy_backup"
fi
if [[ -e "$target_dir" ]]; then
  backup_dir="${target_dir}.backup.$(date +%Y%m%d-%H%M%S)"
  mv "$target_dir" "$backup_dir"
  echo "Backed up existing skill to $backup_dir"
fi

mkdir -p "$target_dir"
cp "$temp_dir/repo/SKILL.md" "$target_dir/SKILL.md"
cp -R "$temp_dir/repo/agents" "$target_dir/agents"
cp -R "$temp_dir/repo/references" "$target_dir/references"
cp -R "$temp_dir/repo/scripts" "$target_dir/scripts"
chmod +x "$target_dir/scripts/"*.sh

test -f "$target_dir/SKILL.md"
bash -n "$target_dir/scripts/mix_bgm.sh"
bash -n "$target_dir/scripts/final_media_qa.sh"

echo "Installed $skill_name to $target_dir"
echo "Invoke it as \$$skill_name"
