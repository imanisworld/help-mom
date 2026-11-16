#!/usr/bin/env python3
"""Real Chromium acceptance tests for the Creative Moments browser app.

Runs against a local HTTP server with mobile viewport emulation. This is not
a substitute for real iPhone/iPad Safari and Apple Pencil acceptance testing.
"""
import json
import re
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
STORAGE_KEY = "creative-moments-browser-preview-v1"


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def open_home(page):
    page.get_by_role("button", name=re.compile("‹ Home")).click()


def run(url):
    failures = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 390, "height": 844},
            device_scale_factor=2,
            is_mobile=True,
            has_touch=True,
            accept_downloads=True,
            service_workers="allow",
        )
        page = context.new_page()
        page.on("pageerror", lambda error: failures.append(str(error)))
        page.on("dialog", lambda dialog: dialog.accept())

        # Home and planner: create, persist, and reopen.
        page.goto(url, wait_until="networkidle")
        assert page.get_by_role("button", name=re.compile("My Planner")).is_visible()
        page.get_by_role("button", name=re.compile("My Planner")).click()
        page.locator("#new-task").fill("Browser acceptance task")
        page.get_by_role("button", name="Add", exact=True).click()
        assert page.get_by_text("Browser acceptance task").count() == 1
        page.reload(wait_until="networkidle")
        page.get_by_role("button", name=re.compile("My Planner")).click()
        assert page.get_by_text("Browser acceptance task").count() == 1
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 2")

        # Journal: autosave into the same month's record across a reload.
        open_home(page)
        page.get_by_role("button", name=re.compile("My Journal")).click()
        page.get_by_label("Notes & inspiration").fill("Browser acceptance journal")
        page.reload(wait_until="networkidle")
        page.get_by_role("button", name=re.compile("My Journal")).click()
        assert page.get_by_label("Notes & inspiration").input_value() == "Browser acceptance journal"

        # Drawing and saved creations: actually draw a stroke with mouse/pointer events.
        open_home(page)
        page.get_by_role("button", name=re.compile("Color & Draw")).click()
        page.get_by_role("button", name="Sketch an idea").click()
        canvas = page.locator("canvas")
        canvas.scroll_into_view_if_needed()
        bounds = canvas.bounding_box()
        assert bounds is not None
        x, y = bounds["x"] + bounds["width"] * 0.3, bounds["y"] + bounds["height"] * 0.3
        page.mouse.move(x, y)
        page.mouse.down()
        page.mouse.move(x + 30, y + 25, steps=5)
        page.mouse.up()
        assert "Drawing saved" in page.locator("#save-status").inner_text()
        saved = page.evaluate("JSON.parse(localStorage.getItem(arguments[0]))", STORAGE_KEY)
        assert any(key.endswith("-sketch") and data["strokes"] for key, data in saved["drawings"].items())
        open_home(page)
        page.get_by_role("button", name=re.compile("My Creations")).click()
        assert page.locator(".saved").count() == 1
        page.wait_for_function(
            "() => [...document.querySelectorAll('.saved img')].some(x => x.src.startsWith('data:image/png'))"
        )
        page.reload(wait_until="networkidle")
        page.get_by_role("button", name=re.compile("My Creations")).click()
        assert page.locator(".saved").count() == 1

        # Download a genuine backup, mutate journal, then restore the downloaded file.
        open_home(page)
        page.get_by_role("button", name="Backup & Restore").click()
        with page.expect_download() as result:
            page.get_by_role("button", name="Download complete backup").click()
        backup = json.loads(Path(result.value.path()).read_text())
        assert backup["data"]["tasks"] and backup["data"]["notes"] and backup["data"]["drawings"]
        open_home(page)
        page.get_by_role("button", name=re.compile("My Journal")).click()
        page.get_by_label("Notes & inspiration").fill("Temporary text that must be restored")
        open_home(page)
        page.get_by_role("button", name="Backup & Restore").click()
        page.locator("#backup-file").set_input_files({
            "name": "CreativeMoments-backup.json",
            "mimeType": "application/json",
            "buffer": json.dumps(backup).encode(),
        })
        assert page.get_by_text("Review imported backup").is_visible()
        page.get_by_role("button", name="Replace my browser data").click()
        page.get_by_role("button", name=re.compile("My Journal")).click()
        assert page.get_by_label("Notes & inspiration").input_value() == "Browser acceptance journal"
        open_home(page)
        page.get_by_role("button", name="Backup & Restore").click()
        assert page.get_by_role("button", name="Download previous version").is_visible()

        # An already-open tab must not silently overwrite a new change in another tab.
        second = context.new_page()
        second.on("pageerror", lambda error: failures.append("second tab: " + str(error)))
        second.goto(url, wait_until="networkidle")
        open_home(page)
        page.get_by_role("button", name=re.compile("My Planner")).click()
        page.locator("#new-task").fill("Change from first tab")
        page.get_by_role("button", name="Add", exact=True).click()
        assert second.get_by_role("button", name="Reload latest saved work").is_visible()
        original = page.evaluate("localStorage.getItem(arguments[0])", STORAGE_KEY)
        second.get_by_role("button", name=re.compile("My Planner")).click()
        second.locator("#new-task").fill("Must not overwrite newer work")
        second.get_by_role("button", name="Add", exact=True).click()
        assert second.evaluate("localStorage.getItem(arguments[0])", STORAGE_KEY) == original
        second.close()

        # Service-worker-controlled offline reopening (Chromium, not Safari).
        open_home(page)
        page.evaluate("async () => { const r = await navigator.serviceWorker.ready; return !!r.active }")
        page.reload(wait_until="networkidle")
        page.wait_for_function("() => navigator.serviceWorker.controller !== null")
        context.set_offline(True)
        page.reload(wait_until="load")
        assert page.get_by_role("button", name=re.compile("My Planner")).is_visible()
        context.set_offline(False)

        assert not failures, "Browser runtime errors: " + "; ".join(failures)
        print("PASS: mobile home, planner persistence, journal persistence, drawing/gallery, backup/restore, stale-tab protection, and offline reopen")
        context.close()
        browser.close()


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(ROOT)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        run(f"http://127.0.0.1:{server.server_port}/")
    finally:
        server.shutdown()
        server.server_close()
