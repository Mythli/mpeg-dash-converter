#!/bin/bash
set -e

# Default values
default_framerate=24
default_min_crf=22
default_max_crf=28
default_steps=4
default_preset="slower"
default_x265=0 # x265 encoding disabled by default
default_x264=0 # x265 encoding disabled by default
default_vp8=0 # x265 encoding disabled by default
default_vp9=0 # x265 encoding disabled by default
available_steps=(1 1.5 3 6 9 12 12 12)
available_audio_steps=(1 2 2 2 2 2 2 2)

# If the flag is turned on a folder should be created for the codec and a separate dash should be created for each codec

# Usage information
usage() {
  echo "Usage: $0 [options] <input_files...>"
  echo
  echo "Options:"
  echo "  --framerate <rate>       Set the framerate for the output videos (default: $default_framerate)."
  echo "  --min-crf <value>        Set the minimum CRF value for the highest quality level (default: $default_min_crf)."
  echo "  --max-crf <value>        Set the maximum CRF value for the lowest quality level (default: $default_max_crf)."
  echo "  --steps <number>         Set the number of resolution steps for the output videos (default: $default_steps)."
  echo "  --preset <preset>        Set the x264 encoding preset (default: $default_preset). This option is also mapped to vp8 and vp9 encoding speed"
#  echo "  --vp8                    Enable vp8 encoding"
#  echo "  --vp9                    Enable vp9 encoding"
  echo "  --x264                   Enable x264 encoding (default if no codec is selected)."
  echo "  --x265                   Enable x265 encoding for HEVC compatibility."
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
vp8=$default_vp8
vp9=$default_vp9
x264=$default_x264
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
    --vp8)
      vp8=1
      shift
      ;;
    --vp9)
      vp9=1
      shift
      ;;
    --x264)
      x264=1
      shift
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

# if no codec is selected, default to x264
if [ $x264 -eq 0 ] && [ $x265 -eq 0 ] && [ $vp8 -eq 0 ] && [ $vp9 -eq 0 ]; then
  x264=1
fi

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

# Function to map x264 preset to vp8/vp9 speed
calculate_speed() {
  local preset=$1
  case "$preset" in
    ultrafast)
      echo 4
      ;;
    superfast)
      echo 3
      ;;
    veryfast)
      echo 2
      ;;
    faster)
      echo 1
      ;;
    fast)
      echo 1
      ;;
    medium)
      echo 0
      ;;
    slow)
      echo 0
      ;;
    slower)
      echo 0
      ;;
    veryslow)
      echo 0
      ;;
    *)
      echo "Unsupported preset: $preset"
      exit 1
      ;;
  esac
}

convert_crf_x264_to_vp8() {
  local h264_crf=$1
  local vp8_crf

  # This is a heuristic conversion and may not be accurate for all cases.
  # The conversion is based on anecdotal evidence and may need to be adjusted
  # for specific use cases or preferences.

  if (( h264_crf <= 18 )); then
    vp8_crf=4
  elif (( h264_crf <= 23 )); then
    vp8_crf=$(( (h264_crf - 18) * 2 + 4 ))
  elif (( h264_crf <= 28 )); then
    vp8_crf=$(( (h264_crf - 23) * 3 + 14 ))
  elif (( h264_crf <= 35 )); then
    vp8_crf=$(( (h264_crf - 28) * 4 + 29 ))
  else
    vp8_crf=63 # VP8's CRF can go up to 63, but we cap it here for simplicity
  fi

  echo "$vp8_crf"
}

speed=$(calculate_speed "$preset")

convert_with_vp8() {
  local input_file=$1
  local output_dir=$2
  local base=$3
  local scaled_width=$4
  local scaled_height=$5
  local vp8_crf=$(convert_crf_x264_to_vp8 "$crf")
#  local vp8_crf=10
  # First pass
  ffmpeg -y -i "$input_file" -c:v libvpx -crf "$vp8_crf" -b:v 10M -speed 4 -pass 1 -an -vf "scale=${scaled_width}:${scaled_height}" -f webm /dev/null
  # Second pass
  ffmpeg -i "$input_file" -c:v libvpx -crf "$vp8_crf" -b:v 10M -speed "$speed" -pass 2 -an -vf "scale=${scaled_width}:${scaled_height}" -f webm "${output_dir}/${base}_${scaled_width}x${scaled_height}_vp8_crf${vp8_crf}.webm"
}

