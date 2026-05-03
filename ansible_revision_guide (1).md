# Ansible Revision Guide — Scratch to 3 Years Production

> Complete revision reference | Cross-checked with iam-veeramalla/ansible-zero-to-hero | Core → Advanced → Production

---

## 1. Foundations

### 01. What is Ansible? `[core]`
Agentless IT automation tool using SSH/WinRM to configure systems declaratively via YAML.

```yaml
# No agents needed — just SSH access
# Push-based model from control node to managed nodes
```

---

### 02. Ansible vs Chef / Puppet / Terraform `[core]`
Ansible is agentless, push-based, YAML-driven; Terraform is infra provisioning; Chef/Puppet need agents.

```
# Ansible: config management + simple orchestration
# Terraform: infra provisioning (VMs, VPCs)
# Use both together in real projects
```

---

### 02b. Ansible vs Shell scripting vs Python `[core]`
Shell scripts are imperative and fragile at scale; Python needs boilerplate; Ansible is declarative, readable, and idempotent — best for config management.

```bash
# Shell (not idempotent):
if ! rpm -q nginx; then yum install nginx; fi

# Ansible (idempotent):
- package:
    name: nginx
    state: present   # Ansible handles the check internally
```

---

### 02c. VS Code + Ansible plugin setup `[core]`
Install Red Hat Ansible extension in VS Code for syntax highlighting, linting, and auto-complete. Use ansible-lint to catch issues before running.

```bash
# VS Code extensions:
# 1. Ansible (Red Hat) — syntax, lint, autocomplete
# 2. YAML (Red Hat)    — YAML validation

# CLI linting:
pip install ansible-lint
ansible-lint playbook.yml
```

---

### 02d. YAML basics for Ansible `[core]`
Ansible playbooks are pure YAML — master indentation, lists, dicts, multiline strings, and booleans before writing playbooks.

```yaml
# Dict (key-value)
nginx_port: 80
become: true        # boolean — use true/false not yes/no

# List
packages:
  - nginx
  - git

# List of dicts — how tasks are written
tasks:
  - name: Install nginx
    apt:
      name: nginx
      state: present

# Multiline string
motd: |
  Welcome to prod server
  Unauthorized access is prohibited
```

---

### 03. Control node vs Managed nodes `[core]`
Control node runs Ansible; managed nodes are the target servers — no Ansible install needed on them.

```
Control node: your laptop or CI server
Managed nodes: web servers, DBs, etc.
```

---

### 04. Installation `[core]`
Install on Linux/Mac via pip or package manager; not natively supported on Windows as control node.

```bash
pip install ansible          # via pip
apt install ansible          # Ubuntu
brew install ansible         # Mac
```

---

### 05. Ansible versions & collections `[core]`
Modern Ansible uses Collections (namespaced modules); ansible-core is the base package.

```bash
ansible --version
ansible-galaxy collection install amazon.aws
```

---

## 2. Passwordless Authentication

### 06. SSH key pair generation `[core]`
Generate public/private key pair; distribute public key to managed nodes for password-free SSH.

```bash
ssh-keygen -t rsa -b 4096 -C 'ansible'
# Creates ~/.ssh/id_rsa and ~/.ssh/id_rsa.pub
```

---

### 07. ssh-copy-id `[core]`
Copies your public key to remote server's authorized_keys automatically.

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub user@192.168.1.10
# Or manually: cat id_rsa.pub >> ~/.ssh/authorized_keys
```

---

### 08. Ansible vault for passwords `[core]`
Encrypt secrets like passwords/keys so they're safe in Git — never store plaintext.

```bash
ansible-vault encrypt_string 'mysecret' --name 'db_pass'
ansible-playbook site.yml --ask-vault-pass
```

---

### 09. SSH agent forwarding & bastion hosts `[production]`
In prod, managed nodes are in private subnets; use bastion/jump host with SSH agent forwarding.

```ini
# ansible.cfg
[ssh_connection]
ssh_args = -o ProxyJump=ubuntu@bastion-ip
control_path = /tmp/ansible-ssh-%h-%p-%r
```

---

### 10. IAM-based auth (AWS SSM) `[production]`
In AWS prod environments, use SSM Session Manager instead of SSH — no ports open needed.

```yaml
# Use community.aws.aws_ssm connection plugin
- hosts: all
  connection: community.aws.aws_ssm
