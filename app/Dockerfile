FROM python:3.12-slim

WORKDIR /app

COPY app.py .

RUN useradd --create-home appuser && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

CMD ["python", "app.py"]