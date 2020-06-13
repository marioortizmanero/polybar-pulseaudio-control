#!/usr/bin/env bash

##################################################################
# Polybar Pulseaudio Control                                     #
# https://github.com/marioortizmanero/polybar-pulseaudio-control #
##################################################################

# Script configuration (more info in the README)
OSD="no"  # On Screen Display message for KDE if enabled
INC=2  # Increment when lowering/rising the volume
MAX_VOL=130  # Maximum volume
AUTOSYNC="no"  # All programs have the same volume if enabled
VOLUME_ICONS=( "# " "# " "# " )  # Volume icons array, from lower volume to higher
MUTED_ICON="# "  # Muted volume icon
MUTED_COLOR="%{F#6b6b6b}"  # Color when the audio is muted
NOTIFICATIONS="no"  # Notifications when switching sinks if enabled
SINK_ICON="# "  # Icon always shown to the left of the default sink names

# Blacklist of PulseAudio sink names when switching between them. To obtain
# the names of your active sinks, use `pactl list sinks short`.
SINK_BLACKLIST=(
    "alsa_output.usb-SinkYouDontUse-00.analog-stereo"
)

# Maps PulseAudio sink names to human-readable names
declare -A SINK_NICKNAMES
SINK_NICKNAMES["alsa_output.usb-SomeManufacturer_SomeUsbSoundcard-00.analog-stereo"]="External Soundcard"


# Environment & global constants for the script
LANGUAGE=en_US  # Some calls depend on English outputs of pactl
END_COLOR="%{F-}"


# Saves the currently default sink into a variable named `curSink`. It will
# return an error code when pulseaudio isn't running.
function getCurSink() {
    if ! pulseaudio --check; then return 1; fi
    curSink=$(pacmd list-sinks | awk '/\* index:/{print $3}')
}


