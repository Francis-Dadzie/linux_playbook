# OpenLDAP

Covers architecture, configuration, replication, TLS, access control, monitoring, and troubleshooting.

> **Installation:** Follow the official guide at https://www.openldap.org/doc/admin26/quickstart.html
---

## 1. Architecture & Components

```
┌──────────────────────────────────────────────┐
│                 OpenLDAP (slapd)              │
│                                              │
│  Frontend → Overlays → Backend               │
│             (ppolicy,   (mdb,                │
│              syncrepl,   monitor,            │
│              audit...)   config)             │
│                                              │
│                 Linux OS                     │
└──────────────────────────────────────────────┘
```

| Component | Description |
|-----------|-------------|
| **slapd** | The LDAP server daemon |
| **LMDB (mdb)** | Default storage backend — memory-mapped, fast, ACID-compliant |
| **cn=config** | Live configuration backend (OLC) — changes apply without restart |
| **cn=Monitor** | Read-only backend exposing runtime statistics |
| **Overlays** | Plugins that extend slapd behaviour — loaded per database |

### Common overlays

| Overlay | Purpose |
|---------|---------|
| `ppolicy` | Password policy (complexity, lockout, expiry) |
| `syncprov` | Enables server to act as replication provider |
| `auditlog` | Writes all changes to a plain-text audit log |
| `memberof` | Auto-maintains `memberOf` attribute on user entries |
| `refint` | Referential integrity — cleans up dangling DN references |
| `unique` | Enforces attribute uniqueness (e.g. no duplicate `uid`) |
| `accesslog` | Logs operations to a second queryable LDAP database |

---

## 2. Directory Layout on Disk

```
/etc/ldap/                         ← Config (Debian) or /etc/openldap/ (RHEL)
├── ldap.conf                      ← Client-side defaults (URI, BASE, TLS)
├── schema/                        ← Schema files
└── slapd.d/                       ← cn=config live config — DO NOT edit directly
    ├── cn=config.ldif
    └── cn=config/
        ├── cn=schema/
        └── olcDatabase={1}mdb,cn=config.ldif

/var/lib/ldap/                     ← LMDB database files
├── data.mdb
└── lock.mdb

/var/log/syslog or journald        ← slapd logs
```

> ** Directly editing `slapd.d/` break checksums and corrupt the config.** Make config changes via `ldapmodify` against `cn=config`.

---

## 3. Configuration — cn=config (OLC)

All configuration lives inside `cn=config`, modified using standard LDAP operations. No restart needed after a change.

### Authenticating to cn=config

```bash
# SASL EXTERNAL over the Unix socket — primary method, no password needed
ldapsearch -Y EXTERNAL -H ldapi:/// -b "cn=config"
```

### Initial setup

```bash
# Set hashed root password
HASHED=$(slappasswd -s YourAdminPassword)

# Set suffix and root DN on the directory database
ldapmodify -Y EXTERNAL -H ldapi:/// << EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=example,dc=com
-
replace: olcRootDN
olcRootDN: cn=admin,dc=example,dc=com
-
replace: olcRootPW
olcRootPW: $HASHED
EOF
```

---

## 4. cn=config Key Directives

### Global (`cn=config`)

| Directive | Description | Example |
|-----------|-------------|---------|
| `olcLogLevel` | Log verbosity | `stats` |
| `olcTLSCACertificateFile` | CA certificate path | `/etc/ldap/ssl/ca.crt` |
| `olcTLSCertificateFile` | Server certificate path | `/etc/ldap/ssl/server.crt` |
| `olcTLSCertificateKeyFile` | Private key path | `/etc/ldap/ssl/server.key` |
| `olcTLSProtocolMin` | Minimum TLS version | `3.3` (TLS 1.2) |
| `olcIdleTimeout` | Idle connection timeout (seconds) | `60` |

### Database (`olcDatabase={1}mdb,cn=config`)

