# Ansible — Top & Medium Priority Interview Topics

> Filtered from the full revision guide — only what interviewers actually ask most. Skipped: network device automation, deep policy-as-code/compliance frameworks, Molecule testing internals, and enterprise-only Terraform pipeline plumbing (low ROI for most DevOps interviews). If you get an architect-level or platform-team interview, ask and I'll add those back.

---

## 1. Core Concepts

**What is Ansible & why agentless matters**
Push-based automation over SSH/WinRM — no agent installed on managed nodes, just Python + SSH access. Contrast with Puppet/Chef (agent-based, pull model, need Ruby/DSL).

```yaml
# No agents needed — just SSH access
# Push-based: control node → managed nodes
```

**Control node vs Managed nodes**
Only the control node needs Ansible installed. Managed nodes just need SSH/WinRM + Python.

**Idempotency (the #1 concept to nail)**
Running a playbook N times gives the same end state — safe re-runs, no side effects.

```yaml
# Idempotent (good)
- package: {name: nginx, state: present}

# NOT idempotent (bad) — appends every run
- shell: echo 'done' >> /var/log/app.log
```

---

## 1b. Ansible Architecture

```
              ┌─────────────────────┐
              │     Control Node     │  ← Ansible installed here
              │  (your laptop / CI)  │
              └──────────┬───────────┘
                         │ SSH / WinRM (push, no agent)
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
   Managed Node 1   Managed Node 2   Managed Node 3
   (Python only)    (Python only)    (Python only)
```

Key pieces that make up the architecture:
- **Control Node** — where Ansible, playbooks, and inventory live; the only machine that needs Ansible installed.
- **Managed Nodes** — targets; need only SSH/WinRM access + a Python interpreter, no agent.
- **Inventory** — the list of managed nodes (static file or dynamic plugin).
- **Modules** — units of work (idempotent Python scripts) shipped to nodes and executed, then removed.
- **Plugins** — extend core behavior (connection, callback, lookup, filter plugins etc.).
- **Playbooks** — YAML files describing desired state, executed against the inventory.
- **API/SDK** — used internally, and by tools like AWX/Tower to trigger runs programmatically.

Interview one-liner: *"Ansible has a agentless, push-based architecture — the control node connects over SSH, pushes a small module as a temporary script to the managed node, executes it, captures the result as JSON, then deletes the script — no persistent agent or daemon runs on managed nodes."*

---

## 2. Inventory

Static (file-based) for small/fixed infra, dynamic (cloud-generated) for real production/AWS environments — dynamic is a near-guaranteed interview topic if the JD mentions AWS.

```ini
# Static
[webservers]
192.168.1.10
192.168.1.11
```

```yaml
# Dynamic (AWS EC2)
plugin: amazon.aws.aws_ec2
regions: [ap-south-1]
filters:
  tag:Env: production
keyed_groups:
  - key: tags.Role
```

---

## 3. Playbooks — Structure & Flow Control

**Hierarchy:** Playbook → Play → Tasks → Modules

```yaml
---
- name: Install nginx
  hosts: webservers
  become: true
  tasks:
    - name: Install nginx
      apt: {name: nginx, state: present}
```

**Handlers (notify)** — run only when triggered by a change:

```yaml
tasks:
  - name: Copy nginx config
    template: {src: nginx.j2, dest: /etc/nginx/nginx.conf}
    notify: Restart nginx
handlers:
  - name: Restart nginx
    service: {name: nginx, state: restarted}
```

**Conditionals (`when`):**

```yaml
- apt: {name: nginx, state: present}
  when: ansible_os_family == 'Debian'
```

**Loops:**

```yaml
- apt: {name: '{{ item }}', state: present}
  loop: [nginx, git, curl]
```

**Variables & precedence** — asked in almost every interview. You don't need to recite all 22 official levels — know the ordering logic (lowest → highest):

```
1. role defaults (roles/x/defaults/main.yml)         ← lowest, easiest to override
2. inventory vars (group_vars / host_vars)
3. playbook vars (vars:, vars_files:)
4. role vars (roles/x/vars/main.yml)
5. include/import_role vars, block vars, task vars
6. registered vars / facts (set_fact, register)
7. extra-vars: -e 'key=value'                         ← highest, ALWAYS wins
```

```bash
ansible-playbook site.yml -e 'app_version=1.3.0'   # beats everything else
```

**Facts** — auto-collected system info (OS, IP, hostname, memory, CPU) gathered at the start of a play, used to make playbooks host-aware.

```yaml
- name: Install on Debian family only
  apt: {name: nginx, state: present}
  when: ansible_facts['os_family'] == 'Debian'

- debug: msg="Host {{ ansible_facts['hostname'] }} has {{ ansible_facts['memtotal_mb'] }}MB RAM"

# Skip fact gathering when not needed — speeds up runs
- hosts: all
  gather_facts: false
```

**`import_tasks` vs `include_tasks`** — static (parse-time, tags/conditions apply globally) vs dynamic (runtime, filename can use a variable).

```yaml
- import_tasks: tasks/nginx.yml     # static
- include_tasks: 'tasks/{{ env }}.yml'  # dynamic
```

**Tags** — run a subset of tasks:

```bash
ansible-playbook site.yml --tags install
```

**Privilege escalation (`become`)** — run tasks as another user (usually root) without permanent root access or a shared root password.

```yaml
- hosts: webservers
  become: true              # escalate for the whole play
  become_user: root         # default is root; can target any user
  become_method: sudo       # sudo, su, doas, etc.

  tasks:
    - apt: {name: nginx, state: present}   # runs with sudo
    - command: whoami
      become: false          # override at task level — runs as normal user
```
Run interactively with a sudo password prompt: `ansible-playbook site.yml --ask-become-pass` (`-K`).

**Collections** — namespaced bundles of modules/roles/plugins (the modern way Ansible content is distributed, since core Ansible no longer ships every module by default).

```bash
ansible-galaxy collection install amazon.aws
ansible-galaxy collection install community.docker
```

```yaml
# Use fully-qualified collection name (FQCN)
- amazon.aws.ec2_instance:
    name: my-server

# Or declare once at play level
- hosts: all
  collections: [amazon.aws, community.docker]
```

---

## 4. Key Modules

```yaml
- file: {path: /var/app, state: directory, mode: '0755'}
- copy: {src: app.conf, dest: /etc/app/}
- template: {src: nginx.j2, dest: /etc/nginx/nginx.conf}   # Jinja2-rendered
- package: {name: nginx, state: present}
- systemd: {name: nginx, state: started, enabled: true}
- user: {name: deploy, groups: sudo,docker, shell: /bin/bash}
- git: {repo: 'https://github.com/org/app.git', dest: /opt/app, version: main}
- uri: {url: 'http://localhost:8080/health', status_code: 200}   # health checks / API calls
```

`copy` vs `template`: copy = static file as-is; template = Jinja2 variables rendered at deploy time. **Very commonly asked.**

**`command` vs `shell` (very commonly asked)**

| | `command` | `shell` |
|---|---|---|
| Shell features (pipes `\|`, redirects `>`, env vars, `&&`) | ❌ Not supported | ✅ Supported |
| Runs through `/bin/sh` | No — runs the binary directly | Yes |
| Security | Safer (no shell injection risk) | Riskier — avoid with untrusted input |
| Default choice | **Prefer this** unless you need shell features | Only when you truly need piping/redirection |

```yaml
# command — no pipes/redirects allowed, safer
- command: /usr/bin/whoami

# shell — needed because of the pipe
- shell: ps aux | grep nginx | wc -l
```
Interview tip: always say *"I prefer `command` by default and only reach for `shell` when I genuinely need shell operators — it avoids shell-injection risk and is closer to idempotent."*

---

## 5. Roles

Standard reusable structure — almost every real playbook interview question assumes you know this layout.

```
roles/nginx/
  tasks/main.yml
  handlers/main.yml
  templates/nginx.j2
  defaults/main.yml   # low priority, easily overridden
  vars/main.yml       # high priority, locked
  meta/main.yml       # role dependencies
```

```bash
ansible-galaxy role init roles/nginx
ansible-galaxy install geerlingguy.nginx   # reuse community roles
```

---

## 6. Jinja2 Templating

```jinja2
server {
  listen {{ nginx_port }};
  server_name {{ ansible_hostname }};
}
{% if ssl_enabled %}
  ssl_certificate /etc/ssl/cert.pem;
{% endif %}
```

Filters: `{{ app_version | default('latest') }}`, `{{ username | upper }}`

---

## 7. Ansible Vault (secrets)

```bash
ansible-vault encrypt group_vars/prod/secrets.yml
ansible-playbook site.yml --ask-vault-pass
```

Production pattern: pull secrets from AWS Secrets Manager / HashiCorp Vault at runtime instead of file-based vault:

```yaml
db_password: "{{ lookup('amazon.aws.aws_secret', 'prod/db/password', region='ap-south-1') }}"
```

---

## 8. Error Handling

## Part 1: Ansible Error Handling (Core Essentials)

By default, Ansible stops executing a play on a host the moment a task fails on that host (other hosts continue independently). These are the constructs you actually need day-to-day — trimmed to what's used in real playbooks.

### 1. `ignore_errors`
Continues execution on a host even if a task fails. Use sparingly — it hides real failures if overused.

```yaml
- name: Try to stop a service that may not exist
  ansible.builtin.service:
    name: legacy-app
    state: stopped
  ignore_errors: true
```

### 2. `failed_when`
Lets you define custom logic for what counts as "failed," overriding the module's default success/fail detection. Useful when a command returns exit code 0 but the output indicates a problem.

```yaml
- name: Run a health check script
  ansible.builtin.command: /opt/scripts/health_check.sh
  register: health_result
  failed_when: "'ERROR' in health_result.stdout"
```

### 3. `block` / `rescue` / `always`
The closest equivalent to try/catch/finally, and the backbone of structured error handling in real playbooks.

```yaml
- name: Deploy application with rollback on failure
  block:
    - name: Copy new build artifact
      ansible.builtin.copy:
        src: app.jar
        dest: /opt/app/app.jar

    - name: Restart application service
      ansible.builtin.service:
        name: myapp
        state: restarted

  rescue:
    - name: Rollback to previous build
      ansible.builtin.copy:
        src: /opt/app/backup/app.jar
        dest: /opt/app/app.jar

    - name: Restart service with old build
      ansible.builtin.service:
        name: myapp
        state: restarted

    - name: Fail the play explicitly after rollback
      ansible.builtin.fail:
        msg: "Deployment failed, rolled back to previous version"

  always:
    - name: Send deployment status notification
      ansible.builtin.debug:
        msg: "Deployment attempt finished for {{ inventory_hostname }}"
```

- `block` — the main tasks you want to run.
- `rescue` — runs only if a task in the block fails; treat it like a catch.
- `always` — runs regardless of success or failure; treat it like a finally.

### 4. Retry logic with `retries` / `until`
Avoids false failures on transient issues (e.g., waiting for a service to come up).

```yaml
- name: Wait for application to respond
  ansible.builtin.uri:
    url: "http://localhost:8080/health"
    status_code: 200
  register: result
  retries: 5
  delay: 10
  until: result.status == 200
```

### 5. `debug` + `register` for diagnosis
Always register the output of a risky task so you can inspect it in `rescue` or `failed_when` conditions.

```yaml
- name: Run migration script
  ansible.builtin.command: /opt/app/migrate.sh
  register: migration_output
  ignore_errors: true

- name: Show migration output if it failed
  ansible.builtin.debug:
    var: migration_output.stdout_lines
  when: migration_output.failed
```

---

## Part 2: `delegate_to`, `include_tasks`, `import_tasks`

### `delegate_to`
Runs a specific task on a different host than the one the play is currently targeting, while everything else in the play still runs against the original host. This is essential any time an action needs to happen on a control point — a load balancer, a monitoring system, a bastion — rather than on the target server itself.

```yaml
- name: Deregister node from load balancer before deployment
  community.general.haproxy:
    state: disabled
    host: "{{ inventory_hostname }}"
    socket: /var/run/haproxy.sock
  delegate_to: lb01.internal

- name: Deploy new artifact on the app server itself
  ansible.builtin.copy:
    src: app.jar
    dest: /opt/app/app.jar

- name: Re-register node with load balancer after deployment
  community.general.haproxy:
    state: enabled
    host: "{{ inventory_hostname }}"
    socket: /var/run/haproxy.sock
  delegate_to: lb01.internal

Common real-world uses of `delegate_to`:
- Updating a load balancer (HAProxy/ALB/Nginx) to drain/add a node during rolling deploys.
- Running a database migration from a single designated host instead of every app server.
- Registering/deregistering with a monitoring or service-discovery system (Consul, Zabbix).
- `delegate_to: localhost` — running a task from the Ansible control node itself (e.g., calling an API, writing a local report).

### `include_tasks` vs `import_tasks`
Both pull in tasks from another file, but they behave fundamentally differently — this trips up most people at least once.

| | `import_tasks` | `include_tasks` |
|---|---|---|
| Processed | Statically, at **playbook parse time** | Dynamically, at **runtime** |
| Can use `loop` on the include itself | No | Yes |
| Conditional (`when`) applies to | Every task inside the file individually | The include statement as a whole (short-circuits) |
| Tags | Applied per-task, always evaluated | Only evaluated if the include actually runs |
| `--list-tasks` / `--list-tags` shows contents | Yes (fully expanded) | No (shows only the include line) |
| Good for | Static structure, predictable task lists, tagging/auditing | Conditional logic, loops, deciding at runtime which file to load |

**`import_tasks` example** (static — resolved before the play runs):
```yaml
- name: Import common setup tasks
  ansible.builtin.import_tasks: common_setup.yml
```

**`include_tasks` example** (dynamic — decided while running, supports looping):
```yaml
- name: Include environment-specific deploy logic
  ansible.builtin.include_tasks: "deploy_{{ target_env }}.yml"

- name: Run a task file once per service
  ansible.builtin.include_tasks: restart_service.yml
  loop:
    - api-service
    - worker-service
    - scheduler-service
  loop_control:
    loop_var: service_name
```

**Rule of thumb:** if the task file is always the same and you want full visibility into the task list up front (good for CI linting/auditing), use `import_tasks`. If you need to loop over the include, choose the file dynamically, or want `when` to skip the whole file cheaply without evaluating every task inside it, use `include_tasks`.


```yaml
- block:
    - include_tasks: deploy.yml
  rescue:
    - include_tasks: rollback.yml
  always:
    - include_tasks: cleanup.yml
```

```yaml
- shell: check_service.sh
  register: result
  ignore_errors: true
```

---

## 8b. Ansible Configuration (`ansible.cfg`)

Controls Ansible's runtime behavior — where it looks for inventory, how it connects, performance tuning, etc. Precedence for which `ansible.cfg` is used (highest to lowest): `ANSIBLE_CONFIG` env var → `./ansible.cfg` (current dir) → `~/.ansible.cfg` → `/etc/ansible/ansible.cfg`.

```ini
# ansible.cfg
[defaults]
inventory      = ./inventory.ini
remote_user    = ubuntu
host_key_checking = False
forks          = 20
gathering      = smart
fact_caching   = jsonfile
fact_caching_connection = /tmp/ansible_facts
retry_files_enabled = False
vault_password_file = .vault_pass

[privilege_escalation]
become = True
become_method = sudo

[ssh_connection]
pipelining = True
control_path = /tmp/ansible-ssh-%h-%p-%r
```
Interview one-liner: *"`ansible.cfg` is how I tune performance (forks, pipelining, fact caching) and set team-wide defaults like the vault password file and inventory path, instead of repeating flags on every CLI call."*

---

## 9. Production Patterns (the ones that actually come up)

**Rolling deployment with `serial`:**

```yaml
- hosts: webservers
  serial: 1
  tasks:
    - include_role: {name: deploy_app}
    - uri: {url: 'http://{{ inventory_hostname }}/health', status_code: 200}
```

**Dry-run before prod:**

```bash
ansible-playbook site.yml --check --diff
```

**CI/CD trigger (GitHub Actions example):**

```yaml
- name: Deploy via Ansible
  run: |
    ansible-playbook -i inventories/prod \
      --vault-password-file .vault_pass \
      playbooks/deploy.yml
```

**Ansible Tower/AWX** — one-liner to remember: adds Web UI, RBAC, scheduling, audit logs, credential vaulting on top of core Ansible for team use.

**Terraform + Ansible** — Terraform provisions infra (VMs/VPCs), Ansible configures what's inside them. Know this pairing even if you don't go deep.


## Part 3: Real-Time Use Case — App Deployment via Ansible, Triggered by Jenkins

**Scenario:** Deploy a Java/Spring Boot microservice to a fleet of `dev` and `prod` servers behind a load balancer, with zero-downtime rolling updates, config templating, and automatic rollback on failure — triggered from Jenkins.

### Project directory structure

```
ansible-deploy/
├── ansible.cfg
├── requirements.yml
├── inventory/
│   ├── dev/
│   │   └── hosts.ini
│   └── prod/
│       └── hosts.ini
├── group_vars/
│   ├── all.yml
│   ├── dev.yml
│   └── prod.yml
├── roles/
│   └── app_deploy/
│       ├── defaults/
│       │   └── main.yml
│       ├── vars/
│       │   └── main.yml
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── deploy.yml
│       │   └── rollback.yml
│       ├── handlers/
│       │   └── main.yml
│       ├── templates/
│       │   └── app.conf.j2
│       └── files/
│           └── healthcheck.sh
├── playbook.yml
└── Jenkinsfile
```

### `roles/app_deploy/tasks/main.yml`
```yaml
- name: Deregister this node from the load balancer
  community.general.haproxy:
    state: disabled
    host: "{{ inventory_hostname }}"
    socket: /var/run/haproxy.sock
  delegate_to: "{{ loadbalancer_host }}"

- name: Run deployment with rollback safety net
  block:
    - name: Include deploy tasks
      ansible.builtin.include_tasks: deploy.yml
  rescue:
    - name: Include rollback tasks
      ansible.builtin.include_tasks: rollback.yml
    - name: Fail build explicitly so Jenkins marks it as failed
      ansible.builtin.fail:
        msg: "Deployment failed on {{ inventory_hostname }}, rollback executed"

- name: Re-register this node with the load balancer
  community.general.haproxy:
    state: enabled
    host: "{{ inventory_hostname }}"
    socket: /var/run/haproxy.sock
  delegate_to: "{{ loadbalancer_host }}"
```

### `playbook.yml` (rolling, one host at a time)
```yaml
- name: Deploy application with zero-downtime rolling update
  hosts: appservers
  become: true
  serial: 1
  roles:
    - app_deploy
```

### `Jenkinsfile` (Declarative Pipeline)
```groovy
pipeline {
    agent any

    parameters {
        choice(name: 'ENV', choices: ['dev', 'prod'], description: 'Target environment')
        string(name: 'BUILD_VERSION', defaultValue: '', description: 'Artifact version to deploy')
    }

    environment {
        ANSIBLE_VAULT_PASS = credentials('ansible-vault-password')
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/company/ansible-deploy.git'
            }
        }

        stage('Lint Playbook') {
            steps {
                sh 'ansible-lint playbook.yml'
            }
        }

        stage('Deploy') {
            steps {
                sh """
                    echo \$ANSIBLE_VAULT_PASS > .vault_pass
                    ansible-playbook -i inventory/${params.ENV}/hosts.ini playbook.yml \
                        --vault-password-file .vault_pass \
                        -e BUILD_VERSION=${params.BUILD_VERSION}
                """
            }
        }
    }

    post {
        always {
            sh 'rm -f .vault_pass'
        }
    }
}
```

---

## Part 4: How Do You Achieve a Zero-Downtime Rolling Deployment with Ansible?

The core idea: never take the whole fleet down at once, and never send traffic to a node that isn't ready. Ansible achieves this through a combination of **batching**, **load-balancer coordination**, and **health verification** before moving to the next batch.

### 1. Control batch size with `serial`
`serial` tells Ansible how many hosts to process per batch instead of all hosts simultaneously.

```yaml
- hosts: appservers
  serial: 1          # one host at a time — safest, slowest
  # or
  serial: "25%"       # rolling batches of 25% of the fleet
  # or a staged rollout:
  serial:
    - 1        # canary: deploy to 1 host first
    - 3        # then 3 more
    - "100%"   # then the rest
