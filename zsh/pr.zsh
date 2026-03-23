#!/usr/bin/env zsh

function prm() {
    pi -p "open a pull request for the jj bookmark '$1' that's already been pushed to github, and give me the url. there's no jira ticket. set me as the assignee."
}