```

---

## 3. Inventory

### 11. Static inventory (INI & YAML) `[core]`
Simple file listing hosts and groups; good for small/fixed infrastructure.

```ini
# inventory.ini
[webservers]
192.168.1.10
192.168.1.11

[dbservers]
db1.example.com ansible_user=ubuntu
```

---

### 12. Host variables & group variables `[core]`
Set variables per host or per group using host_vars/ and group_vars/ directories.

```yaml
# group_vars/webservers.yml
nginx_port: 80
app_env: production

# host_vars/web1.yml
ansible_user: ec2-user
```

---

### 13. Children groups & nested groups `[core]`
Groups can contain other groups using :children — useful for environment grouping.

```ini
[prod:children]
webservers
dbservers

[staging:children]
staging_web
staging_db
```

---

### 14. Dynamic inventory `[advanced]`
Generate inventory from AWS/GCP/Azure at runtime using plugins instead of static files.

```yaml
# aws_ec2.yml
plugin: amazon.aws.aws_ec2
regions: [ap-south-1]
filters:
  tag:Env: production
keyed_groups:
  - key: tags.Role
```

---

### 15. Dynamic inventory in prod (EC2 tags) `[production]`
Tag EC2 instances with Role/Env; ansible auto-discovers them — no manual IP management.

```bash
# Run:
ansible-inventory -i aws_ec2.yml --list

# Use in playbook:
- hosts: tag_Role_webserver
```

---

## 4. Ad-hoc Commands

### 16. ansible command syntax `[core]`
Run one-off tasks without writing a playbook — great for quick checks and emergency fixes.

```bash
ansible all -i inventory.ini -m ping
ansible webservers -m shell -a 'uptime'
ansible all -m gather_facts --tree /tmp/facts
```

---

### 17. Common modules in ad-hoc `[core]`
ping, shell, command, copy, file, service, apt, yum — the workhorses of ad-hoc ops.

```bash
ansible webservers -m apt -a 'name=nginx state=present' -b
ansible all -m service -a 'name=nginx state=restarted' -b
```

---

### 18. Ad-hoc in prod emergencies `[production]`
Quick restart, log check, or patch across 50+ servers without touching playbooks.

```bash
# Restart nginx on all prod webservers immediately
ansible tag_Role_webserver -i aws_ec2.yml \
  -m service -a 'name=nginx state=restarted' -b
```

---

## 5. Playbooks

### 19. Playbook structure & hierarchy `[core]`
YAML files with plays; each play targets hosts and runs ordered tasks. Hierarchy: Playbook → Play → Tasks → Modules → Collections.

```yaml
---
# PLAYBOOK (file)
- name: Install nginx          # PLAY
  hosts: webservers
  become: true
  tasks:                       # TASKS
    - name: Install nginx      # TASK using a MODULE
      apt:                     # MODULE (from ansible.builtin collection)
        name: nginx
        state: present
```

---

### 19b. Collections — what they are `[core]`
Collections are namespaced bundles of modules, roles, plugins — e.g., `amazon.aws`, `community.docker`. The new standard way to distribute Ansible content.

```bash
# Install a collection
ansible-galaxy collection install amazon.aws
ansible-galaxy collection install community.docker

# Use in playbook (FQCN — Fully Qualified Collection Name)
- amazon.aws.ec2_instance:
    name: my-server

# Or declare at play level:
- hosts: all
  collections:
    - amazon.aws
    - community.docker
```

---

### 20. Tasks, handlers, notify `[core]`
Handlers run only when notified — e.g., restart nginx only if config changed.

```yaml
tasks:
  - name: Copy nginx config
    template: src=nginx.j2 dest=/etc/nginx/nginx.conf
    notify: Restart nginx

handlers:
  - name: Restart nginx
    service: name=nginx state=restarted
