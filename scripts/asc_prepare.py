#!/usr/bin/env python3
"""Pregătirea unui build pe GitHub Actions, prin App Store Connect API:

1. află echipa (Team ID) din bundle ID;
2. activează Game Center pe bundle ID, dacă lipsește (necesar pentru Avioane online);
3. alege numărul de build: cel mai mare build urcat vreodată pentru aplicație + 1.

Scrie TEAM_ID și BUILD_NUMBER în $GITHUB_ENV (sau le afișează, local).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_listing import api, BUNDLE_ID  # noqa: E402


def main():
    found = api("GET", f"/v1/bundleIds?filter[identifier]={BUNDLE_ID}&limit=20")["data"]
    bundle = next((b for b in found if b["attributes"]["identifier"] == BUNDLE_ID), None)
    if not bundle:
        raise SystemExit(f"Bundle ID {BUNDLE_ID} nu există în cont")
    team = bundle["attributes"]["seedId"]

    caps = {c["attributes"]["capabilityType"] for c in
            api("GET", f"/v1/bundleIds/{bundle['id']}/bundleIdCapabilities")["data"]}
    if "GAME_CENTER" in caps:
        print("Game Center: activ")
    else:
        api("POST", "/v1/bundleIdCapabilities", {"data": {"type": "bundleIdCapabilities",
            "attributes": {"capabilityType": "GAME_CENTER"},
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}}}}})
        print("Game Center: activat acum")

    app_id = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]["id"]
    builds = api("GET", f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=50")["data"]
    numbers = [int(b["attributes"]["version"]) for b in builds if b["attributes"]["version"].isdigit()]
    build = max(numbers, default=0) + 1
    print(f"Echipa {team}, build nou {build}")

    out = os.environ.get("GITHUB_ENV")
    if out:
        with open(out, "a") as f:
            f.write(f"TEAM_ID={team}\nBUILD_NUMBER={build}\n")


if __name__ == "__main__":
    sys.exit(main())
