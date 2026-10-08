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
                sources = {s["name"]: s for s in data["sources"]}
                self.assertEqual(sources["Desktop"]["id"], desktop_kind)
                self.assertEqual(sources["Camera"]["id"], camera_kind)
                self.assertEqual(sources["Desk Cam"]["id"], camera_kind)
                self.assertNotIn("filters", sources["Desk Cam"])
                desk_item = sources["Desk Cam — Fullscreen"]["settings"]["items"][0]
                self.assertEqual(desk_item["source_uuid"], sources["Desk Cam"]["uuid"])
                self.assertEqual(desk_item["bounds"], {"x": 1920, "y": 1080})
                self.assertEqual(desk_item["bounds_type"], 2)
                desk_overlay = sources["Desk Cam — Fullscreen"]["settings"]["items"][1]
                self.assertEqual(desk_overlay["source_uuid"], sources["Webcam Circle"]["uuid"])
                self.assertEqual(desk_overlay["pos"], {"x": 1600, "y": 760})
                self.assertNotIn("device", sources["Camera"]["settings"])
                self.assertNotIn("device_id", sources["Camera"]["settings"])
                blur = sources["Camera"]["filters"][0]
                self.assertEqual(blur["id"], "background_removal")
                self.assertEqual(blur["settings"]["blur_background"], 8)
                self.assertEqual(blur["settings"]["useGPU"], "coreml" if platform == "macos" else "cpu")
                uuids = {s["uuid"] for s in sources.values()}
                for source in sources.values():
                    for item in source["settings"].get("items", []):
                        self.assertIn(item["source_uuid"], uuids)
                for name, mode in (("Desktop — Fit", 2), ("Desktop — Fill", 3)):
                    items = sources[name]["settings"]["items"]
                    self.assertEqual(items[0]["bounds_type"], mode)
                    self.assertEqual(items[1]["pos"], {"x": 1600, "y": 760})
                webcam = sources["Webcam Circle"]
                self.assertEqual((webcam["settings"]["cx"], webcam["settings"]["cy"]), (280, 280))
                mask = Path(webcam["filters"][0]["settings"]["image_path"])
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