```

---

### 21. Variables & precedence `[core]`
Ansible has 22 variable precedence levels — extra vars (-e) always win; know the key levels.

```yaml
- name: deploy
  vars:
    app_version: 1.2.3
  tasks:
    - debug: msg='Deploying {{ app_version }}'

# Override at runtime:
ansible-playbook site.yml -e 'app_version=1.3.0'
```

---

### 22. Conditionals (when) `[core]`
Run tasks only when condition is true — OS type, variable value, registered output.

```yaml
- name: Install on Ubuntu only
  apt: name=nginx state=present
  when: ansible_os_family == 'Debian'

- name: Run if service is stopped
  command: start_app.sh
  when: service_status.rc != 0
```

---

### 23. Loops (loop / with_items) `[core]`
Repeat a task over a list of items — install multiple packages, create multiple users.

```yaml
- name: Install packages
  apt:
    name: '{{ item }}'
    state: present
  loop:
    - nginx
    - git
    - curl
```

---

### 24. register & debug `[core]`
Capture task output into a variable; debug it or use it in later tasks.

```yaml
- name: Check if app is running
  shell: systemctl is-active myapp
  register: app_status
  ignore_errors: true

- debug: msg='Status is {{ app_status.stdout }}'
```

---

### 25. tags `[advanced]`
Label tasks; run only tagged tasks for faster partial runs in big playbooks.

```yaml
- name: Install nginx
  apt: name=nginx state=present
  tags: [install, nginx]

# Run:
ansible-playbook site.yml --tags install
```

---

### 26. import_tasks vs include_tasks `[advanced]`
import is static (compile-time); include is dynamic (runtime) — affects tags and conditionals.

```yaml
# Static — evaluated at parse time:
- import_tasks: tasks/nginx.yml

# Dynamic — evaluated at runtime:
- include_tasks: 'tasks/{{ env }}.yml'
```

---

## 6. Modules (Key Ones)

### 27. file, copy, template `[core]`
Manage files: set permissions, copy local files, render Jinja2 templates to remote.

```yaml
- file: path=/var/app state=directory mode=0755
- copy: src=app.conf dest=/etc/app/ owner=root
- template: src=nginx.j2 dest=/etc/nginx/nginx.conf
```

---

### 28. apt / yum / package `[core]`
Install/remove packages; use 'package' for OS-agnostic playbooks.

```yaml
- package:
    name: nginx
    state: present   # absent to remove
  become: true
```

---

### 29. service / systemd `[core]`
Start, stop, enable, disable services; use systemd module for unit file control.

```yaml
- systemd:
    name: nginx
    state: started
    enabled: true
    daemon_reload: true
```

---

### 30. user / group `[core]`
Create system users, set shells, home dirs, and group memberships.

```yaml
- user:
    name: deploy
    groups: sudo,docker
    shell: /bin/bash
    create_home: true
```

---

### 31. git `[core]`
Clone or update a git repo on remote servers — standard deploy pattern.

```yaml
- git:
    repo: 'https://github.com/org/app.git'
    dest: /opt/app
    version: main
    force: true
```

---

### 32. uri (HTTP calls) `[advanced]`
Make REST API calls from playbooks — trigger webhooks, health checks, Slack alerts.

```yaml
- uri:
    url: http://localhost:8080/health
    method: GET
    status_code: 200
  register: health_check
```

---

### 33. docker_container / docker_image `[advanced]`
Manage Docker containers and images from Ansible — alternative to raw shell commands.

```yaml
- community.docker.docker_container:
    name: myapp
    image: myapp:latest
    state: started
    ports: ['8080:8080']
```

---

### 34. AWS modules (ec2, s3, rds, elb) `[production]`
Provision and manage AWS resources directly from Ansible — infra + config in one tool.

```yaml
- amazon.aws.ec2_instance:
    name: prod-web-01
    instance_type: t3.medium
    image_id: ami-0abcdef
    security_groups: [web-sg]
    tags:
      Env: production
      Role: webserver