convert_with_vp9() {
  local input_file=$1
  local output_dir=$2
  local base=$3
  local scaled_width=$4
  local scaled_height=$5
  local crf=$6
  local vp8_crf=$(convert_crf_x264_to_vp8 "$crf")

  # First pass
  ffmpeg -y -i "$input_file" -c:v libvpx-vp9 -crf "$vp8_crf" -speed 4 -pass 1 -an -vf "scale=${scaled_width}:${scaled_height}" -f webm /dev/null
  # Second pass
  ffmpeg -i "$input_file" -c:v libvpx-vp9 -crf "$vp8_crf" -speed "$speed" -pass 2 -an -vf "scale=${scaled_width}:${scaled_height}" -f webm "${output_dir}/${base}_${scaled_width}x${scaled_height}_vp9_crf${vp8_crf}.webm"
}

convert_with_libx264() {
  local input_file=$1
  local output_dir=$2
  local base=$3
  local scaled_width=$4
  local scaled_height=$5
  local crf=$6
  ffmpeg -y -i "$input_file" -an -c:v libx264 -preset "$preset" -x264opts keyint="$framerate":min-keyint="$framerate":no-scenecut -vf "scale=${scaled_width}:${scaled_height}" -crf "$crf" -f mp4 "${output_dir}/${base}_${scaled_width}x${scaled_height}_x264_crf${crf}.mp4"
}

convert_with_libx265() {
  local input_file=$1
  local output_dir=$2
  local base=$3
  local scaled_width=$4
  local scaled_height=$5
  local crf=$6

   ffmpeg -y -i "$input_file" -an -c:v libx265 -preset "$preset" \
      -x265-params "keyint=${framerate}:min-keyint=${framerate}:no-scenecut=1" \
      -vf "scale=${scaled_width}:${scaled_height}" -crf "$crf" \
      -f mp4 "${output_dir}/${base}_${scaled_width}x${scaled_height}_x265_crf${crf}.mp4"
}

# Function to convert audio with open-source codec
convert_audio_opensource() {
  local input_file=$1
  local output_audio=$2
  local audio_bitrate=$3
  ffmpeg -i "$input_file" -vn -c:a libvorbis -b:a "${audio_bitrate}k" "$output_audio"
}

# Function to convert audio with proprietary codec
convert_audio_proprietary() {
  local input_file=$1
  local output_audio=$2
  local audio_bitrate=$3
  ffmpeg -i "$input_file" -vn -c:a aac -b:a "${audio_bitrate}k" "$output_audio"
}

# Function to convert audio based on video codec
convert_audio() {
  local input_file=$1
  local output_dir=$2
  local base=$3
  local video_codec=$4
  local original_bitrate=128

  # Determine if an open-source video codec is used like vp8 or vp9, use the open source function, else use the proprietary function
  if [[ "$video_codec" == "vp8" || "$video_codec" == "vp9" ]]; then
    for ((i=0; i<steps; i++)); do
      local audio_bitrate=$(bc <<< "scale=0; $original_bitrate / ${available_audio_steps[$i]} / 1")
      if [ -f "${output_dir}/${base}_audio_${audio_bitrate}.ogg" ]; then
        echo "File exists"
      else
        convert_audio_opensource "$input_file" "${output_dir}/${base}_audio_${audio_bitrate}.ogg" "$audio_bitrate"
      fi
    done
  else
    for ((i=0; i<steps; i++)); do
      local audio_bitrate=$(bc <<< "scale=0; $original_bitrate / ${available_audio_steps[$i]} / 1")

      if [ -f "${output_dir}/${base}_audio_${audio_bitrate}.m4a" ]; then
        echo "File exists"
      else
        convert_audio_proprietary "$input_file" "${output_dir}/${base}_audio_${audio_bitrate}.m4a" "$audio_bitrate"
      fi
    done
  fi
}

