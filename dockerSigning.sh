#!/usr/bin/env bash

exec >>logfile_keygenerator

#Default Parameters for MOSIP. Can be changes accordingly
. ./all.properties

TRUST_KEYS_DIR=$(echo $trustkeydir)
DELEGATION_KEYS_DIR=$(echo $delegationkeydir)
DOMAIN_NAME=$(echo $domainname)
SUBJ=$(echo $subj)
NOTARY_SERVER=$(echo $notaryserver)
HUB_URL=$(echo $huburl)
REPO_ID=$(echo $repoid)
PASS_FILE=$(echo $passfile)
REPO_FILE=$(echo $repofile)

echo -e "\e[31m\e[1m\e[5m**NOTE: \e[25m\e[21m This script is to initiate docker signing for all the repositories linked to one organization. \
The commands running in this script will generate a set of keys for all the repositories for current organization. Request you please take a backup all the directory \
in case of any disaster. Keys will be required to restore or resign the images. IF lost then you will not be able to claim old signed images. \
The script itself will create one zip file for you every time after generating new keys. But it is recommended to create one by yourself and store it in disaster recovery.\e[0m  \n\n"

read -rsn1 -p $"Please make sure that you read the above message carefully. Press any key to continue or Ctrl+C to stop."$'\n'
read -rsn1 -p $"Are you sure you read the above note. Press any key to confirm or Ctrl+C to stop."$'\n'

echo -e "\n\e[31mIf you are not running script for the first time, check if you have already placed the existing trust key to the ${TRUST_KEYS_DIR} directory and delegation key to the ${DELEGATION_KEYS_DIR} directory. \
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

echo -e "\e[31m************Please select option based on your requirement.******************\e[0m \n \
Press 1 : If you want to generate new Delegation Key and Trust Keys. (For the first time signers).\n \
Press 2 : If you already have a key pair as Delegation Keys and \e[31mNo Trust Keys\e[0m. (First time user with own Delegation Key).  \n \
Press 3 : If you already have Delegation Key and existing Trust Keys (Running for the second time but machine changed due to some reason.) \n \
Press 4 : If you have entire setup already (Only new repository signing)"
read -p 'Enter Choice: ' choice
if [[ -z "${choice}" ]]; then
    echo "\e[31m Input cannot be blank please try again.\e[0m  \n"
    exit 0
else
    if ! [[ "${choice}" =~ ^[+-]?[0-9]+\.?[0-9]*$ ]]; then
        echo "\e[31m Input must be a numbers.\e[0m  \n"
        exit 1
    fi
fi


