# ============================================================
# callback_plugins/slack_notify.py — Custom Callback Plugin
# TOPIC COVERED: Callbacks (notify on events)
#
# Callbacks = hooks that fire on Ansible events
# Built-in callbacks: yaml, json, minimal, debug, timer
# Custom callbacks: YOU write Python to handle events
#
# This plugin sends Slack DM when a play FAILS
#
# Enable in ansible.cfg:
#   [defaults]
#   callback_plugins = ./callback_plugins
#   callbacks_enabled = slack_notify
# ============================================================

from ansible.plugins.callback import CallbackBase
import json
try:
    import urllib.request as urllib2
except ImportError:
    import urllib2


class CallbackModule(CallbackBase):
    """
    Sends Slack notification when hosts fail.
    """
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'slack_notify'
    CALLBACK_NEEDS_WHITELIST = True

    def __init__(self):
        super(CallbackModule, self).__init__()
        self.failed_hosts = []

    def v2_runner_on_failed(self, result, ignore_errors=False):
        """Fires when a task fails on a host."""
        host = result._host.get_name()
        task = result._task.get_name()
        self.failed_hosts.append({'host': host, 'task': task})

    def v2_playbook_on_stats(self, stats):
        """Fires at the end of the playbook — send summary."""
        if not self.failed_hosts:
            return   # nothing to report

        msg = "❌ *Ansible Playbook FAILED*\n"
        for item in self.failed_hosts:
            msg += f"  • Host: `{item['host']}` | Task: `{item['task']}`\n"

        # Post to Slack
        # (In production, read webhook from env var: os.environ.get('SLACK_WEBHOOK'))
        webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
        payload = json.dumps({"text": msg}).encode('utf-8')
        req = urllib2.Request(webhook_url, payload,
                              {'Content-Type': 'application/json'})
        try:
            urllib2.urlopen(req, timeout=5)
        except Exception:
            pass   # never let notification failure break the playbook
