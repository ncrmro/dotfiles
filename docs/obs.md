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
4. In **Webcam Circle**, open **Camera** Properties and select your webcam.
   On Linux you can preselect it with `--camera-device /dev/v4l/by-id/...`.
   Prefer a stable by-id device path over `/dev/video0`.
5. Confirm the **Microphone** source is the desired input and set the recording
   destination in Settings → Output. Make a short test recording.

The template targets OBS 30.2 or newer. Linux needs OBS's built-in PipeWire,
V4L2 and PulseAudio sources, plus a working XDG desktop portal; no extra circle
mask plugin is required. The built-in Image Mask/Blend filter does that job.
The default background blur requires OBS Background Removal. Install its
official universal Mac package and restart OBS. On NixOS, include
`pkgs.obs-studio-plugins.obs-backgroundremoval` in `programs.obs-studio.plugins`
through the existing host configuration. Set `background_blur` to `0` in
`layout.json` to generate a collection without that dependency.
Desktop audio is not added separately. Enable it locally if needed and check
for duplicated audio, especially with macOS screen capture.

## Layout

- Canvas and output: **1920×1080, 16:9, 30 fps**.
- Webcam: **280-pixel circle**, bottom right, **40-pixel margin**.
- Background blur: **8/20**, lightweight Selfie Segmentation, applied to the
  camera before the circle mask. macOS uses CoreML; Linux uses two CPU threads.
- **Desktop — Fit** keeps the entire desktop visible with black bars when its
  aspect ratio differs. This is the initial scene.
- **Desktop — Fill** fills 16:9 with a centered crop. An ultrawide loses its
  left/right edges; a taller display loses its top/bottom edges.
- Both scenes reuse one desktop capture and one camera. A square nested scene
  crops the camera automatically before masking it, so the shape remains a
  circle when the camera resolution changes.

For readable tutorials, capture a 16:9 application window or use a matching
desktop region. Neither fitting nor cropping can preserve every ultrawide
pixel while also filling 16:9 without distortion. Unlock a source to reposition
the crop when the content you want is off-center.

Edit `~/.config/obs-template/layout.json` to change the size, fps or margin.
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
