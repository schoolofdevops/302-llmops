FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Chainlit requires --host 0.0.0.0 for NodePort (Pitfall 5)
# Without --host, NodePort connections get WebSocket 403
CMD ["chainlit", "run", "app.py", "--host", "0.0.0.0", "--port", "8000"]
