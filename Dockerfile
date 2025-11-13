FROM python:3.11-slim

# Better output behavior
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install Flask
RUN pip install --no-cache-dir flask

# Copy our app
COPY app.py .
COPY templates/ ./templates/

# Expose port
EXPOSE 5000

# Run the app
CMD ["python", "app.py"]
