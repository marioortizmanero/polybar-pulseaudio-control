#!/usr/bin/env bash

##################################################################
# Polybar Pulseaudio Control                                     #
# https://github.com/marioortizmanero/polybar-pulseaudio-control #
##################################################################

# Defaults for configurable values, expected to be set by command-line arguments
AUTOSYNC="no"
COLOR_MUTED="%{F#6b6b6b}"
ICON_MUTED=
ICON_SINK=
NOTIFICATIONS="no"
OSD="no"
SINK_NICKNAMES_PROP=
VOLUME_STEP=2
VOLUME_MAX=130
# shellcheck disable=SC2016
FORMAT='$VOL_ICON ${VOL_LEVEL}%  $ICON_SINK $SINK_NICKNAME'
declare -A SINK_NICKNAMES
declare -a ICONS_VOLUME
declare -a SINK_BLACKLIST

# Environment & global constants for the script
END_COLOR="%{F-}"  # For Polybar colors
LANGUAGE=en_US  # Some calls depend on English outputs of pactl


# Saves the currently default sink into a variable named `curSink`. It will
# return an error code when pulseaudio isn't running.
function getCurSink() {
    if ! pulseaudio --check; then return 1; fi
    curSink=$(pacmd list-sinks | awk '/\* index:/{print $3}')
}


# Saves the sink passed by parameter's volume into a variable named `VOL_LEVEL`.
function getCurVol() {
    VOL_LEVEL=$(pacmd list-sinks | grep -A 15 'index: '"$1"'' | grep 'volume:' | grep -E -v 'base volume:' | awk -F : '{print $3; exit}' | grep -o -P '.{0,3}%' | sed 's/.$//' | tr -d ' ')
}


# Saves the name of the sink passed by parameter into a variable named
# `sinkName`.
function getSinkName() {
    sinkName=$(pactl list sinks short | awk -v sink="$1" '{ if ($1 == sink) {print $2} }')
}


# Saves the name to be displayed for the sink passed by parameter into a
# variable called `SINK_NICKNAME`.
# If a mapping for the sink name exists, that is used. Otherwise, the string
# "Sink #<index>" is used.
function getNickname() {
    getSinkName "$1"
    unset SINK_NICKNAME

    if [ -n "$sinkName" ] && [ -n "${SINK_NICKNAMES[$sinkName]}" ]; then
        SINK_NICKNAME="${SINK_NICKNAMES[$sinkName]}"
    elif [ -n "$sinkName" ] && [ -n "$SINK_NICKNAMES_PROP" ]; then
        getNicknameFromProp "$SINK_NICKNAMES_PROP" "$sinkName"
        # Cache that result for next time
        SINK_NICKNAMES["$sinkName"]="$SINK_NICKNAME"
    fi

    if [ -z "$SINK_NICKNAME" ]; then
        SINK_NICKNAME="Sink #$1"
    fi
}

# Gets sink nickname based on a given property.
function getNicknameFromProp() {
    local nickname_prop="$1"
    local for_name="$2"

    SINK_NICKNAME=
    while read -r property value; do
        case "$property" in
            name:)
                sink_name="${value//[<>]/}"
                unset sink_desc
                ;;
            "$nickname_prop")
                if [ "$sink_name" != "$for_name" ]; then
                    continue
                fi
                SINK_NICKNAME="${value:3:-1}"
                break
                ;;
        esac
    done < <(pacmd list-sinks)
}

# Saves the status of the sink passed by parameter into a variable named
# `isMuted`.
function getIsMuted() {
    isMuted=$(pacmd list-sinks | grep -A 15 "index: $1" | awk '/muted/ {print $2; exit}')
}


# Saves all the sink inputs of the sink passed by parameter into a string
# named `sinkInputs`.
function getSinkInputs() {
    sinkInputs=$(pacmd list-sink-inputs | grep -B 4 "sink: $1 " | awk '/index:/{print $2}')
}


