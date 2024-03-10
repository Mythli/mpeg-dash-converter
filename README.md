# Mpeg4-Dash-Video-Converter

This Bash script automates the process of converting video files into multiple bitrate versions using the specified CRF (Constant Rate Factor) values and generates MPEG-DASH compatible files. It utilizes FFmpeg and MP4Box to achieve this.

## Features
- Converts input video files into multiple bitrate versions
- Supports custom framerate, CRF values, resolution steps, and encoding preset
- Generates MPEG-DASH compatible files for adaptive streaming
- Automatically detects and uses the original video resolution
- Provides a simple command-line interface with customizable options

## Prerequisites
Before running the script, ensure that you have the following dependencies installed:
- FFmpeg: A powerful multimedia framework for handling video and audio processing
- MP4Box: A tool for creating and manipulating MP4 files, part of the GPAC framework

## Usage
To use the script, follow these steps:
1. Download the `dashify.sh` script and place it in a directory accessible from your command line.

2. Make the script executable by running the following command:
   ```
   chmod +x dashify.sh
   ```

3. Run the script with the desired options and input video files:
   ```
   ./dashify.sh [options] <input_files...>
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

4. The script will process each input video file and generate the corresponding multi-bitrate versions and MPEG-DASH files in a separate directory named `<video_name>.dash`.

## Customization
You can customize the default values for the script by modifying the following variables at the beginning of the script:

- `default_framerate`: The default framerate for the output videos (default: 24).
- `default_crf_values`: An array of default CRF values for different quality levels (default: 22, 28).
- `default_steps`: The default number of resolution steps for the output videos (default: 5).
- `default_preset`: The default x264 encoding preset (default: slower).

Feel free to adjust these values according to your specific requirements.

## License
This script is released under the [MIT License](LICENSE). Feel free to use, modify, and distribute it as per the terms of the license.
