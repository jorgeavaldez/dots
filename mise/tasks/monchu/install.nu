#!/usr/bin/env nu
#MISE description="Install Monchu's edge release when no monchu command exists"

# Monchu ships as a release tarball, not a registry package, so the npm
# backend can't own it. Install it the documented way and leave updates to
# `monchu update`, which reinstalls into the same npm global prefix. An
# existing command (release install or linked checkout) is left alone; a new
# mise Node version has an empty global prefix, so this reinstalls there.
if (which monchu | is-not-empty) { return }

print "installing monchu (edge release)"
^npm install --global --allow-remote=root https://github.com/jorgeavaldez/monchu/releases/download/edge/monchu.tgz
