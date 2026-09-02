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
