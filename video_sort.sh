#!/bin/bash

# Video File Organizer by Codec and Resolution
# Interactive menu-driven script

# Configuration
SOURCE_DIR="${1:-.}"  # Use first argument or current directory
OUTPUT_DIR="./organized_videos"
REPORT_FILE="video_scan_report.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to check and install ffprobe on macOS
check_and_install_ffprobe() {
    if command -v ffprobe &> /dev/null; then
        echo -e "${GREEN}✓ ffprobe is already installed${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}ffprobe is not installed.${NC}"
    
    # Check if running on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Check if Homebrew is installed
        if command -v brew &> /dev/null; then
            echo -e "${CYAN}Installing ffmpeg (includes ffprobe) via Homebrew...${NC}"
            brew install ffmpeg
            
            if command -v ffprobe &> /dev/null; then
                echo -e "${GREEN}✓ ffmpeg/ffprobe installed successfully!${NC}"
                return 0
            else
                echo -e "${RED}✗ Installation failed. Please install manually.${NC}"
                return 1
            fi
        else
            echo -e "${RED}Homebrew is not installed.${NC}"
            echo "Please install Homebrew first: https://brew.sh"
            echo "Or install ffmpeg manually from: https://ffmpeg.org"
            return 1
        fi
    else
        echo -e "${YELLOW}Non-macOS system detected.${NC}"
        echo "Please install ffmpeg manually:"
        echo "  Ubuntu/Debian: sudo apt install ffmpeg"
        echo "  Fedora: sudo dnf install ffmpeg"
        echo "  Arch: sudo pacman -S ffmpeg"
        return 1
    fi
}