case ${choice} in
   1)
     echo -e "\n\n***************Starting new setup*****************\n"
     echo -e "Creating delegation directory*****************\n"
     mkdir -p ${DELEGATION_KEYS_DIR}
     openssl rand -writerand ~/.rnd
     echo -e "Creating delegation key passphrase and storing in file and setting env variable*****************\n"
     export NOTARY_DELEGATION_PASSPHRASE=$(head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128; echo)
     echo "notaryDelegation=${NOTARY_DELEGATION_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}
     echo -e "Creating delegation key pair*****************\n"
     # Generate the server private key
     openssl genrsa -out ${DELEGATION_KEYS_DIR}/${DOMAIN_NAME}-delegation-private.key -passout env:NOTARY_DELEGATION_PASSPHRASE 4096
     # Generate the CSR
     openssl req -new -batch -sha256 -subj ${SUBJ} -key ${DELEGATION_KEYS_DIR}/${DOMAIN_NAME}-delegation-private.key -out ${DELEGATION_KEYS_DIR}/${DOMAIN_NAME}-delegation.csr -passin env:NOTARY_DELEGATION_PASSPHRASE
     #Genrate Public Key
     openssl x509 -req -days 3650 -sha256 -in ${DELEGATION_KEYS_DIR}/${DOMAIN_NAME}-delegation.csr -signkey ${DELEGATION_KEYS_DIR}/${DOMAIN_NAME}-delegation-private.key -out ${DELEGATION_KEYS_DIR}/${DOMAIN_NAME}-delegation-public.crt

     echo -e "\nChecking trust Directory*****************\n"
     if [[ ! -d "${TRUST_KEYS_DIR}" ]]; then
       echo -e "${TRUST_KEYS_DIR} not found. Creating keys directory for the first time to store all the keys.  \n"
       read -rsn1 -p $"Are you sure you don't have any existing keys for the same repositories. Press any key to confirm or Ctrl+C to stop."$'\n';
       mkdir -p ${TRUST_KEYS_DIR}
     else
       echo -e "${TRUST_KEYS_DIR} found. \n"
     fi
       # Creating password and Setting environment Variable
     echo -e "\nCreating password for root key******************\n"
     export NOTARY_ROOT_PASSPHRASE=$(head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128; echo)
     echo -e "notaryRoot=${NOTARY_ROOT_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}

     echo -e "Creating password for targets key*******************\n"
     export NOTARY_TARGETS_PASSPHRASE=$(head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128; echo)
     echo -e "notaryTarget=${NOTARY_TARGETS_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}

     echo -e "Creating password for snapshot key******************\n"
     export NOTARY_SNAPSHOT_PASSPHRASE=$(head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128; echo)
     echo -e "notarySnapshot=${NOTARY_SNAPSHOT_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}
     ;;
   2)
     echo -e "\n\n***************Starting new setup with existing delegation keys*****************\n"
     echo "Please place the delegation keys in ${DELEGATION_KEYS_DIR}.\n"
     read -rsnl -p $"Press any key to continue after placing key in ${DELEGATION_KEYS_DIR} "$'\n'
     read -p $"Enter delegation key passphrase: " delegation_pass
     export NOTARY_DELEGATION_PASSPHRASE=${delegation_pass}
     echo "notaryDelegation=${NOTARY_DELEGATION_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}

     echo -e "\nChecking trust Directory*****************\n"
     if [[ ! -d "${TRUST_KEYS_DIR}" ]]; then
       echo -e "${TRUST_KEYS_DIR} not found. Creating keys directory for the first time to store all the keys.  \n"
       read -rsn1 -p $"Are you sure you don't have any existing keys for the same repositories. Press any key to confirm or Ctrl+C to stop."$'\n';
       mkdir -p ${TRUST_KEYS_DIR}
     else
       echo -e "${TRUST_KEYS_DIR} found. \n"
     fi
       # Creating password and Setting environment Variable
     echo -e "\nCreating password for root key******************\n"
     export NOTARY_ROOT_PASSPHRASE=$(head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128; echo)
     echo -e "notaryRoot=${NOTARY_ROOT_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}

     echo -e "Creating password for targets key*******************\n"
     export NOTARY_TARGETS_PASSPHRASE=$(head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128; echo)
     echo -e "notaryTarget=${NOTARY_TARGETS_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}

     echo -e "Creating password for snapshot key******************\n"
     export NOTARY_SNAPSHOT_PASSPHRASE=$(head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128; echo)
     echo -e "notarySnapshot=${NOTARY_SNAPSHOT_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}
     ;;
   3)
     echo -e "\n\n***************Starting setup with existing delegation keys and trust keys(machine change setup)*****************\n"
     echo "Please place the delegation keys in ${DELEGATION_KEYS_DIR}. \n"
     read -rsnl -p $"Press any key to continue after placing key in ${DELEGATION_KEYS_DIR} "$'\n'
     read -p $"Enter delegation key passphrase: " delegation_pass
     export NOTARY_DELEGATION_PASSPHRASE=${delegation_pass}
     echo "notaryDelegation=${NOTARY_DELEGATION_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}

     echo -e "** Please place the Trust keys in ${TRUST_KEYS_DIR} and Change password in ${DELEGATION_KEYS_DIR}/${PASS_FILE} file.  \n\n"
     read -rsn1 -p $"Please confirm if the trust keys placed in the above location. Press any key to continue or Ctrl+C to stop."$'\n'
     echo -e "\n"

     if [[ -d "${TRUST_KEYS_DIR}" ]]; then
       echo -e "Directory present, Storing new keys in the ${TRUST_KEYS_DIR}  \n\n"

       read -p $"Enter root key passphrase: " root_pass
       export NOTARY_ROOT_PASSPHRASE=${root_pass}
       echo -e "notaryRoot=${NOTARY_ROOT_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}

       read -p $"Enter targets key passphrase: " target_pass
       export NOTARY_TARGETS_PASSPHRASE=${target_pass}
       echo -e "notaryTarget=${NOTARY_TARGETS_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}

       read -p $"Enter snapshot key passphrase: " snapshot_pass
       export NOTARY_SNAPSHOT_PASSPHRASE=${snapshot_pass}
       echo -e "notarySnapshot=${NOTARY_SNAPSHOT_PASSPHRASE}" >> ${DELEGATION_KEYS_DIR}/${PASS_FILE}
     else
       echo -e "${TRUST_KEYS_DIR} not found please place the existing directory."
     fi
   ;;
   4)
     echo -e "\n\n***************Initializing more repositories with existing setup*****************\n"
     read -rsnl -p $"Please confirm if you have the password file in ${DELEGATION_KEYS_DIR}/${PASS_FILE}. Press any key to continue. "$'\n'
     . ${DELEGATION_KEYS_DIR}/${PASS_FILE}
     export NOTARY_DELEGATION_PASSPHRASE=$(echo $notaryDelegation)
     export NOTARY_ROOT_PASSPHRASE=$(echo $notaryRoot)
     export NOTARY_TARGETS_PASSPHRASE=$(echo $notaryTarget)
     export NOTARY_SNAPSHOT_PASSPHRASE=$(echo $notarySnapshot)
   ;;
