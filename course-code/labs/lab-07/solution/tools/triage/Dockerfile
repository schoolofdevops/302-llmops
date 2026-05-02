FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY ./ ./tools/triage/
ENV PORT=8010
EXPOSE 8010
CMD ["python", "-m", "tools.triage.triage_server"]
