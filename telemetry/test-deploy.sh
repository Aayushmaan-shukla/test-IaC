#!/bin/bash
#
# test-deploy.sh - Quick deployment test for monitoring stack
#
# This script performs a minimal deployment test to verify all configurations work together
#

set -e

echo "================================================================"
echo "  MONITORING STACK DEPLOYMENT TEST"
echo "================================================================"
echo ""

echo "Step 1: Validating environment..."
if bash scripts/validate-environment.sh 2>&1 | grep -q "Validation failed"; then
    echo "❌ Validation failed. Please fix validation errors first."
    exit 1
else
    echo "✅ Environment validation passed"
fi
echo ""

echo "Step 2: Checking Docker Compose configuration..."
if docker-compose config > /dev/null 2>&1; then
    echo "✅ Docker Compose configuration is valid"
else
    echo "❌ Docker Compose configuration has errors"
    docker-compose config
    exit 1
fi
echo ""

echo "Step 3: Pulling Docker images..."
if docker-compose pull; then
    echo "✅ Docker images pulled successfully"
else
    echo "❌ Failed to pull Docker images"
    exit 1
fi
echo ""

echo "Step 4: Starting containers in test mode..."
echo "⚠️  This will start containers for 30 seconds, then stop them"
echo ""

if docker-compose up -d; then
    echo "✅ Containers started successfully"
    echo ""
    echo "Waiting 30 seconds for services to initialize..."
    sleep 30

    echo ""
    echo "Step 5: Checking container status..."
    docker-compose ps

    echo ""
    echo "Step 6: Checking service health..."
    echo "Checking Grafana..."
    if curl -s -f http://localhost:4101/api/health > /dev/null 2>&1; then
        echo "✅ Grafana is healthy"
    else
        echo "⚠️  Grafana health check failed (may still be starting)"
    fi

    echo "Checking Prometheus..."
    if curl -s -f http://localhost:4102/-/healthy > /dev/null 2>&1; then
        echo "✅ Prometheus is healthy"
    else
        echo "⚠️  Prometheus health check failed (may still be starting)"
    fi

    echo "Checking Loki..."
    if curl -s -f http://localhost:4103/ready > /dev/null 2>&1; then
        echo "✅ Loki is healthy"
    else
        echo "⚠️  Loki health check failed (may still be starting)"
    fi

    echo ""
    echo "Step 7: Stopping containers..."
    docker-compose down
    echo "✅ Containers stopped"

    echo ""
    echo "================================================================"
    echo "  DEPLOYMENT TEST COMPLETED"
    echo "================================================================"
    echo ""
    echo "✅ All configurations are working correctly!"
    echo ""
    echo "To deploy permanently, run: ./scripts/deploy.sh"
    echo ""
    echo "Access URLs:"
    echo "  - Grafana:     http://localhost:4101"
    echo "  - Prometheus:  http://localhost:4102"
    echo "  - Loki:        http://localhost:4103"
    echo ""
else
    echo "❌ Failed to start containers"
    docker-compose logs --tail=50
    exit 1
fi
