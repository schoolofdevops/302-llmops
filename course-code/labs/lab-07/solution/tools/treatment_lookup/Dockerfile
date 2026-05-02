FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY ./ ./tools/treatment_lookup/
ENV PORT=8020
EXPOSE 8020
CMD ["python", "-m", "tools.treatment_lookup.treatment_lookup_server"]
