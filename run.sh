#!/bin/bash

set -e

PKG_NAME=$1
REPO_URL=$2
PWD_VAR=$3
TEST_TASK=$4
DEPLOY_TASK=$5

echo "--- ${PKG_NAME} ---"

FOLDER="./${PKG_NAME}"
echo -n "Removing folder: ${FOLDER}"
rm -rf $FOLDER
echo " [success]"

echo -n "Adding ssh keys"
KEY_FILE="../keys/${PKG_NAME}"
eval "KEY_PASS=\$${PWD_VAR}"
eval $(ssh-agent)
ssh-add -D
openssl rsa -in ${KEY_FILE} -passin pass:${KEY_PASS} -out ./key
chmod 0600 ./key
ssh-add ./key
echo " [success]"

git clone $REPO_URL
cd $FOLDER

npm install
npm outdated || true

echo -n "Updating dependencies..."
updtr -t "npm run $TEST_TASK" -r none
test -z $(npm outdated) || exit 1
echo " [success]"

echo -n "Checking in dependencies to git..."
git add .
git commit -m "~ updated depdendencies"
echo " [success]"

echo -n "Applying new version... "
npm version patch

echo -n "Deploying new version to npm..."
npm run $DEPLOY_TASK >/dev/null
echo " [success]"

echo -n "Pushing changes to git..."
git push
echo " [success]"

