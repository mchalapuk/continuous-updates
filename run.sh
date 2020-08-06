#!/bin/bash

set -e

PKG_NAME=$1
REPO_URL=$2
PWD_VAR=$3
TEST_TASK=$4
DEPLOY_TASK=$5

red() {
  echo -e "\e[91m$@\e[0m"
}
green() {
  echo -e "\e[92m$@\e[0m"
}
blue() {
  echo -e "\e[36m$@\e[0m"
}
bold() {
  echo -e "\e[1m$@\e[0m"
}

usage() {
  echo "Usage: $0 <pkg-name> <repo-url> <key-password-var> <test-task> [deploy-task]"
}

die() {
  red $@ >&2
  exit 1
}

test -n "$PKG_NAME" || die $(usage)
test -n "$REPO_URL" || die $(usage)
test -n "$PWD_VAR" || die $(usage)
test -n "$TEST_TASK" || die $(usage)

FOLDER="./${PKG_NAME}"
KEY_FILE="../keys/${PKG_NAME}"
SSH_ENV="$HOME/.ssh/environment"
eval "KEY_PASS=\$${PWD_VAR}"

log_success() {
  green " $(bold ✔)"
}
log_failure() {
  red " $(bold ✗)"
}

turn_red() {
  while read LINE
  do
    red $LINE
  done </dev/stdin
}

step() {
  TITLE=$1
  CMD=$2

  echo -n $(bold "$TITLE")

  LOG_FILE=$(mktemp /tmp/cha80s_cu_XXXXX)
  # Running command with both stdout and stderr redirected to the same
  # log file but stderr colored red. This preserves both message order
  # and info about stream instance.
  { $CMD 2>&1 1>&3 3>&- | turn_red >&3; } 3>$LOG_FILE
  RETVAL="${PIPESTATUS[0]}"

  if [[ "$RETVAL" == "0" ]]
  then
    log_success
  else
    log_failure
    cat $LOG_FILE
  fi

  rm $LOG_FILE
  return $RETVAL
}

cmd() {
  echo "\$ $(blue $@)"
  eval "$@"
}

prepare_workspace() {
  cmd rm -rf $FOLDER
}

add_ssh_keys() {
  (umask 066; cmd "ssh-agent > $SSH_ENV")
  cmd . $SSH_ENV

  cmd ssh-add -D
  cmd openssl rsa -in ${KEY_FILE} -passin pass:${KEY_PASS} -out ./key
  cmd chmod 0600 ./key
  cmd ssh-add ./key
}

clone() {
  cmd . $SSH_ENV
  cmd git clone $REPO_URL $FOLDER 
}

install_dependencies() {
  cmd npm install
  cmd npm-install-peers
}

commit_updates() {
  cmd git add .
  cmd git commit -m \"~ updated depdendencies\"
}

bump_version() {
  cmd npm version patch
}

deploy() {
  cmd npm run $DEPLOY_TASK
}

push_updates() {
  cmd . $SSH_ENV
  cmd git push
  cmd git push --tags
}

kill_ssh_agent() {
  . $SSH_ENV
  eval $(ssh-agent -k 2>/dev/null) >/dev/null
}

trap 'kill_ssh_agent' EXIT

step "Preparing workspace: ${FOLDER}" "prepare_workspace"
step "Adding ssh keys" "add_ssh_keys"
step "Cloning $REPO_URL" "clone"

cd $FOLDER
echo "cwd: $(pwd)"

step "Installing dependencies" "install_dependencies"

echo -n $(bold "Checking dependency versions")
OUTDATED=$(npm outdated || true)
log_success
if [ -z "$OUTDATED" ]
then
  echo "All dependencies up to date. Exiting..."
  exit 0
fi

printf "$OUTDATED"
echo ""

echo -n "Found outdated dependencies. Updating..."
updtr -t "npm-install-peers && npm run $TEST_TASK" -r none
OUTDATED=$(npm outdated || true)
if [ -n "$OUTDATED" ]
then
  log_failure
  echo "Detected outdated dependencies after update..." >&2
  printf "$OUTDATED"
  echo ""
  exit 1
fi
log_success

step "Checking in dependencies to git..." "commit_updates"
step "Bumping version... " "bump_version"

if [ -n "$DEPLOY_TASK" ]
then
  step "Deploying new version to npm..." "deploy"
else
  echo "No deploy task. Skipping deploy..."
fi

cmd "Pushing changes to origin..." "push_updates"

