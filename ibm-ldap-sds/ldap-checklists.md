# IBM LDAP Administrator — Checklists

Two checklists for IBM Security Directory Server (SDS/LDAP) administrators on AIX:

1. **Onboarding Checklist** — what to learn, set up, and document when you first join
2. **Daily Ops Checklist** — what to check, verify, and action every day

---

# Part 1: Onboarding Checklist

Use this during your first 30–90 days. The goal is to build a complete picture of the environment before you touch anything.

---

## Week 1 — Orient & Observe

### Access & Credentials
- [ ] Confirm your AIX user account is created and accessible
- [ ] Confirm SSH key-based access is set up to all LDAP servers
- [ ] Confirm you have access to the IBM SDS admin console (web or CLI)
- [ ] Confirm your ServiceNow account is active and you are assigned to the correct team/queue
- [ ] Identify who grants emergency/root access and what the process is
- [ ] Locate the password vault (CyberArk, Thycotic, etc.) and confirm access
- [ ] Confirm read/write access to shared documentation (Confluence, SharePoint, etc.)

### Understand the Landscape
- [ ] Get a list of all LDAP server hostnames, IPs, and their roles (primary, replica, proxy)
- [ ] Understand the replication topology — draw or obtain a diagram
- [ ] Identify the LDAP suffix (base DN) in use — e.g., `dc=example,dc=com`
- [ ] Identify the admin DN and where credentials are stored
- [ ] Understand which applications and services authenticate against LDAP (get the full consumer list)
- [ ] Understand which teams own the consuming applications (so you know who to notify during outages)
- [ ] Locate the IBM SDS installation directory — typically `/opt/IBM/ldap/V6.4/`
- [ ] Understand the AIX version and patch level on each LDAP server (`oslevel -s`)

### Documentation Review
- [ ] Read all existing runbooks and SOPs in ServiceNow knowledge base
- [ ] Review previous incident tickets — look for recurring patterns
- [ ] Review change records for the past 3–6 months
- [ ] Locate the disaster recovery (DR) and backup documentation
- [ ] Identify the escalation path (L1 → L2 → L3 → IBM support)
- [ ] Confirm you have IBM support contract details and know how to raise a PMR/case

---

## Week 2–3 — Explore the Environment

### LDAP Configuration
- [ ] Review `ibmslapd.conf` — understand all configured backends, overlays, and options
- [ ] Review the DB2 database configuration if using DB2 backend (check `db2 get dbm cfg`)
- [ ] Understand the schema in use — note custom object classes and attributes
- [ ] Identify all LDAP ACLs (Access Control Lists) — understand who can read/write what
- [ ] Understand password policy configuration (`ibm-slapdPwdPolicy`)
- [ ] Identify SSL/TLS configuration — certificate store location, expiry dates
- [ ] Identify the ports in use (default: 389 for LDAP, 636 for LDAPS, 3389 for admin)
- [ ] Review the replication agreement configuration (`cn=replication,cn=ibmpolicies`)

### Storage & Performance
- [ ] Check filesystem layout for LDAP data (`lsvg`, `lslv`, `df -g`)
- [ ] Identify where the LDAP database files are stored (default: `/var/ldap/`)
- [ ] Identify where logs are written and confirm log rotation is configured
- [ ] Review current DB2 buffer pool and memory allocation settings
- [ ] Note current index configuration — missing indexes are the #1 cause of slow searches
- [ ] Baseline current performance: run a sample search and note response time

### Monitoring & Alerting
- [ ] Identify the monitoring tool in use (Grafana, Splunk, Nagios, etc.)
- [ ] Confirm LDAP-specific dashboards exist and you have access
- [ ] Understand which alerts are configured and who they notify
- [ ] Confirm you are on the on-call/alert notification list
- [ ] Identify any existing health check scripts and where they run from

**If dashboards don't exist yet, these are the metrics to configure:**

| Metric | Source | Alert Threshold |
|--------|--------|-----------------|
| Service up/down | `lssrc -s ibmslapd` | Any down state |
| Active connections | `cn=Monitor` → `ibm-slapdCurrentConnections` | >80% of `ibm-slapdMaxConnections` |
| Search response time (etime) | `ibmslapd.log` → `etime=` field | >500ms average |
| Replication pending changes | `ibm-replicationPendingChangeCount` | >1000 entries |
| Replication last activation | `ibm-replicationLastActivationTime` | >15 min behind current time |
| Failed bind attempts | `ibmslapd.log` → result code 49 | Spike above baseline |
| Disk usage on `/var/ldap` | `df -g` | >80% |
| DB2 buffer pool hit ratio | `db2 get snapshot for database` | <95% |
| Certificate expiry (days remaining) | `gsk8capicmd_64 -cert -details` | <60 days |
| Error log rate | `grep -c ERROR /var/ldap/ibmslapd.log` | >10 new errors/hour |

