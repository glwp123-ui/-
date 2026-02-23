FROM python:3.12-slim

WORKDIR /app

# railway.json에서 빌드 컨텍스트가 루트이므로 backend/ 경로로 복사
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .

# Railway는 PORT 환경변수로 포트 전달
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
