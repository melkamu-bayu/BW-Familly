FROM python:3.12-slim

WORKDIR /code

RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chmod +x entrypoint.sh

EXPOSE 8000

# entrypoint.sh runs migrations + idempotent seeding before starting uvicorn --
# necessary on platforms like Render's free tier that don't offer shell/
# one-off-job access to run these manually. Local docker-compose overrides
# this with its own `command:`, so this only takes effect on the deployed image.
CMD ["./entrypoint.sh"]