**For Splunk:** ingest `/var/ldap/ibmslapd.log` and `/var/ldap/ibm_audit.log` using a universal forwarder. Key search: `index=ldap sourcetype=ibm_slapd "resultCode: 49"` for failed binds.

**For Grafana:** use the Prometheus LDAP exporter or a custom script that queries `cn=Monitor` and exposes metrics on a scrape endpoint.

### Security Review
- [ ] Confirm TLS 1.2 or higher is enforced (no SSLv3/TLS 1.0)
- [ ] Review certificate expiry dates — flag anything expiring within 90 days
- [ ] Confirm anonymous bind is disabled (unless explicitly required)
- [ ] Review which accounts have admin-level LDAP access
- [ ] Confirm audit logging is enabled in SDS

---

## Week 4 — Hands-On Familiarisation

### Operational Tasks (Read-Only First)
- [ ] Run the LDAP health check command: `ibm_ldap_monitor` or equivalent
- [ ] Execute a test search: `ldapsearch -h host -p 389 -D "cn=admin" -w pass -b "dc=example,dc=com" "(uid=testuser)"`
- [ ] Check replication status: `ldapsearch ... -b "cn=Monitor" "(cn=replication)"`
- [ ] Review current active connections in SDS admin console
- [ ] Review the error log for recent warnings or errors
- [ ] Check DB2 health if applicable: `db2 get snapshot for database on LDAPDB`

### Practice Tasks (in a non-prod environment)
- [ ] Add a test user entry via `ldapadd`
- [ ] Modify an attribute via `ldapmodify`
- [ ] Delete the test user via `ldapdelete`
- [ ] Export the LDAP directory via `db2ldif` or `ldapsearch -LLL > export.ldif`
- [ ] Import a test LDIF file via `ldapadd` or `bulkload`
- [ ] Practice a certificate renewal on a test keystore using `gsk8capicmd_64`
- [ ] Start/stop/restart the LDAP service using SRC: `stopsrc -s ibmslapd` / `startsrc -s ibmslapd`

### Documentation You Should Create/Update
- [ ] Document the replication topology if a diagram doesn't exist
- [ ] Document all certificate expiry dates in a tracked register
- [ ] Document the backup schedule and verify a test restore has been done recently
- [ ] Create your own runbook entry in ServiceNow for any procedure that wasn't documented
- [ ] Update the consumer application inventory if it was outdated

---

# Part 2: Daily Ops Checklist

Run through this every working day. Most items take seconds once you know the commands.

---

## 🟢 Morning Checks (First 30 Minutes)

### 1. Service Health
- [ ] Confirm LDAP service is running on all servers
  ```bash
  lssrc -s ibmslapd
  ```
- [ ] Confirm admin server is running
  ```bash
  lssrc -s ibm-adminserver
  ```
- [ ] Check listening ports are active
  ```bash
  netstat -an | grep -E "389|636|3389"
  ```

### 2. Connectivity Test
- [ ] Run a test LDAP search against each server (primary + replicas)
  ```bash
  ldapsearch -h <server> -p 389 -D "cn=admin,dc=example,dc=com" \
    -w <password> -b "dc=example,dc=com" -s base "(objectclass=*)"
  ```
- [ ] Confirm response time is within normal range (note if unusually slow)

### 3. Replication Status
- [ ] Check replication is in sync across all replicas
  ```bash
  ldapsearch -h <server> -p 389 -D "cn=admin" -w <pass> \
    -b "cn=Monitor" "(cn=replication)" ibm-replicationLastActivationTime
  ```
- [ ] Confirm no replication errors in the log
  ```bash
  grep -i "repl" /var/ldap/ibmslapd.log | grep -i "error\|fail" | tail -20
  ```

### 4. Error Log Review
- [ ] Check the LDAP error log for new issues since yesterday
  ```bash
  grep -iE "error|warning|critical|fail" /var/ldap/ibmslapd.log | \
    awk -v d="$(date -v-1d '+%Y%m%d' 2>/dev/null || date --date='yesterday' '+%Y%m%d')" '$0 ~ d' | tail -50
  ```
- [ ] Check AIX system error report
  ```bash
  errpt | head -30
  ```

