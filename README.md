# Generate Keys for Constitutional Committee

These steps should be performed on a cold, air-gapped machine that has never and
will never be connected to the internet to ensure that your keys are as secure
and protected as possible. Instructions for how to setup and maintain a "cold"
environment is outside the scope of this tutorial.

## Required Software

* [Cardano Signer](https://github.com/gitmachtl/cardano-signer/releases) by
  Martin Lang [ATADA Stake Pool] (v1.16.1 or greater)
* [Cardano CLI](https://github.com/IntersectMBO/cardano-cli/releases) (v8.25.0
  or greater)
* OpenSSL
* JQ

## Certificate Signing Request (CSR) Fields and Values

When generating a CSR via OpenSSL you will be interacting with a "wizard" that
will prompt you for answers on a step-by-step basis in order to build out your
certificate.

**Country Code**: This should be the 2-Letter ISO-3166 code for your country of
residence. Example: `US` for United States

**State or Province Name**: This should be the full name of your state or
province of residence. Example: `New York`

**Locality Name**: This should be the full name of your city of residence. You
may leave this blank if you are concerned with privacy. Example: `Santa Barbara`

**Organization Name**: This should be the name of the organization that you are
representing with the requested certificate. Example: `Cardano Atlantic Council`

**Organizational Unit**: This should be the name of the branch or division of
the organization that is being represented by the requested certificate.
Example: `Cardano Constitutional Committee`

**Common Name**: Your name. Example: `Adam Dean`

**Email Address**: Your email address. Example: `adam.voter@atlanticcouncil.cc`

### Extra Attributes

The extra attributes section of the CSR wizard can be left blank (just press
enter).

**Challenge Password**: This can be used by your organization to provide a
specific pre-shared key (PSK) or phrase to validate (universal or per CSR) to
provide an additional layer of protection when issuing certificates.

**Company Name**: Rarely used because this is generally already covered under
the Organization Name field of the CSR.

> **MOST IMPORTANT NOTE EVER**: DO NOT UNDER ANY CIRCUMSTANCES SHARE YOUR
> MNEMONIC PHRASE, PRIVATE KEYS (`priv.pem, .skey, .eskey, -details.json`) FILES
> WITH ANYONE UNDER ANY CIRCUMSTANCES. IF FOR ANY REASON YOU BELIEVE THAT ONE OR
> MORE OF THESE FILES HAVE BECOME COMPROMISED; NOTIFY YOUR ORGANIZATION'S HEAD
> OF SECURITY IMMEDIATELY. STORE YOUR MNEMONIC PHRASE FOUND IN YOUR
> `-details.json` ON A DURABLE BACKUP IN A SAFE LOCATION LIKE YOU WOULD ANY
> OTHER SEED PHRASE.

## Generate Your Membership Keys and Certificate Request

1. Create a name and keytype variable where `[name]` in the examples below is
   replaced by your name all lowercase and with no spaces. Example: `name=adam`\

```shell
name=[name]
keytype=membership
```

2. Generate a mnemonic and extended keys using `Cardano Signer`

```shell
./cardano-signer keygen \
--path cc-cold \
--json-extended \
--out-skey $name-$keytype.eskey \
--out-vkey $name-$keytype.evkey > $name-$keytype-details.json
```

3. Protect your newly created file from accidental deletion or modification.
   _Note: You will need to use `sudo` to make any changes or delete this file in
   the future._

```shell
chmod 400 $name-$keytype-details.json
```

4. Extract the private portion of the extended signing key and create a regular
   Caradno payment signing key.

```shell
payment_signing_key="5820$(jq ".cborHex" $name-$keytype.xskey -r | cut -c 5-68)"
```

```shell
jq -n --arg cborHex $payment_signing_key \
'{"type":"PaymentSigningKeyShelley_ed25519","description":"Payment Signing Key","cborHex":$cborHex}' > $name-$keytype.skey
```

5. Create the verification (public) key

```shell
cardano-cli key verification-key \
--signing-key-file $name-$keytype.skey \
--verification-key-file $name-$keytype.vkey
```

6. Convert our private payment signing key into an OpenSSL compatible private
   PEM file

```shell
cat $name-$keytype.skey | \
jq -r ".cborHex" | \
cut -c 5- | \
(echo -n "302e020100300506032b657004220420" && cat) | \
xxd -r -p | \
base64 | \
(echo "-----BEGIN PRIVATE KEY-----" && cat) | \
(cat && echo "-----END PRIVATE KEY-----") > $name-$keytype-priv.pem
```

7. Create the public PEM file

```shell
openssl pkey -in $name-$keytype-priv.pem -pubout -out $name-$keytype-pub.pem
```

8. Create your Certificate Signing Request (make sure to follow the rules up
   above for [CSR Fields](#certificate-signing-request-csr-fields-and-values))

```shell
openssl req -new -key $name-$keytype-priv.pem -out $name-$keytype.csr
```

9. Check that the generated CSR matches the fields and values you expect

```shell 
openssl req -in $name-$keytype.csr -text -noout
```

**Example Output**

> Note that the `ED25519 Public-Key` shown in the CSR should match the CBOR Hex
> value found in the `Payment Verification Key` file except for the `5820` CBOR
> tag prefix. If the fields DO NOT match or any of your information displayed in
> the `Subject` area of the Certificate Request is incorrect, please repeat the
> steps until it is corrected.

```shell
~$ openssl req -in $name-$keytype.csr -text -noout
Certificate Request:
    Data:
        Version: 1 (0x0)
        Subject: C = US, ST = Arizona, L = Kingman, O = Cardano Atlantic Council, OU = Cardano Constitutional Committee, CN = Adam Dean, emailAddress = adam.voter@atlanticcouncil.cc
        Subject Public Key Info:
            Public Key Algorithm: ED25519
                ED25519 Public-Key:
                pub:
                    ff:7d:57:bd:f0:b6:55:d4:5d:f1:09:fa:36:ba:26:
                    b9:fb:58:44:12:75:41:a6:68:37:b8:cc:7c:fa:eb:
                    cf:d7
        Attributes:
            a0:00
    Signature Algorithm: ED25519
         dd:57:fa:5f:b5:40:95:df:1e:8e:50:4b:bd:b3:47:59:22:5c:
         26:1f:0f:3d:e6:52:9b:06:72:a1:c1:b7:13:f2:ca:ef:18:22:
         c6:5e:94:03:ee:be:ae:62:17:75:61:14:3d:08:76:8b:23:68:
         fb:64:9c:54:c5:d0:83:d7:ec:0b
~$ jq ".cborHex" $name-$keytype.vkey
"5820ff7d57bdf0b655d45df109fa36ba26b9fb5844127541a66837b8cc7cfaebcfd7"
```

10. After your CSR has been generated you can send the `.csr` file to your
    organization's **Head of Security** to issue you an organization-signed
    certificate (`.cert`) file.


11. Once you have your `.cert` file you can pass this to your organization's *
    *Orchestrator** in order to deploy the scripts and create the transactions
    that you will sign and witness using these credentials.

## Generate Your Delegation Keys and Certificate Request

1. Create a name and keytype variable where `[name]` in the examples below is
   replaced by your name all lowercase and with no spaces. Example: `name=adam`\

```shell
name=[name]
keytype=delegation
```

2. Generate a mnemonic and extended keys using `Cardano Signer`

```shell
./cardano-signer keygen \
--path cc-cold \
--json-extended \
--out-skey $name-$keytype.eskey \
--out-vkey $name-$keytype.evkey > $name-$keytype-details.json
```

3. Protect your newly created file from accidental deletion or modification.
   _Note: You will need to use `sudo` to make any changes or delete this file in
   the future._

```shell
chmod 400 $name-$keytype-details.json
```

4. Extract the private portion of the extended signing key and create a regular
   Caradno payment signing key.

```shell
payment_signing_key="5820$(jq ".cborHex" $name-$keytype.xskey -r | cut -c 5-68)"
```

```shell
jq -n --arg cborHex $payment_signing_key \
'{"type":"PaymentSigningKeyShelley_ed25519","description":"Payment Signing Key","cborHex":$cborHex}' > $name-$keytype.skey
```

5. Create the verification (public) key

```shell
cardano-cli key verification-key \
--signing-key-file $name-$keytype.skey \
--verification-key-file $name-$keytype.vkey
```

6. Convert our private payment signing key into an OpenSSL compatible private
   PEM file

```shell
cat $name-$keytype.skey | \
jq -r ".cborHex" | \
cut -c 5- | \
(echo -n "302e020100300506032b657004220420" && cat) | \
xxd -r -p | \
base64 | \
(echo "-----BEGIN PRIVATE KEY-----" && cat) | \
(cat && echo "-----END PRIVATE KEY-----") > $name-$keytype-priv.pem
```

7. Create the public PEM file

```shell
openssl pkey -in $name-$keytype-priv.pem -pubout -out $name-$keytype-pub.pem
```

8. Create your Certificate Signing Request (make sure to follow the rules up
   above for [CSR Fields](#certificate-signing-request-csr-fields-and-values))

```shell
openssl req -new -key $name-$keytype-priv.pem -out $name-$keytype.csr
```

9. Check that the generated CSR matches the fields and values you expect

```shell 
openssl req -in $name-$keytype.csr -text -noout
```

**Example Output**

> Note that the `ED25519 Public-Key` shown in the CSR should match the CBOR Hex
> value found in the `Payment Verification Key` file except for the `5820` CBOR
> tag prefix. If the fields DO NOT match or any of your information displayed in
> the `Subject` area of the Certificate Request is incorrect, please repeat the
> steps until it is corrected.

```shell
~$ openssl req -in $name-$keytype.csr -text -noout
Certificate Request:
    Data:
        Version: 1 (0x0)
        Subject: C = US, ST = Arizona, L = Kingman, O = Cardano Atlantic Council, OU = Cardano Constitutional Committee, CN = Adam Dean, emailAddress = adam.voter@atlanticcouncil.cc
        Subject Public Key Info:
            Public Key Algorithm: ED25519
                ED25519 Public-Key:
                pub:
                    ff:7d:57:bd:f0:b6:55:d4:5d:f1:09:fa:36:ba:26:
                    b9:fb:58:44:12:75:41:a6:68:37:b8:cc:7c:fa:eb:
                    cf:d7
        Attributes:
            a0:00
    Signature Algorithm: ED25519
         dd:57:fa:5f:b5:40:95:df:1e:8e:50:4b:bd:b3:47:59:22:5c:
         26:1f:0f:3d:e6:52:9b:06:72:a1:c1:b7:13:f2:ca:ef:18:22:
         c6:5e:94:03:ee:be:ae:62:17:75:61:14:3d:08:76:8b:23:68:
         fb:64:9c:54:c5:d0:83:d7:ec:0b
~$ jq ".cborHex" $name-$keytype.vkey
"5820ff7d57bdf0b655d45df109fa36ba26b9fb5844127541a66837b8cc7cfaebcfd7"
```

10. After your CSR has been generated you can send the `.csr` file to your
    organization's **Head of Security** to issue you an organization-signed
    certificate (`.cert`) file.


11. Once you have your `.cert` file you can pass this to your organization's *
    *Orchestrator** in order to deploy the scripts and create the transactions
    that you will sign and witness using these credentials.

