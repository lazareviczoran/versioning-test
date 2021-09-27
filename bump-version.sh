#!/bin/bash

function join { local IFS="$1"; shift; echo "$*"; }
function bump_version {
  local FILE_PATH=$1
  local NEW_VERSION=$2
  awk -v version="$NEW_VERSION" \
    '/"version": ".*?"/ && count < 1 { gsub("\"version\": \".*?\"", "\"version\": \""version"\""); count++ } {print}' $FILE_PATH > \
    "$FILE_PATH"_tmp && \
    mv "$FILE_PATH"_tmp $FILE_PATH
}

CURRENT_GH_BRANCH=$GITHUB_REF
CURRENT_BRANCH=$GITHUB_HEAD_REF
CURRENT_BRANCH_LOWER_CASE=$(echo "$CURRENT_BRANCH" | awk '{print tolower($0)}')

VERSION=patch
# determine which part of the version number to bump
if [[ "$CURRENT_BRANCH_LOWER_CASE" =~ ^feat/.* ]] || [[ "$CURRENT_BRANCH_LOWER_CASE" =~ ^feature/.* ]]; then
    VERSION=minor
elif [[ "$CURRENT_BRANCH_LOWER_CASE" =~ ^release/.* ]]; then
    VERSION=major
fi

## move to project root
cd "$(git rev-parse --show-toplevel)"

## increment version number from $GITHUB_BASE_REF
VALUES=($(git show remotes/origin/$GITHUB_BASE_REF:package.json | grep -P '"version": ".*?"' | grep -Po "\d+"))
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

CURRENT_VERSION_VALUES=($(grep -P '"version": ".*?"' package.json | grep -Po "\d+"))
CURRENT_VERSION=$(join . ${CURRENT_VERSION_VALUES[@]})
if [[ "$NEW_TARGET_VERSION" == "$CURRENT_VERSION" ]]; then
    # current version is already set to target version, exiting script
    echo "the version is already set properly, stoping execution"
    exit 0
fi

echo "version needs to be updated to $NEW_TARGET_VERSION, proceed to bumping relevant files"

git checkout $CURRENT_BRANCH

# update package.json and package-lock.json with new version
bump_version package.json $NEW_TARGET_VERSION
# awk -v version="$NEW_TARGET_VERSION" \
#   '/"version": ".*?"/ && count < 1 { gsub("\"version\": \".*?\"", "\"version\": \""version"\""); count++ } {print}' package.json > \
#   package.json_tmp && \
#   mv package.json_tmp package.json
if [[ -f "package-lock.json" ]]; then
  bump_version package-lock.json $NEW_TARGET_VERSION
  # awk -v version="$NEW_TARGET_VERSION" \
  #   '/"version": ".*?"/ && count < 1 { gsub("\"version\": \".*?\"", "\"version\": \""version"\""); count++ } {print}' package-lock.json > \
  #   package-lock.json_tmp && \
  #   mv package-lock.json_tmp package-lock.json
fi

# commit changes to the branch
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config user.name "$GITHUB_ACTOR"

git add .
git commit -m "bumped version to v$NEW_TARGET_VERSION"
git push

# publish package to private Github Packages npm repository
echo "//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}" >> .npmrc
RANDOM_SHA=$(date +%s | sha256sum | base64 | head -c 32)
bump_version package.json "0.0.0-PR123-$RANDOM_SHA"
npm i
npm run build
npm publish --tag PR123