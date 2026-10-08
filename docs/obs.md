# Portable OBS desktop + webcam template

OBS uses two native formats: a **Scene Collection** (JSON) for scenes, sources,
transforms and filters, and a **Profile** (directory containing `basic.ini`) for
canvas/output size, frame rate and recording settings. Save both, plus any
referenced image assets. The `obs` Stow package provides an editable layout and
circle mask, with a Python 3 command to generate native imports for each OS.

## Install and generate

Provision OBS Studio, Python 3 and the [OBS Background Removal plugin](https://github.com/royshil/obs-backgroundremoval)
on the host, then select the `obs` dotfiles
package alongside your existing packages:

```sh
./install.sh obs
obs-template --output "$HOME/obs-templates/desktop-v1"
```

On a machine without Keystone's `ks-stow-dotfiles`, use GNU Stow directly:

```sh
stow --dir=packages --target="$HOME" --no-folding obs
```

To try it before Stowing, from this repository:

```sh
python3 packages/obs/.local/bin/obs-template \
  --config-dir packages/obs/.config/obs-template \
  --output "$HOME/obs-templates/desktop-v1"
```

The command auto-detects macOS versus Linux; `--platform macos` or
`--platform linux` lets you generate either explicitly. It never writes OBS's
live configuration and refuses to overwrite an existing export directory.
Keep that directory in place after importing: the mask path is absolute.
Generate a fresh export on each machine so its asset path is correct.

## Import once on each machine

1. In OBS, **Profile → Import**, select the generated `profile` directory.
   Select **Desktop + Circle Webcam** from the Profile menu.
2. **Scene Collection → Import**, select `scene-collection.json`, then select
   **Desktop + Circle Webcam** from the Scene Collection menu.
3. Open **Desktop** source Properties and select your display or window. On
   Linux this uses PipeWire and your desktop portal's share picker. On macOS
   grant OBS screen-recording permission if needed.
4. In **Intro — Face**, open **Camera** Properties and select your webcam.
   On Linux you can preselect it with `--camera-device /dev/v4l/by-id/...`.
   Prefer a stable by-id device path over `/dev/video0`.
5. In **Desk Cam — Fullscreen**, open **Desk Cam** Properties and select your
   second camera. `--desk-camera-device` can preselect a Mac camera ID or a
   Linux `/dev/v4l/by-id/...` device. Camera IDs are host-specific; two BRIOs
   have the same display name but different IDs. Keep the face and desk
   device selections separate.
6. Confirm the **Microphone** source is the desired input and set the recording
   destination in Settings → Output. Make a short test recording.

The template targets OBS 30.2 or newer. Linux needs OBS's built-in PipeWire,
V4L2 and PulseAudio sources, plus a working XDG desktop portal; no extra circle
mask plugin is required. The built-in Image Mask/Blend filter does that job.
The default background blur requires OBS Background Removal. Install its
official universal Mac package and restart OBS. On NixOS, include
`pkgs.obs-studio-plugins.obs-backgroundremoval` in `programs.obs-studio.plugins`
through the existing host configuration. Set `background_blur` to `0` in
`layout.json` to generate a collection without that dependency.
Every scene includes the same **Ableton Audio** source. On macOS it captures
only the application with bundle ID `com.ableton.live` using ScreenCaptureKit;
open Ableton Live and grant OBS audio-capture permission. Browser audio and
other applications are excluded. Keep **Audio Monitoring → Monitor Off** for
Ableton Audio and Microphone: Live already provides the playback you hear.
Monitoring the captured playback again can produce a delayed duplicate through
speakers, which the microphone can pick up. The desktop video source stays muted.
If Live also monitors your voice, that voice can reach OBS both through Ableton
and through its Microphone source; use only one voice path for the recording.

On Linux the source targets a dedicated playback sink's monitor,
`obs_ableton.monitor`, rather than the whole desktop. With PipeWire's PulseAudio
compatibility service, create the sink before opening OBS:

```sh
pactl load-module module-null-sink sink_name=obs_ableton \
  sink_properties=device.description=AbletonOBS
```

Route only the intended application's playback to that sink using your audio
routing tool. Configure listening in that tool while keeping OBS monitoring off.
A different dedicated sink can be selected with
`--ableton-audio-device YOUR_SINK.monitor`. This route must exist locally;
the generator does not create it or change application routing. A missing sink
produces silence. Check the Ableton Audio meter while playing audio in Live
before recording, and confirm other applications do not reach it.

## Layout

- Canvas and output: **1920×1080, 16:9, 30 fps**.
- Webcam: **280-pixel circle**, bottom right, **40-pixel margin**.
- Background blur: **8/20**, lightweight Selfie Segmentation, applied to the
  camera before the circle mask. macOS uses CoreML; Linux uses two CPU threads.
- **Intro — Face** shows the same blurred face camera fullscreen for introductions,
  without the circle mask, desktop or desk camera. On macOS, a neutral built-in
  Color Correction filter on this scene provides the color-processing pass
  needed to avoid the overexposed fullscreen blur output observed in OBS 32.2.2.
- **Desktop — Fill** is the initial scene and fills 16:9 with a centered crop. An ultrawide loses its
  left/right edges; a taller display loses its top/bottom edges.
- **Desk Cam — Fullscreen** fits the second camera into the 16:9 canvas,
  keeping desk objects clear, with the same blurred circular face-camera
  overlay in the bottom-right corner. Background blur applies only to the
  face camera.
- The three scenes share Ableton audio and the face camera. Separate groups
  crop the face camera to a square before masking it, so the overlays stay
  circular without adding helper scenes to the scene selector.

For readable tutorials, capture a 16:9 application window or use a matching
desktop region. Neither fitting nor cropping can preserve every ultrawide
pixel while also filling 16:9 without distortion. Unlock a source to reposition
the crop when the content you want is off-center.

Edit `~/.config/obs-template/layout.json` to change the size, fps or margin.
Set `desk_camera` to `false` on hosts where you do not want the second-camera scene.
Generate into a new directory and import as a new version (change `name` to
distinguish versions). OBS remains free to save machine-specific device choices
in its own writable configuration. Do not Stow its entire live config directory
or share portal restore tokens, device IDs, recording paths or streaming keys.

The starter profile uses x264 and MKV. Select an appropriate hardware encoder
locally if software encoding is too expensive; verify with a short recording.

## Saving later OBS edits

Use **Scene Collection → Export** to save your edited layout, and **Profile →
Export** to save its output settings. Keep any referenced assets with it.
Before committing an export, remove streaming/service credentials and inspect
device IDs, absolute paths and portal restore tokens. For the shared baseline,
prefer updating `layout.json` or the generator; keep host bindings local.

References: [Scene Collections](https://obsproject.com/kb/scene-collections),
[Profiles](https://obsproject.com/kb/profiles),
[OBS bounds types](https://github.com/obsproject/obs-studio/blob/master/libobs/obs.h),
[built-in mask filter](https://github.com/obsproject/obs-studio/blob/master/plugins/obs-filters/mask-filter.c).

Run the standalone export tests with `python3 tests/obs-template.py`. They
check both OS variants, source references, asset paths, profile dimensions and
overwrite refusal. Confirm actual capture on each host with a short recording.

When automating OBS 32.2.2 on macOS over WebSocket, avoid enumerating the
`display_uuid` source property: [OBS issue #13905](https://github.com/obsproject/obs-studio/issues/13905)
documents a crash in that request. Select a display in OBS Properties, or obtain
its UUID directly from macOS and set it without listing the property.

OBS 32.2.2 on this Mac also crashed while enumerating the audio source's
`application` property over WebSocket. Set the known Ableton bundle ID directly;
avoid that property-list request.