esac

echo -e "\n\n***************Initializing repositories*****************\n"

while IFS= read -r line
do
  REPO_NAME=$line
  echo -e "\nInitializing ${REPO_NAME}******************\n"

  if notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} init ${HUB_URL}/${REPO_ID}/${REPO_NAME}; then
    echo "Initialization successful"
  else
    echo "Initialization failed"
    return 0
  fi
  if notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} publish ${HUB_URL}/${REPO_ID}/${REPO_NAME}; then
    echo "Changes published successfully"
  else
    echo "Publishing failed"
    return 0
  fi
  if notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} key rotate ${HUB_URL}/${REPO_ID}/${REPO_NAME} snapshot --server-managed; then
    echo "Key rotation successful"
  else
    echo "Key rotation failed"
    return 0
  fi
  if notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} publish ${HUB_URL}/${REPO_ID}/${REPO_NAME}; then
    echo "Changes published successfully"
  else
    echo "Publishing failed"
    return 0
  fi
  if notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} delegation add -p ${HUB_URL}/${REPO_ID}/${REPO_NAME} targets/releases --all-paths ${DELEGATION_KEYS_DIR}/${DOMAIN_NAME}-delegation-public.crt; then
    echo "Added delegation key for release successful"
  else
    echo "Adding delegation key release failed"
    return 0
  fi
  if notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} delegation add -p ${HUB_URL}/${REPO_ID}/${REPO_NAME} targets/mosip --all-paths ${DELEGATION_KEYS_DIR}/${DOMAIN_NAME}-delegation-public.crt; then
    echo "Added delegation key for user successful"
  else
    echo "Adding delegation key for user failed"
    return 0
  fi
  if notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} publish ${HUB_URL}/${REPO_ID}/${REPO_NAME}; then
    echo "Changes published successfully"
  else
    echo "Publishing failed"
    return 0
  fi
done < "$REPO_FILE"

notary -s ${NOTARY_SERVER} -d ${TRUST_KEYS_DIR} key import ${DELEGATION_KEYS_DIR}/${DOMAIN_NAME}-delegation-private.key  --role targets/mosip

echo -e "\n***************Zip all data*******************\n"
CURRENT_DATE=$(date +'%d-%m-%Y_%H:%M')
zip -r Trust_Keys_${CURRENT_DATE}.zip ${TRUST_KEYS_DIR}
zip -r Delegation_Keys_${CURRENT_DATE}.zip ${DELEGATION_KEYS_DIR}