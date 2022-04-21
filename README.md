# GitHub transfer and rename

Scripts to transfer all repositories from one org to another applying the name
change required by the Ignition -> Gazebo

## Requirement

 * `gh` cli tool installed and `gh auth` authentication ready
 * Permissions in target repositories

## Scripts

### SCRIPT: transfer_rename

The script transfers all repositories in a given GitHub orgs to a different one.
It also applies some rules to rename the moved repositories from Ignition names
to the new Gazebo names.

#### Input configurations
Before using, please edit the script and populate the array of `GH_ORGS` with
orig;target repository values (i.e: ignition-forks;gazebo-forks);

#### Usage:

    Usage: transfer_rename.bash [repo-name-for-single-migration]

    repo-name-for-single-migration: if present, instead of processing all
    repositories it will process just the repository name given.

### SCRIPT: copy_board

The scripts copies all the cards from one project board in GitHub to another.
Before using it, both projects needs to exist and have exactly the same columns
with the same name.

Limitation: the script will convert non "note" cards to a "note" card
(those starting with "Added by"). More details below.

#### Input configurations

The script works with project board IDs. These are easy to get using the following:

     gh api "orgs/${github_org_name}/projects" | jq .[].name,.[].id

Before using the script please edit the source code and fill the `SOURCE_PROJECT_ID`
and `TARGET_PROJECT_ID` projects.

#### Usage

    Usage: copy_board.bash

#### Implementation details
Although cards in the board seems similar, API level are different between ones
with a note (those starting with a message "Added by") and others with a direct
link to issues or pull request without that note. This last group probably
comes from automation injecting cards.

  * We can not move cards among different orgs, error message is "The card
    and column must be in the same project".
  * For the non-note cards we can not move use the IDs that they contain
    pointing to a PR/Issue directly among different orgs, error message is:
    "contentID must refer to an issue or pull request in a repository owned
    by the project owner".
  * For the cards with a note, we can inject a new card with the same
    content.

The script will convert the non-note cards into a note card transforming the
issue/pull request  metadata into a valid GitHub link to them and inject them
as a note.
