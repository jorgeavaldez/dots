#!/usr/bin/env zsh

function prm() {
    pi -p "open a pull request for the jj bookmark '$1' that's already been pushed to github, and give me the url. there's no jira ticket. set me as the assignee."
}

function prmj() {
    pi -p "open a pull request for the jj bookmark '$1' that's already been pushed to github, and give me the url. the jira ticket is '$2'. set me as the assignee."
}

function prs() {
    REPO=$(jj git remote list | cut -d" " -f 2 | sed 's/.*github\.com[\/:]\(.*\)\.git/\1/g')
    gh pr list -A '@me' -R "$REPO" --state open
}

function reponame() {
    REPO=$(jj git remote list | cut -d" " -f 2 | sed 's/.*github\.com[\/:]\(.*\)\.git/\1/g')
    echo "$REPO"
}
