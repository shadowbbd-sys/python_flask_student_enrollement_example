FROM python:3.11-slim

# Better Python behavior
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Copy and install dependencies (runtime + pytest)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app files
COPY app.py .
COPY templates/ ./templates/

# Copy tests folder if it exists (optional)
COPY tests/ ./tests/

EXPOSE 5000

CMD ["python", "app.py"]