```

---

## 7. Roles

### 35. Role directory structure `[core]`
Standardised folder layout (tasks, handlers, vars, defaults, templates, files, meta) for reusable code.

```
roles/nginx/
  tasks/main.yml
  handlers/main.yml
  templates/nginx.j2
  defaults/main.yml   # lowest priority vars
  vars/main.yml       # high priority vars
  meta/main.yml       # dependencies
```

---

### 36. ansible-galaxy init `[core]`
Scaffold a new role skeleton instantly — don't create folders manually.

```bash
ansible-galaxy role init roles/nginx
# Creates full skeleton automatically
```

---

### 37. Role defaults vs vars `[core]`
defaults/main.yml = easily overridden; vars/main.yml = harder to override — use defaults for user-facing configs.

```yaml
# defaults/main.yml (overridable)
nginx_port: 80

# vars/main.yml (locked)
_nginx_user: www-data
```

---

### 38. Role dependencies (meta) `[advanced]`
Declare that a role requires other roles — they run first automatically.

```yaml
# meta/main.yml
dependencies:
  - role: common
  - role: security_hardening
```

---

### 39. ansible-galaxy install (community roles) `[advanced]`
Download and reuse community roles from Ansible Galaxy instead of writing from scratch.

```bash
ansible-galaxy install geerlingguy.nginx

# requirements.yml
roles:
  - name: geerlingguy.nginx
    version: 3.1.0
```

---

### 40. Role-based project structure (prod) `[production]`
In production repos, separate roles per service; use site.yml as entry point calling environment-specific playbooks.

```
project/
  inventories/
    production/
    staging/
  roles/
    nginx/  app/  db/  monitoring/
  playbooks/
    deploy.yml  rollback.yml
  site.yml
```

---

## 8. Jinja2 Templating

### 41. Variable interpolation `[core]`
Use `{{ var }}` in templates and playbooks to inject dynamic values.

```jinja2
# nginx.j2
server {
  listen {{ nginx_port }};
  server_name {{ ansible_hostname }};
}
```

---

### 42. Filters `[core]`
Transform variables — default values, string manipulation, list operations.

```yaml
{{ app_version | default('latest') }}
{{ username | upper }}
{{ packages | join(', ') }}
{{ path | basename }}
```

---

### 43. Conditionals & loops in templates `[advanced]`
Use `{% if %}` and `{% for %}` blocks inside Jinja2 templates for dynamic config generation.

```jinja2
{% for server in upstream_servers %}
  server {{ server.ip }}:{{ server.port }};
{% endfor %}

{% if ssl_enabled %}
  ssl_certificate /etc/ssl/cert.pem;
{% endif %}
```

---

### 44. lookup plugin `[advanced]`
Fetch data from files, env vars, password store, or external sources at template time.

```yaml
vars:
  secret_key: '{{ lookup("env", "SECRET_KEY") }}'
  ssh_key: '{{ lookup("file", "/home/user/.ssh/id_rsa.pub") }}'
```

---

## 9. Ansible Vault

### 45. Encrypt/decrypt files `[core]`
Vault encrypts entire files or strings — commit encrypted secrets safely to Git.

```bash
ansible-vault encrypt group_vars/prod/secrets.yml
ansible-vault decrypt secrets.yml
ansible-vault view secrets.yml  # view without decrypting on disk
```

---

### 46. Vault password file `[core]`
Store vault password in a file (not in Git!) and reference it — avoids interactive prompts in CI.

```ini
# .vault_pass (add to .gitignore!)
mysuperSecretPassword

# ansible.cfg
[defaults]
vault_password_file = .vault_pass
```

---

### 47. Multiple vault IDs `[advanced]`
Use different vault passwords for different environments — prod secrets encrypted differently than dev.

```bash
ansible-vault encrypt --vault-id prod@.vault_prod secrets.yml
ansible-playbook site.yml \
  --vault-id prod@.vault_prod \
  --vault-id dev@.vault_dev
```

---

### 48. Vault + AWS Secrets Manager / HashiCorp Vault `[production]`
In prod, don't use file-based vault — pull secrets dynamically from AWS Secrets Manager at runtime.

```yaml
# Use community.aws lookup:
vars:
  db_password: >-
    {{ lookup('amazon.aws.aws_secret',
    'prod/db/password', region='ap-south-1') }}
