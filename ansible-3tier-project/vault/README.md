# Vault Directory

This directory contains encrypted secrets.

## Files
- `secrets.yml` — Main secrets file (MUST be encrypted with ansible-vault)

## Workflow

```bash
# First time: create and encrypt
ansible-vault create vault/secrets.yml

# Edit existing encrypted file
ansible-vault edit vault/secrets.yml

# Encrypt a plain file (after editing)
ansible-vault encrypt vault/secrets.yml

# View without decrypting to disk
ansible-vault view vault/secrets.yml

# Decrypt to plain text (NEVER commit decrypted!)
ansible-vault decrypt vault/secrets.yml
```

## In .gitignore always add:
```
.vault_pass
*.vault_pass
```
