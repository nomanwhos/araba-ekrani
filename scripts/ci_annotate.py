"""Turns an xcodebuild log into GitHub annotations, which are readable on a
public repo without signing in (raw logs are not).

Usage: python3 scripts/ci_annotate.py xcodebuild.log
"""
import os
import re
import sys

COMPILER_ERROR = re.compile(r"^(?P<path>/.+?\.swift):(?P<line>\d+):\d+: error: (?P<msg>.+)$")
MAX_FILE_ERRORS = 9  # GitHub keeps 10 error annotations per step; one is the log tail.
TAIL_LINES = 40


def escape(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def main(log_path):
    workspace = os.environ.get("GITHUB_WORKSPACE", "") + "/"
    with open(log_path, encoding="utf-8", errors="replace") as log:
        lines = log.read().splitlines()

    seen = set()
    for line in lines:
        match = COMPILER_ERROR.match(line)
        if not match or line in seen:
            continue
        seen.add(line)
        path = match["path"].removeprefix(workspace)
        print(f"::error file={path},line={match['line']}::{escape(match['msg'])}")
        if len(seen) == MAX_FILE_ERRORS:
            break

    other_errors = [l for l in lines if "error:" in l and not COMPILER_ERROR.match(l)]
    tail = (other_errors[-10:] + ["--- log tail ---"] + lines[-TAIL_LINES:])
    print(f"::error title=xcodebuild::{escape(chr(10).join(tail))}")


if __name__ == "__main__":
    main(sys.argv[1])