### 5. Certificate Expiry
- [ ] Check certificate expiry (flag anything within 60 days)
  ```bash
  gsk8capicmd_64 -cert -list -db /etc/ldap/key.kdb -pw <password>
  # Then detail per cert:
  gsk8capicmd_64 -cert -details -label "<cert_label>" -db /etc/ldap/key.kdb -pw <password>
  ```

---

## 🔵 Throughout the Day

### 6. ServiceNow Queue
- [ ] Review open tickets assigned to the team
- [ ] Update tickets with progress notes
- [ ] Close resolved tickets with resolution notes and KM doc references
- [ ] Identify any tickets requiring change requests (CRs) and raise them if needed

#### Change Management Process (for any planned production change)

Any non-emergency change to a production LDAP server — config edits, certificate renewals, patches, schema changes, adding replicas — must go through a change request before it is touched.

| Step | Action |
|------|--------|
| **1. Raise CR** | Open a Change Request in ServiceNow with description, risk, rollback plan, and maintenance window |
| **2. Risk assessment** | Classify as Standard (pre-approved, low-risk), Normal (requires CAB approval), or Emergency (break-fix, post-hoc approval) |
| **3. CAB review** | Normal changes are reviewed by the Change Advisory Board — submit at least 5 business days before the window |
| **4. Notify consumers** | Email or Slack the teams who own apps that authenticate against LDAP — they need to know about any potential disruption |
| **5. Implement** | Make the change only within the approved window, with a second pair of eyes where possible |
| **6. Verify** | Run the morning health checks immediately after the change — service up, replication active, test bind passes |
| **7. Close CR** | Update the CR with what was done, actual vs planned time, and any deviations. Link to KM article if a new procedure was followed |

**Rollback triggers:** If any health check fails after a change and cannot be resolved within 15 minutes, execute the rollback plan documented in the CR before the window ends.

### 7. Monitoring Dashboard
- [ ] Review Grafana/Splunk dashboards for any anomalies
  - LDAP search response time
  - Active connection count
  - Replication lag
  - Error rate
  - CPU/memory on LDAP servers
- [ ] Investigate any alerts that fired overnight or earlier in the day

### 8. User Management Requests
- [ ] Process approved user add/modify/delete requests from ticket queue
  ```bash
  # Add user
  ldapadd -h host -D "cn=admin,dc=example,dc=com" -w pass -f newuser.ldif

  # Modify user attribute
  ldapmodify -h host -D "cn=admin,dc=example,dc=com" -w pass -f modify.ldif

  # Delete user
  ldapdelete -h host -D "cn=admin,dc=example,dc=com" -w pass "uid=user,ou=People,dc=example,dc=com"
  ```
- [ ] Verify the change replicated to all replicas after applying

---

## 🟡 End of Day Checks

### 9. Backup Verification
- [ ] Confirm today's backup job completed successfully (check job logs or monitoring)
  ```bash
  # Check backup log
  tail -50 /var/ldap/backup/backup.log

  # Verify backup file exists and has today's date
  ls -lh /var/ldap/backup/ | grep "$(date +%Y%m%d)"
  ```

### 10. Performance Review
- [ ] Check DB2 performance snapshot if applicable
  ```bash
  db2 get snapshot for database on LDAPDB | grep -i "sort\|buffer\|deadlock"
  ```
- [ ] Check for long-running queries or connection pile-up
  ```bash
  ldapsearch -h host -p 3389 -D "cn=admin" -w pass \
    -b "cn=Monitor" "(objectclass=*)" ibm-slapdCurrentConnections ibm-slapdTotalConnections
  ```

### 11. Log Rotation & Disk Space
- [ ] Confirm log files are rotating correctly (no unexpectedly large log files)
  ```bash
  ls -lh /var/ldap/*.log
  df -g /var/ldap
  ```
- [ ] Confirm disk usage is below 80% on all LDAP-related filesystems
  ```bash
  df -g | awk 'NR>1 && $4+0 > 80 {print "WARNING: " $0}'
  ```

### 12. Weekly Status Report (Fridays)
- [ ] Compile the week's activity: tickets closed, changes made, incidents, findings
- [ ] Note any recurring issues or trends
- [ ] Note upcoming certificate renewals, maintenance windows, or planned changes
- [ ] Submit report to team lead / manager using the template below

#### Weekly Status Report Template