# Saves the sink passed by parameter's volume into a variable named `curVol`.
function getCurVol() {
    curVol=$(pacmd list-sinks | grep -A 15 'index: '"$1"'' | grep 'volume:' | grep -E -v 'base volume:' | awk -F : '{print $3}' | grep -o -P '.{0,3}%' | sed s/.$// | tr -d ' ')
}


# Saves the name of the sink passed by parameter into a variable named
# `sinkName`.
function getSinkName() {
    sinkName=$(pactl list sinks short | awk -v sink="$1" '{ if ($1 == sink) {print $2} }')
}


# Saves the name to be displayed for the sink passed by parameter into a
# variable called `nickname`.
# If a mapping for the sink name exists, that is used. Otherwise, the string
# "Sink #<index>" is used.
function getNickname() {
    getSinkName "$1"
    if [ -n "${SINK_NICKNAMES[$sinkName]}" ]; then
        nickname="${SINK_NICKNAMES[$sinkName]}"
    else
        nickname="Sink #$1"
    fi
}


# Saves the status of the sink passed by parameter into a variable named
# `isMuted`.
function getIsMuted() {
    isMuted=$(pacmd list-sinks | grep -A 15 "index: $1" | awk '/muted/{print $2}')
}


# Saves all the sink inputs of the sink passed by parameter into a string
# named `sinkInputs`.
function getSinkInputs() {
    sinkInputs=$(pacmd list-sink-inputs | grep -B 4 "sink: $1 " | awk '/index:/{print $2}')
}


function volUp() {
    # Obtaining the current volume from pacmd into $curVol.
    if ! getCurSink; then
        echo "PulseAudio not running"
        return 1
    fi
    getCurVol "$curSink"
    local maxLimit=$((MAX_VOL - INC))

    # Checking the volume upper bounds so that if MAX_VOL was 100% and the
    # increase percentage was 3%, a 99% volume would top at 100% instead
    # of 102%. If the volume is above the maximum limit, nothing is done.
    if [ "$curVol" -le "$MAX_VOL" ] && [ "$curVol" -ge "$maxLimit" ]; then
        pactl set-sink-volume "$curSink" "$MAX_VOL%"
    elif [ "$curVol" -lt "$maxLimit" ]; then
        pactl set-sink-volume "$curSink" "+$INC%"
    fi

    if [ $OSD = "yes" ]; then showOSD "$curSink"; fi
    if [ $AUTOSYNC = "yes" ]; then volSync; fi
}


function volDown() {
    # Pactl already handles the volume lower bounds so that negative values
    # are ignored.
    if ! getCurSink; then
        echo "PulseAudio not running"
        return 1
    fi
    pactl set-sink-volume "$curSink" "-$INC%"

    if [ $OSD = "yes" ]; then showOSD "$curSink"; fi
    if [ $AUTOSYNC = "yes" ]; then volSync; fi
}


function volSync() {
    if ! getCurSink; then
        echo "PulseAudio not running"
        return 1
    fi
    getSinkInputs "$curSink"
    getCurVol "$curSink"

    # Every output found in the active sink has their volume set to the
    # current one. This will only be called if $AUTOSYNC is `yes`.
    for each in $sinkInputs; do
        pactl set-sink-input-volume "$each" "$curVol%"
    done
}


function volMute() {
    # Switch to mute/unmute the volume with pactl.
    if ! getCurSink; then
        echo "PulseAudio not running"
        return 1
    fi
    if [ "$1" = "toggle" ]; then
        getIsMuted "$curSink"
        if [ "$isMuted" = "yes" ]; then
            pactl set-sink-mute "$curSink" "no"
        else
            pactl set-sink-mute "$curSink" "yes"
        fi
    elif [ "$1" = "mute" ]; then
        pactl set-sink-mute "$curSink" "yes"
    elif [ "$1" = "unmute" ]; then
        pactl set-sink-mute "$curSink" "no"
    fi

    if [ $OSD = "yes" ]; then showOSD "$curSink"; fi
}


function nextSink() {
    # The final sinks list, removing the blacklisted ones from the list of
    # currently available sinks.
    if ! getCurSink; then
        echo "PulseAudio not running"
        return 1
    fi

    # Obtaining a tuple of sink indexes after removing the blacklisted devices
    # with their name.
    sinks=()
    local i=0
    while read -r line; do
        index=$(echo "$line" | cut -f1)
        name=$(echo "$line" | cut -f2)

        # If it's in the blacklist, continue the main loop. Otherwise, add
        # it to the list.
        for sink in "${SINK_BLACKLIST[@]}"; do
            if [ "$sink" = "$name" ]; then
                continue 2
            fi
        done

        sinks[$i]="$index"
        i=$((i + 1))
    done < <(pactl list short sinks)

    # If the resulting list is empty, nothing is done
    if [ ${#sinks[@]} -eq 0 ]; then return; fi

    # If the current sink is greater or equal than last one, pick the first
    # sink in the list. Otherwise just pick the next sink avaliable.
    local newSink
    if [ "$curSink" -ge "${sinks[-1]}" ]; then
        newSink=${sinks[0]}
    else
        for sink in "${sinks[@]}"; do
            if [ "$curSink" -lt "$sink" ]; then
                newSink=$sink
                break
            fi
        done
    fi

    # The new sink is set
    pacmd set-default-sink "$newSink"

    # Move all audio threads to new sink
    local inputs=$(pactl list short sink-inputs | cut -f 1)
    for i in $inputs; do
        pacmd move-sink-input "$i" "$newSink"
    done

    if [ $NOTIFICATIONS = "yes" ]; then
        getNickname "$newSink"
        
        if command -v dunstify &>/dev/null; then
            notify="dunstify --replace 201839192"
        else
            notify="notify-send"
        fi
        $notify "PulseAudio" "Changed output to $nickname" --icon=audio-headphones-symbolic &
    fi
}


# This function assumes that PulseAudio is already running. It only supports
# KDE OSDs for now. It will show a system message with the status of the
# sink passed by parameter, or the currently active one by default.
function showOSD() {
    if [ -z "$1" ]; then
        curSink="$1"
    else
        getCurSink
    fi
    getCurVol "$curSink"
    getIsMuted "$curSink"
    qdbus org.kde.kded /modules/kosd showVolume "$curVol" "$isMuted"
}


function listen() {
    local firstRun=0

    # Listen for changes and immediately create new output for the bar.
    # This is faster than having the script on an interval.
    LANG=$LANGUAGE pactl subscribe 2>/dev/null | {
        while true; do
            {
                # If this is the first time just continue and print the current
                # state. Otherwise wait for events. This is to prevent the
                # module being empty until an event occurs.
                if [ $firstRun -eq 0 ]; then
                    firstRun=1
                else
                    read -r event || break
                    # Avoid double events
                    if ! echo "$event" | grep -e "on card" -e "on sink" -e "on server"; then
                        continue
                    fi
                fi
            } &>/dev/null
            output
        done
    }
}


function output() {
    if ! getCurSink; then
        echo "PulseAudio not running"
        return 1
    fi
    getCurVol "$curSink"
    getIsMuted "$curSink"

    # Fixed volume icons over max volume
    local iconsLen=${#VOLUME_ICONS[@]}
    if [ "$iconsLen" -ne 0 ]; then
        local volSplit=$((MAX_VOL / iconsLen))
        for i in $(seq 1 "$iconsLen"); do
            if [ $((i * volSplit)) -ge "$curVol" ]; then
                volIcon="${VOLUME_ICONS[$((i-1))]}"
                break
            fi
        done
    else
        volIcon=""
    fi

    getNickname "$curSink"

    # Showing the formatted message
    if [ "$isMuted" = "yes" ]; then
        echo "${MUTED_COLOR}${MUTED_ICON}${curVol}%   ${SINK_ICON}${nickname}${END_COLOR}"
    else
        echo "${volIcon}${curVol}%   ${SINK_ICON}${nickname}"
    fi
}


function usage() {
    echo "Usage: $0 ACTION"
    echo ""
    echo "Actions:"
    echo "    help              display this help and exit"
    echo "    output            print the PulseAudio status once"
    echo "    listen            listen for changes in PulseAudio to automatically"
    echo "                      update this script's output"
    echo "    up, down          increase or decrease the default sink's volume"
    echo "    mute, unmute      mute or unmute the default sink's audio"
    echo "    togmute           switch between muted and unmuted"
    echo "    next-sink         switch to the next available sink"
    echo "    sync              synchronize all the output streams volume to"
    echo "                      the be the same as the current sink's volume"
    echo ""
    echo "Author:"
    echo "    Mario O. M."
    echo "More info on GitHub:"
    echo "    https://github.com/marioortizmanero/polybar-pulseaudio-control"
}


case "$1" in
    up)
        volUp
        ;;
    down)
        volDown
        ;;
    togmute)
        volMute toggle
        ;;
    mute)
        volMute mute
        ;;
    unmute)
        volMute unmute
        ;;
    sync)
        volSync
        ;;
    listen)
        listen
        ;;
    next-sink)
        nextSink
        ;;
    output)
        output
        ;;
    *)
        usage
        ;;
esac
