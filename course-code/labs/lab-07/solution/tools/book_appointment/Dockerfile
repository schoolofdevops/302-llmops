FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY ./ ./tools/book_appointment/
ENV PORT=8030
EXPOSE 8030
CMD ["python", "-m", "tools.book_appointment.book_appointment_server"]