| Directive | Description | Example |
|-----------|-------------|---------|
| `olcSuffix` | Directory suffix (base DN) | `dc=example,dc=com` |
| `olcRootDN` | Admin DN (bypasses ACLs) | `cn=admin,dc=example,dc=com` |
| `olcRootPW` | Admin password (hashed) | `{SSHA}...` |
| `olcDbDirectory` | Path to LMDB files | `/var/lib/ldap` |
| `olcDbMaxSize` | Max LMDB size in bytes | `1073741824` (1GB) |
| `olcDbIndex` | Attribute indexes | `uid eq` |
| `olcAccess` | Access control rules | see Section 8 |
| `olcSizeLimit` | Max entries returned per search | `500` |
| `olcTimeLimit` | Max seconds per search | `120` |

### Log levels

| Value | Meaning |
|-------|---------|
| `0` | No logging |
| `stats` | Connections, operations, results (production default) |
| `acl` | Access control decisions (ACL debugging) |
| `sync` | Replication sync operations |
| `-1` | All logging (development only — very verbose) |

```bash
# Change log level live
ldapmodify -Y EXTERNAL -H ldapi:/// << EOF
dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: stats
EOF
```

---

## 5. Core Admin Commands

Run as root or the `ldap` user. **Stop slapd first**

| Command | Description | slapd state |
|---------|-------------|-------------|
| `slaptest` | Validate configuration | Can run live |
| `slapcat` | Export directory to LDIF | Can run live (LMDB) |
| `slapadd` | Import LDIF into database | Stop slapd first |
| `slapindex` | Rebuild indexes | Stop slapd first |
| `slappasswd` | Generate hashed password | Any time |

```bash
# Validate config
slaptest -F /etc/ldap/slapd.d/ -v

# Export directory (backup)
slapcat -F /etc/ldap/slapd.d/ -b "dc=example,dc=com" \
  -l /var/backups/ldap/export_$(date +%Y%m%d).ldif

# Export cn=config
slapcat -F /etc/ldap/slapd.d/ -b "cn=config" \
  -l /var/backups/ldap/config_$(date +%Y%m%d).ldif

# Import LDIF (stop slapd first, fix ownership after)
systemctl stop slapd
slapadd -F /etc/ldap/slapd.d/ -b "dc=example,dc=com" -l /path/to/import.ldif
chown -R ldap:ldap /var/lib/ldap /etc/ldap/slapd.d
systemctl start slapd

# Rebuild indexes (stop slapd first)
systemctl stop slapd
slapindex -F /etc/ldap/slapd.d/ -b "dc=example,dc=com"
chown -R ldap:ldap /var/lib/ldap
systemctl start slapd

# Generate hashed password
slappasswd -s "MyPassword"            # outputs {SSHA}...
slappasswd -h {ARGON2} -s "MyPass"   # modern scheme
```

---

## 6. LDIF Operations

Standard client commands (`ldapsearch`, `ldapadd`, `ldapmodify`, `ldapdelete`) same syntax and LDIF format as any LDAP implementation.

```bash
# Bind via Unix socket (most powerful — no password)
ldapsearch -Y EXTERNAL -H ldapi:/// -b "cn=config"

# Bind via TCP
ldapsearch -H ldap://localhost -x \
  -D "cn=admin,dc=example,dc=com" -w password \
  -b "dc=example,dc=com" "(uid=finn)"

# LDAPS
ldapsearch -H ldaps://localhost \
  -D "cn=admin,dc=example,dc=com" -w password \
  -b "dc=example,dc=com" "(uid=finn)"

# StartTLS
ldapsearch -H ldap://localhost -Z \
  -D "cn=admin,dc=example,dc=com" -w password \
  -b "dc=example,dc=com" "(uid=finn)"
```

### Making live config changes via LDIF

```bash
# Add an index
ldapmodify -Y EXTERNAL -H ldapi:/// << EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: mail eq,sub
EOF

# Load an overlay
ldapadd -Y EXTERNAL -H ldapi:/// << EOF
dn: olcOverlay=memberof,olcDatabase={1}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcMemberOf
olcOverlay: memberof
olcMemberOfDangling: ignore
olcMemberOfRefInt: TRUE
olcMemberOfGroupOC: groupOfNames
olcMemberOfMemberAD: member
olcMemberOfMemberOfAD: memberOf
EOF
```

---

## 7. Schema Management

