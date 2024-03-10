# Mpeg4-Dash-Video-Converter

This Bash script automates the process of converting video files to MPEG-DASH compatible files. It is pretty opinionated and tries to satisfy 3 potential users:
1. A user with a good internet connection, he should get the best video and audio quality
2. A user with a decent connection, he should still get a high quality video and audi
3. A user with a very slow connection (think slow 3g). Quality will be poor but it will still play without buffering.

## Features
- Converts input video files into multiple bitrate versions
- Supports custom framerate, CRF values, resolution steps, and encoding preset
- Generates MPEG-DASH compatible files for adaptive streaming
- Automatically detects and uses the original video resolution
- Provides a simple command-line interface with customizable options

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
    - `--crf <value1,value2>`: Set one or more CRF values for different quality levels (default: 22,28).
    - `--steps <number>`: Set the number of resolution steps for the output videos (default: 5).
    - `--preset <preset>`: Set the x264 encoding preset (default: slower).

   Example usage:
   ```
   ./dashify.sh --framerate 30 --crf 20,24,28 --steps 4 --preset fast video1.mp4 video2.mp4
   ```

3. The script will process each input video file and generate the corresponding multi-bitrate versions and MPEG-DASH files in a separate directory named `<video_name>.dash`.

## Customization
You can customize the default values for the script by modifying the following variables at the beginning of the script:

- `default_framerate`: The default framerate for the output videos (default: 24).
- `default_crf_values`: An array of default CRF values for different quality levels (default: 22, 28).
- `default_steps`: The default number of resolution steps for the output videos (default: 5).
- `default_preset`: The default x264 encoding preset (default: slower).

Feel free to adjust these values according to your specific requirements.

## License
This script is released under the [MIT License](LICENSE). Feel free to use, modify, and distribute it as per the terms of the license.
