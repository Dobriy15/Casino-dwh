FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends make && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# generate data, build + test the warehouse, print the answers
CMD ["sh", "-c", "python generator/generate.py --out data/raw && mkdir -p warehouse && cd dbt && dbt build --profiles-dir . && dbt compile --profiles-dir . --select resource_type:analysis > /dev/null && cd .. && python scripts/answer_questions.py"]
