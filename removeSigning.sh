#!/usr/bin/env bash

exec >>logfile_removesigner

. ./all.properties

TRUST_KEYS_DIR=$(echo $trustkeydir)
DELEGATION_KEYS_DIR=$(echo $delegationkeydir)
DOMAIN_NAME=$(echo $domainname)
SUBJ=$(echo $subj)
NOTARY_SERVER=$(echo $notaryserver)
HUB_URL=$(echo $huburl)
REPO_ID=$(echo $repoid)
TAG_VERSION=$(echo $tagversion)
PASS_FILE=$(echo $passfile)
REPO_FILE=$(echo $repofile)

while IFS= read -r line; do
  REPO_NAME=$line
  if notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} remove -p ${HUB_URL}/${REPO_ID}/${REPO_NAME} -r targets/test; then
    echo "sign removed successfully"
  else
    echo "sign removal failed"
    return 0
  fi
  if notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} delete ${HUB_URL}/${REPO_ID}/${REPO_NAME} --remote; then
    echo "signer keys removed successfully"
  else
    echo "signer keys removal failed"
    return 0
  fi
  if notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} publish ${HUB_URL}/${REPO_ID}/${REPO_NAME}; then
    echo "Changes published successfully"
  else
    echo "Publishing failed"
    return 0
  fi
done < "$REPO_FILE"
