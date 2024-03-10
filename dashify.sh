#!/bin/bash
set -e

# Default values
default_framerate=24
default_crf_values=(22 28)
default_steps=5
default_preset="slower"

# Usage information
usage() {
  echo "Usage: $0 [options] <input_files...>"
  echo
  echo "Options:"
  echo "  --framerate <rate>       Set the framerate for the output videos (default: $default_framerate)."
  echo "  --crf <value1,value2>        Set one or more CRF (Constant Rate Factor) values for different quality levels (default: 22,28)."
  echo "  --steps <number>         Set the number of resolution steps for the output videos (default: $default_steps)."
  echo "  --preset <preset>        Set the x264 encoding preset (e.g., ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo) (default: $default_preset)."
  echo
  echo "  <input_files...>         One or more input video files to be processed."
  echo
  echo "This script converts input video files into multiple bitrate versions using the specified CRF values and generates MPEG-DASH compatible files."
  exit 1
}

# Parse command-line arguments
# Parse command-line arguments
framerate=$default_framerate
crf_values=("${default_crf_values[@]}")
steps=$default_steps
preset=$default_preset
files=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --framerate)
      framerate="$2"
      shift 2
      ;;
    --crf)
      IFS=',' read -r -a crf_values <<< "$2"
      shift 2
      ;;
    --steps)
      steps="$2"
      shift 2
      ;;
    --preset)
      preset="$2"
      shift 2
      ;;
    *)
      files+=("$1")
      shift
      ;;
  esac
done

# If no input files are provided, display usage information
if [ ${#files[@]} -eq 0 ]; then
  usage
fi

# Check for required programs
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed"
    exit 1
fi

if ! command -v MP4Box &> /dev/null; then
    echo "Error: MP4Box is not installed"
    exit 1
fi

# Function to convert video
convert_video() {
  local input_file=$1
  local output_dir=$2
  local base=$3
  local original_width=$4
  local original_height=$5

  # Audio conversion
  ffmpeg -y -i "$input_file" -c:a aac -ac 2 -b:a 128k -vn "${output_dir}/${base}_audio.m4a"

  # Video conversion at various resolutions and CRF values
  for ((i = 0; i < steps; i++)); do
    local res=$(( original_width / (i + 1) ))
    local height=$(( res * original_height / original_width ))
    for crf in "${crf_values[@]}"; do
      ffmpeg -y -i "$input_file" -an -c:v libx264 -preset "$preset" -x264opts "keyint=${framerate}:min-keyint=${framerate}:no-scenecut" -vf "scale=${res}:-2" -crf "$crf" -f mp4 "${output_dir}/${base}_${res}_crf${crf}.mp4"
    done
  done
}

# Function to generate DASH files
generate_dash() {
  local video_dir=$1
  local audio_file=$2
  local output_dir=$3
  local base=$4
  local original_width=$5

  MP4Box -dash 6000 -rap -frag-rap -profile live -bs-switching no -out "${output_dir}/stream.mpd" \
    $(for ((i = 0; i < steps; i++)); do
        local res=$(( original_width / (i + 1) ))
        for crf in "${crf_values[@]}"; do
          echo "${video_dir}/${base}_${res}_crf${crf}.mp4"
        done
      done) \
    "$audio_file"
}

# Main loop to process files
for input_file in "${files[@]}"; do
  filename=$(basename -- "$input_file")
  dirname=$(dirname -- "$input_file")
  base="${filename%.*}"
  dash_dir="${dirname}/${base}.dash"
  tmp_dir="${dirname}/${base}.tmp"

  mkdir -p "$dash_dir"
  mkdir -p "$tmp_dir"

  echo "Converting \"$filename\" to multi-bitrate video in MPEG-DASH"

  original_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$input_file")
  original_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$input_file")

  convert_video "$input_file" "$tmp_dir" "$base" "$original_width" "$original_height"
  generate_dash "$tmp_dir" "${tmp_dir}/${base}_audio.m4a" "$dash_dir" "$base" "$original_width"

  # Remove temporary files
  rm -rf "$tmp_dir"
done
