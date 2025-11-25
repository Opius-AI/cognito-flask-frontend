.PHONY: help setup verify start stop restart logs clean test build run-local

# Default target
help:
	@echo "Flask AWS Cognito Authentication - Available Commands"
	@echo "======================================================"
	@echo ""
	@echo "Setup & Configuration:"
	@echo "  make setup       - Set up AWS Cognito (interactive)"
	@echo "  make verify      - Verify setup and configuration"
	@echo ""
	@echo "Application Management:"
	@echo "  make start       - Start the application (foreground)"
	@echo "  make start-bg    - Start the application (background)"
	@echo "  make stop        - Stop the application"
	@echo "  make restart     - Restart the application"
	@echo "  make logs        - View application logs"
	@echo "  make build       - Build Docker image"
	@echo ""
	@echo "Development:"
	@echo "  make run-local   - Run locally without Docker"
	@echo "  make install     - Install Python dependencies"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean       - Stop and remove containers"
	@echo "  make cleanup     - Delete AWS Cognito resources"
	@echo "  make test        - Test the health endpoint"
	@echo ""
	@echo "Quick Start: make setup && make verify && make start"

# AWS Cognito Setup
setup:
	@echo "Running Cognito setup script..."
	./setup-cognito.sh

# Verify configuration
verify:
	@echo "Verifying setup..."
	./verify-setup.sh

# Start application (foreground)
start:
	@echo "Starting application..."
	docker-compose up --build

# Start application (background)
start-bg:
	@echo "Starting application in background..."
	docker-compose up -d --build
	@echo "Application started. Access at http://localhost:8000"
	@echo "View logs with: make logs"

# Stop application
stop:
	@echo "Stopping application..."
	docker-compose down

# Restart application
restart:
	@echo "Restarting application..."
	docker-compose restart

# View logs
logs:
	@echo "Viewing application logs (Ctrl+C to exit)..."
	docker-compose logs -f

# Build Docker image
build:
	@echo "Building Docker image..."
	docker-compose build

# Clean containers and images
clean:
	@echo "Stopping and removing containers..."
	docker-compose down
	@echo "Removing orphaned images..."
	docker image prune -f

# Clean AWS Cognito resources
cleanup:
	@echo "Cleaning up AWS Cognito resources..."
	./cleanup-cognito.sh

# Test health endpoint
test:
	@echo "Testing health endpoint..."
	@curl -s http://localhost:8000/health | python3 -m json.tool || echo "Application not running. Start it with: make start"

# Run locally without Docker
run-local:
	@echo "Running locally..."
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found. Run 'make setup' first."; \
		exit 1; \
	fi
	@set -a && . ./.env && set +a && python3 app.py

# Install Python dependencies
install:
	@echo "Installing Python dependencies..."
	pip3 install -r requirements.txt

# Show current status
status:
	@echo "Application Status:"
	@echo "==================="
	@docker-compose ps || echo "Docker Compose not running"
	@echo ""
	@echo "AWS Cognito Configuration:"
	@if [ -f .env ]; then \
		echo "User Pool ID: $$(grep COGNITO_USER_POOL_ID .env | cut -d '=' -f2)"; \
		echo "AWS Region: $$(grep AWS_REGION .env | cut -d '=' -f2)"; \
	else \
		echo ".env file not found. Run 'make setup' first."; \
	fi
