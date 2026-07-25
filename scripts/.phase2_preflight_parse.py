#!/usr/bin/env python3
"""Parse one Firebase/Identity-Toolkit REST response for phase2-auth-preflight.sh.

stdin = response body followed by a final line containing the HTTP status code
(as emitted by `curl -w '\\n%{http_code}'`). argv[1] selects what to report.
"""
import json
import sys


def read_stdin():
    raw = sys.stdin.read()
    lines = raw.splitlines()
    status = ""
    if lines and lines[-1].strip().isdigit():
        status = lines[-1].strip()
        body = "\n".join(lines[:-1])
    else:
        body = raw
    try:
        data = json.loads(body) if body.strip() else {}
    except json.JSONDecodeError:
        data = {}
    return status, data


def bad(status, data):
    """Return a short reason string if the call failed, else None."""
    if status and not status.startswith("2"):
        msg = ""
        if isinstance(data, dict):
            msg = (data.get("error", {}) or {}).get("message", "")
        return f"HTTP {status}{': ' + msg if msg else ''}"
    return None


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    status, data = read_stdin()
    fail = bad(status, data)

    if mode == "idp":
        if fail:
            print(f"  [??] providers          ({fail})")
            return
        configs = data.get("defaultSupportedIdpConfigs", []) or []
        by_id = {}
        for c in configs:
            pid = c.get("name", "").rsplit("/", 1)[-1]
            by_id[pid] = c.get("enabled", False)
        for pid, label in (("google.com", "Google provider"),
                            ("apple.com", "Apple provider ")):
            if pid in by_id:
                mark = "OK" if by_id[pid] else "--"
                state = "enabled" if by_id[pid] else "present but DISABLED"
            else:
                mark, state = "--", "not configured"
            print(f"  [{mark}] {label}      {state}")

    elif mode == "config":
        if fail:
            print(f"  [??] one-account-per-email ({fail})")
            return
        sign_in = data.get("signIn", {}) or {}
        dup = sign_in.get("allowDuplicateEmails", None)
        if dup is None:
            print("  [??] one-account-per-email (not reported)")
        elif dup is False:
            print("  [OK] one account per email (allowDuplicateEmails=false)")
        else:
            print("  [--] DUPLICATE emails allowed (allowDuplicateEmails=true) "
                  "-> providers won't converge to one UID")

    elif mode == "android_apps_ids":
        if fail:
            return
        for a in data.get("apps", []) or []:
            print(a.get("appId", ""))

    elif mode == "android_apps_header":
        if fail:
            print(f"  [??] Android apps       ({fail})")
            return
        apps = data.get("apps", []) or []
        if not apps:
            print("  [--] Android apps       none registered")
        else:
            pkgs = ", ".join(a.get("packageName", "?") for a in apps)
            print(f"  [OK] Android apps       {pkgs}")

    elif mode == "sha":
        appid = sys.argv[2] if len(sys.argv) > 2 else "?"
        if fail:
            print(f"       [??] SHA for {appid} ({fail})")
            return
        # The API returns the list under "certificates" (not "shaCertificates").
        certs = data.get("certificates", data.get("shaCertificates", [])) or []
        n1 = sum(1 for c in certs if c.get("certType") == "SHA_1")
        n256 = sum(1 for c in certs if c.get("certType") == "SHA_256")
        mark = "OK" if (n1 and n256) else ("--" if not certs else "OK")
        note = "" if (n1 and n256) else "  <- want BOTH SHA-1 and SHA-256"
        print(f"       [{mark}] SHA certs: {n1}x SHA-1, {n256}x SHA-256{note}")

    elif mode == "ios_apps":
        if fail:
            print(f"  [??] iOS apps           ({fail})")
            return
        apps = data.get("apps", []) or []
        if not apps:
            print("  [--] iOS apps           none registered")
        else:
            bundles = ", ".join(a.get("bundleId", "?") for a in apps)
            print(f"  [OK] iOS apps           {bundles}")


if __name__ == "__main__":
    main()
