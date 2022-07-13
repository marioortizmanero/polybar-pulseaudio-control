# PulseAudio Control

A feature-full volume control module for PulseAudio. Also known as Pavolume. Main features:

* Increase/Decrease and Mute the default audio node (can be sink or source).
* Switch between nodes easily. You can also blacklist useless devices.
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
Usage: ./pulseaudio-control.bash [OPTION...] ACTION

Terminology: A node represents either a sink (output) or source (input).

Options:
  --autosync | --no-autosync
        Whether to maintain same volume for all programs.
        Default: "no"
  --color-muted <rrggbb>
        Color in which to format when muted.
        Default: "6b6b6b"
  --notifications | --no-notifications
        Whether to show notifications when changing nodes.
        Default: "no"
  --osd | --no-osd
        Whether to display KDE's OSD message.
        Default: "no"
  --icon-muted <icon>
        Icon to use when muted.
        Default: none
  --icon-node <icon>
        Icon to use for node.
        Default: none
  --format <string>
        Use a format string to control the output.
        Remember to pass this argument wrapped in single quotes (`'`) instead
        of double quotes (`"`) to avoid your shell from evaluating the
        variables early.
        Available variables:
        * $VOL_ICON
        * $VOL_LEVEL
        * $ICON_NODE
        * $NODE_NICKNAME
        * $IS_MUTED (yes/no)
        Default: '$VOL_ICON ${VOL_LEVEL}%  $ICON_NODE $NODE_NICKNAME'
  --icons-volume <icon>[,<icon>...]
        Icons for volume, from lower to higher.
        Default: none
  --node-type <node_type>
        Whether to consider PulseAudio sinks (output) or sources (input).
        All the operations of pulseaudio-control will apply to one of the two.
        Pass `input` for the sources, e.g. a microphone.
        Pass `output` for the sinks, e.g. speakers, headphones.
        Default: "output"
  --volume-max <int>
        Maximum volume to which to allow increasing.
        Default: "130"
  --volume-step <int>
        Step size when inc/decrementing volume.
        Default: "2"
  --node-blacklist <name>[,<name>...]
        Nodes to ignore when switching. You can use globs. Don't forget to
        quote the string when using globs, to avoid unwanted shell glob
        extension.
        Default: none
  --node-nicknames-from <prop>
        pactl property to use for node names, unless overriden by
        --node-nickname. Its possible values are listed under the 'Properties'
        key in the output of `pactl list sinks` and `pactl list sources`.
        Default: none
  --node-nickname <name>:<nick>
        Nickname to assign to given node name, taking priority over
        --node-nicknames-from. May be given multiple times, and 'name' is
        exactly as listed in the output of `pactl list sinks short | cut -f2`
        and `pactl list sources short | cut -f2`.
        Note that you can also specify a port name for the node with
        `<name>/<port>`.
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
        Default: "0.05"

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
    https://github.com/marioortizmanero/polybar-pulseaudio-control
```

See the [Module](#module) section for an example, or the [Useful icons](#useful-icons) section for some packs of icons.


## Module

The example from the screenshot can:

* Increase and decrease the volume on mousewheel scroll
* Mute the audio on left click
* Switch between devices on mousewheel click
* Open `pavucontrol` on right click

```ini
[module/pulseaudio-control-output]
type = custom/script
tail = true
format-underline = ${colors.cyan}
label-padding = 2
label-foreground = ${colors.foreground}

# Icons mixed from Font Awesome 5 and Material Icons
# You can copy-paste your options for each possible action, which is more
# trouble-free but repetitive, or apply only the relevant ones (for example
# --node-blacklist is only needed for next-node).
exec = pulseaudio-control --icons-volume " , " --icon-muted " " --node-nicknames-from "device.description" --node-nickname "alsa_output.pci-0000_00_1b.0.analog-stereo:  Speakers" --node-nickname "alsa_output.usb-Kingston_HyperX_Virtual_Surround_Sound_00000000-00.analog-stereo:  Headphones" listen
click-right = exec pavucontrol &
click-left = pulseaudio-control togmute
click-middle = pulseaudio-control --node-blacklist "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra2" next-node
scroll-up = pulseaudio-control --volume-max 130 up
scroll-down = pulseaudio-control --volume-max 130 down

[module/pulseaudio-control-input]
type = custom/script
tail = true
format-underline = ${colors.cyan}
label-padding = 2
label-foreground = ${colors.foreground}

