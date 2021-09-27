#!/bin/bash

USERNAME=lazareviczoran
REPONAME=versioning-test

query="$(cat <<EOF | sed 's/"/\\"/g' | tr '\n\r' ' '
query {
    repository(owner:"$USERNAME", name:"$REPONAME"){
        packages(names:"versioning-test",first:1) {
            nodes {
                versions(first:100) {
                    nodes {
                        id
                        version
                    }
                }
            }
        }
    }
}
EOF
)"

PULL_REQUEST_ID=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
TARGET_VERSION_NAME_PREFIX="0.0.0-PR$PULL_REQUEST_ID"

ACTIVE_VERSIONS_ITEMS=$(curl -s \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: bearer $GITHUB_TOKEN" \
    -d '{"query":"'"$query"'"}' \
    https://api.github.com/graphql | jq -r '.data.repository.packages.nodes[0].versions.nodes[]')

FILTERED_VERSIONS_ITEMS=$(echo $ACTIVE_VERSIONS_ITEMS \
                            | jq -r ".|select(.version | startswith(\"$TARGET_VERSION_NAME_PREFIX\"))")
FILTERED_VERSIONS=$(echo $FILTERED_VERSIONS_ITEMS | jq -r '.version')
FILTERED_VERSION_IDS=$(echo $FILTERED_VERSIONS_ITEMS | jq -r '.id')

VERSIONS_TO_DELETE=($(echo $FILTERED_VERSIONS))
VERSION_IDS_TO_DELETE=($(echo $FILTERED_VERSION_IDS))
for i in "${!VERSION_IDS_TO_DELETE[@]}"; do
    echo "deleting version ${VERSIONS_TO_DELETE[i]} (id: ${VERSION_IDS_TO_DELETE[i]})"
    curl -s \
        -X POST \
        -H "Accept: application/vnd.github.package-deletes-preview+json" \
        -H "Authorization: bearer $GITHUB_TOKEN" \
        -d "{\"query\":\"mutation { deletePackageVersion(input:{packageVersionId:\\\"${VERSION_IDS_TO_DELETE[i]}\\\"}) { success }}\"}" \
        https://api.github.com/graphql
done
