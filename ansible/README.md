# ansible-linux-automation

Ansible roles for provisioning, hardening, and monitoring Linux servers in a mixed-OS environment. Built as part of my transition into Linux/platform engineering.

**Tested on:** Ubuntu 26.04, Rocky Linux 10.2
**Control node:** CentOS Stream 10

---

## Roles

### Infrastructure

| Role | Purpose |
|---|---|
| `common` | Baseline packages, timezone, MOTD |
| `chrony` | NTP time synchronisation |
| `users` | User creation, sudo, SSH keys |
| `ssh_hardening` | Hardens sshd_config |
| `firewall` | ufw (Ubuntu) / firewalld (Rocky) |
| `fail2ban` | SSH brute force protection |
| `auditd` | Kernel-level audit logging |
| `logrotate` | Log rotation |

### Monitoring

| Role | Purpose |
|---|---|
| `node_exporter` | Exposes system metrics on port 9100 (all managed nodes) |
| `prometheus` | Scrapes metrics from all nodes, runs on control node |
| `grafana` | Visualises metrics via Prometheus datasource, runs on control node |

---

## Playbooks

| Playbook | Purpose |
|---|---|
| `env.yml` | Full infrastructure provisioning across all managed nodes |
| `monitoring.yml` | Deploys monitoring stack |
| `ping-facts.yml` | Connectivity and facts check |

---

## Setup

Install required collections:

```bash
ansible-galaxy collection install community.general ansible.posix
```

Update `inventory/hosts.ini` with your node IPs:

```ini
[ubuntu]
node1 ansible_host=<ip>
node3 ansible_host=<ip>

[rocky]
node2 ansible_host=<ip>

[linux:children]
ubuntu
rocky

[control]
control-node ansible_host=127.0.0.1 ansible_connection=local
```

Create a host vars file for the control node to set the Grafana admin password:

```bash
mkdir -p host_vars
nano host_vars/control-node.yml
```

```yaml
---
grafana_admin_password: 'your-secure-password'
```

Run the playbooks:

```bash
# Infrastructure
ansible-playbook playbooks/env.yml --ask-become-pass -u <user> --private-key ~/.ssh/id_ed25519

# Monitoring
ansible-playbook playbooks/monitoring.yml --ask-become-pass -u <user> --private-key ~/.ssh/id_ed25519

# Connectivity check
ansible-playbook playbooks/ping-facts.yml
```

---

## Monitoring Access

| Service | URL | Notes |
|---|---|---|
| Grafana | `http://<control-node-ip>:3000` | Login: admin / your password |
| Prometheus | `http://<control-node-ip>:9091` | No login required |
| Node Exporter | `http://<node-ip>:9100/metrics` | Raw metrics endpoint |

The Node Exporter Full dashboard (Grafana ID `1860`) can be imported via **Dashboards → New → Import**.

---

## Notes

- Password authentication is disabled on all nodes after `ssh_hardening` runs — confirm SSH key access works before the first run
- Audit rules are set to immutable (`-e 2`) — rule changes require a reboot
- The `ansible` service account uses a dedicated SSH key with scoped sudo
- SELinux is enforcing on the control node — the `grafana` role configures the required boolean to allow outbound connections to Prometheus
- No credentials or keys are stored in this repository

---

## Disclaimer

Some roles were developed with AI assistance. All code has been reviewed, tested, and adapted to fit my own requirements and understanding. I can explain every design decision used.

---

## Author

Finn — aspiring Linux/platform engineer.
