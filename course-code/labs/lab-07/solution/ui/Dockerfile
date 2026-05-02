FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# Pitfall 5: Chainlit needs --host 0.0.0.0 for Docker-exposed/NodePort access
CMD ["chainlit", "run", "app.py", "--host", "0.0.0.0", "--port", "8000"]