```bash
# List loaded schema
ldapsearch -Y EXTERNAL -H ldapi:/// \
  -b "cn=schema,cn=config" -s one "(objectclass=*)" cn

# View all object classes
ldapsearch -Y EXTERNAL -H ldapi:/// \
  -b "cn=schema,cn=config" "(objectclass=*)" olcObjectClasses

# Convert a .schema file to LDIF and load it
schema2ldif /etc/ldap/schema/custom.schema > /tmp/custom.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /tmp/custom.ldif
```

### Common bundled schema files

| Schema | Provides |
|--------|---------|
| `core.schema` | `top`, `alias`, `referral` |
| `cosine.schema` | `organization`, `organizationalUnit` |
| `inetorgperson.schema` | `inetOrgPerson` (uid, cn, mail, etc.) |
| `nis.schema` | `posixAccount`, `posixGroup`, `shadowAccount` |
| `ppolicy.schema` | `pwdPolicy` (required for ppolicy overlay) |

---

## 8. Access Control Lists (ACLs)

### Syntax

```
olcAccess: to <what> by <who> <level> [by <who> <level>]...
```

### Access levels (lowest → highest)

`none` → `disclose` → `auth` → `compare` → `search` → `read` → `write` → `manage`

### Who clauses

| Who | Meaning |
|-----|---------|
| `*` | Everyone including anonymous |
| `anonymous` | Unauthenticated only |
| `users` | Any authenticated user |
| `self` | The entry itself |
| `dn="..."` | A specific DN |
| `dn.subtree="..."` | Any DN within a subtree |
| `group="..."` | Members of a group |

### Common ACL patterns

```bash
ldapmodify -Y EXTERNAL -H ldapi:/// << 'EOF'
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
# Users can authenticate and change their own password
olcAccess: to attrs=userPassword
  by self write
  by anonymous auth
  by * none
# Users can update their own contact info
olcAccess: to attrs=mail,telephoneNumber,mobile
  by self write
  by users read
  by * none
# App bind account gets read-only access
olcAccess: to dn.subtree="ou=People,dc=example,dc=com"
  by dn="cn=appbind,ou=ServiceAccounts,dc=example,dc=com" read
  by users read
  by * none
# Default — authenticated users can read everything else
olcAccess: to *
  by users read
  by * none
EOF

# View current ACLs
ldapsearch -Y EXTERNAL -H ldapi:/// \
  -b "olcDatabase={1}mdb,cn=config" -s base olcAccess
```

---

## 9. Replication — syncrepl

OpenLDAP uses **syncrepl** — a pull-based mechanism where consumers pull changes from a provider. Two modes: `refreshOnly` (periodic polling) or `refreshAndPersist` (stays connected, real-time).

### Provider setup

```bash
# Load syncprov overlay
ldapadd -Y EXTERNAL -H ldapi:/// << EOF
dn: olcOverlay=syncprov,olcDatabase={1}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpSessionLog: 100
EOF

# Create replication bind account
ldapadd -H ldap://localhost \
  -D "cn=admin,dc=example,dc=com" -w adminpass << EOF
dn: cn=replicator,ou=ServiceAccounts,dc=example,dc=com
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: replicator
userPassword: ReplicatorPass123
EOF

# Grant replicator read access
ldapmodify -Y EXTERNAL -H ldapi:/// << EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: to *
  by dn="cn=replicator,ou=ServiceAccounts,dc=example,dc=com" read
  by * break
EOF
```

### Consumer setup

```bash
ldapmodify -Y EXTERNAL -H ldapi:/// << EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcSyncRepl
olcSyncRepl: rid=001
  provider=ldap://ldap-provider-01.example.com
  bindmethod=simple
  binddn="cn=replicator,ou=ServiceAccounts,dc=example,dc=com"
  credentials=ReplicatorPass123
  searchbase="dc=example,dc=com"
  scope=sub
  type=refreshAndPersist
  retry="60 +"
  interval=00:00:05:00
EOF
```

### Check replication status

