#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Base URL
BASE_URL="https://huggingface.co/datasets/karpathy/llmc-starter-pack/resolve/main/"

# Directory paths based on script location
SAVE_DIR_PARENT="$SCRIPT_DIR/.."
SAVE_DIR_TINY="$SCRIPT_DIR/data/tinyshakespeare"
SAVE_DIR_HELLA="$SCRIPT_DIR/data/hellaswag"

# Create the directories if they don't exist
mkdir -p "$SAVE_DIR_TINY"
mkdir -p "$SAVE_DIR_HELLA"

# Files to download
FILES=(
    "gpt2_124M.bin"
    "gpt2_124M_bf16.bin"
    "gpt2_124M_debug_state.bin"
    "gpt2_tokenizer.bin"
    "tiny_shakespeare_train.bin"
    "tiny_shakespeare_val.bin"
    "hellaswag_val.bin"
)

# Function to download files to the appropriate directory with retry and resume
download_file() {
    local FILE_NAME=$1
    local FILE_URL="${BASE_URL}${FILE_NAME}?download=true"
    local FILE_PATH

    # Determine the save directory based on the file name
    if [[ "$FILE_NAME" == tiny_shakespeare* ]]; then
        FILE_PATH="${SAVE_DIR_TINY}/${FILE_NAME}"
    elif [[ "$FILE_NAME" == hellaswag* ]]; then
        FILE_PATH="${SAVE_DIR_HELLA}/${FILE_NAME}"
    else
        FILE_PATH="${SAVE_DIR_PARENT}/${FILE_NAME}"
    fi

    local MAX_RETRIES=5
    local ATTEMPT=0
    local SUCCESS=0

    echo "Starting download: $FILE_NAME"

    while [ $ATTEMPT -lt $MAX_RETRIES ]; do
        # -L: follow redirects
        # -C -: resume broken downloads
        # --fail: fail silently on server errors (don't save HTML error pages)
        # -# : show simple progress bar
        if curl -L -C - --fail -# -o "$FILE_PATH" "$FILE_URL"; then
            SUCCESS=1
            break
        else
            ATTEMPT=$((ATTEMPT+1))
            echo "Warning: Download interrupted for $FILE_NAME. Retrying ($ATTEMPT/$MAX_RETRIES) in 3 seconds..."
            sleep 3
        fi
    done

    if [ $SUCCESS -eq 0 ]; then
        echo "Error: Failed to download $FILE_NAME completely after $MAX_RETRIES attempts."
    else
        echo "Successfully verified/downloaded: $FILE_NAME"
    fi
}

# Export the function and variables so they are available in subshells
export BASE_URL SAVE_DIR_TINY SAVE_DIR_HELLA SAVE_DIR_PARENT
export -f download_file

# Generate download commands
download_commands=()
for FILE in "${FILES[@]}"; do
    download_commands+=("download_file \"$FILE\"")
done

# Function to manage parallel jobs
run_in_parallel() {
    local batch_size=$1
    shift
    local i=0
    local command

    for command; do
        eval "$command" &
        ((i = (i + 1) % batch_size))
        if [ "$i" -eq 0 ]; then
            wait
        fi
    done

    wait
}

# Reduced batch size from 6 to 3 to prevent HuggingFace connection drops
run_in_parallel 1 "${download_commands[@]}"

echo "All download processes finished. Please check above for any persistent errors."