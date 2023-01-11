# Vault

## When Vault is unsealed

Vault seals up when the cluster is stopped. You can unseal from the workstation
with the following:

```
unset VAULT_TOKEN
unset VAULT_NAMESPACE
VAULT_UNSEAL_KEY=$(cat vault-keys.json | jq -r '.unseal_keys_b64[0]')
export VAULT_ADDR=https://<your vault fqdn>
vault operator unseal $VAULT_UNSEAL_KEY
```

