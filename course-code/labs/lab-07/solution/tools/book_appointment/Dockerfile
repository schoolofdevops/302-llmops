FROM python:3.11-slim
WORKDIR /app
COPY tools/book_appointment/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY tools/ tools/
COPY pytest.ini .
ENV PORT=8030
EXPOSE 8030
CMD ["python", "-m", "tools.book_appointment.book_appointment_server"]
