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
KEY_FILE="../keys/$PKG_NAME"
eval $(ssh-agent)
ssh-add -D
openssl rsa -in ${KEY_FILE} -passin pass:${${PWD_VAR}} -out ./key
chmod 0600 ./key
ssh-add ./key
echo " [success]"

git clone $REPO_URL
cd $FOLDER

npm install
npm outdated

updtr -t "npm run $TEST_TASK"

git add .
git commit -m "~ updated depdendencies"
git push

npm run $DEPLOY_TASK

