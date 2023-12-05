#!/usr/bin/env bash

##################################################################
# Polybar Pulseaudio Control                                     #
# https://github.com/marioortizmanero/polybar-pulseaudio-control #
##################################################################

# Deprecated values, to be removed in a next release. This is kept around to
# be displayed for users using it in custom FORMAT
# shellcheck disable=SC2034
ICON_SINK="Replaced by ICON_NODE, see https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/tag/v3.0.0"
SINK_NICKNAME="Replaced by NODE_NICKNAME, see https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/tag/v3.0.0"

# Defaults for configurable values, expected to be set by command-line arguments
AUTOSYNC="no"
COLOR_MUTED="%{F#6b6b6b}"
ICON_MUTED=
ICON_NODE=
NODE_TYPE="output"
NOTIFICATIONS="no"
OSD="no"
NODE_NICKNAMES_PROP=
VOLUME_STEP=2
VOLUME_MAX=130
LISTEN_TIMEOUT=0.05
# shellcheck disable=SC2016
FORMAT='$VOL_ICON ${VOL_LEVEL}%  $ICON_NODE $NODE_NICKNAME'
declare -A NODE_NICKNAMES
declare -a ICONS_VOLUME
declare -a NODE_BLACKLIST

# Special variable: within the script, pactl, grep, and awk commands are used
# on sinks or sources, depending on NODE_TYPE.
#
# The commands are almost always the same, except for the sink/source part.
# In order to reduce duplication, this variable is used for commands that behave
# the same, regardless of the NODE_TYPE.
#
# Having only the "radix" (ink/ource) and omitting the first letter enables us
# to use that single variable:
#
#   S-ink  , s-ink  , s-ink  -s, S-ink -s
#   S-ource, s-ource, s-ource-s, S-ource-s
SINK_OR_SOURCE="ink"

# Environment & global constants for the script
export LC_ALL=C  # Some calls depend on English outputs of pactl
END_COLOR="%{F-}"  # For Polybar colors


# Saves the currently default node into a variable named `curNode`. It will
# return an error code when pulseaudio isn't running.
function getCurNode() {
    if ! pactl info &>/dev/null; then return 1; fi
    local curNodeName

    curNodeName=$(pactl info | awk "/Default S${SINK_OR_SOURCE}: / {print \$3}")
    curNode=$(pactl list "s${SINK_OR_SOURCE}s" | grep -B 4 -E "Name: $curNodeName\$" | sed -nE "s/^S${SINK_OR_SOURCE} #([0-9]+)$/\1/p")
}


# Saves the node passed by parameter's volume into a variable named `VOL_LEVEL`.
function getCurVol() {
    VOL_LEVEL=$(pactl list "s${SINK_OR_SOURCE}s" | grep -A 15 -E "^S${SINK_OR_SOURCE} #$1\$" | grep 'Volume:' | grep -E -v 'Base Volume:' | awk -F : '{print $3; exit}' | grep -o -P '.{0,3}%' | sed 's/.$//' | tr -d ' ')
}


# Saves the name of the node passed by parameter into a variable named
# `nodeName`.
function getNodeName() {
    nodeName=$(pactl list "s${SINK_OR_SOURCE}s" short | awk -v sink="$1" "{ if (\$1 == sink) {print \$2} }")
    portName=$(pactl list "s${SINK_OR_SOURCE}s" | grep -e "S${SINK_OR_SOURCE} #" -e 'Active Port: ' | sed -n "/^S${SINK_OR_SOURCE} #$1\$/,+1p" | awk '/Active Port: / {print $3}')
}


