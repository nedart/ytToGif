#!/bin/bash

# TODO: steps 3,4,5 don't display a terminal window (no output); display one anyway
#       alternatively display progress using a loop and zenity
# TODO: ability to tweak frame quality as well as size/crop (/w preview?)
# TODO: ability to go back steps if mistakes are made
# TODO: dependency checker (xterm, ffmpeg, imagemagick, zenity, geeqie, pngquant, and youtube-dl)
# TODO: commands assume youtube-dl will create an mp4; is this always the case?

#################
### CONSTANTS ###
#################

ZTITLE="Youtube to GIF"
VIDEO="/tmp/youtubetogif_video.mp4"
VIDEOTRIMMED="/tmp/youtubetogif_video_trimmed.mp4"
FRAMES="/tmp/youtubetogif_frames"

#################
### FUNCTIONS ###
#################

function yesno {
	zenity --question --title="$ZTITLE" --text="$1"
	return $?
}

function input {
	if [[ -z $2 ]]; then
		echo $(zenity --entry --title="$ZTITLE" --text="$1")
	else
		echo $(zenity --entry --title="$ZTITLE" --text="$1" --entry-text="$2")
	fi
}

function download {
	xterm -e "youtube-dl "$1" -f bestvideo/best --output $VIDEO || read -p \"Press any key to continue...\""
}

function trim {
	xterm -e "ffmpeg -ss $1 -i $VIDEO -t $2 $VIDEOTRIMMED || read -p \"Press any key to continue...\""
}

function makeFrames {
	xterm -e "ffmpeg -i $VIDEOTRIMMED -r $1 $FRAMES/frame-%3d.png || read -p \"Press any key to continue...\""
}

function getSize {
	echo $(zenity --forms --title="$ZTITLE" --text="Crop dimensions" \
		--add-entry="X1" \
		--add-entry="Y1" \
		--add-entry="X2" \
		--add-entry="Y2" \
		--add-entry="OutX" \
		--add-entry="OutY")
}

###############################
### STEP 0: CLEANUP & SETUP ###
###############################

# it's easier to have this at the start of the script instead
# of the end when it comes to testing and debugging (i.e. no
# need to manually remove old files if the script does not
# fully execute)
[[ -e $VIDEOTRIMMED ]] && rm -v $VIDEOTRIMMED
[[ -e $FRAMES ]]  && rm -rv $FRAMES
cd /tmp

#############################
### STEP 1: ACQUIRE VIDEO ###
#############################

if ! ([[ -e $VIDEO ]] && $(yesno "Use existing video?")); then # download new video only if it doesn't exist or the user chooses not to use it
	[[ -e $VIDEO ]] && rm -v $VIDEO                        # delete video if it already exists since we're downloading a new one
	URL=$(input "Enter Youtube URL")                       # get URL from user
	[[ -z $URL ]] && exit 1                                # abort if URL is empty, i.e. user canceled
	download "$URL"                                        # download video
	[[ -e $VIDEO ]] || exit 1                              # abort if video doesn't exist, i.e. download failed
fi

#################################
### STEP 2: CONVERT TO FRAMES ###
#################################

begin=$(input "Enter start time" "00:00:00")                          # get start time from user
[[ -z $begin ]] && exit 1                                             # abort if input is empty, i.e. user canceled
duration=$(input "Enter duration")                                    # get duration from user
[[ -z $duration ]] && exit 1                                          # abort if input is empty, i.e. user canceled
trim $begin $duration                                                 # trim video based on user input
[[ -e $VIDEOTRIMMED ]] || exit 1                                      # abort if trimmed video doesn't exist, i.e. trim failed
mkdir $FRAMES                                                         # make directory for images
fps=$(input "Enter FPS" "15")                                         # get FPS from user
[[ -z $fps ]] && exit 1                                               # abort if FPS is empty, i.e. user cancelled
makeFrames $fps                                                       # turn trimmed video into still frames
# TODO: killing ffmpeg still results in an output file; safety check?
# TODO: make sure frames folder is not empty, i.e. make frames failed

###########################
### STEP 3: CROP FRAMES ###
###########################

geeqie $FRAMES > /dev/null 2>&1                                   # let user delete frames and note dimensions
IFS='|' read -ra size <<< $(getSize)                              # get dimensions from user
[[ -z ${size[0]} ]] && exit 1                                     # abort if X1 is empty, i.e. user cancelled / input error
[[ -z ${size[1]} ]] && exit 1                                     # abort if Y1 is empty, i.e. user cancelled / input error
[[ -z ${size[2]} ]] && exit 1                                     # abort if X2 is empty, i.e. user cancelled / input error
[[ -z ${size[3]} ]] && exit 1                                     # abort if Y2 is empty, i.e. user cancelled / input error
width=$((${size[2]}-${size[0]}))                                  # calculate width from X values
height=$((${size[3]}-${size[1]}))                                 # calculate height from Y values
if ([[ -n ${size[4]} ]] || [[ -n ${size[5]} ]]); then             # determine if user defined a new size
	# TODO: why can't we resize with both a width and height?
	mogrify -crop ${width}x${height}+${size[0]}+${size[1]} \
		-geometry ${size[4]}x${size[5]} \
		+repage \
		$FRAMES/*                                         # crop frames with custom size
else
	mogrify -crop ${width}x${height}+${size[0]}+${size[1]} \
		+repage \
		$FRAMES/*                                         # crop frames without custom size
fi

##############################
### STEP 4: ADJUST QUALITY ###
##############################

# for frame in $FRAMES/*; do
# 	pngquant $frame
# 	rm $frame
# done

##########################
### STEP 5: CREATE GIF ###
##########################

speed=$(input "Enter GIF speed" "8")                     # get GIF speed from user
[[ -z $speed ]] && exit 1                                # abort if input is empty, i.e. user cancelled
epoch=$(date +%s)                                        # get time since epoch for a unique output name
convert -delay $speed -loop 0 $FRAMES/* $HOME/$epoch.gif # convert frames into GIF
xdg-open $HOME/$epoch.gif >/dev/null 2>&1 &              # open GIF


