FROM python:3.12-slim

WORKDIR /app

# Root Directory = backend 로 설정 시 컨텍스트가 backend/
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Railway는 PORT 환경변수로 포트 전달
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