# Function to scan files and create report
scan_and_report() {
    echo ""
    echo "========================================"
    echo "SCANNING VIDEO FILES"
    echo "========================================"
    echo "Source: $SOURCE_DIR"
    echo ""
    
    # Create report file
    {
        echo "VIDEO FILE SCAN REPORT"
        echo "Generated: $(date)"
        echo "Source Directory: $SOURCE_DIR"
        echo "========================================"
        echo ""
    } > "$REPORT_FILE"
    
    total_files=0
    failed_files=0
    
    # Arrays to store codec statistics
    declare -A codec_count
    declare -A resolution_count
    
    # Find all video files
    while IFS= read -r video_file; do
        ((total_files++))
        
        filename=$(basename "$video_file")
        echo -e "${CYAN}Scanning: $filename${NC}"
        
        # Extract codec information
        codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null)
        
        # Extract resolution
        width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null)
        height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null)
        
        # Check if we got valid data
        if [ -z "$codec" ] || [ -z "$width" ] || [ -z "$height" ]; then
            echo -e "${RED}  ✗ Failed to get video info${NC}"
            {
                echo "File: $filename"
                echo "  Status: ERROR - Could not read video information"
                echo ""
            } >> "$REPORT_FILE"
            ((failed_files++))
            continue
        fi
        
        # Determine resolution category
        if [ "$height" -ge 2160 ]; then
            resolution="4K (${width}x${height})"
        elif [ "$height" -ge 1440 ]; then
            resolution="2K (${width}x${height})"
        elif [ "$height" -ge 1080 ]; then
            resolution="1080p (${width}x${height})"
        elif [ "$height" -ge 720 ]; then
            resolution="720p (${width}x${height})"
        elif [ "$height" -ge 480 ]; then
            resolution="480p (${width}x${height})"
        else
            resolution="SD (${width}x${height})"
        fi
        
        # Update statistics
        ((codec_count[$codec]++))
        ((resolution_count[$resolution]++))
        
        echo -e "${GREEN}  ✓ Codec: $codec | Resolution: $resolution${NC}"
        
        # Write to report
        {
            echo "File: $filename"
            echo "  Codec: $codec"
            echo "  Resolution: $resolution"
            echo "  Dimensions: ${width}x${height}"
            echo ""
        } >> "$REPORT_FILE"
        
    done < <(find "$SOURCE_DIR" -maxdepth 1 -type f \( \
        -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o \
        -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" -o \
        -iname "*.webm" -o -iname "*.m4v" -o -iname "*.mpg" -o \
        -iname "*.mpeg" \))
    
    # Write summary to report
    {
        echo "========================================"
        echo "SUMMARY"
        echo "========================================"
        echo "Total files scanned: $total_files"
        echo "Successfully processed: $((total_files - failed_files))"
        echo "Failed: $failed_files"
        echo ""
        echo "CODEC BREAKDOWN:"
        for codec in "${!codec_count[@]}"; do
            echo "  $codec: ${codec_count[$codec]} file(s)"
        done
        echo ""
        echo "RESOLUTION BREAKDOWN:"
        for res in "${!resolution_count[@]}"; do
            echo "  $res: ${resolution_count[$res]} file(s)"
        done
    } >> "$REPORT_FILE"
    
    # Display summary
    echo ""
    echo "========================================"
    echo "SCAN COMPLETE!"
    echo "========================================"
    echo "Total files scanned: $total_files"
    echo "Successfully processed: $((total_files - failed_files))"
    echo "Failed: $failed_files"
    echo ""
    echo -e "${GREEN}Report saved to: $REPORT_FILE${NC}"
    echo ""
    
    # Show codec breakdown
    if [ ${#codec_count[@]} -gt 0 ]; then
        echo "Codec Breakdown:"
        for codec in "${!codec_count[@]}"; do
            echo "  $codec: ${codec_count[$codec]} file(s)"
        done
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to organize files by codec
organize_by_codec() {
    echo ""
    echo "========================================"
    echo "ORGANIZING FILES BY CODEC"
    echo "========================================"
    echo "Source: $SOURCE_DIR"
    echo "Output: $OUTPUT_DIR"
    echo ""
    
    read -p "This will move files. Continue? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return
    fi
    
    mkdir -p "$OUTPUT_DIR"
    
    # Create movement report
    MOVE_REPORT="video_organization_report.txt"
    {
        echo "VIDEO FILE ORGANIZATION REPORT"
        echo "Generated: $(date)"
        echo "Source Directory: $SOURCE_DIR"
        echo "Output Directory: $OUTPUT_DIR"
        echo "========================================"
        echo ""
    } > "$MOVE_REPORT"
    
    total_files=0
    processed_files=0
    failed_files=0
    
    declare -A codec_files
    
    # Find and process all video files
    while IFS= read -r video_file; do
        ((total_files++))
        
        filename=$(basename "$video_file")
        echo -e "\n${YELLOW}Processing: $filename${NC}"
        
        # Extract codec information
        codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null)
        
        # Extract resolution for display
        width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null)
        height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null)
        
        if [ -z "$codec" ]; then
            echo -e "${RED}  ✗ Failed to get video info - skipping${NC}"
            {
                echo "FAILED: $filename"
                echo "  Reason: Could not read video information"
                echo ""
            } >> "$MOVE_REPORT"
            ((failed_files++))
            continue
        fi
        
        # Determine resolution category
        if [ "$height" -ge 2160 ]; then
            resolution="4K_${width}x${height}"
        elif [ "$height" -ge 1440 ]; then
            resolution="2K_${width}x${height}"
        elif [ "$height" -ge 1080 ]; then
            resolution="1080p_${width}x${height}"
        elif [ "$height" -ge 720 ]; then
            resolution="720p_${width}x${height}"
        elif [ "$height" -ge 480 ]; then
            resolution="480p_${width}x${height}"
        else
            resolution="SD_${width}x${height}"
        fi
        
        # Create target directory for codec and resolution
        target_dir="$OUTPUT_DIR/$codec/$resolution"
        
        echo "  Codec: $codec"
        echo "  Resolution: $resolution"
        echo "  Target: $target_dir"
        
        # Create target directory
        mkdir -p "$target_dir"
        
        # Move the file
        if mv "$video_file" "$target_dir/"; then
            echo -e "${GREEN}  ✓ Moved successfully${NC}"
            ((processed_files++))
            codec_files[$codec]+="    - $filename (${width}x${height})"$'\n'
            
            {
                echo "MOVED: $filename"
                echo "  Codec: $codec"
                echo "  Resolution: ${width}x${height}"
                echo "  From: $video_file"
                echo "  To: $target_dir/$filename"
                echo ""
            } >> "$MOVE_REPORT"
        else
            echo -e "${RED}  ✗ Failed to move${NC}"
            ((failed_files++))
            
            {
                echo "FAILED: $filename"
                echo "  Reason: Move operation failed"
                echo ""
            } >> "$MOVE_REPORT"
        fi
        
    done < <(find "$SOURCE_DIR" -maxdepth 1 -type f \( \
        -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o \
        -iname "*.mov" -o -iname "*.wmv" -o -iname "*.flv" -o \
        -iname "*.webm" -o -iname "*.m4v" -o -iname "*.mpg" -o \
        -iname "*.mpeg" \))
    
    # Write detailed summary to report
    {
        echo "========================================"
        echo "ORGANIZATION SUMMARY"
        echo "========================================"
        echo "Total files found: $total_files"
        echo "Successfully moved: $processed_files"
        echo "Failed: $failed_files"
        echo ""
        echo "FILES BY CODEC:"
        echo ""
        for codec in "${!codec_files[@]}"; do
            echo "[$codec]"
            echo "${codec_files[$codec]}"
        done
        echo ""
        echo "FOLDER STRUCTURE:"
        find "$OUTPUT_DIR" -type d | sort
    } >> "$MOVE_REPORT"
    
    # Display summary
    echo ""
    echo "========================================"
    echo "ORGANIZATION COMPLETE!"
    echo "========================================"
    echo "Total files found: $total_files"
    echo "Successfully moved: $processed_files"
    echo "Failed: $failed_files"
    echo ""
    echo -e "${GREEN}Complete report saved to: $MOVE_REPORT${NC}"
    echo ""
    echo "Files organized by codec:"
    for codec in "${!codec_files[@]}"; do
        count=$(echo "${codec_files[$codec]}" | grep -c "^    - ")
        echo "  $codec: $count file(s) in $OUTPUT_DIR/$codec/"
    done
    echo ""
    
    read -p "Press Enter to continue..."
}

# Function to display main menu
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "========================================"
    echo "   VIDEO FILE ORGANIZER"
    echo "========================================"
    echo -e "${NC}"
    echo "Source Directory: $SOURCE_DIR"
    echo ""
    echo "1. Scan files and create codec report"
    echo "2. Organize files by codec (move files)"
    echo "3. Change source directory"
    echo "4. Exit"
    echo ""
}

# Main program loop
main() {
    # Check for ffprobe first
    check_and_install_ffprobe
    if [ $? -ne 0 ]; then
        echo ""
        echo "Cannot proceed without ffprobe. Exiting."
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Select an option (1-4): " choice
        
        case $choice in
            1)
                scan_and_report
                ;;
            2)
                organize_by_codec
                ;;
            3)
                echo ""
                read -p "Enter new source directory path: " new_dir
                if [ -d "$new_dir" ]; then
                    SOURCE_DIR="$new_dir"
                    echo -e "${GREEN}Source directory changed to: $SOURCE_DIR${NC}"
                else
                    echo -e "${RED}Directory does not exist!${NC}"
                fi
                sleep 2
                ;;
            4)
                echo ""
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Run the main program
main
