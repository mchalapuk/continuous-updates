#!/bin/bash

set -e

PKG_NAME=$1
REPO_URL=$2
PWD_VAR=$3
TEST_TASK=$4
DEPLOY_TASK=$5

FOLDER="./${PKG_NAME}"
KEY_FILE="../keys/${PKG_NAME}"
eval "KEY_PASS=\$${PWD_VAR}"

red() {
  echo -u "\e[91m$@\e[0m"
}
green() {
  echo -u "\e[92m$@\e[0m"
}
bold() {
  echo -u "\e[1m$@\e[0m"
}

log_uccess() {
  green " $(bold ✔)"
}
log_failure() {
  red " $(bold ✗)"
}

cmd() {
  TITLE=$1
  CMD=$2

  STDOUT=$(mktemp /tmp/cha80s_cu_XXXXX)

  echo -n $(bold "$TITLE")
  if $CMD 1>$STDOUT 2> >(red)>&1
  then
    log_success
    RETVAL=0
  else
    log_failure
    echo $STDOUT
    RETVAL=1
  fi

  rm $STDOUT
  return $RETVAL
}

prepare_workspace() {
  rm -rf $FOLDER
}

add_ssh_keys() {
  eval $(ssh-agent)
  ssh-add -D
  openssl rsa -in ${KEY_FILE} -passin pass:${KEY_PASS} -out ./key
  chmod 0600 ./key
  ssh-add ./key
}

clone() {
  git clone -q $REPO_URL $FOLDER 
  cd $FOLDER
}

install_dependencies() {
  npm install
  npm-install-peers
}

commit_updates() {
  git add .
  git commit -m "~ updated depdendencies"
}

bump_version() {
  npm version patch
}

deploy() {
  npm run $DEPLOY_TASK
}

push_updates() {
  git push
  git push --tags
}

echo ""
echo "--- ${PKG_NAME} ---"
echo ""

cmd "Preparing workspace: ${FOLDER}" "prepare_workspace"
cmd "Adding ssh keys" "add_ssh_keys"
cmd "Cloning $REPO_URL" "clone"
cmd "Installing dependencies" "install_dependencies"

bold "Checking dependency versions"
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

cmd "Checking in dependencies to git..." "commit_updates"
cmd "Bumping version... " "bump_version"

if [ -n "$DEPLOY_TASK" ]
then
  cmd "Deploying new version to npm..." "deploy"
else
  echo "No deploy task. Skipping deploy..."
fi

cmd "Pushing changes to origin..." "push_updates"

