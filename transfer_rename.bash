#!/bin/bash

set -e

get_org_repo_list()
{
  local org="${1}"
  gh api -H "Accept: application/vnd.github.v3+json" \
    --paginate \
    "/orgs/${org}/repos" --jq '.[].name'
}

generate_new_repo_name()
{
  local current_name=${1}

  new_name=${current_name/ignition-/gz-}
  new_name=${new_name/ignition_/gz_}
  new_name=${new_name/ign-/gz-}
  echo "${new_name}"
}

declare -a GH_ORGS
GH_ORGS[0]='ignition-release;gazebo-release'
GH_ORGS[1]='ignitionrobotics;gazebosim'
GH_ORGS[2]='ignition-forks;gazebo-forks'
GH_ORGS[3]='ignition-tooling;gazebo-tooling'

for org_setting in "${GH_ORGS[@]}"; do
  IFS=";" read -r -a org <<< "${org_setting}"
  current_org="${org[0]}"
  new_org=${org[1]}
  echo "ORGANIZATION: ${current_org} -> ${new_org}"
  echo " LIST OF REPOSITORIES"
  repositories=$(get_org_repo_list "${current_org}")
  for repo_name in ${repositories}; do
    echo -n "    * ${repo_name}"
    new_repo_name=$(generate_new_repo_name "${repo_name}")
    if [[ "${repo_name}" == "${new_repo_name}" ]]; then
      echo ": NO CHANGE"
    else
      echo " --> ${new_repo_name}"
    fi
  done
  echo "------------------------------------------"
done
