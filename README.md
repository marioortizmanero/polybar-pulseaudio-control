# PulseAudio Control

A feature-full volume control module for PulseAudio. Also known as Pavolume. Main features:

* Increase/Decrease and Mute the default sink's audio.
* Switch between sinks easily. You can also blacklist useless devices.
* Optionally enable notifications and OSD messages.
* Works as a shortcut to pavucontrol or your favorite audio manager tool.
* Highly customizable: check the [Usage](#usage) section for details.

![example](screenshots/example.png)


## Installation

### Arch

Install [`pulseaudio-control`](https://aur.archlinux.org/packages/pulseaudio-control/) from the AUR with your preferred method, for example:
```
$ yay -S pulseaudio-control
```

### Other Linux

Download the [bash script](https://github.com/marioortizmanero/polybar-pulseaudio-control/blob/master/pulseaudio-control.bash) from this repository, or extract it from [the latest release](https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/latest), and put it somewhere in your `$PATH`.

#### Dependencies

[`pulseaudio`](https://www.freedesktop.org/wiki/Software/PulseAudio/) with `pactl` in your `$PATH`. You might want to have [`pavucontrol`](https://freedesktop.org/software/pulseaudio/pavucontrol/) installed to easily control pulseaudio with a GUI. The script can send notifications if enabled, for which you'll need a notification daemon like [`dunst`](https://github.com/dunst-project/dunst).

This script works with PipeWire as well, as long as your system has something like [`pipewire-pulse`](https://archlinux.org/packages/extra/x86_64/pipewire-pulse/).

To be able to switch the default sinks from this script you might need to disable stream target device restore by editing the corresponing line in `/etc/pulse/default.pa` to:

```
load-module module-stream-restore restore_device=false
```

At a minimum, bash version 4 is required to run the script. You can check your bash version by running `bash --version`.


## Usage

`pulseaudio-control` is expected to be invoked from a [polybar](//github.com/polybar/polybar) module:
```ini
[module/pulseaudio-control]
type = custom/script
exec = pulseaudio-control [option...] <action>
```

where `action`, and (optionally) `option`s are as specified in `pulseaudio-control help`:

```
Usage: pulseaudio-control [OPTION...] ACTION

Options: [defaults]
  --autosync | --no-autosync
        Whether to maintain same volume for all programs.
        Default: no
  --color-muted <rrggbb>
        Color in which to format when muted.
        Default: 6b6b6b
  --notifications | --no-notifications
        Whether to show notifications when changing sinks.
        Default: no
  --osd | --no-osd
        Whether to display KDE's OSD message.
        Default: no
  --icon-muted <icon>
        Icon to use when muted.
        Default: none
  --icon-sink <icon>
        Icon to use for sink.
        Default: none
  --format <string>
        Use a format string to control the output.
        Available variables:
        * $VOL_ICON
        * $VOL_LEVEL
        * $ICON_SINK
        * $SINK_NICKNAME
        Default: $VOL_ICON ${VOL_LEVEL}%  $ICON_SINK $SINK_NICKNAME
  --icons-volume <icon>[,<icon>...]
        Icons for volume, from lower to higher.
        Default: none
  --volume-max <int>
        Maximum volume to which to allow increasing.
        Default: 130
  --volume-step <int>
        Step size when inc/decrementing volume.
        Default: 2
  --sink-blacklist <name>[,<name>...]
        Sinks to ignore when switching.
        Default: none
  --sink-nicknames-from <prop>
        pactl property to use for sink names, unless overriden by
        --sink-nickname. Its possible values are listed under the 'Properties'
        key in the output of `pactl list sinks`
        Default: none
  --sink-nickname <name>:<nick>
        Nickname to assign to given sink name, taking priority over
        --sink-nicknames-from. May be given multiple times, and 'name' is
        exactly as listed in the output of `pactl list sinks short | cut -f2`.
        Note that you can also specify a port name for the sink with
        `<name>/<port>`.
        Default: none

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
```

See the [Module](#module) section for an example, or the [Useful icons](#useful-icons) section for some packs of icons.


## Module

The example from the screenshot can:

* Increase and decrease the volume on mousewheel scroll
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

## Useful icons

Here's a list with some icons from different fonts you can copy-paste. Most have an space afterwards so that the module has a bit of spacing. They may appear bugged on your browser if the font isn't available there. Please add yours if they aren't in the list.

| Font name                                       | Volumes         | Muted   | Sink icons                 |
| ----------------------------------------------- | :-------------: | :-----: | :------------------------: |
| [FontAwesome](https://fontawesome.com)          | `" , "`       | `" "`  | `" "` or `" "`           |
| [Material](https://material.io/resources/icons) | `" , , "`    | `" "`  | `" "` or `" "` or `" "` |
| Emoji                                           | `"🔈 ,🔉 ,🔊 "` | `"🔇 "` | `"🔈 "` or `"🎧 "`         |
| Emoji v2                                        | `"🕨 ,🕩 ,🕪 "`    | `"🔇 "` | `"🕨 "` or `"🎧 "`          |

Most of these can be used after downloading a [Nerd Font](https://www.nerdfonts.com/) and including it in your [Polybar config](https://github.com/polybar/polybar/wiki/Fonts). For example:

```ini
font-X = Font Awesome 5 Free: style=Solid: pixelsize=11
font-Y = Font Awesome 5 Brands: pixelsize=11
font-Z = Material Icons: style=Regular: pixelsize=13; 2
```

## Sources

Part of the script and of this README's info was taken from [customlinux.blogspot.com](http://customlinux.blogspot.com/2013/02/pavolumesh-control-active-sink-volume.html), the creator. It was later adapted to fit polybar. It is also mixed with [the ArcoLinux version](https://github.com/arcolinux/arcolinux-polybar/blob/master/etc/skel/.config/polybar/scripts/pavolume.sh), which implemented the `listen` action to use less resources.

## Development

Any PRs and issues are welcome! The tests can be ran with `bats tests.bats`, preferrably with the Dockerfile in this repository.
