#!/bin/bash

# if [[ -z "${GITHUB_TOKEN}" ]]; then
#   echo "The GITHUB_TOKEN env var is not set"
#   exit 1
# fi

function join { local IFS="$1"; shift; echo "$*"; }

VERSION=patch
CURRENT_BRANCH=$GITHUB_HEAD_REF
echo $CURRENT_BRANCH
CURRENT_BRANCH_LOWER_CASE=$(echo "$CURRENT_BRANCH" | awk '{print tolower($0)}')
echo $CURRENT_BRANCH_LOWER_CASE

# determine which part of the version number to bump
if [[ "$CURRENT_BRANCH_LOWER_CASE" =~ ^feat/.* ]] || [[ "$CURRENT_BRANCH_LOWER_CASE" =~ ^feature/.* ]]; then
    VERSION=minor
elif [[ "$CURRENT_BRANCH_LOWER_CASE" =~ ^release/.* ]]; then
    VERSION=major
fi

echo $VERSION

## move to project root
cd "$(git rev-parse --show-toplevel)"

echo "hello"
grep --version

echo "1.2.3" | grep -Eo "\d+"

git show remotes/origin/$GITHUB_BASE_REF:package.json | grep -E '"version": ".*?"' | grep -Eo "\d+"

echo "printed out the version"

## increment version number from $GITHUB_BASE_REF
VALUES=($(git show remotes/origin/$GITHUB_BASE_REF:package.json | grep -E '"version": ".*?"' | grep -Eo "\d+"))
echo "about to print out new version"
echo $(join . ${VALUES[@]})

CURRENT_VALUES=($(grep -E '"version": ".*?"' package.json | grep -Eo "\d+"))
CURRENT_VERSION=$(join . ${CURRENT_VALUES[@]})
echo $CURRENT_VERSION
if [ "$VERSION" == "major" ]; then
  VALUES[0]=$((VALUES[0] + 1))
  VALUES[1]=0
  VALUES[2]=0
elif [ "$VERSION" == "minor" ]; then
  VALUES[1]=$((VALUES[1] + 1))
  VALUES[2]=0
else
  VALUES[2]=$((VALUES[2] + 1))
fi
NEW_TARGET_VERSION=$(join . ${VALUES[@]})
echo $NEW_TARGET_VERSION

if [[ "$NEW_TARGET_VERSION" == "$CURRENT_VERSION" ]]; then
    # current version is already set to target version, exiting script
    echo "same version"
    exit 0
fi

echo "different version, proceed to bumping relevant files"
## update package.json and package-lock.json with new version
awk -v version="$NEW_TARGET_VERSION" \
  '/\"version\": \".*?\"/ && count < 1 { gsub("\"version\": \".*?\"", "\"version\": \""version"\""); count++ } {print}' package.json > \
  package.json_tmp && \
  mv package.json_tmp package.json
if [[ -f "package-lock.json" ]]; then
  awk -v version="$NEW_TARGET_VERSION" \
    '/\"version\": \".*?\"/ && count < 1 { gsub("\"version\": \".*?\"", "\"version\": \""version"\""); count++ } {print}' package-lock.json > \
    package-lock.json_tmp && \
    mv package-lock.json_tmp package-lock.json
fi

git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config user.name "$GITHUB_ACTOR"

# git add .
# git commit -m "bumped version to v$NEW_TARGET_VERSION"
# git push origin $CURRENT_BRANCH