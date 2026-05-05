# Flask app only; MySQL is provided by docker-compose.
FROM python:3.11-slim-bookworm

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py config.py ./
COPY static ./static
COPY templates ./templates

EXPOSE 8080

CMD ["python", "app.py"]
