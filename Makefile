# SaaS Subscription Analytics - Makefile
# Common commands for development and deployment

.PHONY: help setup generate-data test run docs clean

help:
	@echo "SaaS Subscription Analytics"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  setup          Install dependencies and configure environment"
	@echo "  generate-data  Generate sample data using Python script"
	@echo "  seed           Load seed/reference data into warehouse"
	@echo "  run            Run all dbt models"
	@echo "  run-staging    Run only staging models"
	@echo "  run-marts      Run only mart models"
	@echo "  test           Run dbt tests"
	@echo "  docs           Generate and serve dbt documentation"
	@echo "  clean          Remove dbt artifacts"
	@echo "  fresh          Clean and rebuild everything"

setup:
	@echo "Installing Python dependencies..."
	pip install dbt-bigquery pandas
	@echo "Checking dbt installation..."
	dbt --version
	@echo ""
	@echo "Setup complete! Configure your profiles.yml next."

generate-data:
	@echo "Generating sample data..."
	python scripts/generate_sample_data.py
	@echo "Sample data generated in data/raw/"

seed:
	@echo "Loading seed data..."
	dbt seed

run:
	@echo "Running all models..."
	dbt run

run-staging:
	@echo "Running staging models..."
	dbt run --select staging

run-intermediate:
	@echo "Running intermediate models..."
	dbt run --select intermediate

run-marts:
	@echo "Running mart models..."
	dbt run --select marts

test:
	@echo "Running tests..."
	dbt test

test-staging:
	@echo "Running staging tests..."
	dbt test --select staging

docs:
	@echo "Generating documentation..."
	dbt docs generate
	@echo "Serving documentation at http://localhost:8080"
	dbt docs serve

clean:
	@echo "Cleaning dbt artifacts..."
	rm -rf target/
	rm -rf dbt_packages/
	rm -rf logs/
	@echo "Clean complete."

fresh: clean seed run test
	@echo "Fresh build complete!"

# Development helpers
lint:
	@echo "Linting SQL files..."
	sqlfluff lint models/

format:
	@echo "Formatting SQL files..."
	sqlfluff fix models/

# BigQuery specific
bq-load:
	@echo "Loading raw data to BigQuery..."
	@for file in data/raw/*.csv; do \
		table=$$(basename $$file .csv); \
		echo "Loading $$table..."; \
		bq load --source_format=CSV --autodetect \
			$(BQ_PROJECT):raw.$$table $$file; \
	done

# Validation
validate:
	@echo "Validating project structure..."
	dbt parse
	@echo "Project structure is valid."
