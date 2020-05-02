# PulseAudio Control

A feature-full volume control module for PulseAudio. Also known as Pavolume. Main features:

* Increase/Decrease and Mute the default sink's audio.
* Switch between sinks easily. You can also blacklist useless devices.
* Optionally enable notifications and OSD messages.
* Works as a shortcut to pavucontrol or your favorite audio manager tool.
* Check [Configuration](#configuration) for more.

![example](screenshots/example.png)


## Dependencies

[`pulseaudio`](https://www.freedesktop.org/wiki/Software/PulseAudio/) with `pactl` and `pacmd` in your `$PATH`. You might want to have [`pavucontrol`](https://freedesktop.org/software/pulseaudio/pavucontrol/) installed to easily control pulseaudio with a GUI. The script can send notifications if enabled, for which you'll need a notification daemon like [`dunst`](https://github.com/dunst-project/dunst).

To be able to switch the default sinks from this script you might need to disable stream target device restore by editing the corresponing line in `/etc/pulse/default.pa` to:

`load-module module-stream-restore restore_device=false`

At a minimum, bash version 4 is required to run the script. You can check your bash version by running:

`bash --version`


## Configuration

You can change the script configuration at the beginning of the file:

| Name                   |  Values                  | Description |
| ---------------------- | :----------------------: | ----------- |
| `OSD`                  | `"yes"` / `"no"`         | Will display an OSD message when changing volume if set to true. |
| `INC`                  | Numerical                | Sets the increment/decrease that each volume up/down will perform. |
| `MAX_VOL`              | Numerical                | Maximum volume. |
| `AUTOSYNC`             | `"yes"` / `"no"`         | Will automatically sync all program volumes with the volume of your current sink (output) whenever you change the volume. This is useful if you manage multiple outputs and have issues with the app volumes becoming out of sync with the output. |
| `VOLUME_ICONS`         | Bash array with i        cons like `( "🔉" "🔊" )`\* | Icons used for the volume (ordered by sound level). The volume levels are divided by the number of icons inside it. For example, if you are using 4 icons and `MAX_VOL` is 100, they will show up in order when the volume is lower than 25, 50, 75 and 100. This is useful because some fonts only have 2 volume levels while others can have up to 4. |
| `MUTED_ICON`           | String\*                 | Icon used for the muted volume. |
| `MUTED_COLOR`          | String ([polybar color](https://github.com/polybar/polybar/wiki/Formatting#foreground-color-f))   | Color used when the audio is muted. |
| `NOTIFICATIONS`        | `"yes"` / `"no"`         | Sends a notification when the sink is changed. |
| `SINK_ICON`            | String\*                 | Icon always displayed to the left of the sink names. |
| `SINK_BLACKLIST`       | Bash array               | A blacklist for whenever sinks are switched. Use `pactl list sinks short` to see all active sink names. |
| `SINK_NICKNAMES`       | Bash associative array   | Maps the PulseAudio sink names to human-readable nicknames. Use `pactl list sinks short` to obtain the active sinks names. If unconfigured, `Sink #N` is used instead. Custom icons\* for the sinks can be added here if `SINK_ICON` is set to `""`. |

\*Check the [Useful icons](#useful-icons) section for examples.


## Module

The example from the screenshot can:

* Raise and decrease the volume on mousewheel scroll
* Mute the audio on left click
* Switch between devices on mousewheel click
* Open `pavucontrol` on right click

```ini
[module/pulseaudio-control]
type = custom/script
tail = true
label=%output%
format-underline = ${colors.blue}

exec = ~/.config/polybar/scripts/pulseaudio-control.bash listen
click-right = exec pavucontrol &
click-left = ~/.config/polybar/scripts/pulseaudio-control.bash togmute
click-middle = ~/.config/polybar/scripts/pulseaudio-control.bash next-sink
scroll-up = ~/.config/polybar/scripts/pulseaudio-control.bash up
scroll-down = ~/.config/polybar/scripts/pulseaudio-control.bash down
label-padding = 2
label-foreground = ${colors.foreground}
```

*Note that you will have to change the paths above to where your script is saved. You might want to change or remove the colors and labels, too.*

## Usage

Here are all the available actions, in case you want to modify the module above, or want to use it for different reasons:

```
Usage: pulseaudio-control.bash ACTION

Actions:
    help              display this help and exit
    output            print the PulseAudio status once
    listen            listen for changes in PulseAudio to automatically
                      update this script's output
    up, down          increase or decrease the default sink's volume
    mute, unmute      mute or unmute the default sink's audio
    togmute           switch between muted and unmuted
    next-sink         switch to the next available sink
    sync              synchronize all the output streams volume to
                      the be the same as the current sink's volume
```

## Useful icons

Here's a list with some icons from different fonts you can copy-paste. Most have an space afterwards so that the module has a bit of spacing. They may appear bugged on Firefox if the font isn't available there. Please add yours if they aren't in the list.

| Font name                                       | Volumes               | Muted   | Sink icons             |
| ----------------------------------------------- | :-------------------: | :-----: | :--------------------: |
| [FontAwesome](https://fontawesome.com)          | `(" " " ")`         | `" "`  | `" "`, `" "`         |
| [Material](https://material.io/resources/icons) | `(" " " " " ")`    | `" "`  | `" "`, `" "`, `" "` |
| Emoji                                           | `("🔈 " "🔉 " "🔊 ")` | `"🔇 "` | `"🔈 "`, `"🎧"`        |
| Emoji v2                                        | `("🕨 " "🕩 " "🕪 ")`    | `"🔇 "` | `"🕨 "`, `"🎧"`         |

Most of these can be used after downloading a [Nerd Font](https://www.nerdfonts.com/), or from your distro's repository.

##  Sources

Part of the script and of this README's info was taken from [customlinux.blogspot.com](http://customlinux.blogspot.com/2013/02/pavolumesh-control-active-sink-volume.html), the creator. It was later adapted to fit polybar. It is also mixed with [the ArcoLinux version](https://github.com/arcolinux/arcolinux-polybar/blob/master/etc/skel/.config/polybar/scripts/pavolume.sh), which implemented the `listen` action to use less resources.

## Development

Any PRs and issues are welcome! The tests can be ran with `bats tests.bats`.
