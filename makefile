# Used by `image`, `push` & `deploy` targets, override as required
IMAGE_REG ?= ghcr.io
IMAGE_REPO ?= benc-uk/python-demoapp
IMAGE_TAG ?= latest

# Used by `deploy` target, sets Azure webap defaults, override as required
AZURE_RES_GROUP ?= temp-demoapps
AZURE_REGION ?= uksouth
AZURE_SITE_NAME ?= pythonapp-$(shell git rev-parse --short HEAD)

# Used by `test-api` target
TEST_HOST ?= localhost:5000

# Don't change
SRC_DIR := src

.PHONY: help lint lint-fix image push run deploy undeploy clean test-api .EXPORT_ALL_VARIABLES
.DEFAULT_GOAL := help

help:  ## 💬 This help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint: venv  ## 🔎 Lint & format, will not fix but sets exit code on error 
	. $(SRC_DIR)/.venv/bin/activate \
	&& black --check $(SRC_DIR) \
	&& flake8 src/app/ && flake8 src/run.py

lint-fix: venv  ## 📜 Lint & format, will try to fix errors and modify code
	. $(SRC_DIR)/.venv/bin/activate \
	&& black $(SRC_DIR)

image:  ## 🔨 Build container image from Dockerfile 
	docker build . --file build/Dockerfile \
	--tag $(IMAGE_REG)/$(IMAGE_REPO):$(IMAGE_TAG)

push:  ## 📤 Push container image to registry 
	docker push $(IMAGE_REG)/$(IMAGE_REPO):$(IMAGE_TAG)

run: venv  ## 🏃 Run the server locally using Python & Flask
	call $(SRC_DIR)\.venv\Scripts\activate.bat \
	&& python src/run.py

deploy:  ## 🚀 Deploy to Azure Web App 
	az group create --resource-group $(AZURE_RES_GROUP) --location $(AZURE_REGION) -o table
	az deployment group create --template-file deploy/webapp.bicep \
		--resource-group $(AZURE_RES_GROUP) \
		--parameters webappName=$(AZURE_SITE_NAME) \
		--parameters webappImage=$(IMAGE_REG)/$(IMAGE_REPO):$(IMAGE_TAG) -o table 
	@echo "### 🚀 Web app deployed to https://$(AZURE_SITE_NAME).azurewebsites.net/"

undeploy:  ## 💀 Remove from Azure 
	@echo "### WARNING! Going to delete $(AZURE_RES_GROUP) 😲"
	az group delete -n $(AZURE_RES_GROUP) -o table --no-wait

test: venv  ## 🎯 Unit tests for Flask app
	call $(SRC_DIR)\.venv\Scripts\activate.bat && pytest -v

test-report: venv  ## 🎯 Unit tests for Flask app (with report output)
	call $(SRC_DIR)\.venv\Scripts\activate.bat && pytest -v --junitxml=test-results.xml

test-api: .EXPORT_ALL_VARIABLES  ## 🚦 Run integration API tests, server must be running 
	cd tests \
	&& npm install newman \
	&& ./node_modules/.bin/newman run ./postman_collection.json --env-var apphost=$(TEST_HOST)

clean:  ## 🧹 Clean up project
	if exist "$(SRC_DIR)\.venv" rd /s /q "$(SRC_DIR)\.venv"
	if exist "tests\node_modules" rd /s /q "tests\node_modules"
	if exist "tests\package*" del /f /q "tests\package*"
	if exist "test-results.xml" del /f /q "test-results.xml"
	if exist "$(SRC_DIR)\app\__pycache__" rd /s /q "$(SRC_DIR)\app\__pycache__"
	if exist "$(SRC_DIR)\app\tests\__pycache__" rd /s /q "$(SRC_DIR)\app\tests\__pycache__"
	if exist ".pytest_cache" rd /s /q ".pytest_cache"
	if exist "$(SRC_DIR)\.pytest_cache" rd /s /q "$(SRC_DIR)\.pytest_cache"

# ============================================================================

venv: $(SRC_DIR)/.venv/touchfile

$(SRC_DIR)/.venv/touchfile: $(SRC_DIR)/requirements.txt
	python -m venv $(SRC_DIR)/.venv
	call $(SRC_DIR)\.venv\Scripts\activate.bat && python -m pip install --upgrade pip
	call $(SRC_DIR)\.venv\Scripts\activate.bat && pip install -Ur $(SRC_DIR)/requirements.txt
	type nul > $(SRC_DIR)/.venv/touchfile
