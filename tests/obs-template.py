#!/usr/bin/env python3
"""Standalone portable OBS export checks: python3 tests/obs-template.py."""

import configparser
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
COMMAND = ROOT / "packages/obs/.local/bin/obs-template"
CONFIG = ROOT / "packages/obs/.config/obs-template"


class ExportTests(unittest.TestCase):
    def test_native_imports_and_source_references(self):
        for platform, desktop_kind, camera_kind in (
            ("macos", "screen_capture", "macos-avcapture"),
            ("linux", "pipewire-screen-capture-source", "v4l2_input"),
        ):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as tmp:
                output = Path(tmp) / "export"
                subprocess.run([str(COMMAND), "--config-dir", str(CONFIG),
                                "--platform", platform, "--output", str(output)],
                               check=True, capture_output=True)
                data = json.loads((output / "scene-collection.json").read_text())
                sources = {s["name"]: s for s in data["sources"] + data["groups"]}
                self.assertEqual(sources["Desktop"]["id"], desktop_kind)
                self.assertEqual(sources["Camera"]["id"], camera_kind)
                self.assertEqual(sources["Desk Cam"]["id"], camera_kind)
                self.assertNotIn("filters", sources["Desk Cam"])
                desk_item = sources["Desk Cam — Fullscreen"]["settings"]["items"][0]
                self.assertEqual(desk_item["source_uuid"], sources["Desk Cam"]["uuid"])
                self.assertEqual(desk_item["bounds"], {"x": 1920, "y": 1080})
                self.assertEqual(desk_item["bounds_type"], 2)
                desk_overlay = sources["Desk Cam — Fullscreen"]["settings"]["items"][1]
                self.assertEqual(desk_overlay["source_uuid"], sources["Desk Face Overlay"]["uuid"])
                self.assertEqual(desk_overlay["pos"], {"x": 1600, "y": 760})
                self.assertNotIn("device", sources["Camera"]["settings"])
                self.assertNotIn("device_id", sources["Camera"]["settings"])
                blur = sources["Camera"]["filters"][0]
                self.assertEqual(blur["id"], "background_removal")
                self.assertEqual(blur["settings"]["blur_background"], 8)
                self.assertEqual(blur["settings"]["useGPU"], "coreml" if platform == "macos" else "cpu")
                intro = sources["Intro — Face"]["settings"]["items"]
                self.assertEqual(len(intro), 2)
                self.assertEqual(intro[0]["source_uuid"], sources["Camera"]["uuid"])
                self.assertEqual(intro[0]["bounds"], {"x": 1920, "y": 1080})
                self.assertEqual(intro[0]["pos"], {"x": 0, "y": 0})
                if platform == "macos":
                    self.assertEqual(sources["Intro — Face"]["filters"][0]["versioned_id"], "color_filter_v2")
                uuids = {s["uuid"] for s in sources.values()}
                for source in sources.values():
                    for item in source["settings"].get("items", []):
                        self.assertIn(item["source_uuid"], uuids)
                self.assertEqual({v["name"] for v in data["scene_order"]},
                                 {"Desktop — Fill", "Desk Cam — Fullscreen", "Intro — Face"})
                self.assertNotIn("Webcam Circle", sources)
                self.assertNotIn("Desktop — Fit", sources)
                self.assertTrue(sources["Desktop"]["muted"])
                audio = sources["Desktop Audio"]
                self.assertEqual(audio["id"], "sck_audio_capture" if platform == "macos" else "pulse_output_capture")
                self.assertFalse(audio["muted"])
                self.assertEqual(audio["monitoring_type"], 0)
                for view in data["scene_order"]:
                    items = sources[view["name"]]["settings"]["items"]
                    capture = [i for i in items if i["source_uuid"] == audio["uuid"]]
                    self.assertEqual(len(capture), 1)
                    self.assertTrue(capture[0]["visible"])
                desktop_items = sources["Desktop — Fill"]["settings"]["items"]
                self.assertEqual(desktop_items[0]["bounds_type"], 3)
                self.assertEqual(desktop_items[1]["pos"], {"x": 1600, "y": 760})
                self.assertEqual(desktop_items[1]["source_uuid"], sources["Desktop Face Overlay"]["uuid"])
                for group in data["groups"]:
                    self.assertEqual(group["id"], "group")
                    child = group["settings"]["items"][0]
                    self.assertEqual(child["source_uuid"], sources["Camera"]["uuid"])
                    self.assertEqual(child["bounds"], {"x": 280, "y": 280})
                    self.assertTrue(child["bounds_crop"])
                    mask = Path(group["filters"][0]["settings"]["image_path"])
                    self.assertTrue(mask.is_file())
                    self.assertEqual(mask.read_bytes(), (CONFIG / "circle-mask.png").read_bytes())
                profile = configparser.ConfigParser()
                profile.read(output / "profile/basic.ini")
                self.assertEqual(profile["Video"]["BaseCX"], "1920")
                self.assertEqual(profile["Video"]["OutputCY"], "1080")
                self.assertFalse((output / "profile/service.json").exists())

    def test_existing_export_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "export"
            output.mkdir()
            sentinel = output / "scene-collection.json"
            sentinel.write_text("existing device choices")
            result = subprocess.run([str(COMMAND), "--config-dir", str(CONFIG),
                                     "--output", str(output)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(sentinel.read_text(), "existing device choices")

    def test_invalid_layout_does_not_create_export(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "config"
            shutil.copytree(CONFIG, config)
            layout = json.loads((config / "layout.json").read_text())
            layout["width"] = 3440
            (config / "layout.json").write_text(json.dumps(layout))
            output = Path(tmp) / "export"
            result = subprocess.run([str(COMMAND), "--config-dir", str(config),
                                     "--output", str(output)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
