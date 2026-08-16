FROM python:3.12-slim

WORKDIR /code

RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# Shell form so ${PORT} expands: Render (and most PaaS platforms) inject a PORT
# env var the container must bind to; falls back to 8000 for local `docker run`
# / docker-compose, where PORT is never set.
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
