#!/usr/bin/env python3
"""Validate the lesson/code contract for the Godot learning repo.

The checker is intentionally small and stdlib-only. It catches structural drift
(index/link breakage), exact seeded claims, and configured content scans. Known
curriculum debts can stay as warnings until the lesson-audit goals repair them.
"""
from __future__ import annotations

import argparse
import fnmatch
import html.parser
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "lessons" / "claims.json"


@dataclass
class Finding:
    severity: str
    message: str


class LinkParser(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[tuple[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for key, value in attrs:
            if key in {"href", "src"} and value:
                self.links.append((key, value))


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def is_external_link(value: str) -> bool:
    if value.startswith(("#", "mailto:", "tel:", "javascript:", "data:")):
        return True
    parsed = urlparse(value)
    return bool(parsed.scheme and parsed.scheme not in {"", "file"})


def check_local_links(path: Path, findings: list[Finding]) -> None:
    parser = LinkParser()
    parser.feed(read_text(path))
    for attr, value in parser.links:
        if is_external_link(value):
            continue
        target = unquote(value.split("#", 1)[0])
        if not target:
            continue
        target_path = (path.parent / target).resolve()
        try:
            target_path.relative_to(ROOT)
        except ValueError:
            findings.append(Finding("error", f"{rel(path)} {attr} escapes repo: {value}"))
            continue
        if not target_path.exists():
            findings.append(Finding("error", f"{rel(path)} {attr} missing target: {value}"))


def glob_paths(pattern: str) -> list[Path]:
    return sorted(ROOT.glob(pattern))


def excluded(path: Path, patterns: list[str]) -> bool:
    r = rel(path)
    return any(fnmatch.fnmatch(r, pat) for pat in patterns)


def add(finding_list: list[Finding], severity: str, message: str) -> None:
    finding_list.append(Finding(severity, message))


def check_claim(claim: dict, findings: list[Finding]) -> None:
    ctype = claim.get("type")
    severity = claim.get("severity", "error")
    label = claim.get("label") or ctype

    if ctype == "path_exists":
        path = ROOT / claim["path"]
        if not path.exists():
            add(findings, severity, f"claim failed [{label}]: missing path {claim['path']}")
        return

    if ctype in {"contains", "not_contains"}:
        path = ROOT / claim["path"]
        if not path.exists():
            add(findings, severity, f"claim failed [{label}]: missing file {claim['path']}")
            return
        text = read_text(path)
        needle = claim["value"]
        present = needle in text
        if ctype == "contains" and not present:
            add(findings, severity, f"claim failed [{label}]: {claim['path']} does not contain {needle!r}")
        if ctype == "not_contains" and present:
            add(findings, severity, f"claim failed [{label}]: {claim['path']} still contains {needle!r}")
        return

    if ctype == "regex":
        path = ROOT / claim["path"]
        if not path.exists():
            add(findings, severity, f"claim failed [{label}]: missing file {claim['path']}")
            return
        if not re.search(claim["pattern"], read_text(path), re.MULTILINE):
            add(findings, severity, f"claim failed [{label}]: {claim['path']} lacks /{claim['pattern']}/")
        return

    if ctype == "input_action":
        text = read_text(ROOT / "projects/first-steps/project.godot")
        action = claim["name"]
        if not re.search(rf"(?m)^{re.escape(action)}=\{{", text):
            add(findings, severity, f"claim failed [{label}]: input action {action!r} missing from project.godot")
        return

    if ctype == "autoload":
        text = read_text(ROOT / "projects/first-steps/project.godot")
        expected = f'{claim["name"]}="*{claim["path"]}"'
        if expected not in text:
            add(findings, severity, f"claim failed [{label}]: autoload {expected!r} missing from project.godot")
        return

    if ctype == "known_debt":
        add(findings, "warn", f"known debt [{label}]: {claim['message']}")
        return

    add(findings, "error", f"unknown claim type {ctype!r} in {label}")


def run(manifest_path: Path, fail_on_warn: bool) -> int:
    manifest = json.loads(read_text(manifest_path))
    findings: list[Finding] = []

    lesson_pattern = manifest.get("lessonGlob", "lessons/[0-9][0-9][0-9][0-9]-*.html")
    lesson_files = glob_paths(lesson_pattern)
    expected_count = manifest["expectedLessonCount"]
    index_path = ROOT / manifest.get("index", "lessons/index.html")
    index_text = read_text(index_path)

    if len(lesson_files) != expected_count:
        add(findings, "error", f"expected {expected_count} lesson files, found {len(lesson_files)}")
    count_phrase = f"{expected_count} lessons"
    if count_phrase not in index_text:
        add(findings, "error", f"{rel(index_path)} does not contain {count_phrase!r}")

    linked = set(re.findall(r'href="([0-9]{4}-[^"]+\.html)"', index_text))
    lesson_names = {p.name for p in lesson_files}
    for name in sorted(lesson_names - linked):
        add(findings, "error", f"index missing lesson link {name}")
    for name in sorted(linked - lesson_names):
        add(findings, "error", f"index links missing lesson file {name}")

    for html_path in [index_path, *lesson_files]:
        check_local_links(html_path, findings)

    manifest_lessons = manifest.get("lessons", [])
    manifest_ids = {item["id"] for item in manifest_lessons}
    file_ids = {p.name[:4] for p in lesson_files}
    for lesson_id in sorted(file_ids - manifest_ids):
        add(findings, "error", f"manifest missing lesson {lesson_id}")
    for lesson_id in sorted(manifest_ids - file_ids):
        add(findings, "error", f"manifest has lesson {lesson_id}, but no matching file")

    for lesson in manifest_lessons:
        path = ROOT / lesson["file"]
        if not path.exists():
            add(findings, "error", f"lesson {lesson['id']} missing file {lesson['file']}")
            continue
        if Path(lesson["file"]).name not in index_text:
            add(findings, "error", f"lesson {lesson['id']} file not linked from index: {lesson['file']}")
        title = lesson.get("title")
        if title:
            lesson_text = re.sub(r"<[^>]+>", " ", read_text(path)).lower()
            missing_title_tokens = [tok for tok in re.findall(r"[a-z0-9]+", title.lower()) if tok not in lesson_text]
            if missing_title_tokens:
                add(findings, "error", f"lesson {lesson['id']} title tokens missing from file {lesson['file']}: {missing_title_tokens}")
        for claim in lesson.get("claims", []):
            check_claim(claim, findings)
        for note in lesson.get("evolutionNotes", []):
            if not note.strip():
                add(findings, "error", f"lesson {lesson['id']} has empty evolution note")

    for scan in manifest.get("contentScans", []):
        severity = scan.get("severity", "error")
        pattern = re.compile(scan["pattern"], re.IGNORECASE if scan.get("ignoreCase", True) else 0)
        allow = [re.compile(a, re.IGNORECASE if scan.get("ignoreCase", True) else 0) for a in scan.get("allow", [])]
        excludes = scan.get("exclude", [])
        for glob in scan.get("paths", []):
            for path in glob_paths(glob):
                if path.is_dir() or excluded(path, excludes):
                    continue
                text = read_text(path)
                for line_no, line in enumerate(text.splitlines(), 1):
                    if not pattern.search(line):
                        continue
                    if any(a.search(line) for a in allow):
                        continue
                    add(findings, severity, f"content scan [{scan['name']}]: {rel(path)}:{line_no}: {line.strip()}")

    errors = [f for f in findings if f.severity == "error"]
    warnings = [f for f in findings if f.severity == "warn"]
    print(f"lesson contract: {len(errors)} error(s), {len(warnings)} warning(s)")
    for f in findings:
        print(f"{f.severity.upper()}: {f.message}")
    if errors or (fail_on_warn and warnings):
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Check lesson/code drift claims")
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--fail-on-warn", action="store_true", help="treat warning/debt findings as failures")
    args = parser.parse_args()
    return run(Path(args.manifest), args.fail_on_warn)


if __name__ == "__main__":
    sys.exit(main())
