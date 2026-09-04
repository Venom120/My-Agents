#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# ============================================================================
# OmniRoute Model/Provider Exporter
# ============================================================================
#
# PURPOSE
# -------
# This script is a READ-ONLY diagnostic tool. It exports the current
# list of models and providers from a running OmniRoute instance to
# CSV and JSON files. It does NOT create, update, or delete anything
# in OmniRoute.
#
# WHY YOU WOULD RUN IT
# --------------------
# 1. To see which models are currently available before editing
#    `omniroute_free_combos.py` (the combo builder).
# 2. To check that all model IDs used in the combo builder are still
#    present in OmniRoute.
# 3. To generate a snapshot of the provider pool for audit/debug.
#
# USAGE
# -----
# 1. Make sure OmniRoute is running (see setup/omniroute/README.md).
# 2. Export your management key:
#
#      Linux/macOS:
#        export OMNIROUTE_MANAGE_KEY='YOUR_KEY'
#      Windows (PowerShell):
#        $env:OMNIROUTE_MANAGE_KEY='YOUR_KEY'
#
# 3. Run the script from inside the setup/omniroute/ directory:
#
#      cd setup/omniroute
#      python3 list-models-omniroute.py
#
# 4. The script writes four files into the current working directory:
#
#      omniroute_models.csv         (flat table of every model)
#      omniroute_providers.csv      (flat table of every provider)
#      omniroute_models_raw.json    (exact response from OmniRoute)
#      omniroute_providers_raw.json (exact response from OmniRoute)
#
# 5. Feed the CSVs back to the combo builder (`omniroute_free_combos.py`)
#    when you want to refresh or audit the model list.
#
# LANGUAGE / REQUIREMENTS
# -----------------------
# Python 3.8+ with the `requests` library:
#
#      pip install requests
#
# ============================================================================

import csv
import json
import os
from pathlib import Path

import requests


# ============================================================================
# CONFIGURATION
# ============================================================================
#
# You can override the OmniRoute base URL via the OMNIROUTE_BASE_URL
# environment variable. Default is http://localhost:20128 which matches
# the bundled systemd service (setup/omniroute/omniroute.service).
#
# The management key is REQUIRED. It is a DIFFERENT key from
# OMNIROUTE_API_KEY (the inference key used by the subagents).
# ============================================================================

# Recommended: keep the key in an environment variable.
OMNIROUTE_MANAGE_KEY = os.environ.get("OMNIROUTE_MANAGE_KEY", "").strip()

OMNIROUTE_BASE_URL = os.environ.get(
    "OMNIROUTE_BASE_URL",
    "http://localhost:20128",
).rstrip("/")

MODELS_API_URL = (
    f"{OMNIROUTE_BASE_URL}/api/v1/vscode/"
    f"{OMNIROUTE_MANAGE_KEY}/models"
)

PROVIDERS_API_URL = f"{OMNIROUTE_BASE_URL}/api/providers"

REQUEST_TIMEOUT = 30

MODELS_CSV = "omniroute_models.csv"
PROVIDERS_CSV = "omniroute_providers.csv"

MODELS_RAW = "omniroute_models_raw.json"
PROVIDERS_RAW = "omniroute_providers_raw.json"


# ============================================================================
# HELPERS
# ============================================================================

def normalize_value(value):
    """Keep nested JSON/list values intact inside a CSV cell."""
    if isinstance(value, (dict, list)):
        return json.dumps(
            value,
            ensure_ascii=False,
            separators=(",", ":"),
        )
    return value


def extract_data(payload, list_keys=("data",)):
    """
    Extract a list from the common OmniRoute response shapes.

    /models normally returns:
        {"data": [...]}

    /api/providers returns:
        {"connections": [...], "total": N}

    A bare list is also accepted.
    """
    if isinstance(payload, str):
        payload = json.loads(payload)

    if isinstance(payload, list):
        return payload

    if isinstance(payload, dict):
        for key in list_keys:
            value = payload.get(key)
            if isinstance(value, list):
                return value

    raise TypeError(
        "Expected a list or an object containing one of: "
        + ", ".join(list_keys)
    )


def fetch_json(url, headers=None):
    # Never print the API key-containing URL.
    safe_url = url

    if OMNIROUTE_MANAGE_KEY:
        safe_url = safe_url.replace(OMNIROUTE_MANAGE_KEY, "***REDACTED***")

    print(f"[GET] {safe_url}")

    response = requests.get(
        url,
        headers=headers or {},
        timeout=REQUEST_TIMEOUT,
    )

    print(f"[HTTP] {response.status_code} {response.reason}")

    response.raise_for_status()

    return response.json()


