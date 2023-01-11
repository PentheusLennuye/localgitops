# Dex

The well-known configuration endpoint that can be used in Jenkins automatic
configuration is (https://dex.gitops.local/.well-known/openid-config),
provided that the hostname and domain are the default "dex" and "gitops.local",
respectively.

At the time of writing, SSL verification is troublesome as the ca certs imports
are being ignored by Jenkins and Harbor. SSL verification might best be turned
off.

First off, configure OpenLDAP. Then come back here.

## Jenkins

In Jenkins: Manage Jenkins > Configure Global Security

- Security Realm: Login with Openid Connect
- Advanced:
  - Disable ssl verification: _checked_
- Client id: As per _terraform/services/helm_values/dex_helm_values.yaml_
- Client secret: As per _terraform/services/terraform.tfvars_
- Configuration mode: _Automatic configuration_
  - Well-known configuration endpoint:
    < https://dex.gitops.local/.well-known/openid-configuration >
- User name field name: __name__
- Full name field name: __name__
- Email field name: __mail__
- Groups field name: __groups__

CONFIGURE "Escape Hatch"! This will be used at the URL
<https://jenkins.gitops.local/login> if the OIDC fails.

Ensure to go into _Roles > Assign Roles_ and set the _jenkins_users_ and
_jenkins_admin_ groups appropriately.

## Harbor

Got to _Configuration > Authentication_

- Auth Mode: _OIDC_
- OIDC Provider Name: __dex.gitops.local__ (or equivalent)
- OIDC Endpoint: __https://dex.gitops.local__
- OIDC Client ID: As per _terraform/services/helm_values/dex_helm_values.yaml_
- OIDC Client Secret: As per _terraform/services/terraform.tfvars_
- OIDC Group Filter: As per _docs/openldap.md_
- OIDC Admin Group: As per _docs/openldap.md_
- OIDC Scope: __openid,offline_access,profile,email__
- Verify Certificate: __unchecked__.

## Vault

The OIDC Policy is already set in Vault.

Assuming the OIDC URL is <https://dex.gitops.local>, to enable OIDC:

1. Preliminary
  ```
  export VAULT_ADDR=https://<your vault fqdn>
  ```
2. If Vault is sealed:
  ```
  VAULT_UNSEAL_KEY=$(cat vault-keys.json | jq -r '.unseal_keys_b64[0]')
  vault operator unseal $VAULT_UNSEAL_KEY
  ```
3. Enable and configure OIDC auth method:
  ```
  VAULT_ROOT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')
  CA_PEM=$(cat cacerts/localgitops-ca.pem)
  CLIENT_SECRET=$(grep oidc_client_secret terraform/services/terraform.tfvars |\
    awk '{print $3}' | sed s'/"//g')
  vault login token=$VAULT_ROOT_TOKEN
  vault auth enable oidc
  vault write auth/oidc/config \
         oidc_discovery_url="https://dex.gitops.local/" \
         default_role="reader" \
	 jwks_ca_pem="${CA_PEM}" \
         oidc_client_id="vault-gitopslocal" \
         oidc_client_secret="${CLIENT_SECRET}"
  ```
  Note that the discovery URL does *not* use the .well-known... path.
  The "vault-gitopslocal" as oidc_client_id is from the original helm values.