```
Staged `serial` lists are extremely common: deploy to a single canary host first, verify it's healthy, then widen the batch. If the canary fails, the play stops before touching the rest of the fleet.

### 2. Deregister the node from the load balancer before touching it
This is where `delegate_to` becomes essential — the deregistration command must run against the load balancer, not the app server being updated.

```yaml
- name: Drain node from load balancer
  community.general.haproxy:
    state: disabled
    host: "{{ inventory_hostname }}"
    socket: /var/run/haproxy.sock
  delegate_to: "{{ loadbalancer_host }}"
```
For cloud load balancers, the equivalent is deregistering the instance from an AWS ALB/NLB target group (`community.aws.elb_target` / `amazon.aws.elb_target_group_info`) or deregistering from an Azure/GCP load balancer backend pool.

### 3. Let in-flight connections finish (connection draining)
Give the LB time to stop sending new requests and let existing ones complete before you touch the process.

```yaml
- name: Wait for connections to drain
  ansible.builtin.wait_for:
    timeout: 30
```

### 4. Deploy and restart on the drained node only
Because this node is already out of rotation, restarting it causes zero user-facing impact.

```yaml
- name: Deploy new build
  ansible.builtin.copy:
    src: "app-{{ app_version }}.jar"
    dest: /opt/app/current.jar

