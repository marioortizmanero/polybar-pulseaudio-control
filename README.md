# PulseAudio Control

A feature-full volume control module for PulseAudio. Also known as Pavolume. Main features:

* Increase/Decrease and Mute the default sink's audio.
* Switch between sinks easily. You can also blacklist useless devices.
* Optionally enable notifications and OSD messages.
* Works as a shortcut to pavucontrol or your favorite audio manager tool.
* Highly customizable: check the [Configuration](#configuration) section for details.

![example](screenshots/example.png)


## Dependencies

[`pulseaudio`](https://www.freedesktop.org/wiki/Software/PulseAudio/) with `pactl` and `pacmd` in your `$PATH`. You might want to have [`pavucontrol`](https://freedesktop.org/software/pulseaudio/pavucontrol/) installed to easily control pulseaudio with a GUI. The script can send notifications if enabled, for which you'll need a notification daemon like [`dunst`](https://github.com/dunst-project/dunst).

To be able to switch the default sinks from this script you might need to disable stream target device restore by editing the corresponing line in `/etc/pulse/default.pa` to:

```
load-module module-stream-restore restore_device=false
```

At a minimum, bash version 4 is required to run the script. You can check your bash version by running `bash --version`.


## Usage

`polybar-pulseaudio-control` is expected to be invoked from a [polybar](//github.com/polybar/polybar) module:
```ini
[module/pulseaudio-control]
type = custom/script
exec = polybar-pulseaudio-control [option...] <action>
```

where `action`, and (optionally) `option`s are as specified in `polybar-pulseaudio-control help`:

```
Options: (defaults)
    --autosync | --no-autosync            whether to maintain same volume for all programs (no)
    --color-mute <rrggbb>                 color in which to format when muted (6b6b6b)
    --notifications | --no-notifications  whether to show notifications when changing sink (no)
    --osd | --no-osd                      whether to display KDE's OSD message (no)
    --icon-muted <icon>                   icon to use when muted (none)
    --icon-sink <icon>                    icon to use for sink (none)
    --icons-volume <icon>[,<icon>...]     icons for volume, from lower to higher (none)
    --volume-max <int>                    maximum volume to which to allow increasing (130)
    --volume-step <int>                   step size when inc/decrementing volume (2)
    --sink-blacklist <name>[,<name>...]   sinks to ignore when switching (none)
    --sink-nickname-from <prop>           pacmd property to use for sink name (none)
                                          as listed under the 'properties' key in the output of `pacmd list-sinks`
    --sink-nickname <name>:<nick>         nickname to assign to given sink name (may be given multiple times) (none)
                                          where 'name' is exactly as listed in the output of `pactl list sinks short | cut -f2`

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

See the [Module](#module) section for a concrete example, or the [Useful icons](#useful-icons) section for example icons.


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

exec = "~/.config/polybar/scripts/pulseaudio-control.bash --volume-max=150 --icons-volume='🔈 ,🔉 ,🔊 ' --sink-nickname-from-prop=device.description --osd listen"
click-right = exec pavucontrol &
click-left = ~/.config/polybar/scripts/pulseaudio-control.bash togmute
click-middle = ~/.config/polybar/scripts/pulseaudio-control.bash next-sink
scroll-up = ~/.config/polybar/scripts/pulseaudio-control.bash up
scroll-down = ~/.config/polybar/scripts/pulseaudio-control.bash down
label-padding = 2
label-foreground = ${colors.foreground}
```

*Note that you will have to change the paths above to where your script is saved. You might want to change or remove the colors and labels, too.*

## Useful icons

Here's a list with some icons from different fonts you can copy-paste. Most have an space afterwards so that the module has a bit of spacing. They may appear bugged on your browser if the font isn't available there. Please add yours if they aren't in the list.

| Font name                                       | Volumes               | Muted   | Sink icons             |
| ----------------------------------------------- | :-------------------: | :-----: | :--------------------: |
| [FontAwesome](https://fontawesome.com)          | `" , "`         | `" "`  | `" "` or `" "`         |
| [Material](https://material.io/resources/icons) | `" , , "`    | `" "`  | `" "` or `" "` or `" "` |
| Emoji                                           | `"🔈 ,🔉 ,🔊 "` | `"🔇 "` | `"🔈 "` or `"🎧"`        |
| Emoji v2                                        | `"🕨 ,🕩 ,🕪 "`    | `"🔇 "` | `"🕨 "` or `"🎧"`         |

Most of these can be used after downloading a [Nerd Font](https://www.nerdfonts.com/), or from your distro's repository.

##  Sources

Part of the script and of this README's info was taken from [customlinux.blogspot.com](http://customlinux.blogspot.com/2013/02/pavolumesh-control-active-sink-volume.html), the creator. It was later adapted to fit polybar. It is also mixed with [the ArcoLinux version](https://github.com/arcolinux/arcolinux-polybar/blob/master/etc/skel/.config/polybar/scripts/pavolume.sh), which implemented the `listen` action to use less resources.

## Development

Any PRs and issues are welcome! The tests can be ran with `bats tests.bats`.
