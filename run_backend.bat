@echo off
cd /d "%~dp0backend"
start cmd /k "uvicorn ml_api:app --reload"
