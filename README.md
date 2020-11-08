# PulseAudio Control

A feature-full volume control module for PulseAudio. Also known as Pavolume. Main features:

* Increase/Decrease and Mute the default sink's audio.
* Switch between sinks easily. You can also blacklist useless devices.
* Optionally enable notifications and OSD messages.
* Works as a shortcut to pavucontrol or your favorite audio manager tool.
* Highly customizable: check the [Configuration](#configuration) section for details.

![example](screenshots/example.png)


## Installation

### Arch

Install [`pulseaudio-control`](https://aur.archlinux.org/packages/pulseaudio-control/) from the AUR with your preferred method, for example:
```
$ yay -S pulseaudio-control
```

### Other Linux

Download the [bash script](https://github.com/marioortizmanero/polybar-pulseaudio-control/blob/master/pulseaudio-control.bash) from this repository, or extract it from [the latest release](https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/latest), and put it somewhere on your `$PATH`.

#### Dependencies

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
Usage: ./pulseaudio-control.bash [OPTION...] ACTION

Options: [defaults]
  --autosync | --no-autosync            whether to maintain same volume for all
                                        programs [no]
  --color-muted <rrggbb>                color in which to format when muted
                                        [6b6b6b]
  --notifications | --no-notifications  whether to show notifications when
                                        changing sinks [no]
  --osd | --no-osd                      whether to display KDE's OSD message
                                        [no]
  --icon-muted <icon>                   icon to use when muted [none]
  --icon-sink <icon>                    icon to use for sink [none]
  --format <string>                     use a format string to control the output
                                        Available variables: $VOL_ICON,
                                        $VOL_LEVEL, $ICON_SINK, and
                                        $SINK_NICKNAME
                                        [$VOL_ICON ${VOL_LEVEL}%  $ICON_SINK $SINK_NICKNAME]
  --icons-volume <icon>[,<icon>...]     icons for volume, from lower to higher
                                        [none]
  --volume-max <int>                    maximum volume to which to allow
                                        increasing [130]
  --volume-step <int>                   step size when inc/decrementing volume
                                        [2]
  --sink-blacklist <name>[,<name>...]   sinks to ignore when switching [none]
  --sink-nicknames-from <prop>          pacmd property to use for sink names,
                                        unless overriden by --sink-nickname.
                                        Its possible values are listed under
                                        the 'properties' key in the output of
                                        `pacmd list-sinks` [none]
  --sink-nickname <name>:<nick>         nickname to assign to given sink name,
                                        taking priority over
                                        --sink-nicknames-from. May be given
                                        multiple times, and 'name' is exactly as
                                        listed in the output of
                                        `pactl list sinks short | cut -f2`
                                        [none]

Actions:
  help              display this help and exit
  output            print the PulseAudio status once
  listen            listen for changes in PulseAudio to automatically update
                    this script's output
  up, down          increase or decrease the default sink's volume
  mute, unmute      mute or unmute the default sink's audio
  togmute           switch between muted and unmuted
  next-sink         switch to the next available sink
  sync              synchronize all the output streams volume to be the same
                    as the current sink's volume
```

See the [Module](#module) section for an example, or the [Useful icons](#useful-icons) section for some packs of icons.


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
format-underline = ${colors.cyan}
label-padding = 2
label-foreground = ${colors.foreground}

# Icons mixed from Font Awesome 5 and Material Icons
# You can copy-paste your options for each possible action, which is more
# trouble-free but repetitive, or apply only the relevant ones (for example
# --sink-blacklist is only needed for next-sink).
exec = pulseaudio-control --icons-volume " , " --icon-muted " " --sink-nicknames-from "device.description" --sink-nickname "alsa_output.pci-0000_00_1b.0.analog-stereo:  Speakers" --sink-nickname "alsa_output.usb-Kingston_HyperX_Virtual_Surround_Sound_00000000-00.analog-stereo:  Headphones" listen
click-right = exec pavucontrol &
click-left = pulseaudio-control togmute
click-middle = pulseaudio-control --sink-blacklist "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra2" next-sink
scroll-up = pulseaudio-control --volume-max 130 up
scroll-down = pulseaudio-control --volume-max 130 down
```

*Note that you will have to change the paths above to where your script is saved. You might want to change or remove the colors and labels, too.*

## Useful icons

Here's a list with some icons from different fonts you can copy-paste. Most have an space afterwards so that the module has a bit of spacing. They may appear bugged on your browser if the font isn't available there. Please add yours if they aren't in the list.

| Font name                                       | Volumes         | Muted   | Sink icons                 |
| ----------------------------------------------- | :-------------: | :-----: | :------------------------: |
| [FontAwesome](https://fontawesome.com)          | `" , "`       | `" "`  | `" "` or `" "`           |
| [Material](https://material.io/resources/icons) | `" , , "`    | `" "`  | `" "` or `" "` or `" "` |
| Emoji                                           | `"🔈 ,🔉 ,🔊 "` | `"🔇 "` | `"🔈 "` or `"🎧 "`         |
| Emoji v2                                        | `"🕨 ,🕩 ,🕪 "`    | `"🔇 "` | `"🕨 "` or `"🎧 "`          |

Most of these can be used after downloading a [Nerd Font](https://www.nerdfonts.com/) and including it in your Polybar config. For example:

```ini
font-X = Font Awesome 5 Free: style=Solid: pixelsize=11
font-Y = Font Awesome 5 Brands: pixelsize=11
font-Z = Material Icons: style=Regular: pixelsize=13; 2
```

## Sources

Part of the script and of this README's info was taken from [customlinux.blogspot.com](http://customlinux.blogspot.com/2013/02/pavolumesh-control-active-sink-volume.html), the creator. It was later adapted to fit polybar. It is also mixed with [the ArcoLinux version](https://github.com/arcolinux/arcolinux-polybar/blob/master/etc/skel/.config/polybar/scripts/pavolume.sh), which implemented the `listen` action to use less resources.

## Development

Any PRs and issues are welcome! The tests can be ran with `bats tests.bats`.
