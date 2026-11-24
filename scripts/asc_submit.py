#!/usr/bin/env python3
"""Trimite versiunea curentă la App Review, prin App Store Connect API.

1. găsește versiunea editabilă cu numărul APP_VERSION;
2. îi atașează cel mai nou build procesat al acelei versiuni;
3. creează trimiterea la review (sau o refolosește pe cea deschisă) și o trimite.

Rulează doar la cerere: Actions → „App Review”.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_listing import api, BUNDLE_ID, VERSION  # noqa: E402

EDITABLE = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")


def main():
    app_id = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]["id"]
    versions = api("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
    version = next((v for v in versions if v["attributes"]["versionString"] == VERSION), None)
    if not version:
        raise SystemExit(f"Nu există versiunea {VERSION} în App Store Connect")
    state = version["attributes"].get("appStoreState")
    vid = version["id"]
    print(f"Versiunea {VERSION}: {state}")
    if state not in EDITABLE:
        raise SystemExit(f"Versiunea {VERSION} nu mai e editabilă ({state}); nu trimit nimic.")

    # cel mai nou build procesat al versiunii
    builds = api("GET", f"/v1/builds?filter[app]={app_id}&filter[preReleaseVersion.version]={VERSION}"
                        f"&sort=-uploadedDate&limit=10")["data"]
    valid = [b for b in builds if b["attributes"].get("processingState") == "VALID"
             and not b["attributes"].get("expired")]
    if not valid:
        seen = ", ".join(f"{b['attributes']['version']}:{b['attributes'].get('processingState')}" for b in builds)
        raise SystemExit(f"Niciun build procesat pentru {VERSION} (găsite: {seen or 'niciunul'})")
    build = valid[0]
    print(f"Build {build['attributes']['version']} (urcat {build['attributes'].get('uploadedDate')})")
    api("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build",
        {"data": {"type": "builds", "id": build["id"]}})
    print("Build atașat la versiune")

    # trimiterea: una deschisă, dacă există, altfel una nouă
    subs = api("GET", f"/v1/reviewSubmissions?filter[app]={app_id}&filter[platform]=IOS"
                      f"&filter[state]=READY_FOR_REVIEW,UNRESOLVED_ISSUES&limit=5")["data"]
    if subs:
        sub = subs[0]
        print(f"Trimitere deschisă: {sub['id']} ({sub['attributes'].get('state')})")
    else:
        sub = api("POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
        print(f"Trimitere nouă: {sub['id']}")
    sid = sub["id"]

    items = api("GET", f"/v1/reviewSubmissions/{sid}/items?limit=20")["data"]
    if items:
        print(f"Trimiterea are deja {len(items)} element(e)")
    else:
        api("POST", "/v1/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
        print("Versiunea adăugată în trimitere")

    done = api("PATCH", f"/v1/reviewSubmissions/{sid}", {"data": {
        "type": "reviewSubmissions", "id": sid, "attributes": {"submitted": True}}})["data"]
    print(f"TRIMIS LA REVIEW: {done['attributes'].get('state')} ({done['attributes'].get('submittedDate')})")

    for v in api("GET", f"/v1/apps/{app_id}/appStoreVersions?limit=3")["data"]:
        a = v["attributes"]
        print(f"STARE VERSIUNE {a.get('versionString')}: {a.get('appStoreState')} (release: {a.get('releaseType')})")


if __name__ == "__main__":
    sys.exit(main())