```bash
# Compare contextCSN between provider and consumer — must match for in-sync
ldapsearch -H ldap://provider -x -D "cn=admin,dc=example,dc=com" -w pass \
  -b "dc=example,dc=com" -s base contextCSN

ldapsearch -H ldap://consumer -x -D "cn=admin,dc=example,dc=com" -w pass \
  -b "dc=example,dc=com" -s base contextCSN

# Check consumer log for sync errors
journalctl -u slapd | grep -i "sync\|repl\|error" | tail -30
```

---

## 10. TLS / SSL with OpenSSL

```bash
# Create cert directory
mkdir -p /etc/ldap/ssl && cd /etc/ldap/ssl

# Generate CA key and self-signed cert
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
  -subj "/CN=LDAP-CA/O=Example/C=ZA"

# Generate server key and CSR
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr \
  -subj "/CN=ldap.example.com/O=Example/C=ZA"

# Sign the server cert
openssl x509 -req -days 825 -in server.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt

# Set ownership
chown ldap:ldap /etc/ldap/ssl/*.key /etc/ldap/ssl/*.crt
chmod 600 /etc/ldap/ssl/server.key
chmod 644 /etc/ldap/ssl/server.crt /etc/ldap/ssl/ca.crt
```

### Configure TLS in cn=config

```bash
ldapmodify -Y EXTERNAL -H ldapi:/// << EOF
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/ssl/ca.crt
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/ssl/server.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/ssl/server.key
-
replace: olcTLSProtocolMin
olcTLSProtocolMin: 3.3
EOF
```

### Enable LDAPS (port 636)

```bash
# RHEL/Rocky
sed -i 's/^SLAPD_URLS=.*/SLAPD_URLS="ldapi:\/\/\/ ldap:\/\/\/ ldaps:\/\/\/"/' \
  /etc/sysconfig/slapd && systemctl restart slapd

# Debian/Ubuntu
sed -i 's|^SLAPD_SERVICES=.*|SLAPD_SERVICES="ldap:/// ldapi:/// ldaps:///"|' \
  /etc/default/slapd && systemctl restart slapd

# Verify
ss -tlnp | grep :636
```

### Certificate operations

```bash
# Verify cert on live server
openssl s_client -connect ldap.example.com:636 -showcerts

# Check expiry
echo | openssl s_client -connect ldap.example.com:636 2>/dev/null \
  | openssl x509 -noout -dates

# Verify cert and key match (outputs must be identical)
openssl x509 -noout -modulus -in server.crt | md5sum
openssl rsa  -noout -modulus -in server.key | md5sum

# Renew: generate new CSR → submit to CA → replace cert file → reload
systemctl reload slapd
```

---

## 11. Password Policy (ppolicy overlay)

### Load ppolicy

```bash
# Load schema
ldapadd -Y EXTERNAL -H ldapi:/// \
  -f /etc/ldap/schema/ppolicy.ldif

# Load overlay
ldapadd -Y EXTERNAL -H ldapi:/// << EOF
dn: olcOverlay=ppolicy,olcDatabase={1}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcPPolicyConfig
olcOverlay: ppolicy
olcPPolicyDefault: cn=default,ou=PwdPolicy,dc=example,dc=com
olcPPolicyHashCleartext: TRUE
olcPPolicyUseLockout: TRUE
EOF
```

### Create policy entry

```bash
ldapadd -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w adminpass << EOF
dn: ou=PwdPolicy,dc=example,dc=com
objectClass: organizationalUnit
ou: PwdPolicy

dn: cn=default,ou=PwdPolicy,dc=example,dc=com
objectClass: pwdPolicy
objectClass: person
cn: default
sn: default
pwdAttribute: userPassword
pwdMinLength: 8
pwdMaxAge: 7776000
pwdInHistory: 5
pwdLockout: TRUE
pwdMaxFailure: 5
pwdLockoutDuration: 1800
pwdExpireWarning: 604800
pwdMustChange: FALSE
pwdCheckQuality: 1
EOF
```

