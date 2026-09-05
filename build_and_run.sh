#!/bin/bash

echo "Building Calibrex..."
cd /Users/kapilthakare/calibrex

# Try to build with swift build
swift build 2>&1 | tail -20

if [ $? -eq 0 ]; then
    echo "Build successful! Running Calibrex..."
    swift run Calibrex &
else
    echo "Build failed. Please check the errors above."
    echo ""
    echo "To run manually with Xcode:"
    echo "1. Open Package.swift in Xcode"
    echo "2. Select Calibrex scheme"
    echo "3. Press Cmd+R to build and run"
fi
