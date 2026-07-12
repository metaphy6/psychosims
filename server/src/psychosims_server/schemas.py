"""Pydantic schemas mirroring the Dart `packages/psychemas/` contract."""

from pydantic import BaseModel


class StructuredDelta(BaseModel):
    axis: str
    deltaMillis: int
    reasonKey: str


class SessionReceipt(BaseModel):
    id: str
    schemaVersion: str = "0.1.0"
    rulesetVersion: str
    patientId: str
    turnCount: int
    deltas: list[dict]


class PatientManifest(BaseModel):
    id: str
    schemaVersion: str = "0.1.0"
    rulesetVersion: str
    nameKey: str
    presentationKey: str
