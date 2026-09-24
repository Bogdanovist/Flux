"""Visual-preflight capture: boot Streamlit, screenshot every page + interactive states.

Run from a Streamlit project's repo root:

    uv run python $FLUX_DIR/skills/visual-preflight/capture.py \\
        --app src/app.py \\
        --out .visual-preflight-screenshots

Auto-discovers pages from ``src/pages/*.py`` (Streamlit's NN_slug.py
convention). Screenshots each page in default state, then opens each
sidebar selectbox and each top-level expander in turn and screenshots
those states. Writes PNGs into ``--out`` and prints the directory path
on success.

Exits non-zero with a clear message if Streamlit fails to boot or
Playwright/Chromium isn't installed.
"""

from __future__ import annotations

import argparse
import os
import re
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


HEALTH_TIMEOUT_S = 30
RENDER_SETTLE_MS = 2500
POPOVER_SETTLE_MS = 600


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _wait_for_health(port: int, deadline_s: float) -> None:
    url = f"http://127.0.0.1:{port}/_stcore/health"
    deadline = time.monotonic() + deadline_s
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=1) as resp:
                if resp.status == 200:
                    return
        except (urllib.error.URLError, ConnectionError, TimeoutError):
            pass
        time.sleep(0.25)
    raise TimeoutError(
        f"streamlit /_stcore/health did not respond within {deadline_s}s"
    )


def _discover_pages(repo: Path) -> list[tuple[str, str]]:
    """Return [(slug, url_path)] including the entry page at '/'."""
    pages_dir = repo / "src" / "pages"
    if not pages_dir.is_dir():
        return [("home", "/")]
    items: list[tuple[int, str]] = []
    for p in pages_dir.glob("*.py"):
        m = re.match(r"^(\d+)_(.+)\.py$", p.name)
        if not m:
            continue
        num = int(m.group(1))
        slug = m.group(2)
        items.append((num, slug))
    items.sort()
    out: list[tuple[str, str]] = []
    if items:
        first_slug = items[0][1]
        out.append((first_slug, "/"))
        for _, slug in items[1:]:
            out.append((slug, f"/{slug}"))
    else:
        out.append(("home", "/"))
    return out