- name: Restart service
  ansible.builtin.service:
    name: myapp
    state: restarted
```

### 5. Verify health before re-adding to rotation
Never re-register a node until it's provably healthy — this is the step that actually prevents downtime.

```yaml
- name: Confirm application health endpoint
  ansible.builtin.uri:
    url: "http://localhost:8080/actuator/health"
    status_code: 200
  register: health
  retries: 10
  delay: 5
  until: health.status == 200
```

### 6. Re-register with the load balancer
```yaml
- name: Re-add node to load balancer
  community.general.haproxy:
    state: enabled
    host: "{{ inventory_hostname }}"
    socket: /var/run/haproxy.sock
  delegate_to: "{{ loadbalancer_host }}"
```

### 7. Fail fast and stop the rollout if a batch is unhealthy
Wrap steps 3–5 in a `block`/`rescue` so a bad node triggers rollback for that node, and combine with `max_fail_percentage` (or simply `serial` batching, which naturally halts on failure since a failed host stops the play by default) so a bad build doesn't get rolled out to the entire fleet.

### Putting it together
```yaml
- name: Zero-downtime rolling deployment
  hosts: appservers
  become: true
  serial:
    - 1
    - "25%"
    - "100%"
  vars:
    loadbalancer_host: lb01.internal
  tasks:
    - name: Drain from load balancer
      community.general.haproxy:
        state: disabled
        host: "{{ inventory_hostname }}"
        socket: /var/run/haproxy.sock
      delegate_to: "{{ loadbalancer_host }}"

    - name: Wait for connections to drain
      ansible.builtin.wait_for:
        timeout: 30

    - block:
        - name: Deploy new build
          ansible.builtin.copy:
            src: "app-{{ app_version }}.jar"
            dest: /opt/app/current.jar

        - name: Restart service
          ansible.builtin.service:
            name: myapp
            state: restarted

        - name: Confirm health
          ansible.builtin.uri:
            url: "http://localhost:8080/actuator/health"
            status_code: 200
          register: health
          retries: 10
          delay: 5
          until: health.status == 200
      rescue:
        - name: Roll back this node
          ansible.builtin.include_tasks: rollback.yml
        - name: Fail the play so the batch stops here
          ansible.builtin.fail:
            msg: "Health check failed on {{ inventory_hostname }} — halting rollout"

    - name: Re-add to load balancer
      community.general.haproxy:
        state: enabled
        host: "{{ inventory_hostname }}"
        socket: /var/run/haproxy.sock
      delegate_to: "{{ loadbalancer_host }}"
