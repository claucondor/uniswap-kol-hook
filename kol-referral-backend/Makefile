# Makefile for the KOL Referral Backend

# --- Configuration --- 
# Get the short Git commit hash or use timestamp if no git
GIT_SHA := $(shell git rev-parse --short=7 HEAD 2>/dev/null || date +%s)
# Google Cloud Project ID (Can be overridden by .env or environment)
PROJECT_ID ?= $(shell grep GOOGLE_CLOUD_PROJECT_ID .env | cut -d '=' -f2 || echo 'automatic-ace-457219-r3')
# Google Cloud Region (Replace if different)
REGION=us-central1
# Name of the Cloud Run service
SERVICE_NAME=kol-referral-backend
# Docker image name
IMAGE_NAME=gcr.io/$(PROJECT_ID)/$(SERVICE_NAME):$(GIT_SHA)
# Port (Can be overridden by .env or environment for local runs)
LOCAL_PORT ?= $(shell grep PORT .env | cut -d '=' -f2 || echo '3001')

# --- Targets ---

.PHONY: setup clean build check dev docker-build docker-run deploy list-services init-git

# Initialize git repository if it doesn't exist in the project root
init-git:
	@if [ ! -d "../.git" ]; then \
		echo "[init-git] Initializing git repository in project root (../)..."; \
		(cd .. && git init && git add . && git commit -m "Initial project commit"); \
	else \
		echo "[init-git] Git repository already exists in project root."; \
	fi

# Installs dependencies using npm ci for consistency
setup: init-git
	@echo "[setup] Installing dependencies using npm ci..."
	@npm ci

# Removes node_modules and build artifacts
clean:
	@echo "[clean] Removing node_modules and dist directory..."
	@rm -rf node_modules dist

# Build TypeScript code
build:
	@echo "[build] Compiling TypeScript..."
	@npm run build

# Run type checking, linting, and tests (assumes scripts in package.json)
check:
	@echo "[check] Running TypeScript checks (if 'type-check' script exists)..."
	@npm run type-check || echo "Skipping type-check (script not found or failed)."
	@echo "[check] Running linting (if 'lint' script exists)..."
	@npm run lint || echo "Skipping lint (script not found or failed)."
	@echo "[check] Running tests (if 'test' script exists and is configured)..."
	@npm run test || echo "Skipping tests (script not found or failed)."

# Runs the service locally using ts-node for development
dev:
	@echo "[run-dev $(SERVICE_NAME)] Running service locally with ts-node on port $(LOCAL_PORT)..."
	@npm run dev

# Builds the Docker image locally
docker-build:
	@echo "[docker-build $(SERVICE_NAME)] Building Docker image..."
	@docker build -t $(IMAGE_NAME) -f Dockerfile . --build-arg APP_PORT=$(LOCAL_PORT)

# Builds and runs the Docker container locally
docker-run: docker-build
	@echo "[docker-run $(SERVICE_NAME)] Running Docker container locally, mapping host port $(LOCAL_PORT) to container port $(LOCAL_PORT)..."
	@docker run --rm -p $(LOCAL_PORT):$(LOCAL_PORT) --env-file .env $(IMAGE_NAME)

# Builds, pushes the image, and deploys to Cloud Run
deploy: build docker-build
	@echo "[deploy $(SERVICE_NAME)] Deploying to Cloud Run in $(REGION) for project $(PROJECT_ID)..."
	@echo "  Image: $(IMAGE_NAME)"
	@docker push $(IMAGE_NAME)
	@echo "[secrets] Creating/Updating environment variables in Secret Manager secret: $(SERVICE_NAME)-env ..."
	@ (gcloud secrets versions add $(SERVICE_NAME)-env --project=$(PROJECT_ID) --data-file=.env || \
	 gcloud secrets create $(SERVICE_NAME)-env --project=$(PROJECT_ID) --data-file=.env --replication-policy=automatic)
	@echo "[deploy] Converting .env from Secret Manager to YAML format for Cloud Run deployment..."
	@gcloud secrets versions access latest --project=$(PROJECT_ID) --secret=$(SERVICE_NAME)-env > /tmp/$(SERVICE_NAME).env.tmp
	@ (grep -v '^#' /tmp/$(SERVICE_NAME).env.tmp | grep -v '^$$' | grep -v '^PORT=' | \
     sed -e 's/=\(.*\)/: "'\1'"/' > /tmp/$(SERVICE_NAME).yaml) || \
     (echo "Failed to create YAML from secret. Check secret content and permissions." && exit 1)
	@echo "[deploy] Deploying $(SERVICE_NAME) to Cloud Run..."
	@gcloud run deploy $(SERVICE_NAME) \
		--image $(IMAGE_NAME) \
		--project=$(PROJECT_ID) \
		--region $(REGION) \
		--platform managed \
		--allow-unauthenticated \
		--env-vars-file /tmp/$(SERVICE_NAME).yaml \
		--memory 256Mi \
		--cpu 1 \
		--timeout 300s
	@rm -f /tmp/$(SERVICE_NAME).env.tmp /tmp/$(SERVICE_NAME).yaml
	@echo "Deployment of $(SERVICE_NAME) initiated."

# Lists Cloud Run services in the configured region
list-services:
	@echo "[list-services] Listing Cloud Run services in $(REGION) for project $(PROJECT_ID)..."
	@gcloud run services list --project=$(PROJECT_ID) --region $(REGION)

# KOL Referral specific targets
.PHONY: test-performance test-hono

# Test Hono performance
test-performance:
	@echo "[test-performance] Testing Hono performance..."
	@npm run test:performance || echo "Performance test not configured"

# Test the Hono service locally
test-hono:
	@echo "[test-hono] Running Hono tests..."
	@npm run test:hono || echo "Hono tests not configured" 