### Key ppolicy attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `pwdMaxAge` | Max password age (seconds) | `7776000` (90 days) |
| `pwdMinLength` | Minimum length | `8` |
| `pwdInHistory` | Passwords to remember | `5` |
| `pwdMaxFailure` | Lockout after N failures | `5` |
| `pwdLockoutDuration` | Lockout duration (seconds) | `1800` (30 min) |
| `pwdExpireWarning` | Warn N seconds before expiry | `604800` (7 days) |
| `pwdMustChange` | Force change at next login | `TRUE` |
| `pwdCheckQuality` | 0=none, 1=check if possible, 2=enforce | `1` |

### Manage locked accounts

```bash
# Find locked accounts
ldapsearch -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w pass \
  -b "dc=example,dc=com" "(pwdAccountLockedTime=*)" uid pwdAccountLockedTime

# Unlock an account
ldapmodify -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w pass << EOF
dn: uid=jdoe,ou=People,dc=example,dc=com
changetype: modify
delete: pwdAccountLockedTime
EOF

# Force password change at next login
ldapmodify -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w pass << EOF
dn: uid=jdoe,ou=People,dc=example,dc=com
changetype: modify
replace: pwdMustChange
pwdMustChange: TRUE
EOF
```

---

## 12. Monitoring via cn=Monitor

### Enable monitor backend

```bash
ldapadd -Y EXTERNAL -H ldapi:/// << EOF
dn: olcDatabase=monitor,cn=config
objectClass: olcDatabaseConfig
olcDatabase: monitor
olcAccess: to *
  by dn="cn=admin,dc=example,dc=com" read
  by * none
EOF
```

### Query monitoring data

```bash
# Active connections
ldapsearch -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w pass \
  -b "cn=Current,cn=Connections,cn=Monitor" monitorCounter

# Operations statistics
ldapsearch -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w pass \
  -b "cn=Operations,cn=Monitor" "(objectclass=*)" \
  monitorOpInitiated monitorOpCompleted

# Server uptime
ldapsearch -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w pass \
  -b "cn=Time,cn=Monitor" monitorTimestamp

# Entry count
ldapsearch -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w pass \
  -b "cn=Databases,cn=Monitor" monitoredInfo
```

---

## 13. Logging & Troubleshooting

```bash
# Live log stream
journalctl -u slapd -f

# Filter errors
journalctl -u slapd | grep -i "error\|fail\|warn" | tail -30

# Authentication failures (err=49)
journalctl -u slapd | grep "err=49" | tail -20
```

### Error codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `4` | Size limit exceeded |
| `13` | TLS required but not used |
| `32` | No such object (wrong base DN) |
| `49` | Invalid credentials (wrong password / unknown DN) |
| `50` | Insufficient access (ACL denied) |
| `65` | Object class violation (schema error) |
| `68` | Already exists |

### Common issues

| Problem | Resolution |
|---------|------------|
| `err=49` on bind | Verify DN exists: `ldapsearch ... "(uid=user)"` |
| `err=50` on operation | Enable `acl` log level; check `olcAccess` rules |
| `err=32` — no such object | Check suffix: `ldapsearch -b "" -s base namingContexts` |
| Slow searches | Add `olcDbIndex` for searched attribute; run `slapindex` |
| Replication not syncing | Compare `contextCSN`; check consumer log for errors |
| TLS fails | Run `openssl s_client`; check cert ownership (`ldap:ldap`) |
| slapd won't start | Run `slaptest -F /etc/ldap/slapd.d/ -v` |
| Account locked | Delete `pwdAccountLockedTime` attribute |

### Debug ACL issues

```bash
# Enable ACL logging temporarily
ldapmodify -Y EXTERNAL -H ldapi:/// << EOF
dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: stats acl
EOF

# Reproduce the issue, then watch logs
journalctl -u slapd -f | grep -i "acl\|access"

# Restore normal logging after debugging
ldapmodify -Y EXTERNAL -H ldapi:/// << EOF
dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: stats
EOF
```

---

## 14. Performance Tuning