```

---

## 10. Error Handling & Idempotency

### 49. Idempotency `[core]`
Running a playbook multiple times should produce the same result — the golden rule of Ansible.

```yaml
# Good: idempotent
- apt: name=nginx state=present

# Bad: not idempotent
- shell: echo 'done' >> /var/log/app.log
```

---

### 50. ignore_errors & failed_when `[core]`
Control when Ansible considers a task failed — override default exit-code based logic.

```yaml
- shell: check_service.sh
  register: result
  ignore_errors: true

- command: run_migration.sh
  failed_when: "'ERROR' in result.stderr"
```

---

### 51. changed_when `[core]`
Tell Ansible when a task actually changed something — prevents false notifications.

```yaml
- shell: /opt/app/check_version.sh
  register: ver
  changed_when: ver.stdout != current_version
```

---

### 52. block / rescue / always `[advanced]`
Ansible's try/catch/finally — run rescue tasks on failure, always tasks regardless.

```yaml
- block:
    - include_tasks: deploy.yml
  rescue:
    - include_tasks: rollback.yml
    - notify_slack: msg='Deploy failed!'
  always:
    - include_tasks: cleanup.yml
```

---

### 53. serial, max_fail_percentage `[production]`
Deploy to servers in batches; stop if too many fail — safe rolling updates.

```yaml
- hosts: webservers
  serial: '25%'           # 25% at a time
  max_fail_percentage: 10  # stop if >10% fail
  tasks:
    - include_role: name=deploy_app
```

---

## 11. Production Patterns

### 54. Rolling deployments `[production]`
Deploy new version to servers one batch at a time — zero downtime for users.

```yaml
- hosts: webservers
  serial: 1          # one server at a time
  tasks:
    - include_role: name=nginx
    - include_role: name=deploy_app
    - uri:           # health check before next server
        url: http://{{ inventory_hostname }}/health
        status_code: 200
```

---

### 55. Blue-green deployments `[production]`
Run two identical environments; switch load balancer to new (green) after validation, keep old (blue) as rollback.

```yaml
# Switch ALB target group from blue to green
- amazon.aws.elb_target_group_attachment:
    target_group_arn: '{{ green_tg_arn }}'
    target_id: '{{ item }}'
    state: present
  loop: '{{ green_instances }}'
```

---

### 56. Ansible in CI/CD (Jenkins / GitHub Actions) `[production]`
Trigger Ansible playbooks from CI pipelines on every merge — full GitOps approach.

```yaml
# GitHub Actions snippet
- name: Deploy via Ansible
  run: |
    ansible-playbook -i inventories/prod \
      --vault-password-file .vault_pass \
      playbooks/deploy.yml
```

---

### 57. Dry-run (--check) & diff mode `[production]`
Simulate playbook run without making changes — validate before prod deploy.

```bash
ansible-playbook site.yml --check --diff
# --check = dry run
# --diff  = show exact file changes
```

---

### 58. Ansible Tower / AWX `[production]`
Web UI + RBAC + scheduling + audit logs on top of Ansible — required for enterprise/team use.

```
Key features:
  - Job Templates, Workflows, Credentials vault
  - RBAC (who can run what)
  - Audit trail for compliance
  - Scheduled playbook runs
```

---

### 59. Callback plugins & logging `[production]`
Log playbook run output to syslog, Splunk, or ELK for audit and debugging in prod.

```ini
# ansible.cfg
[defaults]
callback_whitelist = timer, mail, json
log_path = /var/log/ansible.log
stdout_callback = yaml   # cleaner output
```

---

### 60. Testing with Molecule `[production]`
Test your Ansible roles in Docker containers before applying to prod — TDD for infrastructure.

```bash
molecule init scenario --driver-name docker
molecule test          # creates container, runs role, runs tests

# verify.yml checks:
- assert:
    that: nginx_service.status == 'running'
