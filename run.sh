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
eval $(ssh-agent) > /dev/null
ssh-add -D >/dev/null 2>&1
openssl rsa -in ${KEY_FILE} -passin pass:${KEY_PASS} -out ./key >/dev/null 2>&1
chmod 0600 ./key
ssh-add ./key >/dev/null 2>&1
echo " [success]"

echo -n "Cloning $REPO_URL"
git clone $REPO_URL >/dev/null 2>&1
cd $FOLDER
echo " [success]"

echo -n "Installing dependencies"
npm install >/dev/null 2>&1
echo " [success]"

echo -n "Checking dependency versions"
OUTDATED=$(npm outdated || true)
echo " [success]"

if [ -z "$OUTDATED" ]
then
  echo "All dependencies up to date. Exiting..."
  exit 0
fi

echo -e ${OUTDATED//\n/\\n}

echo -n "Found outdated dependencies. Updating..."
updtr -t "npm run $TEST_TASK" -r none
if [ -n "$(npm outdated || true)" ]
then
  echo " [failure]"
  echo "Detected outdated dependencies after update..." >&2
  npm outdated || true
  exit 1
fi
echo " [success]"

echo -n "Checking in dependencies to git..."
git config --global "user.name" "Maciej Chałapuk"
git config --global "user.email" "maciej@chalapuk.pl"
git add .
git commit -m "~ updated depdendencies" >/dev/null 2>&1
echo " [success]"

echo -n "Bumping version... "
npm version patch

echo -n "Deploying new version to npm..."
npm run $DEPLOY_TASK >/dev/null 2>&1
echo " [success]"

echo -n "Pushing changes to origin..."
git push >/dev/null 2>&1
git push --tags >/dev/null 2>&1
echo " [success]"

