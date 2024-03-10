#!/bin/bash
set -e

# Default values
default_framerate=24
default_min_crf=22
default_max_crf=28
default_steps=4
default_preset="slower"
default_x265=0 # x265 encoding disabled by default
available_steps=(1 1.5 3 6 9 12 12 12)
available_audio_steps=(1 2 2 2 2 2 2 2)

# Usage information
usage() {
  echo "Usage: $0 [options] <input_files...>"
  echo
  echo "Options:"
  echo "  --framerate <rate>       Set the framerate for the output videos (default: $default_framerate)."
  echo "  --min-crf <value>        Set the minimum CRF value for the highest quality level (default: $default_min_crf)."
  echo "  --max-crf <value>        Set the maximum CRF value for the lowest quality level (default: $default_max_crf)."
  echo "  --steps <number>         Set the number of resolution steps for the output videos (default: $default_steps)."
  echo "  --preset <preset>        Set the x264 encoding preset (default: $default_preset)."
  echo "                     Enable x265 encoding for HEVC compatibility."
  echo
  echo "  <input_files...>         One or more input video files to be processed."
  echo
  echo "This script converts input video files into multiple bitrate versions using specified CRF values and generates MPEG-DASH compatible files."
  exit 1
}

# Parse command-line arguments
framerate=$default_framerate
min_crf=$default_min_crf
max_crf=$default_max_crf
steps=$default_steps
preset=$default_preset
x265=$default_x265
files=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --framerate)
      framerate="$2"
      shift 2
      ;;
    --min-crf)
      min_crf="$2"
      shift 2
      ;;
    --max-crf)
      max_crf="$2"
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
    --x265)
      x265=1
      shift
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

# Function to calculate the greatest common divisor (GCD)
gcd() {
  local a=$1
  local b=$2
  while [ $b -ne 0 ]; do
    local t=$b
    b=$((a % b))
    a=$t
  done
  echo $a
}

# Function to convert video
convert_video() {
  local input_file=$1
  local output_dir=$2
  local base=$3
  local original_width=$4
  local original_height=$5
  local codec=$6 # Add codec as a parameter

  # Audio conversion at various bitrates
  local original_bitrate=128 # Original audio bitrate in kbps
  for ((i=0; i<steps; i++)); do
    local audio_bitrate=$(bc <<< "scale=0; $original_bitrate / ${available_audio_steps[$i]} / 1")
    ffmpeg -y -i "$input_file" -c:a aac -ac 2 -b:a "${audio_bitrate}k" -vn "${output_dir}/${base}_audio_${audio_bitrate}.m4a"
  done

  # Calculate GCD and aspect ratio
  local gcd=$(gcd $original_width $original_height)
  local aspect_ratio_width=$((original_width / gcd))
  local aspect_ratio_height=$((original_height / gcd))

  # Calculate CRF increment for each step
  local crf_increment=$(bc <<< "scale=2; ($max_crf - $min_crf) / ($steps - 1)")

  # Video conversion at various resolutions and CRF values
  for ((i=0; i<steps; i++)); do
    local crf=$(bc <<< "scale=0; $min_crf + ($crf_increment * $i) / 1") # Calculate CRF for current step

    # Calculate the new height based on the step factor using bc
    local scaled_height=$(bc <<< "scale=0; $original_height / ${available_steps[$i]} / 1")
    scaled_height=$((scaled_height / 2 * 2)) # Make sure height is even

    # Calculate the new width based on the aspect ratio using bc and make sure it's even
    local scaled_width=$(bc <<< "scale=0; $scaled_height * $aspect_ratio_width / $aspect_ratio_height / 1")
    scaled_width=$((scaled_width / 2 * 2)) # Make sure width is even

    # Ensure that the scaled width does not exceed the original width
    if [ "$scaled_width" -gt "$original_width" ]; then
      scaled_width=$original_width
    fi

    # Determine the codec and file extension
    local codec_name
    local file_extension
    local codec_options
    if [ "$codec" == "libx264" ]; then
      codec_name="x264"
      file_extension="mp4"
      codec_options="-preset $preset -x264opts keyint=${framerate}:min-keyint=${framerate}:no-scenecut"
    elif [ "$codec" == "libx265" ]; then
      codec_name="x265"
      file_extension="mp4"
      codec_options="-preset $preset -x265-params keyint=${framerate}:min-keyint=${framerate}:no-scenecut=1"
    else
      echo "Unsupported codec: $codec"
      exit 1
    fi

    ffmpeg -y -i "$input_file" -an -c:v "$codec" $codec_options -vf "scale=${scaled_width}:${scaled_height}" -crf "$crf" -f mp4 "${output_dir}/${base}_${scaled_width}x${scaled_height}_${codec_name}_crf${crf}.${file_extension}"
  done
}

# Function to generate DASH files
generate_dash() {
  local video_dir=$1
  local audio_dir=$2
  local output_dir=$3

  # Find all x265 and x264 files, sort x265 files first
  local video_files=($(find "$video_dir" -name "*_x265_*.mp4" -exec echo {} \; | sort) $(find "$video_dir" -name "*_x264_*.mp4" -exec echo {} \; | sort))

  # Find all audio files
  local audio_files=($(find "$audio_dir" -name "*_audio_*.m4a" -exec echo {} \; | sort))

  # Create the MP4Box command with sorted video files
  local mp4box_cmd="MP4Box -dash 12000 -rap -frag-rap -profile live -bs-switching no -out \"${output_dir}/stream.mpd\""
  for video_file in "${video_files[@]}"; do
    mp4box_cmd+=" \"$video_file\""
  done
  for audio_file in "${audio_files[@]}"; do
    mp4box_cmd+=" \"$audio_file\""
  done

  # Execute the MP4Box command
  eval $mp4box_cmd
}

# Main loop to process files
for input_file in "${files[@]}"; do
  filename=$(basename -- "$input_file")
  dirname=$(dirname -- "$input_file")
  base="${filename%.*}"
  dash_dir="${dirname}/${base}.dash"
  tmp_dir="${dirname}/${base}.tmp"

  # Delete the tmp and dash directories if they already exist
  rm -rf "$dash_dir"
  rm -rf "$tmp_dir"

  # Create new tmp and dash directories
  mkdir -p "$dash_dir"
  mkdir -p "$tmp_dir"

  echo "Converting \"$filename\" to multi-bitrate video in MPEG-DASH"

  original_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$input_file")
  original_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$input_file")

  # Convert using x264 codec
  convert_video "$input_file" "$tmp_dir" "$base" "$original_width" "$original_height" "libx264"

  # If x265 option is set, convert using x265 codec
  if [ "$x265" -eq 1 ]; then
    convert_video "$input_file" "$tmp_dir" "$base" "$original_width" "$original_height" "libx265"
  fi

  generate_dash "$tmp_dir" "$tmp_dir" "$dash_dir"

  # Remove temporary files
  #rm -rf "$tmp_dir"
done
