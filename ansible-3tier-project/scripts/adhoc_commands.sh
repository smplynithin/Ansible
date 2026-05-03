#!/bin/bash
# ============================================================
# scripts/adhoc_commands.sh — Ad-hoc Command Reference
# TOPIC COVERED: Ad-hoc commands (one-off tasks without a playbook)
#
# Syntax: ansible <hosts> -m <module> -a "<arguments>" [options]
#
# When to use ad-hoc:
#   - Quick checks (is service running? disk space?)
#   - Emergency tasks (restart service NOW)
#   - Testing connectivity before running playbook
#   - One-time data gathering
# ============================================================

# ── CONNECTIVITY ────────────────────────────────────────────

# Test SSH connectivity to all hosts
ansible all -m ping

# Test only webservers
ansible webservers -m ping

# Use a specific inventory file
ansible all -i inventories/hosts.ini -m ping

# ── INFORMATION GATHERING ───────────────────────────────────

# Gather ALL facts about a host
ansible web01 -m setup

# Filter specific facts
ansible all -m setup -a "filter=ansible_default_ipv4"
ansible all -m setup -a "filter=ansible_memory_mb"
ansible all -m setup -a "filter=ansible_distribution*"

# Check disk space
ansible all -m shell -a "df -h"

# Check memory
ansible all -m shell -a "free -h"

# ── PACKAGE MANAGEMENT ──────────────────────────────────────

# Install a package on all webservers
ansible webservers -m apt -a "name=nginx state=present" --become

# Remove a package
ansible webservers -m apt -a "name=telnet state=absent" --become

# Update all packages (careful in production!)
ansible all -m apt -a "upgrade=dist update_cache=yes" --become

# ── FILE OPERATIONS ─────────────────────────────────────────

# Copy a file to all servers
ansible all -m copy -a "src=/local/file.conf dest=/remote/file.conf mode=0644" --become

# Create a directory
ansible all -m file -a "path=/opt/myapp state=directory mode=0755 owner=ubuntu" --become

# Delete a file
ansible all -m file -a "path=/tmp/oldfile state=absent" --become

# ── SERVICE MANAGEMENT ──────────────────────────────────────

# Restart nginx on all webservers
ansible webservers -m service -a "name=nginx state=restarted" --become

# Check if service is running
ansible all -m service -a "name=postgresql state=started" --become

# ── RUNNING COMMANDS ────────────────────────────────────────

# Run a shell command (use command module when possible — safer)
ansible all -m command -a "uptime"

# Shell module supports pipes and redirects
ansible all -m shell -a "ps aux | grep java"

# ── USER MANAGEMENT ─────────────────────────────────────────

# Create a user on all servers
ansible all -m user -a "name=devops shell=/bin/bash state=present" --become

# ── DEBUGGING ───────────────────────────────────────────────

# Verbose output (-v, -vv, -vvv)
ansible all -m ping -vvv

# Check mode (--check): shows WHAT WOULD happen, makes no changes
ansible all -m apt -a "name=vim state=present" --check

# Limit to one host
ansible all -m ping --limit web01

# Limit to a comma-separated list
ansible all -m ping --limit "web01,app01"
