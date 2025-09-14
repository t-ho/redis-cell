#!/bin/bash
set -e

echo "🔨 Testing Docker build locally..."

# Simulate GitHub Actions environment variables
export GITHUB_REF="refs/tags/0.4.1-redis8.2-bookworm"
export GITHUB_SHA="abc123def456"
export DOCKER_IMAGE="0x8861/redis-cell"

# Extract version like the workflow does
RELEASE_VERSION=${GITHUB_REF#refs/tags/}

# Create tags like the workflow
TAGS="${DOCKER_IMAGE}:latest,${DOCKER_IMAGE}:stable,${DOCKER_IMAGE}:${RELEASE_VERSION}"

echo "📦 Building with tags: ${TAGS}"

# Build the image locally
docker build -t redis-cell:test .

echo "🚀 Starting Redis with redis-cell module..."
# Clean up any existing container
docker rm -f redis-cell-test 2>/dev/null || true

docker run -d --name redis-cell-test redis-cell:test

# Wait for Redis to start
sleep 3

# Check if container is running
if [ "$(docker inspect -f '{{.State.Running}}' redis-cell-test 2>/dev/null)" != "true" ]; then
    echo "❌ Container failed to start. Logs:"
    docker logs redis-cell-test
    exit 1
fi

echo "✅ Checking if module is loaded..."
docker exec redis-cell-test redis-cli MODULE LIST | grep -q redis-cell && echo "✓ Module loaded" || (echo "✗ Module not loaded" && exit 1)

echo "🧪 Testing CL.THROTTLE command..."
RESULT=$(docker exec redis-cell-test redis-cli CL.THROTTLE test-key 15 30 60 1)
echo "Response: $RESULT"

# Check if response has 5 elements (expected output)
if [[ $(echo "$RESULT" | wc -l) -eq 5 ]]; then
    echo "✓ CL.THROTTLE command works!"
else
    echo "✗ CL.THROTTLE command failed!"
    exit 1
fi

echo "🧹 Cleaning up..."
docker stop redis-cell-test
docker rm redis-cell-test

echo "✅ All tests passed! The workflow should work correctly."
echo ""
echo "To test the actual GitHub workflow without creating a release:"
echo "1. Push to a test branch and create a PR to master"
echo "2. Use the 'Test Docker Build' workflow manually from Actions tab"
echo "3. Or use 'act' tool to run GitHub Actions locally:"
echo "   act release --dry-run"