#!/bin/env bats
# vim: filetype=sh
# 
# Polybar PulseAudio Control - tests.bats
# 
# Simple test script to make sure the most basic functions in this script
# always work as intended. The tests will temporarily modify your pulseaudio
# setup, but they will be restored to the default after finishing.
# The tests can be run with BATS. See the README.md for more info.

# Loading the script and starting pulseaudio if it isn't already
function setup() {
    echo "Loading script"
    if ! pulseaudio --check &>/dev/null; then
        echo "Starting pulseaudio"
        pulseaudio --start -D
    fi
    source pulseaudio-control.bash &>/dev/null
}

function teardown() {
    echo "Restarting pulseaudio"
    killall pulseaudio
    pulseaudio --start -D
}


@test "changeDevice()" {
    # This test will only work if there is currently only one sink. It's
    # kind of hardcoded to avoid excesive complexity.
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
    # reserved to special sinks.
    SINK_BLACKLIST=(0 8 4 2 2 -100 300 -9 13 10)
    local order=(1 3 5 6 7 9 11 12 14 15)
    for i in {1..50}; do
        changeDevice
        getCurSink
        echo "Real sink is $activeSink, expected ${order[$((i % ${#order[@]}))]} at iteration $i"
        [ "$activeSink" -eq "${order[$((i % ${#order[@]}))]}" ]
    done
}


@test "volUp()" {
    # Increases the volume from zero to a set maximum step by step, making
    # sure that the results are expected.
    MAX_VOL=350
    INC=5
    local vol=0
    getCurSink
    pactl set-sink-volume "$activeSink" "$vol%"
    for i in {1..100}; do
        volUp
        getCurVol
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
    pactl set-sink-volume "$activeSink" "$vol%"
    getCurVol
    for i in {1..100}; do
        volDown
        getCurVol
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
    local status=0
    local realStatus
    getCurSink
    pactl set-sink-mute "$activeSink" "$status"
    for i in {1..50}; do
        volMute
        getVolMuteStatus
        if [ "$status" -eq 0 ]; then status=1; fi
        if [ "$isMuted" = "no" ]; then realStatus=1; else realStatus=0; fi
        echo "Real status is $realStatus, expected $status"
        [ "$realStatus" -eq $status ]
    done
}
