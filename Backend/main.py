import os

import anthropic
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

load_dotenv()

app = FastAPI()
client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY from the environment

APP_SHARED_SECRET = os.environ["APP_SHARED_SECRET"]
MODEL = "claude-haiku-4-5"

SYSTEM_PROMPT = """You are a transcription assistant that converts raw voice-memo transcripts into a single actionable task list.

Instructions:
- Extract every concrete action item, whether the speaker assigned it to themselves or someone else assigned it to them. This includes:
  - Imperatives ("call the bank")
  - Stated intentions ("I need to...", "I'll...")
  - Tasks assigned by someone else, often reported secondhand in meeting notes ("my task is to review the code", "they asked me to...", "John wants me to...", "I was told to...")
  - Anything with a deadline or reminder attached
- Do not include general commentary, opinions, or observations that are not action items — omit them entirely rather than forcing them into a task.
- Each task should be a short, clear, standalone instruction written in imperative form (e.g. "Call the bank about the late fee"), not a verbatim quote from the transcript.
- Write one concise sentence summarizing what the recording was about.
- If the transcript contains no actionable items, return an empty tasks list — do not invent one.

Respond only with the structured output; do not add commentary outside it."""


class StructureRequest(BaseModel):
    transcript: str


class StructureResponse(BaseModel):
    summary: str
    tasks: list[str]


@app.post("/structure", response_model=StructureResponse)
async def structure(req: StructureRequest, x_app_secret: str = Header(...)) -> StructureResponse:
    if x_app_secret != APP_SHARED_SECRET:
        raise HTTPException(status_code=401, detail="Unauthorized")

    transcript = req.transcript.strip()
    if not transcript:
        raise HTTPException(status_code=400, detail="Empty transcript")

    try:
        response = client.messages.parse(
            model=MODEL,
            max_tokens=2048,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": transcript}],
            output_format=StructureResponse,
        )
    except anthropic.APIError as error:
        raise HTTPException(status_code=502, detail=f"Claude API error: {error}") from error

    if response.parsed_output is None:
        raise HTTPException(status_code=502, detail="Claude did not return valid structured output")

    return response.parsed_output
