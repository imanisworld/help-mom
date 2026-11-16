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
        native_dialogs = []
        def accept_dialog(dialog):
            native_dialogs.append(dialog.message)
            dialog.accept()
        page.on("dialog", accept_dialog)

        # Home and planner: create, persist, and reopen.
        page.goto(url, wait_until="networkidle")
        # The redesigned home must be comfortably legible on a phone without sideways scroll.
        assert page.get_by_role("heading", name="Checklist").is_visible()
        assert page.get_by_role("heading", name="Coloring Page").is_visible()
        assert page.get_by_role("button", name="Full calendar").is_visible()
        assert page.get_by_role("button", name="Color this page").is_visible()
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 2")
        home_tabs = page.locator(".book-tab")
        assert home_tabs.count() == 4
        bounds = [c.bounding_box() for c in home_tabs.all()]
        assert all(box and box["width"] >= 145 and box["height"] >= 54 for box in bounds)
        assert abs(bounds[0]["y"] - bounds[1]["y"]) <= 2 and bounds[2]["y"] > bounds[1]["y"], "Phone tabs should be 2 by 2"
        screenshots = ROOT / "test-artifacts"
        screenshots.mkdir(exist_ok=True)
        page.screenshot(path=str(screenshots / "home-mobile.png"), full_page=True)
        # A checklist should work directly from the opening planner page.
        page.locator("#home-new-task").fill("Home checklist item")
        page.get_by_role("button", name="Add task", exact=True).click()
        assert page.get_by_text("Home checklist item").count() == 1
        page.reload(wait_until="networkidle")
        assert page.get_by_text("Home checklist item").count() == 1
        assert page.get_by_role("button", name=re.compile("My Planner")).is_visible()
        page.get_by_role("button", name=re.compile("My Planner")).click()
        page.locator("#new-task").fill("Browser acceptance task")
        page.get_by_role("button", name="Add", exact=True).click()
        assert page.get_by_text("Browser acceptance task").count() == 1
        page.reload(wait_until="networkidle")
        page.get_by_role("button", name=re.compile("My Planner")).click()
        assert page.get_by_text("Browser acceptance task").count() == 1
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 2")
        page.screenshot(path=str(screenshots / "planner-mobile.png"), full_page=True)

        # Daily journal entries are independently dated, editable, and persistent.
        open_home(page)
        page.get_by_role("button", name=re.compile("My Journal")).click()
        date_value=page.locator("#journal-date").input_value()
        page.get_by_label("Journal entry", exact=True).fill("Browser acceptance journal")
        page.screenshot(path=str(screenshots / "journal-mobile.png"), full_page=True)
        page.reload(wait_until="networkidle")
        page.get_by_role("button", name=re.compile("My Journal")).click()
        assert page.locator("#journal-date").input_value() == date_value
        assert page.get_by_label("Journal entry", exact=True).input_value() == "Browser acceptance journal"
        page.get_by_role("button", name="‹ Day").click()
        assert page.get_by_label("Journal entry", exact=True).input_value() == ""
        page.get_by_role("button", name="Day ›").click()
        assert page.get_by_label("Journal entry", exact=True).input_value() == "Browser acceptance journal"
        page.locator("summary").filter(has_text="Older monthly notes").click()
        assert page.get_by_label("Notes & inspiration").is_visible()

        # Real tap-fill: pick a light pixel on the seasonal image and save its span mask.
        open_home(page)
        page.get_by_role("button", name="Color this page").click()
        assert page.get_by_role("button", name="Fill area").is_visible()
        page.wait_for_function("() => {const img=document.querySelector('.art-layer img');return img && img.complete && img.naturalWidth>0}")
        seed=page.evaluate("""() => {
            const img=document.querySelector('.art-layer img');
            const c=document.createElement('canvas');c.width=512;c.height=512;
            const ctx=c.getContext('2d');ctx.drawImage(img,0,0,512,512);
            const d=ctx.getImageData(0,0,512,512).data;
            const candidates=[[64,64],[448,64],[64,448],[448,448],[256,256],[128,256],[384,256],[256,128],[256,384]];
            for(const [x,y] of candidates){
                let white=true;
                for(const [dx,dy] of [[0,0],[3,0],[-3,0],[0,3],[0,-3]]){
                    const i=((y+dy)*512+x+dx)*4;
                    if((d[i]+d[i+1]+d[i+2])/3<225) white=false;
                }
                if(white)return [x/512,y/512];
            }
            throw Error('No suitable white area in coloring scene');
        }""")
        fill_canvas=page.locator("canvas")
        fill_canvas.scroll_into_view_if_needed()
        bounds=fill_canvas.bounding_box()
        fill_canvas.click(position={"x":bounds["width"]*seed[0],"y":bounds["height"]*seed[1]})
        page.wait_for_function("() => document.querySelector('#save-status')?.textContent.includes('Area colored')")
        saved=page.evaluate("(key) => JSON.parse(localStorage.getItem(key))", STORAGE_KEY)
        season_keys=[k for k in saved["drawings"] if k.endswith("-season")]
        assert season_keys and any(s.get("tool")=="fill" and len(s.get("runs",[]))>0 for s in saved["drawings"][season_keys[0]]["strokes"])
        page.screenshot(path=str(screenshots / "coloring-mobile.png"), full_page=True)
        page.get_by_role("button", name="Undo", exact=True).click()
        saved=page.evaluate("(key) => JSON.parse(localStorage.getItem(key))", STORAGE_KEY)
        assert saved["drawings"][season_keys[0]]["strokes"] == []
        page.get_by_role("button", name="Redo", exact=True).click()
        page.reload(wait_until="networkidle")
        page.get_by_role("button", name="Color this page").click()
        saved=page.evaluate("(key) => JSON.parse(localStorage.getItem(key))", STORAGE_KEY)
        assert any(s.get("tool")=="fill" for s in saved["drawings"][season_keys[0]]["strokes"])

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
        saved = page.evaluate("(key) => JSON.parse(localStorage.getItem(key))", STORAGE_KEY)
        assert any(key.endswith("-sketch") and data["strokes"] for key, data in saved["drawings"].items())
        open_home(page)
        page.get_by_role("button", name=re.compile("My Creations")).click()
        assert page.locator(".saved").count() == 2
        page.wait_for_function(
            "() => [...document.querySelectorAll('.saved img')].some(x => x.src.startsWith('data:image/png'))"
        )
        page.reload(wait_until="networkidle")
        page.get_by_role("button", name=re.compile("My Creations")).click()
        assert page.locator(".saved").count() == 2

        # Download a genuine backup, mutate journal, then restore the downloaded file.
        open_home(page)
        page.get_by_role("button", name="Backup & Restore").click()
        with page.expect_download() as result:
            page.get_by_role("button", name="Download complete backup").click()
        backup = json.loads(Path(result.value.path()).read_text())
        assert backup["data"]["tasks"] and backup["data"]["journalEntries"] and backup["data"]["drawings"]
        open_home(page)
        page.get_by_role("button", name=re.compile("My Journal")).click()
        page.get_by_label("Journal entry", exact=True).fill("Temporary text that must be restored")
        open_home(page)
        page.get_by_role("button", name="Backup & Restore").click()
        page.locator("#backup-file").set_input_files({
            "name": "CreativeMoments-backup.json",
            "mimeType": "application/json",
            "buffer": json.dumps(backup).encode(),
        })
        try:
            page.get_by_text("Review imported backup").wait_for(state="visible", timeout=5000)
        except Exception as exc:
            raise AssertionError(f"Backup file did not open the restore review. Browser alerts: {native_dialogs}") from exc
        page.get_by_role("button", name="Replace my browser data").click()
        page.get_by_role("button", name=re.compile("My Journal")).click()
        assert page.get_by_label("Journal entry", exact=True).input_value() == "Browser acceptance journal"
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
        original = page.evaluate("(key) => localStorage.getItem(key)", STORAGE_KEY)
        second.get_by_role("button", name=re.compile("My Planner")).click()
        second.locator("#new-task").fill("Must not overwrite newer work")
        second.get_by_role("button", name="Add", exact=True).click()
        assert second.evaluate("(key) => localStorage.getItem(key)", STORAGE_KEY) == original
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

        # Direct title editing and printable dated journal do not change browser origin.
        page.get_by_role("button", name="Edit title").click()
        page.locator("#home-cover-title").fill("My Family Planner")
        page.get_by_role("button", name="Save title").click()
        assert page.get_by_role("heading", name="My Family Planner").is_visible()
        page.reload(wait_until="networkidle")
        assert page.get_by_role("heading", name="My Family Planner").is_visible()
        page.get_by_role("button", name="Print / Save PDF").click()
        page.wait_for_function("() => document.querySelector('#print-sheet')?.textContent.includes('Browser acceptance journal')")

        # A wider screen must recover the two-column overview.
        page.set_viewport_size({"width": 1024, "height": 768})
        page.reload(wait_until="networkidle")
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 2")
        wide = [c.bounding_box() for c in page.locator(".book-tab").all()]
        assert len(wide) == 4 and all(abs(x["y"] - wide[0]["y"]) <= 2 for x in wide), "Desktop section tabs should fit on one row"
        assert page.locator(".mom-workspace").is_visible()
        page.screenshot(path=str(screenshots / "home-desktop.png"), full_page=True)

        assert not failures, "Browser runtime errors: " + "; ".join(failures)
        print("PASS: notebook planner, dated journal, tap-fill, undo/redo, backup/restore, cover title, PDF print, gallery, stale tabs and offline")
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
