#!/bin/bash
# Setup script for WoW Addon Manager

set -e

echo "=========================================="
echo "  WoW Addon Manager Setup"
echo "=========================================="
echo

# Check if we're in the addon_manager directory
if [[ ! -f "addon_manager.py" ]]; then
    echo "Error: Please run this script from the addon_manager directory"
    exit 1
fi

# Create virtual environment
if [[ ! -d "venv" ]]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Activate and install dependencies
echo
echo "Installing dependencies..."
source venv/bin/activate
pip install --upgrade pip > /dev/null 2>&1
pip install inquirer

echo
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo
echo "To run the addon manager:"
echo "  cd addon_manager"
echo "  source venv/bin/activate"
echo "  python3 addon_manager.py"
echo
echo "Or use the run script:"
echo "  ./run.sh"
echo