```

---

---

## 12. Policy as Code with Ansible (DevSecOps)

### 61. What is Policy as Code (PaC)? `[advanced]`
Defining security and compliance rules as code — enforced automatically in CI/CD pipelines instead of manual audits.

```
Traditional:  Security team manually reviews config → slow, inconsistent
PaC:          Policies in Git → auto-enforced in every pipeline run → consistent, auditable
```

---

### 62. Ansible for compliance checks `[advanced]`
Use Ansible to audit servers for compliance — check file permissions, open ports, installed packages against a baseline.

```yaml
- name: Ensure SSH root login is disabled
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^PermitRootLogin'
    line: 'PermitRootLogin no'
    state: present
  notify: Restart sshd

- name: Ensure firewall is running
  service:
    name: ufw
    state: started
    enabled: true
```

---

### 63. Auto-remediation of non-compliant resources `[production]`
Detect and fix AWS resource misconfigurations automatically — e.g., S3 buckets with public access, missing tags, open security groups.

```yaml
- name: Block S3 public access (enforce compliance)
  amazon.aws.s3_bucket:
    name: '{{ item }}'
    state: present
    public_access:
      block_public_acls: true
      block_public_policy: true
      ignore_public_acls: true
      restrict_public_buckets: true
  loop: '{{ s3_buckets }}'
```

---

### 64. Shift-left security with Ansible in CI/CD `[production]`
Run compliance playbooks in pull request pipelines — catch security issues before they reach prod.

```yaml
# GitHub Actions: run compliance check on every PR
- name: Compliance audit
  run: |
    ansible-playbook -i inventories/staging \
      playbooks/compliance_check.yml \
      --check   # dry-run, fail if violations found
```

---

## 13. Network Automation with Ansible

### 65. Why Ansible for network automation? `[advanced]`
Network devices (routers, switches, firewalls) can't run agents — Ansible's agentless model via SSH/API is perfect.

```
Traditional:  SSH into each device → type commands → error-prone, not scalable
Ansible:      Write once → push to 100 devices → consistent, version-controlled
```

---

### 66. Network connection types `[advanced]`
Ansible uses different connection plugins for network devices — `network_cli`, `netconf`, `httpapi`.

```yaml
# inventory for network devices
[routers]
router1 ansible_host=10.0.0.1

[routers:vars]
ansible_network_os=ios          # Cisco IOS
ansible_connection=network_cli
ansible_user=admin
ansible_password: "{{ vault_net_pass }}"
```

---

### 67. Common network modules `[advanced]`
Ansible has modules for Cisco IOS, Juniper, Arista, and vendor-neutral `cli_command` for any SSH device.

```yaml
# Cisco IOS example
- name: Configure hostname
  cisco.ios.ios_hostname:
    config:
      hostname: prod-router-01

# Vendor-neutral — any device
- name: Run show command
  ansible.netcommon.cli_command:
    command: show ip interface brief
  register: output

- debug: msg='{{ output.stdout }}'
```

---

### 68. Network config backup `[production]`
Automatically back up running configs of all network devices to Git daily — critical for disaster recovery.

```yaml
- name: Backup router config
  cisco.ios.ios_config:
    backup: true
    backup_options:
      filename: '{{ inventory_hostname }}_{{ ansible_date_time.date }}.cfg'
      dir_path: /backups/network
```

---

## 14. Terraform + Ansible Integration

### 69. When to use Terraform vs Ansible `[advanced]`
Terraform provisions infrastructure (VMs, VPCs, RDS); Ansible configures what's inside those VMs. Use both together — Terraform first, Ansible second.

```
Terraform:   Create EC2 instance, VPC, Security Group, RDS
     ↓
Ansible:     Install nginx, deploy app, configure DB connection, harden OS
```

---

### 70. Passing Terraform outputs to Ansible `[advanced]`
Terraform outputs (like EC2 IPs) can be fed directly into Ansible inventory via dynamic inventory or output files.

```bash
# Option 1: Terraform output → Ansible var
TF_IP=$(terraform output -raw web_server_ip)
ansible-playbook -i "$TF_IP," playbooks/deploy.yml

