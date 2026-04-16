#!/bin/bash
# Run WoW Addon Manager with virtual environment

# Change to script directory
cd "$(dirname "$0")"

# Check if venv exists
if [[ ! -d "venv" ]]; then
    echo "Virtual environment not found. Running setup..."
    ./setup.sh
fi

# Activate venv and run
source venv/bin/activate
python3 addon_manager.py
