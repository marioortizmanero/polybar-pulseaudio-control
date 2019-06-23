#!/usr/bin/env bash

# Script configuration
osd="no"
inc=2
capVol="no"
maxVol=200
autosync="yes"
notifications="no"
deviceBlacklist=( )

# Polbar-specific configuration
volIcon=" "
mutedIcon=" "
sinkIcon=" "
mutedColor="%{F#6b6b6b}"


# Script variables
isMuted="no"
activeSink=""
limit=$((100 - inc))
maxLimit=$((maxVol - inc))
endColor="%{F-}"


function getCurVol {
    curVol=$(pacmd list-sinks | grep -A 15 'index: '"$activeSink"'' | grep 'volume:' | grep -E -v 'base volume:' | awk -F : '{print $3}' | grep -o -P '.{0,3}%'| sed s/.$// | tr -d ' ')
}

function getCurSink {
    activeSink=$(pacmd list-sinks | awk '/* index:/{print $3}')
}

function volMuteStatus {
    isMuted=$(pacmd list-sinks | grep -A 15 "index: $activeSink" | awk '/muted/{ print $2}')
}

function getSinkInputs {
    input_array=$(pacmd list-sink-inputs | grep -B 4 "sink: $1 " | awk '/index:/{print $2}')
}

function volUp {
    getCurVol

    if [ "$capVol" = "yes" ]; then
        if [ "$curVol" -le 100 ] && [ "$curVol" -ge "$limit" ]; then
            pactl set-sink-volume "$activeSink" -- 100%
        elif [ "$curVol" -lt "$limit" ]; then
            pactl set-sink-volume "$activeSink" -- "+$inc%"
        fi
    elif [ "$curVol" -le "$maxVol" ] && [ "$curVol" -ge "$maxLimit" ]; then
        pactl set-sink-volume "$activeSink" "$maxVol%"
    elif [ "$curVol" -lt "$maxLimit" ]; then
        pactl set-sink-volume "$activeSink" "+$inc%"
    fi

    getCurVol

    if [ ${osd} = "yes" ]; then
        qdbus org.kde.kded /modules/kosd showVolume "$curVol" 0
    fi

    if [ ${autosync} = "yes" ]; then
        volSync
    fi
}

function volDown {
    pactl set-sink-volume "$activeSink" "-$inc%"
    getCurVol

    if [ ${osd} = "yes" ]; then
        qdbus org.kde.kded /modules/kosd showVolume "$curVol" 0
    fi

    if [ ${autosync} = "yes" ]; then
        volSync
    fi
}

function volSync {
    getSinkInputs "$activeSink"
    getCurVol

    for each in $input_array; do
        pactl set-sink-input-volume "$each" "$curVol%"
    done
}


function volMute {
    case "$1" in
        mute)
            pactl set-sink-mute "$activeSink" 1
            curVol=0
            status=1
            ;;
        unmute)
            pactl set-sink-mute "$activeSink" 0
            getCurVol
            status=0
            ;;
    esac

    if [ ${osd} = "yes" ]; then
        qdbus org.kde.kded /modules/kosd showVolume ${curVol} ${status}
    fi

}

# Changing the audio device, from 
function changeDevice {
    # Treats pulseaudio sink list to avoid calling pacmd list-sinks twice
    o_pulseaudio=$(pacmd list-sinks| grep -e 'index' -e 'device.description')

    # Gets max sink index
    nSinks=$(echo "$o_pulseaudio" | grep index | cut -d: -f2 | sed '$!d')

    # Gets present default sink index
    activeSink=$(echo "$o_pulseaudio" | grep "\* index" | cut -d: -f2)

    # Sets new sink index, checks that it's not in the blacklist
    newSink=$activeSink
    i=0
    found=0
    while [ $i -le "$nSinks" ] && [ "$found" -ne 1 ]; do
        found=1
        newSink=$((newSink + 1))
        if [ "$newSink" -gt "$nSinks" ]; then newSink=0; fi
        for el in "${deviceBlacklist[@]}"; do
            if [ "$el" -eq "${newSink}" ]; then 
                found=0
                break
            fi
        done
        i=$((i+1))
    done

    # New sink
    pacmd set-default-sink $newSink

    # Moves all audio threads to new sink
    inputs=$(pactl list sink-inputs short | cut -f 1)
    for i in $inputs; do
        pacmd move-sink-input "$i" "$newSink"
    done

    if [ $notifications = "yes" ]; then
        sendNotification
    fi
}

function sendNotification {
    o_pulseaudio=$(pacmd list-sinks| grep -e 'index' -e 'device.description')
    deviceName=$(echo "$o_pulseaudio" | sed -n '/* index/{n;p;}' | grep -o '".*"' | sed 's/"//g')
    notify-send "Output cycle" "Changed output to ${deviceName}" --icon=audio-headphones-symbolic
}



# Prints output for bar
# Listens for events for fast update speed
function listen {
    firstrun=0

    pactl subscribe 2>/dev/null | {
        while true; do 
            {
                # If this is the first time just continue
                # and print the current state
                # Otherwise wait for events
                # This is to prevent the module being empty until
                # an event occurs
                if [ $firstrun -eq 0 ]
                then
                    firstrun=1
                else
                    read -r event || break
                    if ! echo "$event" | grep -e "on card" -e "on sink" -e "on server"
                    then
                        # Avoid double events
                        continue
                    fi
                fi
            } &>/dev/null
            output
        done
    }
}

function output() {
    getCurSink
    getCurVol
    volMuteStatus
    if [ "${isMuted}" = "yes" ]; then
        echo "${mutedColor}${mutedIcon}${curVol}%   ${sinkIcon}${activeSink}${endColor}"
    else
        echo "${volIcon}${curVol}%   ${sinkIcon}${activeSink}"
    fi
}

getCurSink
case "$1" in
    --up)
        volUp
        ;;
    --down)
        volDown
        ;;
    --togmute)
        volMuteStatus
        if [ "$isMuted" = "yes" ]
        then
            volMute unmute
        else
            volMute mute
        fi
        ;;
    --mute)
        volMute mute
        ;;
    --unmute)
        volMute unmute
        ;;
    --sync)
        volSync
        ;;
    --listen)
        # Listen for changes and immediately create new output for the bar
        # This is faster than having the script on an interval
        listen
        ;;
    --change)
        # Changes the audio device
        changeDevice
        ;;
    *)
        # By default print output for bar
        output
        ;;
esac
