FROM python:3.11-slim

# Install dependencies including sqlite3
RUN apt-get update && apt-get install -y \
    sqlite3 \
    libsqlite3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN pip install psutil


# Set working directory
WORKDIR /webui

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Set environment variable for Flask DB path (optional override)
ENV DB_PATH=/webui/data/users.db

# Expose port
EXPOSE 5000

# Run bootstrap script before starting the app
CMD ["sh", "-c", "python bootstrap_users.py && python app.py"]
