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
VIDEO="/tmp/youtubetogif_video.mp4"
VIDEOTRIMMED="/tmp/youtubetogif_video_trimmed.mp4"
FRAMES="/tmp/youtubetogif_frames"
FRAMESCROPPED="/tmp/youtubetogif_frames_cropped"

cd /tmp

function cleanup {
	[[ -e $VIDEOTRIMMED ]] && rm -v $VIDEOTRIMMED
	[[ -e $FRAMES ]]  && rm -rv $FRAMES
	[[ -e $FRAMESCROPPED ]]  && rm -rv $FRAMESCROPPED
}

function videoExists {
	[[ -e $VIDEO ]]
	return $?
}

function useExistingVideo {
	zenity --question --title="$ZTITLE" --text="Use existing video?"
	return $?
}

function getURL {
	echo $(zenity --entry --title="$ZTITLE" --text="Enter Youtube URL")
}

function downloadVideo {
	[[ -z $1 ]] && exit 1 # abort if input is empty
	# TODO: verify URL
	xterm -e "youtube-dl \"$1\" -f bestvideo --output $VIDEO || read -p \"Press any key to continue...\""
}

function getStartTime {
	echo $(zenity --entry --title="$ZTITLE" --text="Enter start time" --entry-text="00:00:00")
}

function getDuration {
	echo $(zenity --entry --title="$ZTITLE" --text="Enter duration" --entry-text="0")
}

function trimVideo {
	start=$(getStartTime)
	duration=$(getDuration)
	xterm -e "ffmpeg -i $VIDEO -ss $start -t $duration $VIDEOTRIMMED || read -p \"Press any key to continue...\""
}

function trimmedExists {
	[[ -e $VIDEOTRIMMED ]]
	return $?
}

function getFPS {
	echo $(zenity --entry --title="$ZTITLE" --text="Enter FPS" --entry-text="7")
}

function makeFrames {
	xterm -e "ffmpeg -i $VIDEOTRIMMED -r $(getFPS) $FRAMES/frame-%3d.png || read -p \"Press any key to continue...\""
}

cleanup

if ! (videoExists && useExistingVideo); then # download new video only if it doesn't exist or the user chooses not to use it
	videoExists && rm -v $VIDEO          # delete video if it already exists since we're downloading a new one
	downloadVideo $(getURL)              # download video based on user input
	videoExists || exit 1                # abort if video doesn't exist, i.e. download failed
fi

trimVideo                                    # trim video based on user input
trimmedExists || exit 1                      # abort if trimmed video doesn't exist, i.e. trim failed
mkdir $FRAMES                                # create directory for frames
makeFrames                                   # turn trimmed video into still frames
geeqie $FRAMES > /dev/null 2>&1              # let user delete frames and note dimensions
exit

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