def save_raw_json(payload, filename):
    Path(filename).write_text(
        json.dumps(
            payload,
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    print(f"[OK] Saved raw response -> {filename}")


# ============================================================================
# MODEL CSV
# ============================================================================

def export_models_to_csv(payload, filename=MODELS_CSV):
    models = extract_data(payload, ("data",))

    fieldnames = []

    for model in models:
        if not isinstance(model, dict):
            continue

        for key in model.keys():
            if key not in fieldnames:
                fieldnames.append(key)

    # Put the fields most useful for our router at the beginning.
    preferred = [
        "id",
        "name",
        "owned_by",
        "root",
        "family",
        "capabilities",
        "toolCalling",
        "vision",
        "supportsThinking",
        "supportedReasoningEfforts",
        "defaultReasoningEffort",
        "context_length",
        "max_input_tokens",
        "max_output_tokens",
        "maxInputTokens",
        "maxOutputTokens",
        "input_modalities",
        "output_modalities",
        "pricing",
        "configurationSchema",
    ]

    ordered = [x for x in preferred if x in fieldnames]
    ordered += [x for x in fieldnames if x not in ordered]

    if not ordered:
        ordered = ["id", "name", "type"]

    with open(
        filename,
        "w",
        newline="",
        encoding="utf-8",
    ) as f:
        writer = csv.DictWriter(
            f,
            fieldnames=ordered,
            extrasaction="ignore",
        )

        writer.writeheader()

        for model in models:
            if not isinstance(model, dict):
                continue

            writer.writerow({
                field: normalize_value(model.get(field, ""))
                for field in ordered
            })

    print(f"[OK] Exported {len(models)} models -> {filename}")


# ============================================================================
# PROVIDER CSV
# ============================================================================

def export_providers_to_csv(payload, filename=PROVIDERS_CSV):
    providers = extract_data(payload, ("connections", "data", "providers"))

    if isinstance(payload, dict) and "total" in payload:
        print(
            f"[INFO] /api/providers reports total="
            f"{payload.get('total')} connections"
        )

    fieldnames = []

    for provider in providers:
        if not isinstance(provider, dict):
            continue

        for key in provider.keys():
            if key not in fieldnames:
                fieldnames.append(key)

    preferred = [
        "id",
        "provider",
        "name",
        "authType",
        "priority",
        "isActive",
        "testStatus",
        "backoffLevel",
        "lastHealthCheckAt",
        "lastTested",
        "expiresAt",
        "tokenExpiresAt",
        "expiresIn",
        "maxConcurrent",
        "consecutiveUseCount",
        "lastUsedAt",
        "rateLimitProtection",
        "proxyEnabled",
        "perKeyProxyEnabled",
        "quotaVisible",
        "errorCode",
        "lastErrorType",
        "lastError",
        "rateLimitedUntil",
        "providerSpecificData",
    ]

    ordered = [x for x in preferred if x in fieldnames]
    ordered += [x for x in fieldnames if x not in ordered]

    if not ordered:
        ordered = ["id", "provider", "name", "isActive", "testStatus"]

    with open(
        filename,
        "w",
        newline="",
        encoding="utf-8",
    ) as f:
        writer = csv.DictWriter(
            f,
            fieldnames=ordered,
            extrasaction="ignore",
        )

        writer.writeheader()

        for provider in providers:
            if not isinstance(provider, dict):
                continue

            writer.writerow({
                field: normalize_value(provider.get(field, ""))
                for field in ordered
            })

    print(f"[OK] Exported {len(providers)} provider records -> {filename}")


# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    try:
        if not OMNIROUTE_MANAGE_KEY:
            raise RuntimeError(
                "OMNIROUTE_MANAGE_KEY is not set.\n\n"
                "PowerShell:\n"
                '$env:OMNIROUTE_MANAGE_KEY = "YOUR_API_KEY"\n'
            )

        print("=" * 80)
        print("OmniRoute Model + Provider Exporter")
        print("=" * 80)
        print(f"Base URL: {OMNIROUTE_BASE_URL}")
        print()

        # STEP 1 --------------------------------------------------------------
        print("[STEP 1/2] Fetching /models ...")

        models_payload = fetch_json(MODELS_API_URL)

        export_models_to_csv(
            models_payload,
            MODELS_CSV,
        )

        save_raw_json(
            models_payload,
            MODELS_RAW,
        )

        # STEP 2 --------------------------------------------------------------
        print()
        print("[STEP 2/2] Fetching /api/providers ...")

        providers_payload = fetch_json(
            PROVIDERS_API_URL,
            headers={
                "Authorization": f"Bearer {OMNIROUTE_MANAGE_KEY}",
                "Accept": "application/json",
            },
        )

        export_providers_to_csv(
            providers_payload,
            PROVIDERS_CSV,
        )

        save_raw_json(
            providers_payload,
            PROVIDERS_RAW,
        )

        print()
        print("=" * 80)
        print("DONE")
        print("=" * 80)
        print()
        print("Give me these files for the combo-builder:")
        print(f"  {MODELS_CSV}")
        print(f"  {PROVIDERS_CSV}")
        print()
        print("If anything looks ambiguous, also give me:")
        print(f"  {MODELS_RAW}")
        print(f"  {PROVIDERS_RAW}")
        print()
        print("No OmniRoute configuration was changed.")

    except requests.RequestException as e:
        print()
        print("[ERROR] OmniRoute API request failed:")
        print(e)
        raise SystemExit(1)

    except (TypeError, ValueError, RuntimeError) as e:
        print()
        print("[ERROR]")
        print(e)
        raise SystemExit(1)
