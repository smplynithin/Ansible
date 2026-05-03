# ============================================================
# AWX / Ansible Tower — CI/CD Integration Guide
# TOPIC COVERED: AWX/Tower, CI/CD integration
# ============================================================

## What is AWX / Ansible Tower?
- AWX = open-source web UI for Ansible (free)
- Ansible Tower = Red Hat's enterprise version (paid)
- Both give you: Web UI, RBAC, Scheduling, Audit logs, REST API

## Key Concepts in AWX/Tower

### 1. Organizations
  Groups of users, teams, inventories, projects

### 2. Credentials
  Store SSH keys, Vault passwords, Cloud credentials
  (never in plaintext — encrypted by Tower)

### 3. Inventory
  Import your inventories (static or dynamic)
  Tower can sync from AWS EC2 automatically

### 4. Projects
  Link your Git repo (GitHub/GitLab/Bitbucket)
  Tower pulls latest code before each run

### 5. Job Templates
  Define: playbook + inventory + credentials + extra_vars
  One-click run or API-triggered

### 6. Workflows
  Chain multiple Job Templates:
    common → nginx → tomcat → postgres → smoke_test

## CI/CD Integration (GitHub Actions → AWX)

```yaml
# .github/workflows/deploy.yml
name: Deploy via Ansible Tower

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger AWX Job Template via API
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.AWX_TOKEN }}" \
            -H "Content-Type: application/json" \
            -d '{"extra_vars": {"app_version": "${{ github.sha }}"}}' \
            https://your-awx-server/api/v2/job_templates/42/launch/
```

## AWX REST API Examples

```bash
# List all job templates
curl -H "Authorization: Bearer TOKEN" \
  https://awx.example.com/api/v2/job_templates/

# Launch a job
curl -X POST -H "Authorization: Bearer TOKEN" \
  -d '{"limit": "webservers"}' \
  https://awx.example.com/api/v2/job_templates/5/launch/

# Check job status
curl -H "Authorization: Bearer TOKEN" \
  https://awx.example.com/api/v2/jobs/1234/
```

## Install AWX locally (Docker)

```bash
git clone https://github.com/ansible/awx
cd awx
pip install ansible docker
ansible-playbook -i inventory tools/docker-compose-build.yml
ansible-playbook -i inventory install.yml
# Access at: http://localhost (admin/password)
```
