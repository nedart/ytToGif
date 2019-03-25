#!/bin/bash

# geeqie is recommended for viewing frames
# TODO: safety checks
# TODO: use zenity instead of read
# TODO: ability to make more than one gif per video / reuse existing video
# TODO: ability to go back steps if mistakes are made
# TODO: dependency checker (ffmpeg, imagemagick, zenity, and youtube-dl)
# TODO: consistency with variables names, file names, and project name
# TODO: prompting for a new size relies on the user knowing the syntax for -geometry; fix this

# exit script on command failure
set -e

# create working directory name using time since Epoch to ensure uniqueness
EPOCH=$(date +%s)
mkdir "/tmp/ytgif-$EPOCH"

# cd to previous command's last argument; our working directory
cd "$_"

# tell user where the working directory is
echo "Created working directory at $(pwd)"

# prompt user for URL
read -p "Enter Youtube URL: " URL

# download URL
printf "Downloading..."
youtube-dl "$URL" --output "video.%(ext)s" --no-warnings >/dev/null
echo "Done!"

# get downloaded video filename and extension
ORIGINAL=$(echo video*)
EXT=${ORIGINAL##*.}

# prompt user for where to start and end the trim
read -p "Enter start time (mm:ss): " STARTTIME
read -p "Enter duration in seconds: " DURATION

# trim video based on user input
printf "Trimming..."
ffmpeg -i "$ORIGINAL" -ss "00:$STARTTIME" -t "00:00:$DURATION" "trimmed.$EXT" -loglevel fatal
echo "Done!"

# prompt user for FPS to extract from video
read -p "Enter FPS for converting video to images [15]: " FPS
[[ -z "$FPS" ]] && FPS=15

# convert trimmed video to images
mkdir frames
printf "Converting to frames..."
ffmpeg -i "trimmed.$EXT" -r $FPS frames/frame-%3d.png -loglevel fatal
echo "Done!"

# open working directory for user
echo "Individual frames may be edited now"
xdg-open ./ & >/dev/null 2>&1

# prompt user for crop dimensions
read -p "Enter X for top-left corner: " X1
read -p "Enter Y for top-left corner: " Y1
read -p "Enter X for bottom-right corner: " X2
read -p "Enter Y for bottom-right corner: " Y2
WIDTH=$(($X2-$X1))
HEIGHT=$(($Y2-$Y1))
read -p "Resize from ${WIDTH}x${HEIGHT}? [none]: " DIMENSIONS

# crop images based on user input
mkdir cropped
if [[ -z $DIMENSIONS ]]; then
	printf "Cropping..."
	mogrify -crop ${WIDTH}x${HEIGHT}+${X1}+${Y1} +repage -path cropped frames/*
else
	printf "Cropping and resizing..."
	mogrify -crop ${WIDTH}x${HEIGHT}+${X1}+${Y1} -geometry $DIMENSIONS +repage -path cropped frames/*
fi
echo "Done!"

# get user input on GIF animation speed
read -p "Specify the speed of the GIF animation [8]: " SPEED
[[ -z $SPEED ]] && SPEED=8

# create and open GIF
printf "Creating GIF..."
convert -delay $SPEED -loop 0 cropped/* $HOME/ytgif-$EPOCH.gif
echo "Done!"
xdg-open "ytgif-$EPOCH.gif" & >/dev/null 2>&1

# prompt to clean up
read -p "Delete temp files? [Y/N]: " DELETE
[[ $DELETE == [yY] ]] && rm -r *
