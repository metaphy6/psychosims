"""Minimal FastAPI health-check stub."""

from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Psychosims Server", version="0.1.0")


class HealthResponse(BaseModel):
    status: str
    version: str


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(status="ok", version="0.1.0")


def main() -> None:
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8080)
