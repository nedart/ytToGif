#!/bin/bash

# TODO: safety checks
# TODO: modularize with functions
# TODO: use zenity instead of read
# TODO: ability to make more than one gif per video / reuse existing video
# TODO: ability to tweak frame quality as well as size/crop (/w preview?)
# TODO: ability to go back steps if mistakes are made
# TODO: dependency checker (xterm, ffmpeg, imagemagick, zenity, geeqie, and youtube-dl)
# TODO: consistency with variables names, file names, and project name
# TODO: prompting for a new size relies on the user knowing the syntax for -geometry; fix this

ZTITLE="Youtube to GIF"
VIDEOPRE="/tmp/youtubetogifvideo"

cd /tmp

function videoExists {
	ls $VIDEOPRE*[mkv,mp4,flv] >/dev/null 2>&1
	return $?
}

function getVideoFilename {
	echo $VIDEOPRE*[mkv,mp4,flv]
}

function getVideoExt {
	filename=$(getVideoFilename)
	echo "${filename##*.}"
}

function rmVideoFiles {
	rm -v $VIDEOPRE*
}

function useExistingVideo {
	zenity --question --title="$ZTITLE" --text="Use existing video?"
	return $?
}

function getURL {
	echo $(zenity --entry --title="$ZTITLE" --text="Enter Youtube URL")
}

function downloadVideo {
	[[ -z $1 ]] && exit 1
	# TODO: verify URL
	xterm -e "youtube-dl \"$1\" --output \"$VIDEOPRE\"; read -p \"Press any key to continue...\""
}

function getStartTime {
	echo $(zenity --entry --title="$ZTITLE" --text="Enter start time" --entry-text="00:00:00")
}

function getDuration {
	echo $(zenity --entry --title="$ZTITLE" --text="Enter duration" --entry-text="0")
}

function trimVideo {
	ext=$(getVideoExt)
	start=$(getStartTime)
	duration=$(getDuration)
	output="${VIDEOPRE}_trimmed.$ext"
	[[ -e $output ]] && rm -v $output
	xterm -e "ffmpeg -i $(getVideoFilename) -ss $start -t $duration $output; read -p \"Press any key to continue...\""
}

# download new video only if video doesn't exist or the user chooses not to use it
if ! (videoExists && useExistingVideo); then
	rmVideoFiles
	downloadVideo $(getURL)
	videoExists || exit 1
fi

trimVideo
exit

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
geeqie frames > /dev/null 2>&1

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
xdg-open "$HOME/ytgif-$EPOCH.gif" & >/dev/null 2>&1

# prompt to clean up
read -p "Delete temp files? [Y/N]: " DELETE
[[ $DELETE == [yY] ]] && rm -r *