```
Weekly LDAP Admin Status Report — Week ending <DATE>

Incidents:
- INC#: <brief description> → <resolution> → RCA documented? Y/N

Requests Completed:
- <count> user additions
- <count> password resets
- <count> service accounts created
- <other notable requests>

Changes Completed:
- CHG#: <description and outcome>

Upcoming:
- CHG#: <planned change, date, window>
- Certificate on <server> expires <date> — renewal status: <in progress / not started>

Observations / Trends:
- <recurring incident patterns, performance trends, risks to flag>
```

---

## 🔴 Incident Response Quick Reference

| Symptom | First Check | Command |
|---------|-------------|---------|
| LDAP not responding | Is the service running? | `lssrc -s ibmslapd` |
| Slow search responses | DB2 buffer pool / indexes | `db2 get snapshot for database on LDAPDB` |
| Replication lag | Replication errors in log | `grep -i "repl.*error" /var/ldap/ibmslapd.log` |
| Auth failures spiking | Password policy / account lockout | `ldapsearch ... "(ibm-pwdAccountLocked=true)"` |
| Disk space alert | Log files or DB growth | `df -g` then `du -sm /var/ldap/*` |
| Certificate error | Cert expiry / misconfig | `gsk8capicmd_64 -cert -list -db key.kdb -pw pass` |
| High CPU on LDAP server | Runaway search / unindexed attribute | `topas` then check `ibmslapd.log` for slow ops |
| Consumer app auth broken | Check LDAP bind account is not locked | `ldapsearch ... -D "cn=appbind" -w pass "(uid=test)"` |

### Worked Example: Application Bind Account Lockout

One of the most common incidents — an application suddenly can't authenticate and users are locked out of a consuming system (ERP, VPN, middleware).

**Step 1: Reproduce the failure with the app's bind account**
```bash
ldapsearch -h ldap-primary-01 -p 389 \
  -D "cn=appbind,ou=ServiceAccounts,dc=example,dc=com" \
  -w "$APP_BIND_PASS" \
  -b "dc=example,dc=com" -s base "(objectclass=*)"
```
If this returns `LDAP_INVALID_CREDENTIALS`, the account is locked or the password has drifted.

**Step 2: Check the account status as admin**
```bash
ldapsearch -h ldap-primary-01 -p 389 \
  -D "cn=root,dc=example,dc=com" -w "$LDAP_ADMIN_PASS" \
  -b "cn=appbind,ou=ServiceAccounts,dc=example,dc=com" \
  "(objectclass=*)" ibm-pwdAccountLocked ibm-pwdLastLogonTime
```

**Step 3a: Unlock if locked**
```bash
ldapmodify -h ldap-primary-01 -p 389 \
  -D "cn=root,dc=example,dc=com" -w "$LDAP_ADMIN_PASS" << EOF
dn: cn=appbind,ou=ServiceAccounts,dc=example,dc=com
changetype: modify
delete: ibm-pwdAccountLocked
EOF
```

**Step 3b: Reset password if drifted (confirm new password with app team first)**
```bash
ldapmodify -h ldap-primary-01 -p 389 \
  -D "cn=root,dc=example,dc=com" -w "$LDAP_ADMIN_PASS" << EOF
dn: cn=appbind,ou=ServiceAccounts,dc=example,dc=com
changetype: modify
replace: userPassword
userPassword: <confirmed-new-password>
EOF
```

**Step 4: Verify and document**
- Confirm the app is authenticating again
- Document root cause in the ServiceNow ticket
- If this is a recurring pattern, raise a problem ticket and recommend migrating the bind account credentials to a vault with automated rotation

---

## ✅ Principles: What Makes a Good LDAP Admin

| Habit | Why It Matters |
|-------|---------------|
| Check replication every morning | Replication lag silently causes auth failures in consumer apps hours later |
| Track certificate expiry proactively | A surprise cert expiry takes down every app using LDAPS — simultaneously |
| Document every change in ServiceNow | Your future self and new colleagues will thank you at 2am |
| Never type bind account passwords manually | One typo locks a service account and can trigger an outage |
| Test changes on replicas before primary | If something goes wrong, the master keeps serving requests |
| Know your consumer applications | When LDAP has an issue, you need to notify the right teams fast |
| Baseline performance metrics | You can't spot degradation without knowing what normal looks like |
| Understand the schema before making changes | A bad schema change requires a full restart and possible data export to revert |
| Store service account credentials in a vault | Eliminates an entire class of lockout incidents |
| Write KM articles for every non-trivial resolution | Turns every incident into institutional knowledge for new joiners |

---

*Cross-reference: [aix-commands.md](./aix-commands.md) | [ibm-ldap-sds-reference.md](./ibm-ldap-sds-reference.md)*
