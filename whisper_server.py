"""
Local Whisper server — OpenAI-compatible /v1/audio/transcriptions endpoint.
Usage: python3 whisper_server.py [--model base|medium] [--port 8080]
"""
import argparse
import tempfile
import os
from typing import Optional
import whisper
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse
import uvicorn

parser = argparse.ArgumentParser()
parser.add_argument("--model", default="base", choices=["tiny", "base", "small", "medium", "large"])
parser.add_argument("--port", type=int, default=8080)
args, _ = parser.parse_known_args()

print(f"Loading whisper model: {args.model} ...")
whisper_model = whisper.load_model(args.model)
print("Model loaded.")

app = FastAPI()

async def _do_transcribe(file: UploadFile, language: Optional[str]) -> str:
    suffix = os.path.splitext(file.filename or "audio.m4a")[1] or ".m4a"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name
    try:
        options = {}
        if language:
            options["language"] = language
        result = whisper_model.transcribe(tmp_path, **options)
        return result["text"].strip()
    finally:
        os.unlink(tmp_path)


@app.post("/v1/audio/transcriptions")
@app.post("/audio/transcriptions")
async def transcribe(
    file: UploadFile = File(...),
    model: str = Form(default="whisper-1"),
    language: str = Form(default=None),
    response_format: str = Form(default="json"),
):
    text = await _do_transcribe(file, language)
    return JSONResponse({"text": text})


if __name__ == "__main__":
    print(f"Whisper server running at http://localhost:{args.port}")
    uvicorn.run(app, host="0.0.0.0", port=args.port)
