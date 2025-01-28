#!/bin/bash

set -e

# Step 1: Create local branches from main
echo "Creating local branches from main..."
BRANCHES=("promotion/qa" "qa" "promotion/staging" "staging")
for BRANCH in "${BRANCHES[@]}"; do
  echo "Creating branch: $BRANCH"
  git checkout main
  git pull origin main
  git checkout -b "$BRANCH"
  echo "$BRANCH created locally."
done

echo "Local branches created successfully."

# Step 2: Push branches to remote repository
echo "Pushing branches to remote..."
for BRANCH in "${BRANCHES[@]}"; do
  echo "Pushing branch: $BRANCH"
  git push origin "$BRANCH"
  echo "$BRANCH pushed to remote successfully."
done

echo "All branches pushed to remote."
