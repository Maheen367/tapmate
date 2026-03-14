# tapmate/backend/main.py

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import yt_dlp
import os
import uuid
from pydantic import BaseModel
from typing import Optional

app = FastAPI(title="TapMate Downloader API")

# CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Downloads folder
DOWNLOAD_DIR = "downloads"
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

class DownloadRequest(BaseModel):
    url: str
    quality: Optional[str] = "best"

@app.get("/")
async def root():
    return {"message": "TapMate Downloader API", "status": "running"}

@app.post("/api/download")
async def download_video(request: DownloadRequest):
    """
    Download video from any platform
    """
    task_id = str(uuid.uuid4())
    output_template = os.path.join(DOWNLOAD_DIR, f"%(title)s_{task_id}.%(ext)s")

    ydl_opts = {
        'format': request.quality,
        'outtmpl': output_template,
        'quiet': True,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(request.url, download=True)
            filename = ydl.prepare_filename(info)

            return {
                'success': True,
                'task_id': task_id,
                'title': info.get('title', ''),
                'filename': os.path.basename(filename),
                'filepath': filename
            }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/file/{task_id}")
async def get_file(task_id: str):
    """Get downloaded file"""
    for filename in os.listdir(DOWNLOAD_DIR):
        if task_id in filename:
            file_path = os.path.join(DOWNLOAD_DIR, filename)
            return FileResponse(file_path, filename=filename)

    raise HTTPException(status_code=404, detail="File not found")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)