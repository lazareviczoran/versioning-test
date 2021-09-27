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

ACTIVE_VERSIONS_ITEMS=$(curl -s \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: bearer $GITHUB_TOKEN" \
    -d '{"query":"'"$query"'"}' \
    https://api.github.com/graphql | jq -r '.data.repository.packages.nodes[0].versions.nodes[]')

FILTERED_VERSIONS_ITEMS=$(echo $ACTIVE_VERSIONS_ITEMS \
                            | jq -r '.|select(.version | startswith("0.0.0-PR7"))' \
                            | jq -r '.id')

VERSION_IDS_TO_DELETE=($(echo $FILTERED_VERSIONS_ITEMS))
for id in "${VERSION_IDS_TO_DELETE[@]}"; do
    curl -X POST \
        -H "Accept: application/vnd.github.package-deletes-preview+json" \
        -H "Authorization: bearer $GITHUB_TOKEN" \
        -d "{\"query\":\"mutation { deletePackageVersion(input:{packageVersionId:\\\"$id\\\"}) { success }}\"}"
        https://api.github.com/graphql
done
