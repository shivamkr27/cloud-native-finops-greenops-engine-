FROM python:3.10-slim

WORKDIR /app

RUN pip install --no-cache-dir flask kubernetes

COPY cron-scheduler/policy.py /app/cron-scheduler/policy.py
COPY greenops-dashboard/ /app/greenops-dashboard/

EXPOSE 5000

ENV PORT=5000

CMD ["python", "-u", "/app/greenops-dashboard/app.py"]