```bash
# Add indexes for commonly searched attributes
ldapmodify -Y EXTERNAL -H ldapi:/// << EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: uid          eq
olcDbIndex: cn           eq,sub
olcDbIndex: sn           eq,sub
olcDbIndex: mail         eq,sub
olcDbIndex: memberOf     eq
olcDbIndex: member       eq
olcDbIndex: objectClass  eq
olcDbIndex: entryUUID    eq
olcDbIndex: entryCSN     eq
EOF

# After adding indexes — rebuild (stop slapd first)
systemctl stop slapd
slapindex -F /etc/ldap/slapd.d/ -b "dc=example,dc=com"
chown -R ldap:ldap /var/lib/ldap
systemctl start slapd

# Increase LMDB max size (no restart needed)
ldapmodify -Y EXTERNAL -H ldapi:/// << EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcDbMaxSize
olcDbMaxSize: 4294967296
EOF
```

---

## 15. Backup & Recovery

```bash
# Export data (safe while slapd is running with LMDB)
slapcat -F /etc/ldap/slapd.d/ -b "dc=example,dc=com" \
  -l /var/backups/ldap/data_$(date +%Y%m%d_%H%M).ldif

# Export cn=config
slapcat -F /etc/ldap/slapd.d/ -b "cn=config" \
  -l /var/backups/ldap/config_$(date +%Y%m%d_%H%M).ldif

# Back up TLS certs
cp -r /etc/ldap/ssl /var/backups/ldap/ssl_$(date +%Y%m%d)

# Cron backup script
cat > /usr/local/bin/ldap-backup.sh << 'SCRIPT'
#!/bin/bash
DIR=/var/backups/ldap; DATE=$(date +%Y%m%d_%H%M); mkdir -p $DIR
slapcat -F /etc/ldap/slapd.d/ -b "dc=example,dc=com" -l $DIR/data_$DATE.ldif
slapcat -F /etc/ldap/slapd.d/ -b "cn=config"         -l $DIR/config_$DATE.ldif
gzip $DIR/data_$DATE.ldif $DIR/config_$DATE.ldif
find $DIR -name "*.ldif.gz" -mtime +30 -delete
SCRIPT
chmod +x /usr/local/bin/ldap-backup.sh
echo "0 2 * * * ldap /usr/local/bin/ldap-backup.sh" >> /etc/cron.d/ldap-backup
```

### Restore

```bash
systemctl stop slapd
rm -rf /var/lib/ldap/*.mdb
slapadd -F /etc/ldap/slapd.d/ -b "dc=example,dc=com" \
  -l /var/backups/ldap/data_20260101_0200.ldif
chown -R ldap:ldap /var/lib/ldap
systemctl start slapd
```

---

## 16. Useful One-Liners

| Goal | Command |
|------|---------|
| Test server responds | `ldapsearch -H ldap://localhost -x -b "" -s base namingContexts` |
| Validate config | `slaptest -F /etc/ldap/slapd.d/ -v 2>&1 \| tail -3` |
| Count all entries | `ldapsearch -H ldap://localhost -x -D "cn=admin,dc=example,dc=com" -w pass -b "dc=example,dc=com" -s sub "(objectclass=*)" \| grep "^dn:" \| wc -l` |
| Find locked accounts | `ldapsearch ... "(pwdAccountLockedTime=*)" uid` |
| Show loaded overlays | `ldapsearch -Y EXTERNAL -H ldapi:/// -b "cn=config" "(objectclass=olcOverlayConfig)" olcOverlay` |
| Show all indexes | `ldapsearch -Y EXTERNAL -H ldapi:/// -b "olcDatabase={1}mdb,cn=config" -s base olcDbIndex` |
| Check TLS cert expiry | `echo \| openssl s_client -connect ldap.example.com:636 2>/dev/null \| openssl x509 -noout -dates` |
| Generate hashed password | `slappasswd -s "MyPassword"` |
| Live log stream | `journalctl -u slapd -f` |
| Count failed binds today | `journalctl -u slapd --since today \| grep "err=49" \| wc -l` |
| Check active connections | `ldapsearch -H ldap://localhost -D "cn=admin,dc=example,dc=com" -w pass -b "cn=Current,cn=Connections,cn=Monitor" monitorCounter` |
| Reload TLS certs | `systemctl reload slapd` |

---

*See also: [ibm-ldap-sds-reference.md](./ibm-ldap-sds-reference.md) | [ldap-checklists.md](./ldap-checklists.md)*
