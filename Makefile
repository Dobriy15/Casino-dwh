.PHONY: help install data build test incremental answers docs lint clean all

PY      ?= python3
DBT      = cd dbt && dbt
DBT_ARGS = --profiles-dir .
SCALE   ?= 1.0

help:          ## Show this help
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

install:       ## Install Python dependencies
	$(PY) -m pip install -r requirements-dev.txt

data:          ## Generate synthetic source extracts into data/raw (SCALE=0.1 for a quick run)
	$(PY) generator/generate.py --out data/raw --scale $(SCALE)

build:         ## Full refresh: seeds, models, tests
	@mkdir -p warehouse
	$(DBT) build $(DBT_ARGS) --full-refresh

incremental:   ## Incremental run (facts process only the look-back window)
	$(DBT) build $(DBT_ARGS)

test:          ## Run data tests only
	$(DBT) test $(DBT_ARGS)

answers:       ## Print the answers to the 9 business questions (+ docs/sample_answers.md)
	$(DBT) compile $(DBT_ARGS) --select "resource_type:analysis" > /dev/null
	$(PY) scripts/answer_questions.py --markdown

docs:          ## Generate and serve dbt docs with lineage graph
	$(DBT) docs generate $(DBT_ARGS) && $(DBT) docs serve $(DBT_ARGS)

lint:          ## Lint Python
	ruff check generator scripts

clean:         ## Remove generated artefacts
	rm -rf data warehouse dbt/target dbt/logs

all: data build answers  ## Generate data, build the warehouse, answer the questions