def _safe_filename(s: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "_", s)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", default="src/app.py", help="Path to streamlit entry script")
    parser.add_argument("--out", default=".visual-preflight-screenshots")
    parser.add_argument("--mock", default=None, help="Optional designer mock PNG path (informational)")
    parser.add_argument("--data-dir-env", default="BROKER_DEMO_DATA_DIR")
    parser.add_argument("--data-dir", default="data", help="Data directory passed via --data-dir-env")
    parser.add_argument("--viewport-width", type=int, default=1440)
    parser.add_argument("--viewport-height", type=int, default=900)
    args = parser.parse_args()

    repo = Path.cwd().resolve()
    app_path = (repo / args.app).resolve()
    if not app_path.is_file():
        print(f"error: app not found at {app_path}", file=sys.stderr)
        return 2

    out_dir = (repo / args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    try:
        from playwright.sync_api import Error as PlaywrightError
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(
            "error: playwright not installed. Run `uv sync --extra dev` and "
            "`uv run playwright install chromium`.",
            file=sys.stderr,
        )
        return 3

    pages = _discover_pages(repo)
    print(f"discovered {len(pages)} page(s): {[s for s, _ in pages]}", file=sys.stderr)

    port = _free_port()
    env = {**os.environ}
    if args.data_dir_env and args.data_dir:
        env[args.data_dir_env] = str(repo / args.data_dir)

    proc = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "streamlit",
            "run",
            str(app_path),
            f"--server.port={port}",
            "--server.headless=true",
            "--browser.gatherUsageStats=false",
        ],
        cwd=repo,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    try:
        try:
            _wait_for_health(port, HEALTH_TIMEOUT_S)
        except TimeoutError as exc:
            try:
                output = (proc.stdout.read(4096) or b"").decode("utf-8", "replace") if proc.stdout else ""
            except Exception:
                output = ""
            print(f"error: {exc}\nstreamlit output (first 4KB):\n{output}", file=sys.stderr)
            return 4

        base_url = f"http://127.0.0.1:{port}"

        with sync_playwright() as pw:
            try:
                browser = pw.chromium.launch()
            except PlaywrightError as exc:
                print(
                    f"error: chromium not installed: {exc}\n"
                    "Run `uv run playwright install chromium`.",
                    file=sys.stderr,
                )
                return 5
            context = browser.new_context(
                viewport={"width": args.viewport_width, "height": args.viewport_height}
            )
            page = context.new_page()

            captured: list[Path] = []

            for slug, path in pages:
                url = base_url + path
                print(f"capturing {slug} ({url})", file=sys.stderr)
                try:
                    page.goto(url, wait_until="networkidle", timeout=30_000)
                except PlaywrightError as exc:
                    print(f"  warn: navigation failed: {exc}", file=sys.stderr)
                    continue
                page.wait_for_timeout(RENDER_SETTLE_MS)

                default_path = out_dir / f"{_safe_filename(slug)}__default.png"
                page.screenshot(path=str(default_path), full_page=True)
                captured.append(default_path)

                # Sidebar interactive controls (selectbox, multiselect,
                # date_input). Streamlit renders each as
                # `[data-testid="stSelectbox|stMultiSelect|stDateInput"]`
                # wrapping a baseweb-driven control. Clicking the outer
                # wrapper can land on the label and only expand a
                # sidebar section without opening the popover. Click the
                # inner trigger directly, then verify the popover/menu
                # opens before screenshotting — otherwise the capture is
                # blind to the dropdown contrast bugs this skill exists
                # to catch.
                sidebar = page.locator('[data-testid="stSidebar"]')
                widget_kinds = [
                    ("select", '[data-testid="stSelectbox"]', '[role="combobox"], [data-baseweb="select"] > div'),
                    ("multiselect", '[data-testid="stMultiSelect"]', '[data-baseweb="select"] > div'),
                    ("date", '[data-testid="stDateInput"]', 'input'),
                ]
                for kind, wrapper_sel, trigger_sel in widget_kinds:
                    widgets = sidebar.locator(wrapper_sel)
                    count = widgets.count()
                    for i in range(count):
                        wid = widgets.nth(i)
                        trigger = wid.locator(trigger_sel).first
                        try:
                            trigger.scroll_into_view_if_needed(timeout=2000)
                            trigger.click()
                        except PlaywrightError as exc:
                            print(f"  warn: sidebar {kind} {i} click failed: {exc}", file=sys.stderr)
                            continue
                        # Wait for the popover/listbox/calendar to
                        # appear at body root. Streamlit popovers use
                        # `[data-baseweb="popover"]`; calendars use
                        # `[data-baseweb="calendar"]`.
                        popover = page.locator(
                            '[data-baseweb="popover"], [data-baseweb="calendar"], [role="listbox"]'
                        ).first
                        try:
                            popover.wait_for(state="visible", timeout=2500)
                        except PlaywrightError:
                            print(f"  warn: sidebar {kind} {i} popover did not open", file=sys.stderr)
                            try:
                                page.keyboard.press("Escape")
                                page.wait_for_timeout(200)
                            except PlaywrightError:
                                pass
                            continue
                        page.wait_for_timeout(POPOVER_SETTLE_MS)
                        state_path = out_dir / f"{_safe_filename(slug)}__sidebar_{kind}_{i}.png"
                        # Viewport-sized (not full_page) so the popover
                        # overlay is captured — full_page screenshots
                        # scroll the page which can dismiss the popover.
                        page.screenshot(path=str(state_path), full_page=False)
                        captured.append(state_path)
                        # Close popover before next iteration
                        try:
                            page.keyboard.press("Escape")
                            popover.wait_for(state="hidden", timeout=1500)
                        except PlaywrightError:
                            page.wait_for_timeout(300)

                # Top-level expanders (capture first 3 only — diminishing returns)
                expanders = page.query_selector_all('details[data-testid="stExpander"]')
                for i, exp in enumerate(expanders[:3]):
                    try:
                        already_open = exp.evaluate("el => el.open")
                        if not already_open:
                            exp.click()
                            page.wait_for_timeout(POPOVER_SETTLE_MS)
                    except PlaywrightError as exc:
                        print(f"  warn: expander {i} click failed: {exc}", file=sys.stderr)
                        continue
                    state_path = out_dir / f"{_safe_filename(slug)}__expander_{i}.png"
                    page.screenshot(path=str(state_path), full_page=True)
                    captured.append(state_path)
                    if not already_open:
                        try:
                            exp.click()
                            page.wait_for_timeout(200)
                        except PlaywrightError:
                            pass

            context.close()
            browser.close()

        print(str(out_dir))
        print(f"captured {len(captured)} screenshot(s)", file=sys.stderr)
        if args.mock:
            mock_p = Path(args.mock).resolve()
            if mock_p.is_file():
                print(f"mock: {mock_p}", file=sys.stderr)
            else:
                print(f"warn: --mock path not found: {mock_p}", file=sys.stderr)
        return 0
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
