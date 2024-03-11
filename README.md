# Mpeg4-Dash-Video-Converter
This Bash script automates the process of converting video files to MPEG-DASH compatible files. It is designed to cater to users with varying internet connection speeds, ensuring the best possible quality for each user's bandwidth.

## Features
- Converts input video files into multiple bitrate versions for both video and audio.
- Supports custom framerate, minimum and maximum CRF values, resolution steps, and encoding preset.
- Generates MPEG-DASH compatible files for adaptive streaming.
- Automatically detects and uses the original video resolution.
- Provides a simple command-line interface with customizable options.
- Optional x265 encoding for HEVC compatibility.

## Usage
To use the script, follow these steps:
1. Install the script
   ```
   bash <(curl -sL https://raw.githubusercontent.com/Mythli/mpeg-dash-converter/main/src/download.sh)
   ```
2. Run the script with the desired options and input video files:
   ```
   dashify [options] <input_files...>
   ```

   Available options:
   - `--framerate <rate>`: Set the framerate for the output videos (default: 24).
   - `--min-crf <value>`: Set the minimum CRF value for the highest quality level (default: 22).
   - `--max-crf <value>`: Set the maximum CRF value for the lowest quality level (default: 28).
   - `--steps <number>`: Set the number of resolution steps for the output videos (default: 4).
   - `--preset <preset>`: Set the x264 encoding preset (default: slower).
   - `--x264`: Encode with x264 (highest compatibility)
   - `--x265`: Encode with x265 (highest compression)

   Example usage:
   ```
   dashify.sh --framerate 24 --min-crf 18 --max-crf 28 --steps 4 --preset fast --x265 --x264 video1.mp4 video2.mp4
   ```

3. The script will process each input video file and generate the corresponding multi-bitrate versions and MPEG-DASH files in a separate directory named `<video_name>.dash`.

## Customization
You can customize the default values for the script by modifying the following variables at the beginning of the script:

- `default_framerate`: The default framerate for the output videos (default: 24).
- `default_min_crf`: The default minimum CRF value for the highest quality level (default: 22).
- `default_max_crf`: The default maximum CRF value for the lowest quality level (default: 28).
- `default_steps`: The default number of resolution steps for the output videos (default: 4).
- `default_preset`: The default x264 encoding preset (default: slower).
- `default_x265`: The default setting for x265 encoding (disabled by default).
- `default_x264`: The default setting for x264 encoding (disabled by default).

Feel free to adjust these values according to your specific requirements.

## License
This script is released under the [MIT License](LICENSE). Feel free to use, modify, and distribute it as per the terms of the license.