# Saves the name to be displayed for the node passed by parameter into a
# variable called `NODE_NICKNAME`.
# If a mapping for the node name exists, that is used. Otherwise, the string
# "Node #<index>" is used.
function getNickname() {
    getNodeName "$1"
    unset NODE_NICKNAME

    if [ -n "$nodeName" ] && [ -n "$portName" ] && [ -n "${NODE_NICKNAMES[$nodeName/$portName]}" ]; then
        NODE_NICKNAME="${NODE_NICKNAMES[$nodeName/$portName]}"
    elif [ -n "$nodeName" ] && [ -n "${NODE_NICKNAMES[$nodeName]}" ]; then
        NODE_NICKNAME="${NODE_NICKNAMES[$nodeName]}"
    elif [ -n "$nodeName" ]; then
        # No exact match could be found, try a Glob Match
        for glob in "${!NODE_NICKNAMES[@]}"; do
            # shellcheck disable=SC2053 # Disable Shellcheck warning for Glob-Matching
            if [[ "$nodeName/$portName" == $glob ]] || [[ "$nodeName" == $glob ]]; then
                NODE_NICKNAME="${NODE_NICKNAMES[$glob]}"
                # Cache that result for next time
                NODE_NICKNAMES["$nodeName"]="$NODE_NICKNAME"
                break
            fi
        done
    fi

    if [ -z "$NODE_NICKNAME" ] && [ -n "$nodeName" ] && [ -n "$NODE_NICKNAMES_PROP" ]; then
        getNicknameFromProp "$NODE_NICKNAMES_PROP" "$nodeName"
        # Cache that result for next time
        NODE_NICKNAMES["$nodeName"]="$NODE_NICKNAME"
    elif [ -z "$NODE_NICKNAME" ]; then
        NODE_NICKNAME="S${SINK_OR_SOURCE} #$1"
    fi
}

# Gets node nickname based on a given property.
function getNicknameFromProp() {
    local nickname_prop="$1"
    local for_name="$2"

    NODE_NICKNAME=
    while read -r property value; do
        case "$property" in
            Name:)
                node_name="$value"
                unset node_desc
                ;;
            "$nickname_prop")
                if [ "$node_name" != "$for_name" ]; then
                    continue
                fi
                NODE_NICKNAME="${value:3:-1}"
                break
                ;;
        esac
    done < <(pactl list "s${SINK_OR_SOURCE}s")
}

# Saves the status of the node passed by parameter into a variable named
# `IS_MUTED`.
function getIsMuted() {
    IS_MUTED=$(pactl list "s${SINK_OR_SOURCE}s" | grep -E "^S${SINK_OR_SOURCE} #$1\$" -A 15 | awk '/Mute: / {print $2}')
}


# Saves all the sink inputs of the sink passed by parameter into a string
# named `sinkInputs`.
function getSinkInputs() {
    sinkInputs=$(pactl list sink-inputs | grep -B 4 "Sink: $1" | sed -nE "s/^Sink Input #([0-9]+)\$/\1/p")
}


# Saves all the source outputs of the source passed by parameter into a string
# named `sourceOutputs`.
function getSourceOutputs() {
    sourceOutputs=$(pactl list source-outputs | grep -B 4 "Source: $1" | sed -nE "s/^Source Output #([0-9]+)\$/\1/p")
}


function volUp() {
    # Obtaining the current volume from pulseaudio into $VOL_LEVEL.
    if ! getCurNode; then
        echo "PulseAudio not running"
        return 1
    fi
    getCurVol "$curNode"
    local maxLimit=$((VOLUME_MAX - VOLUME_STEP))

    # Checking the volume upper bounds so that if VOLUME_MAX was 100% and the
    # increase percentage was 3%, a 99% volume would top at 100% instead
    # of 102%. If the volume is above the maximum limit, nothing is done.
    if [ "$VOL_LEVEL" -le "$VOLUME_MAX" ] && [ "$VOL_LEVEL" -ge "$maxLimit" ]; then
        pactl "set-s${SINK_OR_SOURCE}-volume" "$curNode" "$VOLUME_MAX%"
    elif [ "$VOL_LEVEL" -lt "$maxLimit" ]; then
        pactl "set-s${SINK_OR_SOURCE}-volume" "$curNode" "+$VOLUME_STEP%"
    fi

    if [ $OSD = "yes" ]; then showOSD "$curNode"; fi
    if [ $AUTOSYNC = "yes" ]; then volSync; fi
}


function volDown() {
    # Pactl already handles the volume lower bounds so that negative values
    # are ignored.
    if ! getCurNode; then
        echo "PulseAudio not running"
        return 1
    fi
    pactl "set-s${SINK_OR_SOURCE}-volume" "$curNode" "-$VOLUME_STEP%"

    if [ $OSD = "yes" ]; then showOSD "$curNode"; fi
    if [ $AUTOSYNC = "yes" ]; then volSync; fi
}