function volUp() {
    # Obtaining the current volume from pacmd into $VOL_LEVEL.
    if ! getCurSink; then
        echo "PulseAudio not running"
        return 1
    fi
    getCurVol "$curSink"
    local maxLimit=$((VOLUME_MAX - VOLUME_STEP))

    # Checking the volume upper bounds so that if VOLUME_MAX was 100% and the
    # increase percentage was 3%, a 99% volume would top at 100% instead
    # of 102%. If the volume is above the maximum limit, nothing is done.
    if [ "$VOL_LEVEL" -le "$VOLUME_MAX" ] && [ "$VOL_LEVEL" -ge "$maxLimit" ]; then
        pactl set-sink-volume "$curSink" "$VOLUME_MAX%"
    elif [ "$VOL_LEVEL" -lt "$maxLimit" ]; then
        pactl set-sink-volume "$curSink" "+$VOLUME_STEP%"
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
    pactl set-sink-volume "$curSink" "-$VOLUME_STEP%"

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
        pactl set-sink-input-volume "$each" "$VOL_LEVEL%"
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
    local inputs
    inputs="$(pactl list short sink-inputs | cut -f 1)"
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
        $notify "PulseAudio" "Changed output to $SINK_NICKNAME" --icon=audio-headphones-symbolic &
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
    qdbus org.kde.kded /modules/kosd showVolume "$VOL_LEVEL" "$isMuted"
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
    local iconsLen=${#ICONS_VOLUME[@]}
    if [ "$iconsLen" -ne 0 ]; then
        local volSplit=$((VOLUME_MAX / iconsLen))
        for i in $(seq 1 "$iconsLen"); do
            if [ $((i * volSplit)) -ge "$VOL_LEVEL" ]; then
                VOL_ICON="${ICONS_VOLUME[$((i-1))]}"
                break
            fi
        done
    else
        VOL_ICON=""
    fi

    getNickname "$curSink"

    # Showing the formatted message
    if [ "$isMuted" = "yes" ]; then
        # shellcheck disable=SC2034
        VOL_ICON=$ICON_MUTED
        echo "${COLOR_MUTED}$(eval echo "$FORMAT")${END_COLOR}"
    else
        eval echo "$FORMAT"
    fi
}


function usage() {
    echo "\
Usage: $0 [OPTION...] ACTION

Options: [defaults]
  --autosync | --no-autosync            whether to maintain same volume for all
                                        programs [$AUTOSYNC]
  --color-muted <rrggbb>                color in which to format when muted
                                        [${COLOR_MUTED:4:-1}]
  --notifications | --no-notifications  whether to show notifications when
                                        changing sinks [$NOTIFICATIONS]
  --osd | --no-osd                      whether to display KDE's OSD message
                                        [$OSD]
  --icon-muted <icon>                   icon to use when muted [none]
  --icon-sink <icon>                    icon to use for sink [none]
  --format <string>                     use a format string to control the output
                                        Available variables: \$VOL_ICON,
                                        \$VOL_LEVEL, \$ICON_SINK, and
                                        \$SINK_NICKNAME
                                        [$FORMAT]
  --icons-volume <icon>[,<icon>...]     icons for volume, from lower to higher
                                        [none]
  --volume-max <int>                    maximum volume to which to allow
                                        increasing [$VOLUME_MAX]
  --volume-step <int>                   step size when inc/decrementing volume
                                        [$VOLUME_STEP]
  --sink-blacklist <name>[,<name>...]   sinks to ignore when switching [none]
  --sink-nicknames-from <prop>          pacmd property to use for sink names,
                                        unless overriden by --sink-nickname.
                                        Its possible values are listed under
                                        the 'properties' key in the output of
                                        \`pacmd list-sinks\` [none]
  --sink-nickname <name>:<nick>         nickname to assign to given sink name,
                                        taking priority over
                                        --sink-nicknames-from. May be given
                                        multiple times, and 'name' is exactly as
                                        listed in the output of
                                        \`pactl list sinks short | cut -f2\`
                                        [none]

Actions:
  help              display this message and exit
  output            print the PulseAudio status once
  listen            listen for changes in PulseAudio to automatically update
                    this script's output
  up, down          increase or decrease the default sink's volume
  mute, unmute      mute or unmute the default sink's audio
  togmute           switch between muted and unmuted
  next-sink         switch to the next available sink
  sync              synchronize all the output streams volume to be the same as
                    the current sink's volume

Author:
    Mario Ortiz Manero
More info on GitHub:
    https://github.com/marioortizmanero/polybar-pulseaudio-control"
}

while [[ "$1" = --* ]]; do
    unset arg
    unset val
    if [[ "$1" = *=* ]]; then
        arg="${1//=*/}"
        val="${1//*=/}"
        shift
    else
        arg="$1"
        # Support space-separated values, but also value-less flags
        if [[ "$2" != --* ]]; then
            val="$2"
            shift
        fi
        shift
    fi

    case "$arg" in
        --autosync)
            AUTOSYNC=yes
            ;;
        --no-autosync)
            AUTOSYNC=no
            ;;
        --color-muted|--colour-muted)
            COLOR_MUTED="%{F#$val}"
            ;;
        --notifications)
            NOTIFICATIONS=yes
            ;;
        --no-notifications)
            NOTIFICATIONS=no
            ;;
        --osd)
            OSD=yes
            ;;
        --no-osd)
            OSD=no
            ;;
        --icon-muted)
            ICON_MUTED="$val"
            ;;
        --icon-sink)
            # shellcheck disable=SC2034
            ICON_SINK="$val"
            ;;
        --icons-volume)
            IFS=, read -r -a ICONS_VOLUME <<< "$val"
            ;;
        --volume-max)
            VOLUME_MAX="$val"
            ;;
        --volume-step)
            VOLUME_STEP="$val"
            ;;
        --sink-blacklist)
            IFS=, read -r -a SINK_BLACKLIST <<< "$val"
            ;;
        --sink-nicknames-from)
            SINK_NICKNAMES_PROP="$val"
            ;;
        --sink-nickname)
            SINK_NICKNAMES["${val//:*/}"]="${val//*:}"
            ;;
        --format)
	    FORMAT="$val"
            ;;
        *)
            echo "Unrecognised option: $arg" >&2
            exit 1
            ;;
    esac
done

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
    help)
        usage
        ;;
    *)
        echo "Unrecognised action: $1" >&2
        exit 1
        ;;
esac
