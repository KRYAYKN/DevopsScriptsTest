#!/bin/bash

set -e

# AccelQ API credentials
API_TOKEN="_vEXPgyaqAxtXL7wbvzvooY49cnsIYYHrWQMJH-ZcEM"
EXECUTION_ID="452922"
USER_ID="koray.ayakin@pargesoft.com"

# Step 1: Fetch AccelQ Test Results
echo "Fetching AccelQ test results..."
curl -X GET "https://poc.accelq.io/awb/api/1.0/poc25/runs/${EXECUTION_ID}" \
  -H "api_key: ${API_TOKEN}" \
  -H "user_id: ${USER_ID}" \
  -H "Content-Type: application/json" > accelq-results.json
echo "AccelQ test results saved to accelq-results.json"

# Step 2: Identify Failed and Passed Branches
echo "Identifying failed and passed branches..."

# Extract failed branches
FAILED_BRANCHES=$(jq -r '.summary.testCaseSummaryList[] | select(.status == "fail") | .metadata.tags[]' accelq-results.json | sort | uniq)

# Extract passed branches
PASSED_BRANCHES=$(jq -r '.summary.testCaseSummaryList[] | select(.status == "pass") | .metadata.tags[]' accelq-results.json | sort | uniq)

# Fetch latest remote branches and prune deleted ones
echo "Fetching latest remote branches..."
git fetch --all --prune

echo "Failed branches:"
echo "$FAILED_BRANCHES"
echo "Passed branches:"
echo "$PASSED_BRANCHES"

# Step 3: Process Passed Branches
STAGING_BRANCH="promotion/staging"
for BRANCH in $PASSED_BRANCHES; do
  TEMP_BRANCH="TEMP_${BRANCH// /}"  # Trim spaces
  echo "Processing passed branch: |$TEMP_BRANCH|"

  # Debugging Output: Uzak repodaki branch'leri listeleyelim
  echo "Checking existence of $TEMP_BRANCH in remote repository..."
  git ls-remote origin | grep TEMP_
  echo "Verifying exact match for: |$TEMP_BRANCH|"
  git ls-remote origin | grep "^.*$TEMP_BRANCH$"

  # Check if TEMP_BRANCH exists in remote
  if git ls-remote --exit-code --heads origin "$TEMP_BRANCH" > /dev/null; then
    echo "$TEMP_BRANCH exists. Preparing to create a PR to $STAGING_BRANCH..."

    # Create a PR from TEMP_BRANCH to STAGING_BRANCH
    gh pr create \
      --title "Merge $TEMP_BRANCH into $STAGING_BRANCH" \
      --body "Automated PR from $TEMP_BRANCH to $STAGING_BRANCH." \
      --base "$STAGING_BRANCH" \
      --head "$TEMP_BRANCH"

    # Check for conflicts
    PR_NUMBER=$(gh pr list --base "$STAGING_BRANCH" --head "$TEMP_BRANCH" --state open --json number --jq '.[0].number')
    if [[ -n "$PR_NUMBER" ]]; then
      echo "Checking for conflicts in PR #$PR_NUMBER..."
      if gh pr view "$PR_NUMBER" --json mergeable --jq '.mergeable' | grep -q "true"; then
        echo "No conflicts detected. Merging PR #$PR_NUMBER into $STAGING_BRANCH..."
        gh pr merge "$PR_NUMBER" --merge --body "Merging $TEMP_BRANCH into $STAGING_BRANCH."
        echo "PR #$PR_NUMBER merged successfully."
      else
        echo "Conflict detected in PR #$PR_NUMBER. Please resolve manually."
        echo "Conflict resolution link: https://github.com/$(echo $GITHUB_REPO | cut -d'/' -f4,5)/pull/$PR_NUMBER"
      fi
    else
      echo "Failed to create or find PR for $TEMP_BRANCH to $STAGING_BRANCH."
    fi
  else
    echo "Error: $TEMP_BRANCH does not exist in the remote repository. Skipping."
    echo "Available branches:"
    git branch -r | grep TEMP_
  fi
done

# Step 4: Cleanup TEMP branches
for BRANCH in $PASSED_BRANCHES $FAILED_BRANCHES; do
  TEMP_BRANCH="TEMP_${BRANCH// /}"
  echo "Deleting TEMP branch: |$TEMP_BRANCH|"
  
  if git ls-remote --exit-code --heads origin "$TEMP_BRANCH" > /dev/null; then
    echo "Executing: git push origin --delete $TEMP_BRANCH"
    git push origin --delete "$TEMP_BRANCH"
    
    # Silme işlemini doğrulama
    if git ls-remote --exit-code --heads origin "$TEMP_BRANCH" > /dev/null; then
      echo "Error: $TEMP_BRANCH could not be deleted!"
    else
      echo "$TEMP_BRANCH deleted successfully."
    fi
  else
    echo "Error: $TEMP_BRANCH does not exist in the remote repository. Skipping."
    echo "Available branches:"
    git branch -r | grep TEMP_
  fi
done

# Cleanup
rm -f accelq-results.json

echo "Completed processing branches."