function volSync() {
    # This will only be called if $AUTOSYNC is `yes`.

    if ! getCurNode; then
        echo "PulseAudio not running"
        return 1
    fi
    
    getCurVol "$curNode"
    
    if [[ "$NODE_TYPE" = "output" ]]; then
        getSinkInputs "$curNode"

        # Every output found in the active sink has their volume set to the
        # current one.
        for each in $sinkInputs; do
            pactl "set-sink-input-volume" "$each" "$VOL_LEVEL%"
        done
    else
        getSourceOutputs "$curNode"

        # Every input found in the active source has their volume set to the
        # current one.
        for each in $sourceOutputs; do
            pactl "set-source-output-volume" "$each" "$VOL_LEVEL%"
        done
    fi
}


function volMute() {
    # Switch to mute/unmute the volume with pactl.
    if ! getCurNode; then
        echo "PulseAudio not running"
        return 1
    fi
    if [ "$1" = "toggle" ]; then
        getIsMuted "$curNode"
        if [ "$IS_MUTED" = "yes" ]; then
            pactl "set-s${SINK_OR_SOURCE}-mute" "$curNode" "no"
        else
            pactl "set-s${SINK_OR_SOURCE}-mute" "$curNode" "yes"
        fi
    elif [ "$1" = "mute" ]; then
        pactl "set-s${SINK_OR_SOURCE}-mute" "$curNode" "yes"
    elif [ "$1" = "unmute" ]; then
        pactl "set-s${SINK_OR_SOURCE}-mute" "$curNode" "no"
    fi

    if [ $OSD = "yes" ]; then showOSD "$curNode"; fi
}


