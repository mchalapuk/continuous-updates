#!/bin/bash

set -e

PKG_NAME=$1
REPO_URL=$2
PWD_VAR=$3
TEST_TASK=$4
DEPLOY_TASK=$5

echo ""
echo "--- ${PKG_NAME} ---"
echo ""

FOLDER="./${PKG_NAME}"
echo -n "Preparing workspace: ${FOLDER}"
rm -rf $FOLDER
echo " [success]"

echo -n "Adding ssh keys"
KEY_FILE="../keys/${PKG_NAME}"
eval "KEY_PASS=\$${PWD_VAR}"
eval $(ssh-agent) >/dev/null
ssh-add -D -q 
openssl rsa -in ${KEY_FILE} -passin pass:${KEY_PASS} -out ./key >/dev/null
chmod 0600 ./key
ssh-add -q ./key
echo " [success]"

echo -n "Cloning $REPO_URL"
git clone -q $REPO_URL $FOLDER 
cd $FOLDER
echo " [success]"

echo -n "Installing dependencies"
npm install
npm-install-peers
echo " [success]"

echo -n "Checking dependency versions"
OUTDATED=$(npm outdated || true)
echo " [success]"

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
  echo " [failure]"
  echo "Detected outdated dependencies after update..." >&2
  printf "$OUTDATED"
  echo ""
  exit 1
fi
echo " [success]"

echo -n "Checking in dependencies to git..."
git add .
git commit -q -m "~ updated depdendencies"
echo " [success]"

echo -n "Bumping version... "
npm version patch

if [ -n "$DEPLOY_TASK" ]
then
  echo -n "Deploying new version to npm..."
  npm run --silent $DEPLOY_TASK >/dev/null
  echo " [success]"
else
  echo "No deploy task. Skipping deploy..."
fi

echo -n "Pushing changes to origin..."
git push -q
git push -q --tags
echo " [success]"

