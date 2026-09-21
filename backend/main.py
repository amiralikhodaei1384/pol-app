import os
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from app.api import auth, projects, admin

app = FastAPI(title="Pol API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    # Flutter web can only read custom response headers that CORS exposes.
    expose_headers=["X-Account-Blocked"],
)

os.makedirs("uploads/resumes", exist_ok=True)
# Serve uploaded resumes and chat files.
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(auth.router, prefix="/auth", tags=["Auth"])
app.include_router(projects.router, prefix="/projects", tags=["Projects"])
app.include_router(admin.router, prefix="/admin", tags=["Admin"])