# Option 2: Terraform writes inventory file
# In main.tf:
resource "local_file" "ansible_inventory" {
  content  = "[webservers]\n${aws_instance.web.public_ip}"
  filename = "../ansible/inventories/prod/hosts"
}
```

---

### 71. Full pipeline: Terraform → Ansible in CI/CD `[production]`
Provision infra with Terraform then immediately configure it with Ansible in the same pipeline — full GitOps.

```yaml
# GitHub Actions full pipeline
jobs:
  infra:
    steps:
      - name: Terraform apply
        run: terraform apply -auto-approve
      - name: Get server IP
        run: echo "SERVER_IP=$(terraform output -raw ip)" >> $GITHUB_ENV

  configure:
    needs: infra
    steps:
      - name: Run Ansible
        run: |
          ansible-playbook -i "$SERVER_IP," \
            --private-key ~/.ssh/id_rsa \
            playbooks/configure.yml
```

---

## 15. Interview Questions (from Veeramalla's Day-14)

### 72. Top Ansible interview Q&A `[must-know]`

**Q1: What is the difference between a playbook and a role?**
> Playbook is a single YAML file with tasks. Role is a structured directory (tasks, handlers, templates, vars) that packages reusable automation — roles make playbooks modular and shareable.

**Q2: What happens if you run an Ansible playbook twice?**
> Idempotent tasks produce the same result — no change on second run. Non-idempotent tasks (like `shell: echo >> file`) will run again and cause drift.

**Q3: How does Ansible handle failures in a multi-host scenario?**
> By default, Ansible aborts the entire play for a host that fails but continues on others. Use `ignore_errors`, `block/rescue`, or `max_fail_percentage` to control behavior.

**Q4: What is the difference between `copy` and `template` module?**
> `copy` transfers files as-is. `template` renders Jinja2 variables inside the file before transferring — use template for dynamic configs.

**Q5: How do you pass sensitive data to Ansible without storing it in plaintext?**
> Use `ansible-vault` to encrypt variables/files. In production, use `lookup('amazon.aws.aws_secret', ...)` to pull secrets from AWS Secrets Manager at runtime.

**Q6: What is the difference between `import_tasks` and `include_tasks`?**
> `import_tasks` is static — processed at parse time, so tags and conditions apply to all tasks. `include_tasks` is dynamic — processed at runtime, useful when the task file name depends on a variable.

**Q7: What is ansible_facts and how do you use it?**
> ansible_facts are system facts auto-collected at play start (OS, IP, memory, etc.). Use with `when: ansible_os_family == 'Debian'` for conditional tasks. Disable with `gather_facts: false` to speed up playbooks.

**Q8: How do you speed up Ansible playbooks in production?**
> Enable SSH pipelining, use `gather_facts: false` when not needed, increase forks, use async tasks, and cache facts with `fact_caching = jsonfile`.

```ini
# ansible.cfg performance tuning
[defaults]
forks = 20
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts

[ssh_connection]
pipelining = true
```

**Q9: What is the use of `delegate_to`?**
> Run a task on a different host than the play target — e.g., deregister a server from load balancer (run on LB host) before deploying to it.

```yaml
- name: Remove from load balancer
  command: lb_deregister.sh {{ inventory_hostname }}
  delegate_to: loadbalancer.example.com
```

**Q10: Explain Ansible Tower / AWX and when you'd use it.**
> Tower/AWX adds Web UI, RBAC, audit logs, scheduling, and credential management on top of Ansible. Use it in teams where multiple people run playbooks — ensures access control and visibility. AWX is open-source; Tower is the enterprise Red Hat product.

---



| Topic | Why It Matters |
|---|---|
| Variable precedence | Interviewers always ask this — extra vars (-e) always win |
| Idempotency | Be able to explain with a good/bad example |
| import_tasks vs include_tasks | Static vs dynamic — real interview question |
| block/rescue/always | Shows you understand prod error handling |
| Dynamic inventory (EC2) | Non-negotiable for AWS DevOps roles |
| Molecule testing | Shows production mindset, not just YAML knowledge |
| Rolling deploy + serial | Shows you understand zero-downtime deployments |
| Vault + AWS Secrets Manager | Shows real prod security awareness |

---

*Ansible Revision Guide — Built for DevOps transition 2026*
