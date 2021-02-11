#!/usr/bin/env bash

#Default Parameters for MOSIP. Can be changes accordingly
TRUST_KEYS_DIR="./.docker-mosip/trust"
DELEGATION_KEYS_DIR="./delegation_keys"
DOMAIN_NAME="mosipdev"
NOTARY_SERVER="https://notary.docker.io"
HUB_URL="docker.io"
REPO_ID="mosipdev"
TAG_VERSION="1.1.4"
PASS_FILE=passphrases.properties
REPO_FILE=./repo-name.txt
HASH_REGEX="(?<=sha256:).*(?=size)"
SIZE_REGEX="(?<=size:).*"

echo -e "\e[31m\e[1m\e[5m**NOTE: \e[25m\e[21m This script is to start the signing process of the images. Please think and accept to continue.\e[0m  \n\n"

read -rsn1 -p $"Please make sure that you read the above message carefully. Press any key to continue or Ctrl+C to stop."$'\n'

echo -e "\n\e[31mCcheck if you have already placed the existing trust key to the ${TRUST_KEYS_DIR} directory and delegation key to the ${DELEGATION_KEYS_DIR} directory. \
Otherwise script will throw error and keys get corrupted.\e[0m \n"

read -rsn1 -p $"Press any key to agree or Ctrl+C to stop."$'\n'

echo -e "\n***************Checking notary client****************\n"
if [[ -f "/usr/bin/notary" ]]; then
  echo -e "Notary already present\n"
else
  echo -e "Downloading the notary client.\n"
  curl -L https://github.com/theupdateframework/notary/releases/download/v0.6.1/notary-Linux-amd64 -o notary
  chmod +x notary
  sudo mv notary /usr/bin/
  echo -e "\n"
fi

echo "********************Docker Login****************"
read -p $"Enter Docker UserName: " docker_user
read -s -p $"Enter Docker Password: " docker_password
export NOTARY_AUTH=$(echo -n "$docker_user:$docker_password" | base64)
echo -e "\n\n"

echo -e "\n\n***************Initializing more repositories with existing setup*****************\n"
read -rsnl -p $"Please confirm if you have the password file in ${DELEGATION_KEYS_DIR}/${PASS_FILE}. Press any key to continue. "$'\n'
. ${DELEGATION_KEYS_DIR}/${PASS_FILE}
export NOTARY_DELEGATION_PASSPHRASE=$(echo $notaryDelegation)
export NOTARY_ROOT_PASSPHRASE=$(echo $notaryRoot)
export NOTARY_TARGETS_PASSPHRASE=$(echo $notaryTarget)
export NOTARY_SNAPSHOT_PASSPHRASE=$(echo $notarySnapshot)


while IFS= read -r line
do
  REPO_NAME=$line
  docker pull ${HUB_URL}/${REPO_ID}/${REPO_NAME}:${TAG_VERSION}
  IMAGE_INFO=$(docker pull ${HUB_URL}/${REPO_ID}/${REPO_NAME}:${TAG_VERSION} | grep "digest: sha256")
  echo ${IMAGE_INFO}

  TAG_VERSION=$(echo -n ${IMAGE_INFO} | grep -o -P $HASH_REGEX)
  echo ${TAG_VERSION}

  IMAGE_SIZE=$(echo -n ${IMAGE_INFO} | grep -o -P $SIZE_REGEX)
  echo ${IMAGE_SIZE}

  notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} -D addhash -p ${HUB_URL}/${REPO_ID}/${REPO_NAME} ${TAG_VERSION} ${IMAGE_SIZE} --sha256 ${IMAGE_HASH} -r targets/mosip

done < "$REPO_FILE"

#notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} -D addhash -p ${HUB_URL}/${REPO_ID}/${REPO_NAME} ${TAG_VERSION} ${IMAGE_SIZE} --sha256 ${IMAGE_HASH} -r targets/mosip