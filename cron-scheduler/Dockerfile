FROM python:3.10-slim
RUN pip install --no-cache-dir kubernetes
WORKDIR /app
COPY carbon_job.py /app/carbon_job.py
COPY policy.py /app/policy.py
RUN chmod +x /app/carbon_job.py
CMD ["python", "-u", "/app/carbon_job.py"]
