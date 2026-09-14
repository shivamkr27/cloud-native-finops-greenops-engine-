FROM python:3.10-slim

WORKDIR /app

RUN pip install --no-cache-dir flask kubernetes

COPY . /app

EXPOSE 5000

ENV PORT=5000

CMD ["python", "-u", "app.py"]
