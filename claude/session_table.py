# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Pretty-print a table of local Claude Code sessions.

Sessions live under ``~/.claude/projects/<encoded-cwd>/<session-id>.jsonl``.
Each transcript carries the session's working directory, git branch and
timestamps on every message, plus zero or more ``ai-title`` records holding
the derived session name and, when the user has run ``/rename``, one or more
``custom-title`` records holding the explicit name. Currently-running sessions
also appear in ``~/.claude/sessions/*.json`` (keyed by PID) with a live
``status`` and, for renamed sessions, a user-set ``name``.

This script merges both sources and prints one row per session. No third-party
dependencies — just the standard library.

Usage:
    python3 session_table.py [--dir PATH] [--all] [--limit N] [--sort {modified,name,dir}]
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

CLAUDE_HOME = Path(os.environ.get("CLAUDE_HOME", Path.home() / ".claude"))
PROJECTS_DIR = CLAUDE_HOME / "projects"
SESSIONS_DIR = CLAUDE_HOME / "sessions"


@dataclass
class Session:
    session_id: str
    path: Path
    mtime: float
    cwd: str | None = None
    git_branch: str | None = None
    ai_title: str | None = None
    custom_title: str | None = None  # explicit name from /rename (in transcript)
    user_name: str | None = None  # explicit name from live-session file
    first_prompt: str | None = None
    message_count: int = 0
    status: str | None = None  # live status, if running
    versions: set[str] = field(default_factory=set)

    @property
    def name(self) -> str:
        """Best available human-readable name for the session.

        A user-set name (``/rename`` -> ``custom-title``, or the live-session
        file) always wins over the auto-derived ``ai-title``.
        """
        return (
            self.custom_title
            or self.user_name
            or self.ai_title
            or self.first_prompt
            or "(untitled)"
        )


def _load_live_sessions() -> dict[str, dict]:
    """Map session-id -> live metadata for currently-running sessions."""
    live: dict[str, dict] = {}
    if not SESSIONS_DIR.is_dir():
        return live
    for f in SESSIONS_DIR.glob("*.json"):
        try:
            data = json.loads(f.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        sid = data.get("sessionId")
        if sid:
            live[sid] = data
    return live


def _scan_transcript(path: Path) -> Session:
    """Read a single .jsonl transcript and extract summary metadata."""
    sess = Session(
        session_id=path.stem,
        path=path,
        mtime=path.stat().st_mtime,
    )
    try:
        fh = path.open(encoding="utf-8")
    except OSError:
        return sess

    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue

            rtype = rec.get("type")

            # ai-title records hold the derived session name; keep the latest.
            if rtype == "ai-title":
                title = rec.get("aiTitle")
                if title:
                    sess.ai_title = title
                continue

            # custom-title records hold the user's explicit /rename value;
            # keep the latest (a session may be renamed more than once).
            if rtype == "custom-title":
                title = rec.get("customTitle")
                if title:
                    sess.custom_title = title
                continue

            # cwd / git branch / version live on message records.
            if sess.cwd is None and rec.get("cwd"):
                sess.cwd = rec["cwd"]
            if sess.git_branch is None and rec.get("gitBranch"):
                sess.git_branch = rec["gitBranch"]
            if rec.get("version"):
                sess.versions.add(rec["version"])

            if rtype in ("user", "assistant"):
                sess.message_count += 1

            # First human-typed prompt, used as a fallback name.
            if (
                sess.first_prompt is None
                and rtype == "user"
                and rec.get("origin", {}).get("kind") == "human"
            ):
                content = rec.get("message", {}).get("content")
                if isinstance(content, str) and content.strip():
                    sess.first_prompt = content.strip()

    return sess


def collect_sessions(project_filter: str | None = None) -> list[Session]:
    """Walk all project transcripts and merge in live-session metadata."""
    live = _load_live_sessions()
    sessions: list[Session] = []

    if not PROJECTS_DIR.is_dir():
        return sessions

    for jsonl in PROJECTS_DIR.rglob("*.jsonl"):
        # Skip subagent sidechain transcripts; they aren't top-level sessions.
        if "subagents" in jsonl.parts:
            continue
        sess = _scan_transcript(jsonl)

        meta = live.get(sess.session_id)
        if meta:
            sess.status = meta.get("status")
            if meta.get("nameSource") == "custom" and meta.get("name"):
                sess.user_name = meta["name"]
            if sess.cwd is None:
                sess.cwd = meta.get("cwd")

        if project_filter and (sess.cwd or "") and project_filter not in sess.cwd:
            continue
        sessions.append(sess)

    return sessions


def _fmt_age(mtime: float) -> str:
    now = datetime.now(timezone.utc)
    dt = datetime.fromtimestamp(mtime, tz=timezone.utc)
    delta = now - dt
    secs = int(delta.total_seconds())
    if secs < 60:
        return "just now"
    if secs < 3600:
        return f"{secs // 60}m ago"
    if secs < 86400:
        return f"{secs // 3600}h ago"
    if secs < 86400 * 30:
        return f"{secs // 86400}d ago"
    return dt.strftime("%Y-%m-%d")


def _shorten(text: str, width: int) -> str:
    text = text.replace("\n", " ").strip()
    if len(text) <= width:
        return text
    return text[: width - 1] + "…"


def _home_rel(cwd: str | None) -> str:
    if not cwd:
        return "(unknown)"
    home = str(Path.home())
    if cwd.startswith(home):
        return "~" + cwd[len(home):]
    return cwd


def render_table(sessions: list[Session], limit: int | None = None) -> str:
    rows = []
    for s in sessions:
        marker = "● " if s.status in ("busy", "idle", "running") else "  "
        # Flag sessions the user explicitly renamed via /rename.
        renamed = "✎ " if (s.custom_title or s.user_name) else "  "
        rows.append(
            [
                marker + _fmt_age(s.mtime),
                renamed + _shorten(s.name, 46),
                _shorten(_home_rel(s.cwd), 34),
                _shorten(s.git_branch or "-", 16),
                str(s.message_count),
                s.session_id[:8],
            ]
        )
    if limit:
        rows = rows[:limit]

    headers = ["Modified", "Name", "Directory", "Branch", "Msgs", "Session"]
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    def fmt_row(cells: list[str]) -> str:
        return "  ".join(c.ljust(widths[i]) for i, c in enumerate(cells))

    lines = [fmt_row(headers), "  ".join("-" * w for w in widths)]
    lines += [fmt_row(r) for r in rows]
    return "\n".join(lines)


def _resolve_and_exit(session_id: str) -> None:
    """Print '<full-id>\\t<cwd>' for the session whose id matches ``session_id``.

    The table shows an 8-char id prefix, so matching is by prefix; an exact
    match wins outright. Errors go to stderr with a non-zero exit so the
    calling shell function can bail cleanly.
    """
    import sys

    sessions = collect_sessions()
    exact = [s for s in sessions if s.session_id == session_id]
    prefix = [s for s in sessions if s.session_id.startswith(session_id)]
    matches = exact or prefix

    if not matches:
        print(f"No session matching id '{session_id}'.", file=sys.stderr)
        raise SystemExit(1)
    if len(matches) > 1:
        print(
            f"Ambiguous session id '{session_id}' matches {len(matches)} "
            "sessions; use a longer prefix:",
            file=sys.stderr,
        )
        for s in matches:
            print(f"  {s.session_id[:8]}  {_home_rel(s.cwd)}", file=sys.stderr)
        raise SystemExit(1)

    s = matches[0]
    if not s.cwd:
        print(
            f"Session '{s.session_id[:8]}' has no recorded directory.",
            file=sys.stderr,
        )
        raise SystemExit(1)
    print(f"{s.session_id}\t{s.cwd}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-k",
        "--dir",
        help="Only show sessions whose cwd contains this substring "
        "(e.g. -k notes).",
    )
    parser.add_argument(
        "-a",
        "--all",
        action="store_true",
        help="Show all sessions, not just user-renamed ones (the default "
        "lists only sessions with a /rename custom title).",
    )
    parser.add_argument(
        "-n", "--limit", type=int, default=None, help="Show at most N sessions."
    )
    parser.add_argument(
        "--sort",
        choices=["modified", "name", "dir"],
        default="modified",
        help="Sort order (default: modified, newest first).",
    )
    parser.add_argument(
        "--resolve",
        metavar="SESSION_ID",
        help="Resolve a (possibly abbreviated) session id to a "
        "'<full-id>\\t<cwd>' line and exit. Used by the run-claude alias to "
        "cd into the session's directory and resume it.",
    )
    args = parser.parse_args()

    if args.resolve:
        _resolve_and_exit(args.resolve)
        return

    sessions = collect_sessions(project_filter=args.dir)

    # By default show only user-renamed sessions; -a lists everything.
    if not args.all:
        sessions = [s for s in sessions if s.custom_title or s.user_name]

    if args.sort == "modified":
        sessions.sort(key=lambda s: s.mtime, reverse=True)
    elif args.sort == "name":
        sessions.sort(key=lambda s: s.name.lower())
    elif args.sort == "dir":
        sessions.sort(key=lambda s: (s.cwd or "", -s.mtime))

    if not sessions:
        if not args.all:
            print("No user-renamed sessions found. Use -a to list all sessions.")
        else:
            print("No Claude Code sessions found under", PROJECTS_DIR)
        return

    print(render_table(sessions, limit=args.limit))
    shown = min(len(sessions), args.limit) if args.limit else len(sessions)
    print(
        f"\n{shown} of {len(sessions)} session(s)"
        "  ·  ● = running  ·  ✎ = user-renamed"
    )


if __name__ == "__main__":
    main()
