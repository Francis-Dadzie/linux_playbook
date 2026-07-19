# ansible automation

Ansible roles for provisioning, hardening, and monitoring servers in a mixed-OS environment.

**nodes:** Ubuntu 26.04, Rocky Linux 10.2, CentOS Stream 10

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

## Playbooks

| Playbook | Purpose |
|---|---|
| `setup.yml` | Full infrastructure provisioning across all managed nodes |
| `monitoring.yml` | Deploys monitoring stack |
| `ping-facts.yml` | Connectivity and facts check |

Run the playbooks:

```bash
# Infrastructure
ansible-playbook playbooks/setup.yml --ask-become-pass -u <user> --private-key ~/.ssh/id_ed25519

# Monitoring
ansible-playbook playbooks/monitoring.yml --ask-become-pass -u <user> --private-key ~/.ssh/id_ed25519

# Connectivity check
ansible-playbook playbooks/ping-facts.yml
```

## Monitoring

| Service | URL | Notes |
|---|---|---|
| Grafana | `http://<control-node-ip>:3000` | Login: admin / password |
| Prometheus | `http://<control-node-ip>:9091` | No login |
| Node Exporter | `http://<node-ip>:9100/metrics` | Metrics endpoint |

The Node Exporter Full dashboard (Grafana ID `1860`) can be imported via **Dashboards → New → Import**.

<img width="1718" height="1011" alt="Grafana dashboard" src="https://github.com/user-attachments/assets/c31e1c6d-d25f-47b6-a1ce-6c3200df4467" />

---

## Notes

- Password authentication is disabled on all nodes after `ssh_hardening` runs — confirm SSH key access works before the first run


