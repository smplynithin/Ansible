# 🚀 Ansible 3-Tier Web App Project
## Complete reference for 3-year experienced DevOps Engineer

---

## 📁 Project Structure

```
ansible-3tier-project/
│
├── ansible.cfg                    # Global config, SSH, performance
│
├── inventories/
│   ├── hosts.ini                  # Static inventory (groups + vars)
│   └── aws_ec2.yml                # Dynamic inventory (AWS EC2 plugin)
│
├── group_vars/
│   ├── all.yml                    # Variables for ALL hosts
│   ├── webservers.yml             # Variables only for webservers
│   ├── appservers.yml             # Variables only for app servers
│   └── dbservers.yml              # Variables only for DB servers
│
├── host_vars/
│   └── web01.yml                  # Variables only for web01
│
├── vault/
│   ├── secrets.yml                # Encrypted secrets (ansible-vault)
│   └── README.md                  # Vault usage guide
│
├── roles/
│   ├── common/                    # Applied to ALL servers
│   │   ├── tasks/main.yml         # packages, dirs, swap, sysctl, facts
│   │   ├── handlers/main.yml      # restart SSH, cron
│   │   ├── templates/             # appinfo.fact.j2
│   │   ├── defaults/main.yml      # lowest-priority defaults
│   │   └── meta/main.yml          # galaxy metadata, dependencies
│   │
│   ├── nginx/                     # Load balancer / web tier
│   │   ├── tasks/main.yml         # install, block/rescue, delegate_to
│   │   ├── handlers/main.yml      # start/reload/restart nginx
│   │   └── templates/nginx.conf.j2  # Jinja2: loops, conditionals
│   │
│   ├── tomcat/                    # Application tier
│   │   ├── tasks/main.yml         # java, user, download, deploy WAR
│   │   ├── handlers/main.yml      # restart tomcat, reload systemd
│   │   └── templates/             # setenv.sh, server.xml, systemd
│   │
│   └── postgres/                  # Database tier
│       ├── tasks/main.yml         # full block/rescue/always
│       ├── handlers/main.yml      # restart/reload postgres
│       └── templates/             # pg_hba.conf, postgresql.conf
│
├── site.yml                       # MASTER PLAYBOOK — runs everything
│
├── callback_plugins/
│   └── slack_notify.py            # Custom Slack failure notifications
│
├── molecule/
│   └── default/                   # Testing with Molecule
│       ├── molecule.yml            # Docker test config
│       ├── tasks/converge.yml      # Run role in test container
│       └── tests/verify.yml       # Assert role worked correctly
│
└── scripts/
    ├── adhoc_commands.sh          # Ad-hoc command reference
    └── awx_tower_guide.md         # AWX/Tower CI/CD guide
```

---

## 🎯 Topics → File Mapping (Quick Reference)

| Topic | File |
|---|---|
| `ansible.cfg` | `ansible.cfg` |
| Static Inventory | `inventories/hosts.ini` |
| Dynamic Inventory (AWS) | `inventories/aws_ec2.yml` |
| `group_vars` + Variables | `group_vars/*.yml` |
| `host_vars` | `host_vars/web01.yml` |
| Ansible Vault | `vault/secrets.yml` |
| Modules: `apt`, `file`, `copy`, `service` | `roles/common/tasks/main.yml` |
| Modules: `template`, `lineinfile`, `sysctl` | `roles/common/tasks/main.yml` |
| Modules: `get_url`, `unarchive`, `user` | `roles/tomcat/tasks/main.yml` |
| Modules: `postgresql_db`, `postgresql_user` | `roles/postgres/tasks/main.yml` |
| Loops (`loop`) | `roles/common/tasks/main.yml` |
| Conditions (`when`) + `register` | `roles/common/tasks/main.yml` |
| `set_fact` | `roles/tomcat/tasks/main.yml` |
| Handlers + `notify` | `roles/*/handlers/main.yml` |
| Jinja2 Templates + filters | `roles/nginx/templates/nginx.conf.j2` |
| Jinja2 for loop in template | `roles/postgres/templates/pg_hba.conf.j2` |
| `block` / `rescue` / `always` | `roles/nginx/tasks/main.yml` + `roles/postgres/tasks/main.yml` |
| `ignore_errors` | `roles/common/tasks/main.yml` |
| `no_log: true` | `roles/postgres/tasks/main.yml` |
| `delegate_to` + `run_once` | `roles/nginx/tasks/main.yml` |
| Custom Facts | `roles/common/tasks/main.yml` + `templates/appinfo.fact.j2` |
| Role meta + Galaxy | `roles/common/meta/main.yml` |
| Tags | every `tasks/main.yml` |
| Strategy: `serial`, `linear`, `free` | `site.yml` |
| `pre_tasks` + `post_tasks` | `site.yml` |
| `until` + `retries` (health check) | `site.yml` |
| `wait_for` | `site.yml` |
| `assert` | `site.yml` |
| Callbacks (Slack) | `callback_plugins/slack_notify.py` |
| Molecule Testing | `molecule/` |
| Ad-hoc Commands | `scripts/adhoc_commands.sh` |
| AWX/Tower CI/CD | `scripts/awx_tower_guide.md` |

---

## ⚡ Quick Start Commands

```bash
# 1. Setup SSH key distribution
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/my-key.pem

# 2. Test connectivity
ansible all -i inventories/hosts.ini -m ping

# 3. View dynamic inventory
ansible-inventory -i inventories/aws_ec2.yml --graph

# 4. Dry run (no changes)
ansible-playbook site.yml --check --diff --ask-vault-pass

# 5. Full deploy
ansible-playbook site.yml --ask-vault-pass

# 6. Only configure nginx
ansible-playbook site.yml --tags nginx --ask-vault-pass

# 7. Test your common role with Molecule
cd roles/common
molecule test

# 8. Lint and validate
ansible-lint site.yml
yamllint .
```

---

## 📚 Ansible Interview Cheat Sheet

**Q: Difference between `command` and `shell` module?**
A: `command` = safer, no shell features (no pipes/redirects). `shell` = full bash, supports pipes.

**Q: When do handlers run?**
A: At the END of each play, only if notified. Even if notified 10 times — runs once.

**Q: Difference between `vars`, `defaults`, `group_vars` in priority?**
A: defaults < group_vars/all < group_vars/group < host_vars < playbook vars < extra_vars (-e)

**Q: What is `register`?**
A: Captures a task's output into a variable for use in later tasks.

**Q: What is `delegate_to`?**
A: Runs a task on a DIFFERENT host than the current loop host.

**Q: Difference between `serial` and `strategy: free`?**
A: `serial` controls how many hosts in a batch. `strategy: free` lets each host advance independently.

**Q: How does Ansible Vault work?**
A: Encrypts files with AES-256. You reference encrypted vars normally; pass password at runtime.
