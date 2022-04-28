#!/bin/bash

set -e

if [[ ${#} -eq 1 ]] && [[ ${1} == '--help' ]]; then
    echo "Usage: ${0} [repo-name-for-single-migration]"
    exit 1
fi

DO_MIGRATION=${DO_MIGRATION:-false}

SINGLE_MIGRATION_REPO=
if [[ ${#} -eq 1 ]]; then
  SINGLE_MIGRATION_REPO=${1}
  echo "! Single repository migration enabled. Only for ${SINGLE_MIGRATION_REPO}"
fi

if [[ ${DO_MIGRATION} != 'true' && ${DO_MIGRATION} != 'false' ]]; then
  echo "DO_MIGRATION needs to true OR false"
  exit 1
fi

if ! ${DO_MIGRATION}; then
  echo "! DO_MIGRATION var is set to false. NO REAL MIGRATION IS DONE"
fi

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

  new_name=${current_name/ign-gazebo/gz-sim}
  new_name=${current_name/ignition-/gz-}
  new_name=${new_name/ignition_/gz_}
  new_name=${new_name/ign-/gz-}
  new_name=${new_name/-ign/-gz}
  echo "${new_name}"
}

declare -a GH_ORGS
GH_ORGS[0]='ignitiontesting;gazebotesting'
# GH_ORGS[0]='ignition-release;gazebo-release'
# GH_ORGS[1]='ignitionrobotics;gazebosim'
# GH_ORGS[2]='ignition-forks;gazebo-forks'
# GH_ORGS[3]='ignition-tooling;gazebo-tooling'

for org_setting in "${GH_ORGS[@]}"; do
  IFS=";" read -r -a org <<< "${org_setting}"
  current_org="${org[0]}"
  new_org=${org[1]}
  echo "ORGANIZATION: ${current_org} -> ${new_org}"
  echo " LIST OF REPOSITORIES"
  repositories=$(get_org_repo_list "${current_org}")
  for repo_name in ${repositories}; do
    if [[ -n ${SINGLE_MIGRATION_REPO} ]]; then
      [[ "${SINGLE_MIGRATION_REPO}" != "${repo_name}" ]] && continue
    fi
    # 1. Move to the new org
    current_gh_uri="${current_org}/${repo_name}"
    new_org_old_repo_name_uri="${new_org}/${repo_name}"
    echo "  + ORG MOVE: ${current_gh_uri} -> ${new_org}"
      echo "     > gh api repos/${current_gh_uri}/transfer -f new_owner=${new_org} --silent"
    if ${DO_MIGRATION}; then
      gh api "repos/${current_gh_uri}/transfer" -f new_owner="${new_org}" --silent
    fi
    # Rename the repository
    new_repo_name=$(generate_new_repo_name "${repo_name}")
    echo -n "    * ${repo_name}"
    if [[ "${repo_name}" == "${new_repo_name}" ]]; then
      echo ": NO CHANGE"
    else
      echo " --> ${new_repo_name}"
      echo "     > gh repo rename ${new_repo_name} --repo ${new_org_old_repo_name_uri}"
      if ${DO_MIGRATION}; then
        # API seems not to be accesible so fast for moved large repos. Wait a bit
        sleep 2
        gh repo rename "${new_repo_name}" --repo "${new_org_old_repo_name_uri}"
      fi
    fi
  done
  echo "------------------------------------------"
done