# Use --node-blacklist to remove the unwanted PulseAudio .monitor that are child of sinks
exec = pulseaudio-control  --node-type input --icons-volume "" --icon-muted "" --node-nickname "alsa_output.pci-0000_0c_00.3.analog-stereo:  Webcam" --node-nickname "alsa_output.usb-Kingston_HyperX_Virtual_Surround_Sound_00000000-00.analog-stereo:  Headphones" --node-blacklist "*.monitor" listen
click-right = exec pavucontrol &
click-left = pulseaudio-control --node-type input togmute
click-middle = pulseaudio-control --node-type input next-node
scroll-up = pulseaudio-control --node-type input --volume-max 130 up
scroll-down = pulseaudio-control --node-type input --volume-max 130 down
```

## Useful icons

Here's a list with some icons from different fonts you can copy-paste. Most have a space afterwards so that the module has a bit of spacing. They may appear bugged on your browser if the font isn't available there. Please add yours if they aren't in the list.

| Font name                                       | Volumes         | Muted            | Output icons               | Input icons |
| ----------------------------------------------- | :-------------: | :--------------: | :------------------------: | :---------: |
| [FontAwesome](https://fontawesome.com)          | `" , , "`    | `" "` or `" "` | `" "` or `" "` or ``    | `", "`    |
| [Material](https://material.io/resources/icons) | `" , , "`    | `" "` or `"󰍭 "` | `" "` or `" "` or `" "` | `"󰍬, 󰍮"`    |
| Emoji                                           | `"🔈 ,🔉 ,🔊 "` | `"🔇 "`          | `"🔈 "` or `"🎧 "`         | `"🎙️ "`      |
| Emoji v2                                        | `"🕨 ,🕩 ,🕪 "`    | `"🔇 "`          | `"🕨 "` or `"🎧 "`          | `"🎤 "`     |

Most of these can be used after downloading a [Nerd Font](https://www.nerdfonts.com/) and including it in your [Polybar config](https://github.com/polybar/polybar/wiki/Fonts). For example:

```ini
font-X = Font Awesome 5 Free: style=Solid: pixelsize=11
font-Y = Font Awesome 5 Brands: pixelsize=11
font-Z = Material Icons: style=Regular: pixelsize=13; 2
```

## FAQ

### Can I use this with a status bar other than Polybar?

The only part of this script that's tied to Polybar is the color formatting.
When muted, the dimmed color will probably not work. Please [let us know in this
issue](https://github.com/marioortizmanero/polybar-pulseaudio-control/issues/36)
if you want support for a new status bar. I'd strongly recommend you to open a
PR yourself, as it should be relatively easy!

### Does this work with PipeWire?

Yes! You only need to install the pulseaudio client on your machine. On Arch
Linux, that's
[`pipewire-pulse`](https://archlinux.org/packages/extra/x86_64/pipewire-pulse/),
for example.

It won't work with other audio servers like JACK, though.

### This script uses too much CPU

We use the `pactl subscribe` command to get notified of new events that may
occur in order to refresh the output. However, the command often outputs *a lot*
of events for a simple action, like increasing the volume. Instead of refreshing
for every single line it prints, we:

1. Wait for one event
2. Update the output first
3. Continue to listen for events until a timeout ends, or until we reach a large
   enough number of them
4. Update the output again
5. Go back to step 1

This way, the first event will update quickly, and the following ones, which are
most likely unnecessary, will be ignored until some time passes. This reduces
the CPU usage, but it's not really perfect, as everyone percieves latency
differently, and it depends on the use-case.

The timer can be configured with `--listen-timeout-secs`, which has a default
value of `0.05` (50 ms). If you want less CPU usage, i.e., ignore more duplicate
events, you can bump it to, for example, `0.1` (100 ms). Or for faster refreshes
when performing multiple actions quickly, e.g., updating the volume with your
mousewheel, you can even use a smaller value.

### This script feels laggy when performing multiple actions quickly

Please refer to the previous question, as you can fix this by setting a smaller
refresh delay with `--listen-timeout-secs`.

## Sources

Part of the script and of this README's info was taken from [customlinux.blogspot.com](http://customlinux.blogspot.com/2013/02/pavolumesh-control-active-sink-volume.html), the creator. It was later adapted to fit polybar. It is also mixed with [the ArcoLinux version](https://github.com/arcolinux/arcolinux-polybar/blob/master/etc/skel/.config/polybar/scripts/pavolume.sh), which implemented the `listen` action to use less resources.

## Development

Any PRs and issues are welcome! The tests can be ran with `bats tests.bats`, preferrably with the Dockerfile in this repository.
