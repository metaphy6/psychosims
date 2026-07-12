"""Contract tests: shared schemas round-trip between Dart and Python."""

import json
from pathlib import Path

from psychosims_server.schemas import PatientManifest, SessionReceipt

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURES = REPO_ROOT / "test_fixtures"


def test_patient_manifest_round_trip() -> None:
    raw = (FIXTURES / "manifests" / "sample_patient.json").read_text()
    data = json.loads(raw)
    manifest = PatientManifest.model_validate(data)
    assert manifest.id == "fixture-p-001"
    assert manifest.schemaVersion == "0.1.0"
    assert manifest.rulesetVersion == "0.1.0"


def test_session_receipt_round_trip() -> None:
    raw = (FIXTURES / "receipts" / "sample_receipt.json").read_text()
    data = json.loads(raw)
    receipt = SessionReceipt.model_validate(data)
    assert receipt.patientId == "fixture-p-001"
    assert receipt.turnCount == 3
    assert receipt.schemaVersion == "0.1.0"
