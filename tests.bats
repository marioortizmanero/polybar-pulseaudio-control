#!/bin/env bats
# vim: filetype=sh
# 
# Polybar PulseAudio Control - tests.bats
# 
# Simple test script to make sure the most basic functions in this script
# always work as intended. The tests will modify the system's PulseAudio
# setup until it's restarted, so either do that after running the test, or
# launch the tests inside a container.
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
    source pulseaudio-control.bash --output &>/dev/null
}


@test "nextSink()" {
    # This test will only work if there is currently only one sink. It's
    # kind of hardcoded to avoid excessive complexity.
    pactl list short sinks
    if [ "$(pactl list short sinks | wc -l)" -ne 1 ]; then
        skip
    fi

    # Testing sink swapping with 8 sinks
    for i in {1..15}; do
        pacmd load-module module-null-sink sink_name="null-sink-$i"
    done
    pacmd set-default-sink 1

    # The blacklist has valid and invalid sinks. The switching will be in
    # the same order as the array.
    # This test assumes that `getCurSink` works properly, and tries it 50
    # times. The sink with ID zero must always be ignored, because it's
    # reserved to special sinks, and it might cause issues in the test.
    SINK_BLACKLIST=(
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
        nextSink
        getCurSink
        echo "Real sink is $curSink, expected ${order[$((i % ${#order[@]}))]} at iteration $i"
        [ "$curSink" -eq "${order[$((i % ${#order[@]}))]}" ]
    done
}


@test "volUp()" {
    # Increases the volume from zero to a set maximum step by step, making
    # sure that the results are expected.
    MAX_VOL=350
    INC=5
    local vol=0
    getCurSink
    pactl set-sink-volume "$curSink" "$vol%"
    for i in {1..100}; do
        volUp
        getCurVol "$curSink"
        if [ "$vol" -lt $MAX_VOL ]; then
            vol=$((vol + INC))
        fi
        echo "Real volume is $curVol, expected $vol"
        [ "$curVol" -eq $vol ]
    done
}


@test "volDown()" {
    # Decreases the volume to 0 step by step, making sure that the results
    # are expected.
    MAX_VOL=350
    INC=5
    # It shouldn't matter that the current volume exceeds the maximum volume
    local vol=375
    getCurSink
    pactl set-sink-volume "$curSink" "$vol%"
    for i in {1..100}; do
        volDown
        getCurVol "$curSink"
        if [ "$vol" -gt 0 ]; then
            vol=$((vol - INC))
        fi
        echo "Real volume is $curVol, expected $vol"
        [ "$curVol" -eq $vol ]
    done
}


@test "volMute()" {
    # Very simple tests to make sure that volume muting works. The sink starts
    # muted, and its state is changed to check that the function doesn't fail.
    # First of all, the toggle mode is tested.
    getCurSink
    local expected="no"
    pactl set-sink-mute "$curSink" "$expected"
    for i in {1..50}; do
        volMute toggle
        getIsMuted "$curSink"
        if [ "$expected" = "no" ]; then expected="yes"; else expected="no"; fi
        echo "Real status is '$isMuted', expected '$expected'"
        [ "$isMuted" = "$expected" ]
    done

    # Testing that muting once or more results in a muted sink
    volMute mute
    getIsMuted "$curSink"
    [ "$isMuted" = "yes" ]
    volMute mute
    getIsMuted "$curSink"
    [ "$isMuted" = "yes" ]
    volMute mute
    getIsMuted "$curSink"
    [ "$isMuted" = "yes" ]

    # Same for unmuting
    volMute unmute
    getIsMuted "$curSink"
    [ "$isMuted" = "no" ]
    volMute unmute
    getIsMuted "$curSink"
    [ "$isMuted" = "no" ]
    volMute unmute
    getIsMuted "$curSink"
    [ "$isMuted" = "no" ]
}


@test "getNickname()" {
    # The already existing sinks will be ignored.
    offset=$(pactl list short sinks | wc -l)

    # Testing sink nicknames with 10 null sinks. Only a few of them will
    # have a name in the nickname map.
    for i in {0..9}; do
        pacmd load-module module-null-sink sink_name="null-sink-$i"
    done

    unset SINK_NICKNAMES
    declare -A SINK_NICKNAMES
    # Checking with an empty map.
    for i in {0..9}; do
        getNickname "$((i + offset))"
        [ "$nickname" = "Sink #$((i + offset))" ]
    done

    # Populating part of the map.
    SINK_NICKNAMES["does-not-exist"]="null"
    for i in {0..4}; do
        SINK_NICKNAMES["null-sink-$i/"]="Null Sink $i"
        getNickname "$((i + offset))"
        [ "$nickname" = "Null Sink $i" ]
    done
    for i in {5..9}; do
        getNickname "$((i + offset))"
        [ "$nickname" = "Sink #$((i + offset))" ]
    done
}
