SHELL := $(shell command -v bash)

.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help
.PHONY: help start resume

PDF_IMAGE := pdf-builder
DARK ?=

help: ## Show available commands
	echo -e "\nUsage:\n"
	grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-26s\033[0m %s\n", $$1, $$2}'
	echo

start: ## Run the Zola dev server with live reload
	zola serve

resume: ## Build resume PDF(s) from content/resume/index*.md into static/
	docker build -t $(PDF_IMAGE) tools/pdf
	docker run --rm --user "$$(id -u):$$(id -g)" -v "$(CURDIR)":/work -w /work $(PDF_IMAGE) bash tools/pdf/generate.sh$(if $(DARK), --dark,)

%:
	:
