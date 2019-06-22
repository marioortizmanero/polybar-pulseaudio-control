# Script: pavolume

A full volume control module for PulseAudio. It can:

* Increase/Decrease and Mute the default sink's audio
* Open pavucontrol with a click
* Switch between sinks easily, with optional notifications


![example](screenshots/example.png)


## Dependencies

Obviously `pulseaudio` to use `pactl` and `pacmd`. You might want to have `pavucontrol` installed to easily control pulseaudio with a GUI. The script can send notifications if enabled, so you may want a notification daemon like `dunst`.

To be able to switch the default sinks from this script you may need to disable stream target device restore by editing the corresponing line in `/etc/pulse/default.pa` to:

`load-module module-stream-restore restore_device=false`

## Configuration

| Name            |  Values          | Description |
| --------------- | :--------------: | ----------- |
| `osd`           | `"yes"` / `"no"` | Will display an OSD message when changing volume if set to true |
| `inc`           | numerical        | Sets the increment/decrease that each volume up/down will perform |
| `capvol`        | `"yes"` / `"no"` | Will limit volume to 100 if set to true |
| `maxvol`        | numerical        | Maximum volume (overrided by `capvol`) |
| `autosync`      | `"yes"` / `"no"` | Will automatically sync all sink-inputs (apps) with the current volume of your output (speakers) whenever you change the volume. This is useful if you manage multiple outputs and have issues with the app volumes becoming out of sync with the output (they should move up/down together). If you like keeping apps at different volumes then you should change this to "no" |
| `notifications` | `"yes"` / `"no"` | Sends a notifcation when the sink is changed |
| `volIcon`       | string           | Icon used for the volume (default is from FontAwesome) |
| `mutedIcon`     | string           | Icon used for the muted volume (default is from FontAwesome)|
| `sinkIcon`      | string           | Icon used for the sink (default is from FontAwesome)|
| `mutedColor`    | Polybar color    | Color used when the audio is muted |

## Module

The example from the screenshot can:

* Open `pavucontrol` on right click
* Mute the audio on left click
* Change devices on mousewheel click
* Raise and decrease the volume with on mousewheel scroll

```ini
[module/pavolume]
type = custom/script
interval = 0.5
label=%output%

exec = ~/.config/polybar/scripts/pavolume.sh
click-right = exec pavucontrol
click-left = ~/.config/polybar/scripts/pavolume.sh --togmute
click-middle = ~/.config/polybar/scripts/pavolume.sh --change
scroll-up = ~/.config/polybar/scripts/pavolume.sh --up
scroll-down = ~/.config/polybar/scripts/pavolume.sh --down
label-padding = 2
label-foreground = ${colors.foreground}
```

*Note that you will have to change the paths above to where your script is saved. You might want to change the colors too.*

##  Sources

Part of the script and of this README's info was taken from [customlinux.blogspot.com](http://customlinux.blogspot.com/2013/02/pavolumesh-control-active-sink-volume.html), the creator. It was later adaped to fit polybar. It is also mixed with another script to switch between devices from [here](https://gist.github.com/Jguer/3443e23145902ff30481). The latter was also modified to suit polybar and with the main script. Any more contributions are welcome.

