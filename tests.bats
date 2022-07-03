#!/usr/bin/env bats
# vim: filetype=sh
# 
# Polybar PulseAudio Control - tests.bats
# 
# Simple test script to make sure the most basic functions in this script
# always work as intended. The tests will modify the system's PulseAudio
# setup until it's restarted, so either do that after running the test, or
# launch the tests inside a container (see the Dockerfile in the main
# repository).
#
# The tests can be run with BATS. See the README.md for more info.

function restartPulseaudio() {
    if pulseaudio --check; then
        echo "Killing PulseAudio"
        killall pulseaudio
    fi

    # Starting and killing PulseAudio is performed asynchronously, so this
    # makes sure the requested state is real.
    while pgrep pulseaudio &>/dev/null; do :; done
    echo "Starting PulseAudio"
    pulseaudio --start -D
    while ! pgrep pulseaudio &>/dev/null; do :; done
}


# Loading the script and starting pulseaudio if it isn't already
function setup() {
    restartPulseaudio
    echo "Loading script"
    source pulseaudio-control.bash output &>/dev/null
}


@test "nextNode()" {
    # This test will only work if there is currently only one sink. It's
    # kind of hardcoded to avoid excessive complexity.
    numSinks=$(pactl list short sinks | wc -l)
    if [ "$numSinks" -ne 1 ]; then
        skip
    fi

    # Testing sink swapping with 8 sinks
    for i in {1..15}; do
        pactl load-module module-null-sink sink_name="null-sink-$i"
    done
    pactl set-default-sink 1

    # The blacklist has valid and invalid sinks. The switching will be in
    # the same order as the array.
    # This test assumes that `getCurNode` works properly, and tries it 50
    # times. The sink with ID zero must always be ignored, because it's
    # reserved to special sinks, and it might cause issues in the test.
    NODE_BLACKLIST=(
        "null-sink-0"
        "null-sink-8"
        "null-sink-4"
        "null-sink-2"
        "null-sink-2"
        "null-sink-doesntexist"
        "null-sink-300"
        "null-sink-noexist"
        "null-sink-13"
        "null-sink-10"
    )
    local order=(1 3 5 6 7 9 11 12 14 15)
    for i in {1..50}; do
        nextNode
        getCurNode
        echo "Real sink is $curNode, expected ${order[$((i % ${#order[@]}))]} at iteration $i"
        [ "$curNode" -eq "${order[$((i % ${#order[@]}))]}" ]
    done
}


@test "volUp()" {
    # Increases the volume from zero to a set maximum step by step, making
    # sure that the results are expected.
    VOLUME_MAX=350
    VOLUME_STEP=5
    local vol=0
    getCurNode
    pactl set-sink-volume "$curNode" "$vol%"
    for i in {1..100}; do
        volUp
        getCurVol "$curNode"
        if [ "$vol" -lt $VOLUME_MAX ]; then
            vol=$((vol + VOLUME_STEP))
        fi
        echo "Real volume is $VOL_LEVEL, expected $vol"
        [ "$VOL_LEVEL" -eq $vol ]
    done
}


@test "volDown()" {
    # Decreases the volume to 0 step by step, making sure that the results
    # are expected.
    VOLUME_MAX=350
    VOLUME_STEP=5
    # It shouldn't matter that the current volume exceeds the maximum volume
    local vol=375
    getCurNode
    pactl set-sink-volume "$curNode" "$vol%"
    for i in {1..100}; do
        volDown
        getCurVol "$curNode"
        if [ "$vol" -gt 0 ]; then
            vol=$((vol - VOLUME_STEP))
        fi
        echo "Real volume is $VOL_LEVEL, expected $vol"
        [ "$VOL_LEVEL" -eq $vol ]
    done
}


@test "volMute()" {
    # Very simple tests to make sure that volume muting works. The sink starts
    # muted, and its state is changed to check that the function doesn't fail.
    # First of all, the toggle mode is tested.
    getCurNode
    local expected="no"
    pactl set-sink-mute "$curNode" "$expected"
    for i in {1..50}; do
        volMute toggle
        getIsMuted "$curNode"
        if [ "$expected" = "no" ]; then expected="yes"; else expected="no"; fi
        echo "Real status is '$IS_MUTED', expected '$expected'"
        [ "$IS_MUTED" = "$expected" ]
    done

    # Testing that muting once or more results in a muted sink
    volMute mute
    getIsMuted "$curNode"
    [ "$IS_MUTED" = "yes" ]
    volMute mute
    getIsMuted "$curNode"
    [ "$IS_MUTED" = "yes" ]
    volMute mute
    getIsMuted "$curNode"
    [ "$IS_MUTED" = "yes" ]

    # Same for unmuting
    volMute unmute
    getIsMuted "$curNode"
    [ "$IS_MUTED" = "no" ]
    volMute unmute
    getIsMuted "$curNode"
    [ "$IS_MUTED" = "no" ]
    volMute unmute
    getIsMuted "$curNode"
    [ "$IS_MUTED" = "no" ]
}


@test "getNickname()" {
    # The already existing sinks will be ignored.
    offset=$(pactl list short sinks | wc -l)

    # Testing sink nicknames with 10 null sinks. Only a few of them will
    # have a name in the nickname map.
    for i in {0..9}; do
        pactl load-module module-null-sink sink_name="null-sink-$i"
    done

    unset NODE_NICKNAMES
    declare -A NODE_NICKNAMES
    # Checking with an empty map.
    for i in {0..9}; do
        getNickname "$((i + offset))"
        [ "$NODE_NICKNAME" = "Sink #$((i + offset))" ]
    done

    # Populating part of the map.
    NODE_NICKNAMES["does-not-exist"]="null"
    for i in {0..4}; do
        NODE_NICKNAMES["null-sink-$i"]="Null Sink $i"
        getNickname "$((i + offset))"
        [ "$NODE_NICKNAME" = "Null Sink $i" ]
    done
    for i in {5..9}; do
        getNickname "$((i + offset))"
        [ "$NODE_NICKNAME" = "Sink #$((i + offset))" ]
    done

    # Testing empty $nodeName.
    # Observed to happen when a sink is removed (e.g. Bluetooth disconnect)
    # possibly only with unlucky timing of when `getNodeName` runs. cf. #41
    function getNodeName() {
        nodeName=''
    }
    getNickname "$((10 + offset))" # beyond what exists
    [ "$NODE_NICKNAME" = "Sink #$((10 + offset))" ]
}
