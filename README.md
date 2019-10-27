# PulseAudio Control

A full volume control module for PulseAudio. Also known as Pavolume. Main features:

* Increase/Decrease and Mute the default sink's audio.
* Work as a shortcut to pavucontrol.
* Switch between sinks easily, with optional notifications. You can also blacklist useless devices.
* Check [Configuration](#configuration) for more.

![example](screenshots/example.png)


## Dependencies

Obviously `pulseaudio` to use `pactl` and `pacmd`. You might want to have `pavucontrol` installed to easily control pulseaudio with a GUI. The script can send notifications if enabled, so you may want a notification daemon like `dunst`.

To be able to switch the default sinks from this script you may need to disable stream target device restore by editing the corresponing line in `/etc/pulse/default.pa` to:

`load-module module-stream-restore restore_device=false`


## Configuration

You can change the script configuration at the beginning of the file:

| Name                |  Values          | Description |
| ------------------- | :--------------: | ----------- |
| `OSD`               | `"yes"` / `"no"` | Will display an OSD message when changing volume if set to true |
| `INC`               | Numerical        | Sets the increment/decrease that each volume up/down will perform |
| `MAX_VOL`           | Numerical        | Maximum volume |
| `AUTOSYNC`          | `"yes"` / `"no"` | Will automatically sync all program volumes with the volume of your current sink (output) whenever you change the volume. This is useful if you manage multiple outputs and have issues with the app volumes becoming out of sync with the output |
| `VOLUME_ICONS`      | Bash array like `( "🔉" "🔊" )` | Icons used for the volume (ordered by sound). It uses an array to divide the volume levels by the number of icons you want. For example, if you are using 4 icons and `MAX_VOL` is 100, they will show up in order when the volume is lower than 25, 50, 75 and 100. This is useful because some fonts only have 2 volume levels while others can have up to 4 |
| `MUTED_ICON`        | String           | Icon used for the muted volume |
| `MUTED_COLOR`       | Polybar color    | Color used when the audio is muted |
| `DEFAULT_SINK_ICON` | String           | Icon used for the sink |
| `CUSTOM_SINK_ICON`  | String           | Custom icons for each of your sinks. If a custom icon isn't found, the default one will be used instead |
| `NOTIFICATIONS`     | `"yes"` / `"no"` | Sends a notifcation when the sink is changed |
| `SINK_BLACKLIST`    | Bash array like `( 0 1 2 )` | A blacklist for whenever you switch sinks. You should put in the array the indexes of the devices you want to blaclist. Use `pacmd list-sinks` to see all device names in order to get its index. The list should also be sorted for a small performance improvement |


## Module

The example from the screenshot can:

* Open `pavucontrol` on right click
* Mute the audio on left click
* Change devices on mousewheel click
* Raise and decrease the volume with on mousewheel scroll

```ini
[module/pulseaudio-control]
type = custom/script
tail = true
label=%output%
format-underline = ${colors.blue}

exec = ~/.config/polybar/scripts/pulseaudio-control.sh --listen
click-right = exec pavucontrol &
click-left = ~/.config/polybar/scripts/pulseaudio-control.sh --togmute
click-middle = ~/.config/polybar/scripts/pulseaudio-control.sh --change
scroll-up = ~/.config/polybar/scripts/pulseaudio-control.sh --up
scroll-down = ~/.config/polybar/scripts/pulseaudio-control.sh --down
label-padding = 2
label-foreground = ${colors.foreground}
```

*Note that you will have to change the paths above to where your script is saved. You might want to change or remove the colors too.*

##  Sources

Part of the script and of this README's info was taken from [customlinux.blogspot.com](http://customlinux.blogspot.com/2013/02/pavolumesh-control-active-sink-volume.html), the creator. It was later adapted to fit polybar. It is also mixed with [the ArcoLinux version](https://github.com/arcolinux/arcolinux-polybar/blob/master/etc/skel/.config/polybar/scripts/pavolume.sh) to use the --listen flag and have a faster refresh.