function nextNode() {
    # The final nodes list, removing the blacklisted ones from the list of
    # currently available nodes.
    if ! getCurNode; then
        echo "PulseAudio not running"
        return 1
    fi

    # Obtaining a tuple of node indexes after removing the blacklisted devices
    # with their name.
    nodes=()
    local i=0
    while read -r line; do
        index=$(echo "$line" | cut -f1)
        name=$(echo "$line" | cut -f2)

        # If it's in the blacklist, continue the main loop. Otherwise, add
        # it to the list.
        for node in "${NODE_BLACKLIST[@]}"; do
            # shellcheck disable=SC2053 # Disable Shellcheck warning for Glob-Matching
            if [[ "$name" == $node ]]; then
                continue 2
            fi
        done

        nodes[i]="$index"
        i=$((i + 1))
    done < <(pactl list short "s${SINK_OR_SOURCE}s" | sort -n)

    # If the resulting list is empty, nothing is done
    if [ ${#nodes[@]} -eq 0 ]; then return; fi

    # If the current node is greater or equal than last one, pick the first
    # node in the list. Otherwise just pick the next node avaliable.
    local newNode
    if [ "$curNode" -ge "${nodes[-1]}" ]; then
        newNode=${nodes[0]}
    else
        for node in "${nodes[@]}"; do
            if [ "$curNode" -lt "$node" ]; then
                newNode=$node
                break
            fi
        done
    fi

    # The new node is set
    pactl "set-default-s${SINK_OR_SOURCE}" "$newNode"

    # Move all audio threads to new node
    local inputs

    if [[ "$NODE_TYPE" = "output" ]]; then
        inputs="$(pactl list short sink-inputs | cut -f 1)"
        for i in $inputs; do
            pactl move-sink-input "$i" "$newNode"
        done
    else
        outputs="$(pactl list short source-outputs | cut -f 1)"
        for i in $outputs; do
            pactl move-source-output "$i" "$newNode"
        done
    fi

    if [ $NOTIFICATIONS = "yes" ]; then
        getNickname "$newNode"

        if command -v dunstify &>/dev/null; then
            notify="dunstify --replace 201839192"
        else
            notify="notify-send"
        fi
        $notify "PulseAudio" "Changed $NODE_TYPE to $NODE_NICKNAME" --icon=audio-headphones-symbolic &
    fi
}


# This function assumes that PulseAudio is already running. It only supports
# KDE OSDs for now. It will show a system message with the status of the
# node passed by parameter, or the currently active one by default.
function showOSD() {
    if [ -z "$1" ]; then
        curNode="$1"
    else
        getCurNode
    fi
    getCurVol "$curNode"
    getIsMuted "$curNode"
    qdbus org.kde.kded /modules/kosd showVolume "$VOL_LEVEL" "$IS_MUTED"
}


function listen() {
    # If this is the first time start by printing the current state. Otherwise,
    # directly wait for events. This is to prevent the module being empty until
    # an event occurs.
    output

    # Listen for changes and immediately create new output for the bar.
    # This is faster than having the script on an interval.
    pactl subscribe 2>/dev/null | grep --line-buffered -e "on \(card\|s${SINK_OR_SOURCE}\|server\)" | {
        while read -r; do
            # Output the new state
            output

            # Read all stdin to flush unwanted pending events, i.e. if there are
            # 15 events at the same time (100ms window), output is only called
            # twice.
            read -r -d '' -t "$LISTEN_TIMEOUT" -n 10000

            # After the 100ms waiting time, output again the state, as it may
            # have changed if the user did an action during the 100ms window.
            output
        done
    }
}


function output() {
    if ! getCurNode; then
        echo "PulseAudio not running"
        return 1
    fi
    getCurVol "$curNode"
    getIsMuted "$curNode"

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

    getNickname "$curNode"

    # Showing the formatted message
    if [ "$IS_MUTED" = "yes" ]; then
        # shellcheck disable=SC2034
        VOL_ICON=$ICON_MUTED
        content="$(eval echo "$FORMAT")"
        if [ -n "$COLOR_MUTED" ]; then
            echo "${COLOR_MUTED}${content}${END_COLOR}"
        else
            echo "$content"
        fi
    else
        eval echo "$FORMAT"
    fi
}


function usage() {
    echo "\
Usage: $0 [OPTION...] ACTION

Terminology: A node represents either a sink (output) or source (input).

Options:
  --autosync | --no-autosync
        Whether to maintain same volume for all programs.
        Default: \"$AUTOSYNC\"
  --color-muted <rrggbb>
        Color in which to format when muted.
        Pass empty string to disable.
        Default: \"${COLOR_MUTED:4:-1}\"
  --notifications | --no-notifications
        Whether to show notifications when changing nodes.
        Default: \"$NOTIFICATIONS\"
  --osd | --no-osd
        Whether to display KDE's OSD message.
        Default: \"$OSD\"
  --icon-muted <icon>
        Icon to use when muted.
        Default: none
  --icon-node <icon>
        Icon to use for node.
        Default: none
  --format <string>
        Use a format string to control the output.
        Remember to pass this argument wrapped in single quotes (\`'\`) instead
        of double quotes (\`\"\`) to avoid your shell from evaluating the
        variables early.
        Available variables:
        * \$VOL_ICON
        * \$VOL_LEVEL
        * \$ICON_NODE
        * \$NODE_NICKNAME
        * \$IS_MUTED (yes/no)
        Default: '$FORMAT'
  --icons-volume <icon>[,<icon>...]
        Icons for volume, from lower to higher.
        Default: none
  --node-type <node_type>
        Whether to consider PulseAudio sinks (output) or sources (input).
        All the operations of pulseaudio-control will apply to one of the two.
        Pass \`input\` for the sources, e.g. a microphone.
        Pass \`output\` for the sinks, e.g. speakers, headphones.
        Default: \"$NODE_TYPE\"
  --volume-max <int>
        Maximum volume to which to allow increasing.
        Default: \"$VOLUME_MAX\"
  --volume-step <int>
        Step size when inc/decrementing volume.
        Default: \"$VOLUME_STEP\"
  --node-blacklist <name>[,<name>...]
        Nodes to ignore when switching. You can use globs. Don't forget to
        quote the string when using globs, to avoid unwanted shell glob
        extension.
        Default: none
  --node-nicknames-from <prop>
        pactl property to use for node names, unless overridden by
        --node-nickname. Its possible values are listed under the 'Properties'
        key in the output of \`pactl list sinks\` and \`pactl list sources\`.
        Default: none
  --node-nickname <name>:<nick>
        Nickname to assign to given node name, taking priority over
        --node-nicknames-from. May be given multiple times, and 'name' is
        exactly as listed in the output of \`pactl list sinks short | cut -f2\`
        and \`pactl list sources short | cut -f2\`.
        Note that you can also specify a port name for the node with
        \`<name>/<port>\`.
        It is also possible to use glob matching to match node and port names.
        Exact matches are prioritized. Don't forget to quote the string when
        using globs, to avoid unwanted shell glob extension.
        Default: none
  --listen-timeout-secs
        The listen command updates the output as soon as it receives an event
        from PulseAudio. However, events are often accompanied by many other
        useless ones, which may result in unnecessary consecutive output
        updates. This script buffers the following events until a timeout is
        reached to avoid this scenario, which lessens the CPU load on events.
        However, this may result in noticeable latency when performing many
        actions quickly (e.g., updating the volume with the mouse wheel). You
        can specify what timeout to use to control the responsiveness, in
        seconds.
        Default: \"$LISTEN_TIMEOUT\"

Actions:
  help              display this message and exit
  output            print the PulseAudio status once
  listen            listen for changes in PulseAudio to automatically update
                    this script's output
  up, down          increase or decrease the default node's volume
  mute, unmute      mute or unmute the default node's audio
  togmute           switch between muted and unmuted
  next-node         switch to the next available node
  sync              synchronize all the output streams volume to be the same as
                    the current node's volume

Author:
    Mario Ortiz Manero
More info on GitHub:
    https://github.com/marioortizmanero/polybar-pulseaudio-control"
}

# Obtains the value for an option and returns 1 if no shift is needed.
function getOptVal() {
    if [[ "$1" = *=* ]]; then
        val="${1//*=/}"
        return 1
    fi

    val="$2"
}

# Parsing the options from the arguments
while [[ "$1" = --* ]]; do
    unset arg
    unset val

    arg="$1"
    case "$arg" in
        --autosync)
            AUTOSYNC=yes
            ;;
        --no-autosync)
            AUTOSYNC=no
            ;;
        --color-muted|--colour-muted)
            if getOptVal "$@"; then shift; fi
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
            if getOptVal "$@"; then shift; fi
            ICON_MUTED="$val"
            ;;
        --icon-node)
            if getOptVal "$@"; then shift; fi
            # shellcheck disable=SC2034
            ICON_NODE="$val"
            ;;
        --icons-volume)
            if getOptVal "$@"; then shift; fi
            IFS=, read -r -a ICONS_VOLUME <<< "${val//[[:space:]]/}"
            ;;
        --volume-max)
            if getOptVal "$@"; then shift; fi
            VOLUME_MAX="$val"
            ;;
        --volume-step)
            if getOptVal "$@"; then shift; fi
            VOLUME_STEP="$val"
            ;;
        --node-blacklist)
            if getOptVal "$@"; then shift; fi
            IFS=, read -r -a NODE_BLACKLIST <<< "${val//[[:space:]]/}"
            ;;
        --node-nicknames-from)
            if getOptVal "$@"; then shift; fi
            NODE_NICKNAMES_PROP="$val"
            ;;
        --node-nickname)
            if getOptVal "$@"; then shift; fi
            NODE_NICKNAMES["${val//:*/}"]="${val//*:}"
            ;;
        --format)
            if getOptVal "$@"; then shift; fi
            FORMAT="$val"
            ;;
        --node-type)
            if getOptVal "$@"; then shift; fi
            if [[ "$val" != "output" && "$val" != "input" ]]; then
                echo "node-type must be 'output' or 'input', got '$val'" >&2
                exit 1
            fi
            NODE_TYPE="$val"
            SINK_OR_SOURCE=$([ "$NODE_TYPE" == "output" ] && echo "ink" || echo "ource")
            ;;
        --listen-timeout-secs)
            if getOptVal "$@"; then shift; fi
            LISTEN_TIMEOUT="$val"
            ;;
        # Deprecated options, to be removed in a next release
        --icon-sink)
            echo "Replaced by --icon-node, see https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/tag/v3.0.0" >&2
            exit 1
            ;;
        --sink-blacklist)
            echo "Replaced by --node-blacklist, see https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/tag/v3.0.0" >&2
            exit 1
            ;;
        --sink-nicknames-from)
            echo "Replaced by --node-nicknames-from, see https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/tag/v3.0.0" >&2
            exit 1
            ;;
        --sink-nickname)
            echo "Replaced by --node-nickname, see https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/tag/v3.0.0" >&2
            exit 1
            ;;
        # Undocumented because the `help` action already exists, but makes the
        # help message more accessible.
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unrecognised option: $arg" >&2
            exit 1
            ;;
    esac
    shift
done

# Parsing the action from the arguments
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
    next-node)
        nextNode
        ;;
    output)
        output
        ;;
    help)
        usage
        ;;
    # Deprecated action, to be removed in a next release
    next-sink)
        echo "Replaced by next-node, see https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/tag/v3.0.0" >&2
        exit 1
        ;;
    "")
        echo "No action specified. Run \`$0 help\` for more information." >&2
        ;;
    *)
        echo "Unrecognised action: $1" >&2
        exit 1
        ;;
esac
