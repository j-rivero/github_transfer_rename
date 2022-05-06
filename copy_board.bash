#!/bin/bash
# A sample script to migrate cards from one project board to another
#  
# 1. The script requires Github auth token for API communication
# https://github.com/settings/tokens/new?scopes=repo
#
# 2. To discover the board ids, you can call the following endpoints with
# the Authorization and Accept headers used throughout this script:
# GET /orgs/{org}/projects
# GET /users/{username}/projects
# GET /repos/{owner}/{repo}/projects
#
# Bear in mind that the Accept header application/vnd.github.v3+json
# indicates that the API is in preview period and may be subject to change
# https://docs.github.com/en/rest/reference/projects

set -e

IGNITIONTESTING_BOARD1_ID=14388694
GAZEBOTESTING_BOARD1_ID=14390837
GAZEBOTESTING_BOARD2_ID=14392283

# Core
IGNITION_CORE3_ID=4304048
# TRI
IGNITION_CORE6_ID=12772514
# Core
GAZEBOSIM_BOARD1=14403295
# TRI
GAZEBOSIM_BOARD2=14434469

SOURCE_PROJECT_ID=${IGNITION_CORE3_ID}
TARGET_PROJECT_ID=${GAZEBOSIM_BOARD1}

sourceColumnIds=( $(gh api \
  -H "Accept: application/vnd.github.v3+json" \
  projects/${SOURCE_PROJECT_ID}/columns | jq .[].id) )

targetColumnIds=( $(gh api \
  -H "Accept: application/vnd.github.v3+json" \
  projects/${TARGET_PROJECT_ID}/columns | jq .[].id) )

if [ "${#videos[@]}" -ne "${#subtitles[@]}" ]; then
    echo "Different number of columns in between projects"
    exit -1
fi

# Safe check: look that column scheme matches
# TODO(j-rivero): de-duplicate loop
for sourceColumnIndex in "${!sourceColumnIds[@]}"
do
    sourceColumnId=${sourceColumnIds[$sourceColumnIndex]}
    sourceColumnId=${sourceColumnId//[^a-zA-Z0-9_]/}
    targetColumnId=${targetColumnIds[$sourceColumnIndex]}
    targetColumnId=${targetColumnId//[^a-zA-Z0-9_]/}

    orig_column_name=$(gh api \
      -H "Accept: application/vnd.github.v3+json" \
      projects/columns/${sourceColumnId} | jq .name)
    target_column_name=$(gh api \
      -H "Accept: application/vnd.github.v3+json" \
      projects/columns/${targetColumnId} | jq .name)

    echo "Checking columns: ${orig_column_name} is equal to ${target_column_name}"
    if [[ ${orig_column_name} != ${target_column_name} ]]; then
      echo "COLUMNS does not match"
      exit 1
    fi
done

for sourceColumnIndex in "${!sourceColumnIds[@]}"
do
    sourceColumnId=${sourceColumnIds[$sourceColumnIndex]}
    sourceColumnId=${sourceColumnId//[^a-zA-Z0-9_]/}
    targetColumnId=${targetColumnIds[$sourceColumnIndex]}
    targetColumnId=${targetColumnId//[^a-zA-Z0-9_]/}

    orig_column_name=$(gh api \
      -H "Accept: application/vnd.github.v3+json" \
      projects/columns/${sourceColumnId} | jq .name)
    target_column_name=$(gh api \
      -H "Accept: application/vnd.github.v3+json" \
      projects/columns/${targetColumnId} | jq .name)

    echo "Processing column SRC ${orig_column_name} -> DEST ${target_column_name}"
    if [[ ${orig_column_name} != ${target_column_name} ]]; then
      echo "COLUMNS does not match"
      exit 1
    fi

    gh api --paginate \
      -H "Accept: application/vnd.github.v3+json" \
      projects/columns/${sourceColumnId}/cards \
      | jq reverse \
      | jq -c '.[]' \
      | while read card; do
        note=$(jq '.note' <<< "$card")
        card_id=$(jq '.id' <<< "$card")
        node_id=$(jq '.node_id' <<< "$card")
        content_url=$(jq '.content_url' <<< "$card")

        # cut from api in content_url the relevant info
        issue_or_pr_number=${content_url##*/}
        github_repo_substr=${content_url##*repos/}  # incomplete cleanup
        if [[ ${content_url} != ${content_url/\/issues\/} ]]; then
          echo "Detected Issue card"
          content_type='Issue'
          github_repo=${github_repo_substr%%/issues*}
        elif [[ ${content_url} != ${content_url/\/pull\/} ]]; then
          echo "Detected PullRequest card"
          github_repo=${github_repo_substr%%/pull*}
          content_type='PullRequest'
        elif [[ ${note} == "null" ]]; then
          echo "ERROR: Unknown"
          exit 1
        fi

       if [[ ${note} == 'null' ]]; then
         note="https://github.com/${github_repo_substr}"
       fi

       gh api \
          -X POST \
          -H "Accept: application/vnd.github.v3+json" \
          -f "note=${note}" \
          "projects/columns/${targetColumnId}/cards"
#
#          Try to follow API to inject not note cards only work
#          in the repositories refered are under the same org than
#          project board
#
#          content_id=$(gh api \
#            -H "Accept: application/vnd.github.v3+json" \
#            /repos/${github_repo_substr} --jq .id)
#          gh api \
#            -X POST \
#            -H "Accept: application/vnd.github.v3+json" \
#            -F "content_id=${content_id}" \
#            -f "content_type=${content_type}" \
#            projects/columns/${targetColumnId}/cards || true

        echo " for card migration: ${note}"
    done
done
