FROM python:3.11-slim
WORKDIR /app
COPY tools/triage/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY tools/ tools/
COPY pytest.ini .
ENV PORT=8010
EXPOSE 8010
CMD ["python", "-m", "tools.triage.triage_server"]
