#!/bin/bash

if [ $# -lt 2 ] || [[ ! ${2^^} =~ ^(MEMBERSHIP|DELEGATION|VOTER)$ ]]; then
cat >&2 <<EOF
Usage: $(basename $0) <KeyName> <KeyPurpose: membership | delegation | voter>

Examples:
$(basename $0) adam membership ... Generate a set of keys for membership certificates
$(basename $0) adam delegation ... Generate a set of keys for delegation certificates
$(basename $0) adam voter      ... Generate a set of keys for voting certificates
EOF
exit 1;
else
  mkdir "$(dirname $1)";
  keyName="$(dirname $1)/$(basename $1)";
  keyName=${keyName/#.\//};
  keyType=$2;
fi

if [ -f "${keyName}.json" ]; then echo -e "\e[35mWARNING - ${keyName}.json already exists. Delete it or use another name!\e[0m"; exit 2; fi
if [ -f "${keyName}.skey" ]; then echo -e "\e[35mWARNING - ${keyName}.skey already exists. Delete it or use another name!\e[0m"; exit 2; fi

if [[ "${keyType^^}" == "VOTER" ]]; then # It's a hot key!
  keyPath="cc-hot";
elif [[ "${keyType^^}" == "MEMBERSHIP" || "${keyType^^}" == "DELEGATION" ]]; then # It's a cold key!
  keyPath="cc-cold";
else
  echo -e "\e[33mUnknown Key Purpose '${keyType^^}'\e[00m";
  echo
  exit 2;
fi

./cardano-signer keygen --path $keyPath --json-extended > ${keyName}.json

chmod 400 ${keyName}.json

secret_key=$(jq -r ".secretKey[0:64]" ${keyName}.json)

jq -n --arg cborHex "5820${secret_key}" \
'{"type":"PaymentSigningKeyShelley_ed25519","description":"Payment Signing Key","cborHex":$cborHex}' > ${keyName}.skey

chmod 400 ${keyName}.skey

./cardano-cli key verification-key \
--signing-key-file ./${keyName}.skey \
--verification-key-file ${keyName}.vkey

echo ${secret_key} | \
(echo -n "302e020100300506032b657004220420" && cat) | \
xxd -r -p | \
base64 | \
(echo "-----BEGIN PRIVATE KEY-----" && cat) | \
(cat && echo "-----END PRIVATE KEY-----") > ${keyName}.priv

chmod 400 ${keyName}.priv

openssl pkey -in ${keyName}.priv -pubout -out ${keyName}.pub

openssl req -new -key ./${keyName}.priv -out ${keyName}.csr