```

**Why this achieves zero downtime:** at any point in time, only the small batch currently being updated is out of the load balancer's rotation — the rest of the fleet keeps serving traffic. A node is never re-added until its health check passes, and a failed health check halts the rollout before it spreads to the next batch, rather than taking the whole fleet down or serving traffic from a broken node.

---

## Part 5: How Do You Manage Secrets at Enterprise Scale Across Many Teams/Pipelines?

At small scale, a single `ansible-vault`-encrypted file is fine. At enterprise scale — many teams, many pipelines, many environments — that approach breaks down: one shared vault password becomes a single point of compromise, there's no per-team access boundary, no rotation strategy, and no audit trail. Here's how it's actually handled at scale.

### 1. Move away from a single shared vault password
Ansible Vault supports **multiple vault IDs**, so different teams/environments can each have their own encryption identity instead of one password everyone shares.

```bash
ansible-vault encrypt group_vars/prod/secrets.yml --vault-id prod@prompt
ansible-vault encrypt group_vars/dev/secrets.yml --vault-id dev@prompt
```

```yaml
# ansible.cfg
[defaults]
vault_identity_list = dev@~/.vault_pass_dev.txt, prod@~/.vault_pass_prod.txt
```
This alone limits blast radius: a leaked `dev` password doesn't expose `prod` secrets, and each team can own its own vault identity.

### 2. Prefer an external secrets manager over static encrypted files
The real shift at enterprise scale is moving secrets **out of the Git repo entirely** and pulling them at runtime from a centralized, access-controlled secret store:

- **HashiCorp Vault** — via the `community.hashi_vault` collection
- **AWS Secrets Manager / SSM Parameter Store** — via `amazon.aws.aws_secret` lookup
- **Azure Key Vault** — via `azure.azcollection`
- **CyberArk / Thycotic** — common in large regulated enterprises

```yaml
- name: Fetch DB password from HashiCorp Vault
  ansible.builtin.set_fact:
    db_password: "{{ lookup('community.hashi_vault.hashi_vault', 'secret=secret/data/myapp/db:password') }}"
