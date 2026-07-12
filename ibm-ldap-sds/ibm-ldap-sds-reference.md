# IBM Security Directory Server (SDS) — LDAP Administrator Reference

A reference for administering IBM SDS. Covers architecture, core concepts, day-to-day commands, replication, certificates, performance tuning, and health monitoring.

---

## Table of Contents

- [Intro](#intro)
- [IBM SDS Architecture](#ibm-sds-architecture)
- [Installation Layout on AIX](#installation-layout-on-aix)
- [ibmslapd.conf — Key Directives](#ibmslapdconf--key-directives)
- [Core Admin Commands](#core-admin-commands)
- [LDIF — The LDAP Data Format](#ldif--the-ldap-data-format)
- [Schema Management](#schema-management)
- [Replication Management](#replication-management)
- [User & Group Management via LDAP](#user--group-management-via-ldap)
- [Access Control Lists (ACLs)](#access-control-lists-acls)
- [Password Policy](#password-policy)
- [Certificate Management (TLS/SSL)](#certificate-management-tlsssl)
- [Performance Tuning & Indexing](#performance-tuning--indexing)
- [Scalability — Growing the Directory](#scalability--growing-the-directory)
- [Audit Logging](#audit-logging)
- [Backup & Recovery](#backup--recovery)
- [Health Monitoring](#health-monitoring)
- [Logging & Troubleshooting](#logging--troubleshooting)
- [IBM SDS Web Admin Console](#ibm-sds-web-admin-console)
- [Useful LDAP Search Filters Reference](#useful-ldap-search-filters-reference)

---

### Intro
LDAP is a standard protocol for reading and writing hierarchical directory data over TCP/IP. Used primarily for:
- Authentication (verifying identity)
- Authorization (checking group membership)
- Address books / user stores (HR systems, email clients)

### LDAP Data Model

```
dc=example,dc=com                   ← Root (Base DN / Suffix)
├── ou=People                       ← Organizational Unit
│   ├── uid=finn                    ← User entry
│   └── uid=bob
├── ou=Groups
│   ├── cn=admins
│   └── cn=developers
└── ou=ServiceAccounts
    └── cn=appbind                  ← Application bind account
```

### Key Terminology

| Term | Meaning |
|------|---------|
| **DN** | Distinguished Name — the unique path to an entry (e.g., `uid=finn,ou=People,dc=example,dc=com`) |
| **RDN** | Relative Distinguished Name — the local part of a DN (e.g., `uid=finn`) |
| **Base DN / Suffix** | The root of the directory tree (e.g., `dc=example,dc=com`) |
| **Object Class** | Defines what attributes an entry can/must have (e.g., `inetOrgPerson`) |
| **Attribute** | A property of an entry (e.g., `uid`, `cn`, `mail`, `userPassword`) |
| **LDIF** | LDAP Data Interchange Format — text format for directory entries |
| **Bind DN** | The account used to authenticate to the LDAP server |
| **Anonymous Bind** | Connecting without credentials — usually disabled in enterprise |
| **Schema** | The rules defining valid object classes and attributes |
| **Replica** | A copy of the directory that receives changes from the master |
| **Supplier** | The server that sends replication updates (master) |
| **Consumer** | The server that receives replication updates (replica) |
| **Referral** | A pointer to another LDAP server when the local server doesn't hold the requested data |
| **Overlay** | A plugin that extends SDS functionality (e.g., audit, password policy) |

### LDAP Operations

| Operation | Description |
|-----------|-------------|
| **bind** | Authenticate to the server |
| **unbind** | End the session |
| **search** | Query for entries matching a filter |
| **add** | Create a new entry |
| **modify** | Change attributes on an existing entry |
| **delete** | Remove an entry |
| **modifyDN** | Rename or move an entry |
| **compare** | Check if an attribute has a specific value |
| **abandon** | Cancel an in-progress operation |
| **extended** | Extended operations (e.g., StartTLS, password modify) |

### Default Ports

| Port | Protocol | Use |
|------|----------|-----|
| 389 | LDAP (plaintext or StartTLS) | Standard LDAP |
| 636 | LDAPS (TLS) | Encrypted LDAP |
| 3389 | IBM admin server | SDS-specific admin port |
| 3636 | IBM admin server TLS | Encrypted admin port |

---

## IBM SDS Architecture

### Components

```
┌─────────────────────────────────────────────────────────┐
│                   IBM Security Directory Server          │
│                                                         │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────┐  │
│  │  ibmslapd   │    │ ibm-admin    │    │  DB2      │  │
│  │ (LDAP daemon)│   │   server     │    │ (backend) │  │
│  └──────┬──────┘    └──────┬───────┘    └─────┬─────┘  │
│         │                  │                   │        │
│         └──────────────────┴───────────────────┘        │
│                        AIX OS                            │
└─────────────────────────────────────────────────────────┘
```

- **ibmslapd** — the core LDAP server daemon
- **ibm-adminserver** — the admin server (handles web console and admin operations)
- **DB2** — the backend database where all directory data is stored (IBM SDS uses DB2, unlike OpenLDAP which uses LMDB)
- **GSKit** — IBM's SSL/TLS library, used for certificate management (not OpenSSL's native keystore format)

### Deployment Topology Options

| Topology | Description | Use Case |
|----------|-------------|----------|
| **Single Server** | One SDS instance, no replication | Dev/test only |
| **Master-Replica** | One supplier, one or more consumers | High availability reads |
| **Multi-Master** | Multiple servers accepting writes | Write HA (complex) |
| **Proxy** | SDS proxy forwards requests to backend servers | Load balancing, routing |
| **Gateway** | Translates between LDAP v2 and v3 | Legacy integration |

---

## Installation Layout on AIX

```
/opt/IBM/ldap/V6.4/              ← SDS binaries and libraries
├── bin/                         ← Admin commands (ldapsearch, ldapadd, etc.)
├── etc/                         ← Config templates
├── lib/                         ← Shared libraries
└── sbin/                        ← Server binaries (ibmslapd)

/etc/opt/IBM/ldap/               ← Runtime config
└── V6.4/
    └── etc/
        └── ibmslapd.conf        ← Main SDS configuration file

/var/ldap/                       ← Data, logs, and runtime files
├── ibmslapd.log                 ← Main LDAP log
├── ibmslapd.conf -> (symlink)
├── backup/                      ← Backup location
└── db2/                         ← DB2 database files (may vary)

/home/ldapdb2/                   ← DB2 instance owner home directory

/tmp/ibm-adminserver/            ← Admin server temp files
```

> Exact paths vary by version (V6.3, V6.4, V6.5). Always confirm with `find /opt/IBM -name "ibmslapd" 2>/dev/null`.

---

## ibmslapd.conf — Key Directives

The main SDS configuration file. Location: `/etc/opt/IBM/ldap/V6.4/etc/ibmslapd.conf`
Validate syntax before restarting: `ibmslapd -t -f /etc/opt/IBM/ldap/V6.4/etc/ibmslapd.conf`

> Changes to `ibmslapd.conf` require a server restart to take effect — **except** for attributes that can be changed live via `ldapmodify` against `cn=ibmpolicies` (noted below).

### Core Server Stanza (`cn=Front End`)

| Directive | Description | Example Value |
|-----------|-------------|---------------|
| `ibm-slapdPort` | LDAP listen port | `389` |
| `ibm-slapdSecurePort` | LDAPS listen port | `636` |
| `ibm-slapdSecurity` | TLS mode: `none`, `ssl`, `ssltls` | `ssltls` |
| `ibm-slapdSslKeyDatabase` | Path to GSKit KDB file | `/etc/ldap/key.kdb` |
| `ibm-slapdSslKeyDatabasePW` | Stash file for KDB password | `/etc/ldap/key.sth` |
| `ibm-slapdMaxConnections` | Max simultaneous client connections | `1024` |
| `ibm-slapdMaxThreads` | Max worker threads | `64` |
| `ibm-slapdErrorLog` | Path to the error/operations log | `/var/ldap/ibmslapd.log` |
| `ibm-slapdSyslogLevel` | Log verbosity (0=minimal, 65535=full debug) | `0` |
| `ibm-slapdSizeLimit` | Max entries returned per search | `500` |
| `ibm-slapdTimeLimit` | Max seconds per search operation | `120` |
| `ibm-slapdAllowAnon` | Allow anonymous binds (`true`/`false`) | `false` |

### Backend / Database Stanza (`cn=Directory`)

| Directive | Description | Example Value |
|-----------|-------------|---------------|
| `ibm-slapdSuffix` | The directory suffix (base DN) | `dc=example,dc=com` |
| `ibm-slapdDbType` | Backend type | `db2` |
| `ibm-slapdDbInstance` | DB2 instance name | `ldapdb2` |
| `ibm-slapdDbName` | DB2 database name | `LDAPDB` |
| `ibm-slapdDbLocation` | DB2 database path | `/home/ldapdb2` |

### Replication Stanza (`cn=Replication`)

| Directive | Description |
|-----------|-------------|
| `ibm-replicationBindDN` | DN used by the supplier to bind to consumers |
| `ibm-replicationBindPW` | Password for replication bind account |
| `ibm-replicationSchedule` | When replication runs (default: immediate) |
| `ibm-replicationConsumerURL` | LDAP URL of the consumer server |

### Schema Includes

```
include /etc/opt/IBM/ldap/V6.4/etc/schema/core.schema
include /etc/opt/IBM/ldap/V6.4/etc/schema/inetorgperson.schema
include /etc/opt/IBM/ldap/V6.4/etc/schema/ibmconfig.schema
include /etc/opt/IBM/ldap/V6.4/etc/schema/custom.schema
```

---

## Core Admin Commands

### Starting / Stopping SDS

```bash
# Start LDAP server
startsrc -s ibmslapd

# Stop LDAP server
stopsrc -s ibmslapd

# Start admin server
startsrc -s ibm-adminserver

# Stop admin server
stopsrc -s ibm-adminserver

# Check status of both
lssrc -s ibmslapd
lssrc -s ibm-adminserver

# Start with config file specified
ibmslapd -f /etc/opt/IBM/ldap/V6.4/etc/ibmslapd.conf
```

### ldapsearch

```bash
# Basic search — find a user
ldapsearch -h localhost -p 389 \
  -D "cn=root" -w password \
  -b "ou=People,dc=example,dc=com" \
  "(uid=finn)"

# Return specific attributes only
ldapsearch -h localhost -p 389 \
  -D "cn=root" -w password \
  -b "dc=example,dc=com" \
  "(uid=finn)" cn mail telephoneNumber

# Search over TLS (LDAPS)
ldapsearch -h localhost -p 636 -Z \
  -K /etc/ldap/key.kdb -P keypassword \
  -D "cn=root" -w password \
  -b "dc=example,dc=com" "(uid=finn)"

# Count entries matching a filter
ldapsearch -h localhost -p 389 -D "cn=root" -w pass \
  -b "dc=example,dc=com" -s sub "(objectclass=inetOrgPerson)" \
  | grep "^dn:" | wc -l

# Export entire directory to LDIF
ldapsearch -h localhost -p 389 -D "cn=root" -w pass \
  -b "dc=example,dc=com" -s sub "(objectclass=*)" -LLL \
  > /var/ldap/backup/full_export_$(date +%Y%m%d).ldif
```

### ldapadd

```bash
# Add a single entry from LDIF file
ldapadd -h localhost -p 389 \
  -D "cn=root,dc=example,dc=com" -w password \
  -f newuser.ldif

# Add with verbose output
ldapadd -h localhost -p 389 \
  -D "cn=root,dc=example,dc=com" -w password \
  -v -f newuser.ldif
```

### ldapmodify

```bash
# Modify an attribute
ldapmodify -h localhost -p 389 \
  -D "cn=root,dc=example,dc=com" -w password \
  -f modify.ldif

# Inline modification
ldapmodify -h localhost -p 389 \
  -D "cn=root,dc=example,dc=com" -w password << EOF
dn: uid=finn,ou=People,dc=example,dc=com
changetype: modify
replace: mail
mail: finn@example.com
EOF
```

### ldapdelete

```bash
# Delete a single entry
ldapdelete -h localhost -p 389 \
  -D "cn=root,dc=example,dc=com" -w password \
  "uid=finn,ou=People,dc=example,dc=com"

# Delete recursively (subtree) — requires IBM extension
ldapdelete -h localhost -p 389 \
  -D "cn=root,dc=example,dc=com" -w password \
  -r "ou=TestOU,dc=example,dc=com"
```

### IBM SDS-Specific Admin Commands

```bash
# Verify server configuration
ibmslapd -t -f /etc/opt/IBM/ldap/V6.4/etc/ibmslapd.conf

# Rebuild DB2 indexes (run when performance degrades)
idsrunstats -I ldapinst

# Export directory using DB2 ldif tool (faster than ldapsearch for large dirs)
db2ldif -o /var/ldap/backup/export.ldif -s "dc=example,dc=com"

# Import LDIF using bulk load (much faster than ldapadd for large imports)
bulkload -c /etc/opt/IBM/ldap/V6.4/etc/ibmslapd.conf \
  -i /var/ldap/backup/import.ldif

# Monitor active connections
ldapsearch -h localhost -p 3389 -D "cn=root" -w pass \
  -b "cn=Monitor" "(objectclass=*)" ibm-slapdCurrentConnections
```

---

## LDIF — The LDAP Data Format

LDIF (LDAP Data Interchange Format) is the standard text format for representing LDAP entries and change operations.

### Adding a New User Entry

```ldif
dn: uid=finn,ou=People,dc=example,dc=com
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: finn
cn: Finn Surname
sn: Surname
givenName: Finn
mail: finn@example.com
telephoneNumber: +27-11-000-0000
userPassword: {SSHA}hashedpasswordhere
```

### Modifying an Entry

```ldif
# Replace an attribute
dn: uid=finn,ou=People,dc=example,dc=com
changetype: modify
replace: telephoneNumber
telephoneNumber: +27-11-111-1111

# Add a new attribute
dn: uid=finn,ou=People,dc=example,dc=com
changetype: modify
add: description
description: Linux Sysadmin

# Delete a specific attribute value
dn: uid=finn,ou=People,dc=example,dc=com
changetype: modify
delete: description
description: Linux Sysadmin
```

### Adding to a Group

```ldif
dn: cn=admins,ou=Groups,dc=example,dc=com
changetype: modify
add: member
member: uid=finn,ou=People,dc=example,dc=com
```

### Deleting an Entry

```ldif
dn: uid=finn,ou=People,dc=example,dc=com
changetype: delete
```

### Renaming / Moving an Entry

```ldif
dn: uid=finn,ou=People,dc=example,dc=com
changetype: moddn
newrdn: uid=finn.surname
deleteoldrdn: 1
newsuperior: ou=Alumni,dc=example,dc=com
```

---

## Schema Management

Schema defines the rules of the directory — what attributes and object classes exist.

```bash
# View the schema via LDAP
ldapsearch -h localhost -p 389 -D "cn=root" -w pass \
  -b "cn=schema" "(objectclass=*)" objectclasses attributetypes

# Add a custom schema file
idscfgsuf -I ldapinst -t /path/to/custom.schema

# List loaded schema files
ls /etc/opt/IBM/ldap/V6.4/etc/schema/

# Key built-in schema files
/etc/opt/IBM/ldap/V6.4/etc/schema/core.schema        # Core LDAP objects
/etc/opt/IBM/ldap/V6.4/etc/schema/inetorgperson.schema # inetOrgPerson
/etc/opt/IBM/ldap/V6.4/etc/schema/ibmconfig.schema    # IBM-specific objects
```

---

## Replication Management

### Check Replication Status

```bash
# Check last replication time on a consumer
ldapsearch -h replica-server -p 389 \
  -D "cn=root" -w password \
  -b "cn=Monitor" "(cn=replication)" \
  ibm-replicationLastActivationTime ibm-replicationResult

# Check replication queue depth (backlog)
ldapsearch -h master-server -p 389 \
  -D "cn=root" -w password \
  -b "cn=replication,cn=ibmpolicies" \
  "(objectclass=ibm-replicationAgreement)" \
  ibm-replicationPendingChangeCount
```

### View Replication Agreements

```bash
ldapsearch -h localhost -p 389 \
  -D "cn=root" -w password \
  -b "cn=replication,cn=ibmpolicies" \
  "(objectclass=ibm-replicationAgreement)"
```

### Force Replication Resync (IBM Extension)

```bash
# Initiate immediate replication from supplier to consumer
ldapmodify -h master -p 389 -D "cn=root" -w pass << EOF
dn: cn=<consumer-agreement-dn>,cn=replication,cn=ibmpolicies
changetype: modify
replace: ibm-replicationActivationTime
ibm-replicationActivationTime: 19700101000000Z
EOF
```

### Replication Troubleshooting

```bash
# Check for replication errors in the log
grep -i "repl.*error\|error.*repl" /var/ldap/ibmslapd.log | tail -30

# Check replication bind account is not locked
ldapsearch -h consumer -p 389 \
  -D "cn=replication-binddn,dc=example,dc=com" \
  -w replication-pass \
  -b "dc=example,dc=com" -s base "(objectclass=*)"

# Check clock skew between supplier and consumer (must be within 5 minutes)
ssh consumer "date"
date
```

---

## User & Group Management via LDAP

### Add a User

```bash
cat > /tmp/newuser.ldif << EOF
dn: uid=jdoe,ou=People,dc=example,dc=com
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: jdoe
cn: John Doe
sn: Doe
givenName: John
mail: jdoe@example.com
userPassword: TempPass@2026
EOF

ldapadd -h localhost -p 389 -D "cn=root" -w adminpass -f /tmp/newuser.ldif
```

### Reset a User's Password

```bash
ldapmodify -h localhost -p 389 -D "cn=root" -w adminpass << EOF
dn: uid=jdoe,ou=People,dc=example,dc=com
changetype: modify
replace: userPassword
userPassword: NewSecurePass@2026
EOF
```

### Unlock a Locked Account

```bash
ldapmodify -h localhost -p 389 -D "cn=root" -w adminpass << EOF
dn: uid=jdoe,ou=People,dc=example,dc=com
changetype: modify
delete: ibm-pwdAccountLocked
EOF
```

### Disable a User Account

```bash
ldapmodify -h localhost -p 389 -D "cn=root" -w adminpass << EOF
dn: uid=jdoe,ou=People,dc=example,dc=com
changetype: modify
replace: ibm-pwdAccountLocked
ibm-pwdAccountLocked: true
EOF
```

### Add User to a Group

```bash
ldapmodify -h localhost -p 389 -D "cn=root" -w adminpass << EOF
dn: cn=admins,ou=Groups,dc=example,dc=com
changetype: modify
add: member
member: uid=jdoe,ou=People,dc=example,dc=com
EOF
```

### Find All Members of a Group

```bash
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "cn=admins,ou=Groups,dc=example,dc=com" \
  "(objectclass=groupOfNames)" member
```

### Find All Groups a User Belongs To

```bash
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "ou=Groups,dc=example,dc=com" \
  "(member=uid=jdoe,ou=People,dc=example,dc=com)" cn
```

---

## Access Control Lists (ACLs)

IBM SDS uses ACIs (Access Control Items) to define who can read/write what in the directory.

### View Current ACLs

```bash
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "dc=example,dc=com" -s base "(objectclass=*)" aclentry
```

### Example ACI: Allow Self-Modification of Phone Number

```ldif
dn: ou=People,dc=example,dc=com
changetype: modify
add: aclentry
aclentry: access-id:cn=this:at=telephoneNumber:read:write:
```

### Example ACI: Allow App Account Read-Only to People OU

```ldif
dn: ou=People,dc=example,dc=com
changetype: modify
add: aclentry
aclentry: access-id:cn=appbind,ou=ServiceAccounts,dc=example,dc=com:objectclass=*:read:
```

---

## Password Policy

### View Current Password Policy

```bash
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "cn=ibmpolicies" "(objectclass=ibm-slapdPolicyGroup)"
```

### Common Password Policy Attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `ibm-pwdMaxAge` | Maximum password age (days) | `ibm-pwdMaxAge: 90` |
| `ibm-pwdMinLength` | Minimum password length | `ibm-pwdMinLength: 8` |
| `ibm-pwdMaxFailure` | Lockout after N failures | `ibm-pwdMaxFailure: 5` |
| `ibm-pwdLockoutDuration` | How long lockout lasts (seconds) | `ibm-pwdLockoutDuration: 1800` |
| `ibm-pwdMustChange` | Force change at next login | `ibm-pwdMustChange: TRUE` |
| `ibm-pwdMinAge` | Minimum age before change allowed | `ibm-pwdMinAge: 1` |
| `ibm-pwdInHistory` | Number of historical passwords remembered | `ibm-pwdInHistory: 12` |

### Check If an Account is Locked

```bash
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "dc=example,dc=com" \
  "(ibm-pwdAccountLocked=true)" uid ibm-pwdAccountLocked
```

---

## Certificate Management (TLS/SSL)

IBM SDS uses **IBM GSKit** (Global Security Kit) for certificate management, not the OpenSSL keystore format directly. The tool is `gsk8capicmd_64`.

### GSKit Key Database (KDB) Commands

```bash
# List all certificates in the key database
gsk8capicmd_64 -cert -list -db /etc/ldap/key.kdb -pw keystorepassword

# View certificate details (including expiry date)
gsk8capicmd_64 -cert -details \
  -label "my-ldap-cert" \
  -db /etc/ldap/key.kdb \
  -pw keystorepassword

# Create a new key database
gsk8capicmd_64 -keydb -create \
  -db /etc/ldap/key.kdb \
  -pw keystorepassword \
  -type cms -expire 365 -stash

# Generate a Certificate Signing Request (CSR)
gsk8capicmd_64 -certreq -create \
  -db /etc/ldap/key.kdb -pw keystorepassword \
  -label "ldap-server-cert" \
  -dn "CN=ldap.example.com,O=Example,C=ZA" \
  -size 2048 -sig_alg SHA256WithRSA \
  -file /tmp/ldap-server.csr

# Import a signed certificate from CA
gsk8capicmd_64 -cert -receive \
  -file /tmp/ldap-server.crt \
  -db /etc/ldap/key.kdb -pw keystorepassword \
  -label "ldap-server-cert"

# Import a CA/root certificate
gsk8capicmd_64 -cert -add \
  -db /etc/ldap/key.kdb -pw keystorepassword \
  -label "RootCA" \
  -file /tmp/rootca.crt \
  -format ascii -trust enable

# Export a certificate
gsk8capicmd_64 -cert -export \
  -db /etc/ldap/key.kdb -pw keystorepassword \
  -label "ldap-server-cert" \
  -target /tmp/exported-cert.p12 \
  -target_pw exportpassword \
  -target_type pkcs12

# Delete an old/expired certificate
gsk8capicmd_64 -cert -delete \
  -db /etc/ldap/key.kdb -pw keystorepassword \
  -label "old-expired-cert"

# Set a certificate as the default (server identity cert)
gsk8capicmd_64 -cert -setdefault \
  -db /etc/ldap/key.kdb -pw keystorepassword \
  -label "ldap-server-cert"
```

### Certificate Renewal Process

1. Generate a new CSR using `gsk8capicmd_64 -certreq -create`
2. Submit CSR to your Certificate Authority (CA)
3. Receive signed certificate from CA
4. Import the signed cert with `gsk8capicmd_64 -cert -receive`
5. Set the new cert as default with `-setdefault`
6. Stop and restart `ibmslapd` to pick up the new certificate
7. Verify TLS with: `openssl s_client -connect ldap.example.com:636`

---

## Performance Tuning & Indexing

### Why Performance Degrades

- Missing indexes on frequently-searched attributes
- DB2 buffer pool too small for the directory size
- Too many simultaneous connections
- Replication backlog causing lock contention
- Large unindexed searches scanning the entire directory

### Check and Create Indexes

```bash
# List existing indexes
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "cn=indexes,cn=ibmpolicies" "(objectclass=*)"

# Add an index on the 'mail' attribute (equality search)
ldapmodify -h localhost -p 389 -D "cn=root" -w adminpass << EOF
dn: cn=mail,cn=indexes,cn=ibmpolicies
objectclass: top
objectclass: ibm-slapdIndex
cn: mail
ibm-slapdIndexEq: TRUE
ibm-slapdIndexSub: TRUE
EOF

# Rebuild all indexes after adding new ones (requires server restart)
idsrunstats -I ldapinst

# Commonly indexed attributes in enterprise directories
# uid, cn, mail, sn, givenName, telephoneNumber,
# memberOf, member, objectClass
```

### DB2 Performance Tuning

```bash
# Check DB2 database configuration
su - ldapdb2
db2 get db cfg for LDAPDB

# Check buffer pool hit ratio (should be > 95%)
db2 get snapshot for database on LDAPDB | grep -i "buffer pool"

# Increase buffer pool size if hit ratio is low
db2 alter bufferpool IBMDEFAULTBP size 50000

# Run statistics for query optimizer
db2 runstats on table LDAPDB2.LDAP_ENTRY with distribution and detailed indexes all
```

### SDS Connection Limits

```bash
# View current connection settings in ibmslapd.conf
grep -i "ibm-slapdMaxConnections\|ibm-slapdMaxThreads" \
  /etc/opt/IBM/ldap/V6.4/etc/ibmslapd.conf

# Increase connection limits via ldapmodify
ldapmodify -h localhost -p 3389 -D "cn=root" -w adminpass << EOF
dn: cn=Front End, cn=IBM SecureWay Directory, cn=Schemas, cn=ibmpolicies
changetype: modify
replace: ibm-slapdMaxConnections
ibm-slapdMaxConnections: 1024
EOF
```

---

## Scalability — Growing the Directory

When user counts grow or read load increases, the typical progression is:

| Trigger | Action |
|---------|--------|
| Search response time increasing | Add indexes first — cheapest fix |
| DB2 buffer pool hit ratio <95% | Increase buffer pool size (`db2 alter bufferpool`) |
| High read load across many apps | Add a read replica (consumer) |
| Single point of failure risk | Add a second supplier (multi-master) or a hot standby replica |
| Many different apps querying LDAP | Add an SDS proxy tier to load-balance and abstract backend topology |
| Directory size exceeding millions of entries | Enable DB2 database partitioning (DPF) — requires IBM planning |
| Geographic distribution (multi-site) | Set up a remote replica per site; apps bind to local replica |

### Adding a New Read Replica (Consumer)

1. Install SDS on the new server
2. Export the current directory from the supplier:
   ```bash
   db2ldif -I ldapinst -o /var/ldap/backup/initial_export.ldif -s "dc=example,dc=com"
   ```
3. Import on the new consumer:
   ```bash
   bulkload -c /etc/opt/IBM/ldap/V6.4/etc/ibmslapd.conf -i /var/ldap/backup/initial_export.ldif
   ```
4. Create a replication agreement on the supplier pointing to the new consumer
5. Create the replication bind account on the consumer
6. Start replication and verify with `ibm-replicationPendingChangeCount`
7. Update any load balancer or application config to include the new replica

### Capacity Signals to Watch

```bash
# Current active connections (approaching ibm-slapdMaxConnections = risk)
ldapsearch -h localhost -p 389 -D "cn=root" -w pass \
  -b "cn=Monitor" "(objectclass=*)" ibm-slapdCurrentConnections ibm-slapdMaxConnections

# DB2 tablespace usage (>85% = time to extend)
db2 list tablespaces show detail | grep -i "used\|total"

# Search response time trend — check etime values in the log
grep "etime=" /var/ldap/ibmslapd.log | awk -F'etime=' '{print $2}' \
  | awk '{print $1}' | sort -n | tail -10
```

---

## Audit Logging

Audit logging in IBM SDS records **who did what** to the directory — which bind DN performed which operation (add, modify, delete, bind, search) and when. This is distinct from the error/operations log and is required for compliance in most enterprise environments (SOX, PCI-DSS, HIPAA).

### Enable Audit Logging in ibmslapd.conf

Audit is configured as an overlay in `ibmslapd.conf`. Add or confirm the following stanza:

```
dn: cn=audit,cn=ibmpolicies
objectclass: ibm-slapdPlugin
objectclass: top
cn: audit
ibm-slapdPlugin: preoperation audit /opt/IBM/ldap/V6.4/lib/libaudit.so audit_init
ibm-slapdAuditLog: /var/ldap/ibm_audit.log
ibm-slapdAuditEnabled: TRUE
```

Restart `ibmslapd` after adding this stanza.

### Enable/Disable Audit Without Restart (live change)

```bash
# Enable audit logging live
ldapmodify -h localhost -p 3389 -D "cn=root" -w adminpass << EOF
dn: cn=audit,cn=ibmpolicies
changetype: modify
replace: ibm-slapdAuditEnabled
ibm-slapdAuditEnabled: TRUE
EOF

# Disable audit logging live
ldapmodify -h localhost -p 3389 -D "cn=root" -w adminpass << EOF
dn: cn=audit,cn=ibmpolicies
changetype: modify
replace: ibm-slapdAuditEnabled
ibm-slapdAuditEnabled: FALSE
EOF
```

### Configure Which Operations to Audit

```bash
ldapmodify -h localhost -p 3389 -D "cn=root" -w adminpass << EOF
dn: cn=audit,cn=ibmpolicies
changetype: modify
replace: ibm-slapdAuditEvents
ibm-slapdAuditEvents: add modify delete moddn bind unbind
EOF
```

Common event values: `add`, `modify`, `delete`, `moddn`, `bind`, `unbind`, `search`, `compare`

### Read the Audit Log

The audit log is written to `/var/ldap/ibm_audit.log` (or as configured above). Each record shows timestamp, operation, bind DN, target DN, and result code.

```bash
# Tail audit log live
tail -f /var/ldap/ibm_audit.log

# Find all modifications made by a specific admin
grep -A5 "bindDN: cn=root" /var/ldap/ibm_audit.log | grep -i "modify\|add\|delete"

# Find all failed bind attempts (result code 49 = INVALID_CREDENTIALS)
grep "resultCode: 49" /var/ldap/ibm_audit.log | tail -30

# Find all operations on a specific user entry
grep "targetDN: uid=jdoe" /var/ldap/ibm_audit.log

# Count operations by type today
grep "$(date +%Y%m%d)" /var/ldap/ibm_audit.log | grep "^operation:" | sort | uniq -c | sort -rn
```

### Audit Log Rotation

The audit log can grow very large in active directories. Configure rotation in `/etc/logrotate.d/ibm-ldap-audit`:

```
/var/ldap/ibm_audit.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    postrotate
        refresh -s ibmslapd
    endscript
}
```

> **Note:** Do not delete audit logs without authorization — in regulated environments they are evidence and may be subject to retention policies (often 90 days to 7 years depending on the standard).

---

## Backup & Recovery

### Export (Backup) the Directory

```bash
# Full export via ldapsearch (suitable for small/medium directories)
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "dc=example,dc=com" -s sub "(objectclass=*)" -LLL \
  > /var/ldap/backup/ldap_backup_$(date +%Y%m%d_%H%M).ldif

# Full export via db2ldif (faster for large directories)
db2ldif -I ldapinst \
  -o /var/ldap/backup/ldap_backup_$(date +%Y%m%d_%H%M).ldif \
  -s "dc=example,dc=com"

# Back up the key database (certificates)
cp /etc/ldap/key.kdb /var/ldap/backup/key_$(date +%Y%m%d).kdb
cp /etc/ldap/key.sth /var/ldap/backup/key_$(date +%Y%m%d).sth

# Back up the configuration file
cp /etc/opt/IBM/ldap/V6.4/etc/ibmslapd.conf \
  /var/ldap/backup/ibmslapd_$(date +%Y%m%d).conf
```

### Import (Restore) the Directory

```bash
# Stop the LDAP server first
stopsrc -s ibmslapd

# Import via bulkload (fast, for full restores)
bulkload -c /etc/opt/IBM/ldap/V6.4/etc/ibmslapd.conf \
  -i /var/ldap/backup/ldap_backup_20260101_0600.ldif

# Import via ldapadd (for partial restores or smaller files)
ldapadd -h localhost -p 389 -D "cn=root" -w adminpass \
  -f /var/ldap/backup/ldap_backup_20260101_0600.ldif

# Start the server
startsrc -s ibmslapd
```

---

## Health Monitoring

### Monitor Key Metrics via cn=Monitor

IBM SDS exposes real-time statistics through the `cn=Monitor` subtree:

```bash
# All monitor data
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "cn=Monitor" "(objectclass=*)"

# Current and total connections
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "cn=Monitor" "(objectclass=*)" \
  ibm-slapdCurrentConnections ibm-slapdTotalConnections

# Operations statistics
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "cn=Monitor" "(objectclass=*)" \
  ibm-slapdTotalAdd ibm-slapdTotalModify \
  ibm-slapdTotalDelete ibm-slapdTotalSearch

# Server uptime
ldapsearch -h localhost -p 389 -D "cn=root" -w adminpass \
  -b "cn=Monitor" "(objectclass=*)" ibm-slapdStartTime
```

### Key Health Checks Summary

| Check | Command | Healthy Indicator |
|-------|---------|-------------------|
| Service running | `lssrc -s ibmslapd` | Status: active |
| Port listening | `netstat -an \| grep 389` | Port in LISTEN state |
| Bind test | `ldapsearch ... -s base "(objectclass=*)"` | Returns rootDSE data |
| Replication lag | Check `ibm-replicationLastActivationTime` | Within minutes of current time |
| Disk space | `df -g /var/ldap` | Below 80% |
| Certificate expiry | `gsk8capicmd_64 -cert -details ...` | >60 days remaining |
| DB2 health | `db2 get snapshot for database on LDAPDB` | No errors |
| Error log | `grep -i error /var/ldap/ibmslapd.log` | No new critical errors |

---

## Logging & Troubleshooting

### Log Locations

| Log | Location | Purpose |
|-----|----------|---------|
| LDAP server log | `/var/ldap/ibmslapd.log` | Main operational log |
| Admin server log | `/var/ldap/ibm-adminserver.log` | Admin console operations |
| DB2 diagnostic log | `/home/ldapdb2/sqllib/db2dump/db2diag.log` | DB2 backend issues |
| AIX system log | `/var/log/messages` | OS-level events |
| AIX error report | `errpt -a` | Hardware and software errors |

### Increase Log Verbosity

```bash
# Enable debug logging (only in non-prod — very verbose)
ldapmodify -h localhost -p 3389 -D "cn=root" -w adminpass << EOF
dn: cn=Front End, cn=IBM SecureWay Directory, cn=Schemas, cn=ibmpolicies
changetype: modify
replace: ibm-slapdErrorLog
ibm-slapdErrorLog: /var/ldap/ibmslapd.log
replace: ibm-slapdSyslogLevel
ibm-slapdSyslogLevel: 65535
EOF
# Reset to normal after debugging:
# ibm-slapdSyslogLevel: 0
```

### Common Issues & Solutions

| Problem | Likely Cause | Resolution |
|---------|-------------|------------|
| Service won't start | Config file syntax error | `ibmslapd -t -f ibmslapd.conf` to validate |
| Slow searches | Missing index | Add index on searched attribute, run `idsrunstats` |
| Replication broken | Network, clock skew, or bind account locked | Check log, verify clock sync, unlock bind account |
| Certificate error | Expired cert or wrong KDB path | Renew cert, verify path in `ibmslapd.conf` |
| DB2 errors | Disk space, permissions | Check `db2diag.log`, `df -g` |
| Account lockout | Password policy | Unlock via `ldapmodify` removing `ibm-pwdAccountLocked` |
| Anonymous bind rejected | Security policy | Confirm app is using the correct bind DN/password |
| Connection refused | Service down or wrong port | `lssrc -s ibmslapd`, `netstat -an \| grep 389` |

---

## IBM SDS Web Admin Console

The IBM SDS Web Administration Tool runs on the admin server (port 3389) and provides a GUI for most admin tasks.

```
URL: http://<server>:3389/IDSWebApp/
or: https://<server>:3636/IDSWebApp/
```

### Key Features in the Web Console

- **Server Administration** — start/stop, view status
- **Directory Management** — browse, add, modify, delete entries
- **Schema Viewer** — view object classes and attributes
- **Replication Management** — view agreements, check status, trigger sync
- **Monitoring** — connections, operations statistics
- **Security** — manage ACLs, password policies, TLS settings
- **Log Viewer** — view and filter log files

---

## Useful LDAP Search Filters Reference

| Goal | Filter |
|------|--------|
| Find a user by uid | `(uid=jdoe)` |
| Find all users | `(objectclass=inetOrgPerson)` |
| Find by email | `(mail=jdoe@example.com)` |
| Find all groups | `(objectclass=groupOfNames)` |
| Find user in a group | `(member=uid=jdoe,ou=People,dc=example,dc=com)` |
| Find locked accounts | `(ibm-pwdAccountLocked=true)` |
| Find accounts with no password | `(!(userPassword=*))` |
| Find accounts with expired passwords | `(ibm-pwdLastChanged<=<timestamp>)` |
| Wildcard search by name | `(cn=John*)` |
| Combined filter (AND) | `(&(objectclass=inetOrgPerson)(mail=*@example.com))` |
| Combined filter (OR) | `(\|(uid=jdoe)(uid=jsmith))` |
| Combined filter (NOT) | `(&(objectclass=inetOrgPerson)(!(ibm-pwdAccountLocked=true)))` |
| Find all entries modified today | `(modifyTimestamp>=20260101000000Z)` |

---

*Cross-reference: [aix-commands.md](./aix-commands.md) | [ldap-checklists.md](./ldap-checklists.md) | [decision-guide.md](../decision-guide.md)*