# Function to convert video
convert_video() {
  local input_file=$1
  local output_dir=$2
  local base=$3
  local original_width=$4
  local original_height=$5
  local codec=$6
  #local steps=$7
  #local min_crf=$8
  #local max_crf=$9
  #local preset=${10}
  #local framerate=${11}
  #local available_steps=("${@:12}") # Array of available steps for video scaling

  convert_audio "$input_file" "$output_dir" "$base" "$codec"

  # Calculate GCD and aspect ratio
  local gcd=$(gcd $original_width $original_height)
  local aspect_ratio_width=$((original_width / gcd))
  local aspect_ratio_height=$((original_height / gcd))

  # Calculate CRF increment for each step

  local steps_adjusted=$((steps > 1 ? steps : 2))
  local crf_increment=$(bc <<< "scale=2; ($max_crf - $min_crf) / ($steps_adjusted - 1)")

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

    # Call the appropriate codec-specific conversion function
    if [ "$codec" == "x264" ]; then
      convert_with_libx264 "$input_file" "$output_dir" "$base" "$scaled_width" "$scaled_height" "$crf"
    elif [ "$codec" == "x265" ]; then
      convert_with_libx265 "$input_file" "$output_dir" "$base" "$scaled_width" "$scaled_height" "$crf"
    elif [ "$codec" == "vp8" ]; then
      convert_with_vp8 "$input_file" "$output_dir" "$base" "$scaled_width" "$scaled_height" "$crf"
    elif [ "$codec" == "vp9" ]; then
      convert_with_vp9 "$input_file" "$output_dir" "$base" "$scaled_width" "$scaled_height" "$crf"
    else
      echo "Unsupported codec: $codec"
      exit 1
    fi
  done
}

generate_dash() {
  local media_dir=$1
  local output_dir=$2

  # Create the MP4Box command with the base options
  local mp4box_cmd="MP4Box -dash 12000 -rap -frag-rap -profile live -bs-switching no -out \"${output_dir}/stream.mpd\""

  # Find all video and audio files and sort them by size in descending order
  # The sort command uses -n for numeric sort, -r for reverse (descending), and -k2 to sort by the second column (file size)
  local sorted_files
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS uses a different syntax for stat and sort
    sorted_files=$(find "${media_dir}" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.m4a" -o -name "*.ogg" \) -exec stat -f"%z %N" {} \; | sort -nr -k1,1 | cut -d' ' -f2-)
  else
    # Linux
    sorted_files=$(find "${media_dir}" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.m4a" -o -name "*.ogg" \) -exec stat -c"%s %n" {} \; | sort -nr -k1,1 | cut -d' ' -f2-)
  fi

  # Add sorted files to the MP4Box command
  for media_file in $sorted_files; do
    mp4box_cmd+=" \"$media_file\""
  done

  echo "Executing MP4Box command: $mp4box_cmd"
  # exit 1

  # Execute the MP4Box command
  eval $mp4box_cmd
}

# Main loop to process files
for input_file in "${files[@]}"; do

  filename=$(basename -- "$input_file")
  dirname=$(dirname -- "$input_file")
  base="${filename%.*}"

  echo "Converting \"$filename\" to multi-bitrate video in MPEG-DASH"

  original_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$input_file")
  original_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$input_file")

  # Process each codec separately
  for codec in "x264" "x265" "vp8" "vp9"; do
    if [ "${!codec}" -eq 1 ]; then
      codec_dir="${dirname}/${base}_${codec}"
      tmp_dir="${codec_dir}.tmp"
      dash_dir="${codec_dir}.dash"

      # Delete the tmp and dash directories if they already exist
      rm -rf "$dash_dir"
      rm -rf "$tmp_dir"

      # Create new tmp and dash directories
      mkdir -p "$dash_dir"
      mkdir -p "$tmp_dir"

      # Convert video using the specified codec
      convert_video "$input_file" "$tmp_dir" "$base" "$original_width" "$original_height" "${codec}"

      # Generate DASH files for the codec
      generate_dash "$tmp_dir" "$dash_dir"
#      generate_dash_shaka "$tmp_dir" "$dash_dir"

      # Remove temporary files
      #rm -rf "$tmp_dir"
    fi
  done
done