```
This means the secret never sits encrypted-at-rest in Git at all — it's fetched just-in-time during the playbook run, and access is controlled by the secrets manager's own IAM/ACL policies rather than a shared vault password.

### 3. Enforce per-team / per-namespace access boundaries
In a multi-team setup, the secrets backend (not Ansible) should enforce who can read what:
- HashiCorp Vault: separate secret **paths/namespaces per team** (`secret/team-payments/*`, `secret/team-search/*`) with policies bound to each team's auth method (LDAP group, AppRole, or Kubernetes service account).
- AWS Secrets Manager: separate secrets per team/environment with IAM policies scoped by resource tag or ARN prefix, assumed via distinct pipeline IAM roles.
- This means Team A's Jenkins pipeline literally cannot read Team B's secrets, even though both use the same Ansible tooling.

### 4. Inject the unlock credential through the CI/CD credential store, never hard-coded
In Jenkins specifically:
```groovy
environment {
    VAULT_ADDR = 'https://vault.company.internal'
    VAULT_TOKEN = credentials('vault-approle-token')   // Jenkins Credentials Binding plugin
}
```
The Jenkins Credentials store (backed by its own encrypted credential provider, or better, a Jenkins-to-Vault plugin using short-lived AppRole/OIDC tokens) hands out a short-lived token per build rather than a long-lived static password baked into the Jenkinsfile or repo.

### 5. Use short-lived, dynamically generated secrets where possible
Rather than static passwords rotated manually, HashiCorp Vault (and AWS Secrets Manager) can issue **dynamic secrets** — e.g., a database credential generated on demand with a short TTL, unique per pipeline run, and automatically revoked after expiry. This drastically reduces the value of a leaked credential and removes manual rotation overhead entirely.

### 6. Rotation policy
- Static secrets that can't go dynamic (API keys for third-party SaaS, etc.) should have an enforced rotation cadence (e.g., 90 days) tracked centrally, not per-team spreadsheets.
- Vault password/AppRole credentials used to unlock Ansible Vault or the secrets backend should themselves be rotated and never committed anywhere, including CI logs.

### 7. Audit logging
Enterprise secret managers log every read: who/what accessed which secret, when, from which pipeline/IP. This is usually a compliance requirement (SOC2/ISO27001) and is something static `ansible-vault` files can't give you — a decrypted vault file leaves no record of who actually read which value once it's on disk.

### 8. Keep Git clean regardless of approach
- Add pre-commit hooks / `git-secrets` or `detect-secrets` scanning in the pipeline to catch accidentally committed plaintext secrets before merge.
- Never log decrypted variables — set `no_log: true` on any task handling secret values so they don't leak into Jenkins console output.

```yaml
- name: Configure database connection
  ansible.builtin.template:
    src: db.conf.j2
    dest: /etc/myapp/db.conf
  no_log: true
```

### Summary — small scale vs enterprise scale

| | Small team | Enterprise, many teams/pipelines |
|---|---|---|
| Secret storage | `ansible-vault` encrypted file in repo | External secrets manager (Vault/AWS Secrets Manager/Azure Key Vault) |
| Access control | One shared vault password | Per-team paths/policies enforced by the secrets backend itself |
| Credential lifetime | Long-lived, manually rotated | Short-lived, often dynamically generated per pipeline run |
| CI/CD integration | Vault password stored as one Jenkins credential | Per-pipeline scoped tokens (AppRole/OIDC) via Jenkins Credentials/Vault plugin |
| Audit trail | None (decrypted file, no access log) | Full access logging per secret, per identity, per timestamp |
| Git hygiene | Encrypted file committed | Nothing sensitive touches Git; secret-scanning hooks as a safety net |

---

# Top 20 Scenario-Based Interview Questions

**1. What is the difference between a playbook and a role, and when do you use each?**
> Playbook = single YAML file of tasks for a specific job. Role = reusable, structured directory (tasks/handlers/templates/vars) used across multiple playbooks/projects — use roles once logic needs to be shared or grows beyond one file.

**2. What happens if you run the same Ansible playbook twice? How do you guarantee this behavior?**
> Idempotent tasks (package, file, service modules) produce no change on the second run. Guarantee it by avoiding raw `shell`/`command` for state changes, or by adding `creates`/`changed_when` to make custom commands idempotent.

**3. How does Ansible handle a failure across a multi-host run, and how do you control it?**
> By default, a failed host drops out of the play but others continue. Control it with `ignore_errors`, `block/rescue`, or `max_fail_percentage` for batch tolerance.

**4. `copy` vs `template` — when would each cause a production bug if used wrong?**
> Using `copy` for a config that needs environment-specific values (ports, hostnames) ships the same static file everywhere — breaks per-environment configs. `template` renders Jinja2 first, so it's the right choice for env-specific files.

**5. How do you pass secrets to Ansible without ever storing them in plaintext in Git?**
> `ansible-vault` for encrypted files/strings; in production, dynamically pull from AWS Secrets Manager / HashiCorp Vault via `lookup()` instead of committing anything.

**6. `import_tasks` vs `include_tasks` — give a real scenario where the choice matters.**
> If the task file to run depends on a variable (e.g., per-OS install steps), you must use `include_tasks` (runtime). If you need tags/conditionals applied uniformly across all included tasks, use `import_tasks` (parse-time).

**7. Your playbook run against 200 servers is too slow. How do you speed it up?**
> Enable SSH pipelining, set `gathering: smart` / disable facts when not needed, increase `forks`, use async for long tasks, and enable fact caching (`fact_caching = jsonfile`).

**8. When would you use `delegate_to`, with a concrete example?**
> Deregistering a server from a load balancer before deploying to it — the deregister task runs on the LB host (`delegate_to: loadbalancer.example.com`) even though the play targets the app servers.

**9. When would you introduce Ansible Tower/AWX into a team that's currently running raw `ansible-playbook`?**
> Once multiple people need to trigger runs — Tower/AWX adds RBAC, scheduling, credential management, and audit trails that raw CLI usage lacks.

**10. How do you achieve a zero-downtime rolling deployment with Ansible?**
> `serial` to batch hosts (e.g., 1 or 25% at a time), a health-check (`uri` module) after each batch before moving to the next, and `max_fail_percentage` to abort if too many batches fail.

**11. How would you set up a blue/green deployment with Ansible?**
> Maintain two identical environments; deploy to the idle one (green), validate via health checks, then switch the load balancer's target group to green — old (blue) stays as instant rollback.

**12. How do you enforce GitOps principles using Ansible?**
> Store the desired state (playbooks/inventory/vars) in Git as the single source of truth; playbooks reconcile actual infrastructure state against Git and detect/correct drift on each run.

**13. How do you manage secrets at enterprise scale across many teams/pipelines?**
> External secret managers (Vault/AWS Secrets Manager) fetched at runtime, never logged or written to disk, with RBAC controlling which pipeline/team can access which secret path.

**14. How do you let multiple teams work on the same Ansible codebase without stepping on each other?**
> Separate roles per service/team, shared common roles, environment-specific `group_vars`, mandatory code review, and RBAC/branch protections — avoids accidental overwrites.

**15. How would you build self-healing infrastructure with Ansible?**
> Combine facts/monitoring integration to detect drift or failed services, then trigger playbooks automatically (via event-driven automation or a scheduler) to restart services or reprovision unhealthy nodes without manual intervention.

**16. How do you apply immutable infrastructure practices using a tool that's traditionally about in-place config?**
> Instead of patching running servers, use Ansible to build and validate a new instance/image with the updated config, then swap it in and decommission the old one — avoids config drift entirely.

**17. How would you manage a hybrid environment with some servers on-prem and some in the cloud?**
> Combine dynamic inventory (cloud) with static/on-prem inventory groups, use `delegate_to` and connection plugins as needed, and abstract environment differences with variables so the same playbook targets both.

**18. How do you test that your disaster recovery plan actually works, using Ansible?**
> Automate failover simulation (shift traffic to a secondary region), restore from backups, and run validation playbooks to confirm the app is healthy — do this on a schedule, not just once.

**19. Your inventory has grown to thousands of hosts and runs are getting unmanageable — what do you change?**
> Move to dynamic inventory with caching, group hosts logically, use tags for selective runs, and lean on delegation/async so the control node isn't a bottleneck.

**20. Walk me through a full pipeline: someone merges code, and it ends up running in production. Where does Ansible fit?**
> CI pipeline (GitHub Actions/Jenkins) triggers on merge → Terraform provisions/updates infra if needed → Ansible playbook runs against the new/existing inventory to deploy the app, using vault-stored secrets and a rolling/`serial` strategy with health checks → dry-run (`--check`) gates prod for risky changes.

---

*Trimmed for interview efficiency — pair this with hands-on practice on your capstone project so you can back every answer with "and here's how I actually did this."*
