#!/usr/bin/env python3
"""Bundle ID + capabilitatea Game Center + profil App Store, prin App Store Connect API.

1. Înregistrează bundle ID-ul dacă lipsește.
2. Activează Game Center pe el (bundle ID-urile create prin API nu-l au implicit).
3. Recreează profilul App Store dacă a fost făcut înainte de activarea Game Center
   (un profil nu se actualizează singur când se adaugă o capabilitate).
După rulare: Codemagic → Code signing identities → iOS provisioning profiles → Fetch profiles.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_listing import api, BUNDLE_ID

PROFILE_NAME = os.environ.get("PROFILE_NAME", "Whist App Store GC")
CAPABILITIES = ["GAME_CENTER"]


def main():
    found = api("GET", f"/v1/bundleIds?filter[identifier]={BUNDLE_ID}&limit=20")["data"]
    bundle = next((b for b in found if b["attributes"]["identifier"] == BUNDLE_ID), None)
    if not bundle:
        bundle = api("POST", "/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
            "identifier": BUNDLE_ID, "name": "Whist Romanesc", "platform": "IOS"}}})["data"]
        print(f"Bundle ID creat: {BUNDLE_ID}")
    bid = bundle["id"]

    have = {c["attributes"]["capabilityType"] for c in
            api("GET", f"/v1/bundleIds/{bid}/bundleIdCapabilities")["data"]}
    added = False
    for cap in CAPABILITIES:
        if cap in have:
            print(f"Capabilitate {cap}: activă")
            continue
        api("POST", "/v1/bundleIdCapabilities", {"data": {"type": "bundleIdCapabilities",
            "attributes": {"capabilityType": cap},
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid}}}}})
        print(f"Capabilitate {cap}: activată acum")
        added = True

    profiles = [p for p in api("GET", f"/v1/bundleIds/{bid}/profiles")["data"]
                if p["attributes"]["profileType"] == "IOS_APP_STORE"]
    if profiles and not added:
        print(f"Profil App Store: există ({profiles[0]['attributes']['name']}), nu-l schimb")
        return
    for p in profiles:
        api("DELETE", f"/v1/profiles/{p['id']}", ok=(200, 204, 404))
        print(f"Profil vechi șters: {p['attributes']['name']} (fără {', '.join(CAPABILITIES)})")

    certs = []
    for kind in ("DISTRIBUTION", "IOS_DISTRIBUTION"):
        certs += api("GET", f"/v1/certificates?filter[certificateType]={kind}&limit=50")["data"]
    if not certs:
        raise SystemExit("Nu există certificat de distribuție în cont")
    prof = api("POST", "/v1/profiles", {"data": {"type": "profiles",
        "attributes": {"name": PROFILE_NAME, "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bid}},
            "certificates": {"data": [{"type": "certificates", "id": c["id"]} for c in certs]}}}})["data"]
    print(f"Profil nou: {prof['attributes']['name']} ({prof['attributes']['uuid']}), "
          f"expiră {prof['attributes']['expirationDate']}")
    print("Acum: Codemagic → Code signing identities → iOS provisioning profiles → Fetch profiles.")


if __name__ == "__main__":
    sys.exit(main())
