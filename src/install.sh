#!/usr/bin/env bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
script_path=$(realpath "$0")

check_and_provide_install_commands() {
    local missing_tools=0
    local tools=(
        "ffmpeg"
        "MP4Box"
    )

    # Detect package manager and prepare installation commands
    local pkg_manager
    local install_commands=()

    if command -v apt-get &> /dev/null; then
        pkg_manager="sudo apt-get install"
        install_commands+=(
            "sudo apt-get install ffmpeg"
            "sudo apt-get install gpac" # MP4Box is part of the GPAC package
        )
    elif command -v yum &> /dev/null; then
        pkg_manager="sudo yum install"
        install_commands+=(
            "sudo yum install ffmpeg"
            "sudo yum install gpac" # MP4Box is part of the GPAC package
        )
    elif command -v dnf &> /dev/null; then
        pkg_manager="sudo dnf install"
        install_commands+=(
            "sudo dnf install ffmpeg"
            "sudo dnf install gpac" # MP4Box is part of the GPAC package
        )
    elif command -v pacman &> /dev/null; then
        pkg_manager="sudo pacman -S"
        install_commands+=(
            "sudo pacman -S ffmpeg"
            "sudo pacman -S gpac" # MP4Box is part of the GPAC package
        )
    elif command -v zypper &> /dev/null; then
        pkg_manager="sudo zypper install"
        install_commands+=(
            "sudo zypper install ffmpeg"
            "sudo zypper install gpac" # MP4Box is part of the GPAC package
        )
    elif command -v brew &> /dev/null; then
        pkg_manager="brew install"
        install_commands+=(
            "brew install ffmpeg"
            "brew install gpac" # MP4Box is part of the GPAC package
        )
    else
        echo "Error: No known package manager found. Please install the missing tools manually." >&2
        return 1
    fi

    # Check for required tools
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo "Error: Required tool '$tool' is not installed." >&2
            case "$tool" in
                "ffmpeg")
                    echo "To install 'ffmpeg', run: ${install_commands[0]}" >&2
                    ;;
                "MP4Box")
                    echo "To install 'MP4Box', run: ${install_commands[1]}" >&2
                    ;;
            esac
            missing_tools=1
        fi
    done

    if [ "$missing_tools" -ne 0 ]; then
        echo "One or more required tools are missing." >&2
        return 1
    fi

    echo "All required tools are installed."
    return 0
}

detect_shell_config() {
  # Determine the operating system
  case "$(uname -s)" in
    Darwin)
      os="osx"
      ;;
    Linux)
      os="linux"
      ;;
    *)
      echo "Unsupported operating system."
      return 1
      ;;
  esac

  # Determine the shell and the corresponding config file
  case "$SHELL" in
    */zsh)
      echo "${HOME}/.zshrc"
      ;;
    */bash)
      if [ "$os" = "osx" ]; then
        echo "${HOME}/.bash_profile"
      else
        echo "${HOME}/.bashrc"
      fi
      ;;
    *)
      echo "Unsupported shell."
      return 1
      ;;
  esac
}

add_alias_to_config() {
  local script_path="$1"
  local script_name=$(basename "$script_path" .sh)  # Exclude the .sh extension
  local shell_config="$2"

  # Add the alias to the shell configuration file
  if [ -f "$shell_config" ]; then
    if ! grep -q "alias $script_name=" "$shell_config"; then
      echo "alias $script_name='$script_path'" >> "$shell_config"
      echo "Alias for $script_name added to $shell_config"
    else
      echo "Alias for $script_name already exists in $shell_config"
    fi
  else
    echo "Shell configuration file not found."
    return 1
  fi
}

source_shell_config() {
  local shell_config="$1"
  if [ -f "$shell_config" ]; then
    echo "Run 'source \"$shell_config\"' to make the alias available."
  else
    echo "Shell configuration file not found."
    return 1
  fi
}

add_alias() {
  local script_path="$1"
  local shell_config=$(detect_shell_config)
  if [ $? -eq 0 ]; then
    add_alias_to_config "$script_path" "$shell_config"
    source_shell_config "$shell_config"
  fi
}

install() {
  if ! check_and_provide_install_commands; then
      exit 1
  fi
  add_alias "$script_dir/dashify.sh"
  $script_dir/dashify.sh
}

install
