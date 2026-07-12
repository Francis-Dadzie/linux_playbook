# AIX Sysadmin Command Reference

A practical, workflow-ordered command reference for IBM AIX administrators. AIX is IBM's enterprise Unix operating system — POSIX-compliant and conceptually similar to Linux, but with its own tooling, filesystem layout, package manager, and conventions. Where a Linux equivalent exists, it is noted.

> **Linux admin tip:** If you're coming from Linux, the biggest mental shifts are: `smit`/`smitty` instead of editing config files directly, `ODM` (Object Data Manager) as the system config database, `LVM` works differently (AIX invented it), and `installp`/`nim` instead of `apt`/`dnf`.

## Table of Contents

- [1. System Identity & Overview](#1-system-identity--overview)
- [2. Hardware & Devices](#2-hardware--devices)
- [3. Users, Groups & Authentication](#3-users-groups--authentication)
- [4. Files & Directories](#4-files--directories)
- [5. Permissions & Ownership](#5-permissions--ownership)
- [6. Text Processing](#6-text-processing)
- [7. Processes & Job Control](#7-processes--job-control)
- [8. Performance & Diagnostics](#8-performance--diagnostics)
- [9. Storage, LVM & Filesystems](#9-storage-lvm--filesystems)
- [10. Networking](#10-networking)
- [11. Package Management (installp, nim, rpm)](#11-package-management-installp-nim-rpm)
- [12. Services & System Control](#12-services--system-control)
- [13. Scheduling & Automation](#13-scheduling--automation)
- [14. Logging & Auditing](#14-logging--auditing)
- [15. Security & Certificates](#15-security--certificates)
- [16. Backup & Recovery](#16-backup--recovery)
- [17. SMIT — AIX's Admin Interface](#17-smit--aixs-admin-interface)
- [18. AIX-Specific Utilities](#18-aix-specific-utilities)
- [19. DB2 — IBM SDS Backend](#19-db2--ibm-sds-backend)
- [20. Quick One-Liners for AIX](#20-quick-one-liners-for-aix)

---

## 1. System Identity & Overview

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `uname -a` | OS name, version, hardware | `uname -a` | Same |
| `oslevel` | Show exact AIX version/service pack | `oslevel -s` | `cat /etc/os-release` |
| `hostname` | Show/set hostname | `hostname` | Same |
| `prtconf` | Print system configuration (CPU, RAM, model) | `prtconf` | `lshw -short` |
| `lsattr -El sys0` | Show system-level attributes (RAM, CPU) | `lsattr -El sys0` | `dmidecode` |
| `uptime` | System uptime and load average | `uptime` | Same |
| `who -b` | Last boot time | `who -b` | Same |
| `date` | Display or set system date/time | `date` | Same |
| `bootinfo -r` | Show real memory (RAM) in KB | `bootinfo -r` | `free -k` |
| `bootinfo -y` | Show CPU architecture (32/64-bit) | `bootinfo -y` | `uname -m` |
| `lparstat` | Show LPAR (partition) CPU/memory stats | `lparstat -i` | `lscpu` |
| `smtctl` | Simultaneous multi-threading info | `smtctl` | `lscpu \| grep Thread` |

---

## 2. Hardware & Devices

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `lsdev -Cc processor` | List processor devices | `lsdev -Cc processor` | `lscpu` |
| `lsdev -Cc memory` | List memory devices | `lsdev -Cc memory` | `free -h` |
| `lsdev -Cc disk` | List disk devices | `lsdev -Cc disk` | `lsblk` |
| `lsdev -Cc adapter` | List adapter devices (NIC, HBA, etc.) | `lsdev -Cc adapter` | `lspci` |
| `lsdev -Cc if` | List network interfaces | `lsdev -Cc if` | `ip link` |
| `lsattr -El <device>` | Show attributes of a specific device | `lsattr -El hdisk0` | `hdparm -I /dev/sda` |
| `prtconf` | Full system hardware overview | `prtconf` | `lshw` |
| `errpt` | System error report (hardware/software faults) | `errpt -a` | `dmesg` |
| `errpt -j <ID>` | Show detail on a specific error entry | `errpt -j AA8AB241` | `dmesg | grep <string>` |
| `errclear 0` | Clear all error log entries | `errclear 0` | N/A |
| `cfgmgr` | Detect and configure new hardware | `cfgmgr` | `udevadm trigger` |
| `lscfg -v` | List all configured hardware verbosely | `lscfg -v` | `lshw` |

---

## 3. Users, Groups & Authentication

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `mkuser` | Create a new user | `mkuser home=/home/finn shell=/usr/bin/bash finn` | `useradd` |
| `rmuser` | Remove a user | `rmuser finn` | `userdel` |
| `chuser` | Modify user attributes | `chuser shell=/usr/bin/bash finn` | `usermod` |
| `lsuser` | List user attributes | `lsuser -a ALL finn` | `getent passwd finn` |
| `passwd` | Change user password | `passwd finn` | Same |
| `pwdadm` | Manage password admin (force change, etc.) | `pwdadm -f ADMCHG finn` | `chage` |
| `chsec` | Change security stanza attributes | `chsec -f /etc/security/user -s finn -a maxage=12` | `chage` / `usermod` |
| `mkgroup` | Create a new group | `mkgroup admins` | `groupadd` |
| `rmgroup` | Remove a group | `rmgroup admins` | `groupdel` |
| `chgroup` | Modify group attributes | `chgroup users=finn,bob admins` | `gpasswd` |
| `lsgroup` | List group attributes | `lsgroup -a ALL admins` | `getent group` |
| `id` | Show user and group IDs | `id finn` | Same |
| `who` | Show currently logged in users | `who` | Same |
| `w` | Who is logged in and what they're doing | `w` | Same |
| `last` | Login history | `last -20` | Same |
| `su` | Switch user | `su - finn` | Same |
| `sudo` | Run as another user (if configured) | `sudo command` | Same |
| `lsuser -f ALL` | List all users with all attributes | `lsuser -f ALL` | `cat /etc/passwd` |

> **AIX auth note:** AIX stores user attributes in `/etc/security/user`, `/etc/security/passwd`, and `/etc/security/limits` — not just `/etc/passwd` and `/etc/shadow` like Linux.

---

## 4. Files & Directories

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `ls` | List directory contents | `ls -lah` | Same |
| `pwd` | Print working directory | `pwd` | Same |
| `cd` | Change directory | `cd /var/log` | Same |
| `mkdir` | Create directory | `mkdir -p /opt/ldap/backup` | Same |
| `rm` | Remove files/directories | `rm -rf dir/` | Same |
| `cp` | Copy files | `cp -r src/ dest/` | Same |
| `mv` | Move/rename files | `mv old new` | Same |
| `touch` | Create empty file / update timestamp | `touch file.txt` | Same |
| `ln` | Create links | `ln -s target link` | Same |
| `find` | Search for files | `find /var -mtime -1 -type f` | Same |
| `stat` | Show file metadata | `stat file` | Same |
| `file` | Determine file type | `file binary` | Same |
| `which` / `whence` | Find a command's location | `whence lsuser` | `which` / `type` |

> **AIX filesystem note:** AIX uses JFS2 (Journaled File System 2) by default, not ext4/XFS. Key paths differ slightly — e.g., `/usr/bin` for most commands, `/usr/sbin` for admin tools.

---

## 5. Permissions & Ownership

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `chmod` | Change file permissions | `chmod 750 script.sh` | Same |
| `chown` | Change owner | `chown finn:admins file` | Same |
| `chgrp` | Change group | `chgrp admins file` | Same |
| `umask` | View/set default permission mask | `umask 022` | Same |
| `acledit` | Edit ACLs on AIX files | `acledit file` | `setfacl` |
| `aclget` | Display ACL on a file | `aclget file` | `getfacl` |
| `aclput` | Apply ACL from a file | `aclput file < acl.txt` | `setfacl --restore` |

---

## 6. Text Processing

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `cat` / `tac` | Print file contents | `cat /etc/hosts` | Same |
| `head` / `tail` | First/last lines of a file | `tail -f /var/log/messages` | Same |
| `grep` / `egrep` | Search text | `grep -r "error" /var/log` | Same |
| `sed` | Stream editor | `sed -i 's/old/new/g' file` | Same |
| `awk` | Field processing | `awk -F: '{print $1}' /etc/passwd` | Same |
| `cut` | Extract fields | `cut -d: -f1 /etc/passwd` | Same |
| `sort` / `uniq` | Sort and deduplicate | `sort file \| uniq -c` | Same |
| `wc` | Count lines/words/bytes | `wc -l file` | Same |
| `diff` | Compare files | `diff file1 file2` | Same |
| `pg` | AIX pager (similar to `more`) | `pg /etc/security/user` | `less` / `more` |
| `tee` | Write to file and stdout | `command \| tee output.txt` | Same |
| `xargs` | Build commands from stdin | `find . -name "*.log" \| xargs rm` | Same |
| `vi` / `vim` | Text editor | `vi /etc/hosts` | Same |

---

## 7. Processes & Job Control

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `ps` | List running processes | `ps -ef` | `ps aux` |
| `ps -ef \| grep <name>` | Find a specific process | `ps -ef \| grep slapd` | Same |
| `kill` | Send signal to a process | `kill -9 PID` | Same |
| `killall` | Kill by process name | `killall slapd` | Same |
| `nice` / `renice` | Set/change process priority | `renice -n 5 -p PID` | Same |
| `nohup` | Run immune to hangups | `nohup ./script.sh &` | Same |
| `bg` / `fg` / `jobs` | Background/foreground job control | `bg %1` | Same |
| `wait` | Wait for background jobs | `wait` | Same |
| `lsof` | List open files by process | `lsof -i :389` | Same |
| `procinfo` | Show process resource usage | `procinfo PID` | `/proc/PID/status` |
| `svmon` | AIX virtual memory monitor per process | `svmon -P PID` | `pmap` |

---

## 8. Performance & Diagnostics

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `topas` | AIX's interactive performance monitor | `topas` | `htop` |
| `nmon` | Full-screen performance tool (CPU/disk/net/mem) | `nmon` | `glances` |
| `vmstat` | Virtual memory/CPU statistics | `vmstat 1 5` | Same |
| `iostat` | I/O statistics per disk | `iostat -d 1 5` | Same |
| `netstat` | Network stats and connections | `netstat -an` | `ss -an` |
| `sar` | System activity reporter (historical) | `sar -u 1 5` | Same |
| `filemon` | Monitor file/disk activity | `filemon -o out.txt` | `iotop` |
| `netpmon` | Monitor network activity | `netpmon -o out.txt` | `nethogs` |
| `tprof` | CPU profiler | `tprof -p program` | `perf` |
| `svmon` | System virtual memory monitor | `svmon -G` | `vmstat` |
| `lparstat` | LPAR CPU usage (virtualized environments) | `lparstat 1 5` | N/A (AIX-specific) |
| `errpt` | Error report — hardware/software faults | `errpt -a \| head -50` | `dmesg` |
| `bindprocessor` | Bind processes to specific CPUs | `bindprocessor -q` | `taskset` |

---

## 9. Storage, LVM & Filesystems

> AIX invented LVM (Logical Volume Manager). Its terminology differs from Linux LVM — **Volume Groups**, **Logical Volumes**, and **Physical Volumes** exist in AIX too, but the commands are different.

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `lspv` | List physical volumes (disks) | `lspv` | `pvdisplay` |
| `lsvg` | List volume groups | `lsvg` / `lsvg -l rootvg` | `vgdisplay` |
| `lslv` | List logical volumes | `lslv hd1` | `lvdisplay` |
| `mkvg` | Create a volume group | `mkvg -y datavg hdisk1` | `vgcreate` |
| `mklv` | Create a logical volume | `mklv -y ldaplv -t jfs2 datavg 1G` | `lvcreate` |
| `extendvg` | Add a disk to a volume group | `extendvg datavg hdisk2` | `vgextend` |
| `extendlv` | Extend a logical volume | `extendlv ldaplv 512M` | `lvextend` |
| `reducevg` | Remove disk from volume group | `reducevg datavg hdisk2` | `vgreduce` |
| `rmlv` | Remove a logical volume | `rmlv ldaplv` | `lvremove` |
| `rmvg` | Remove a volume group | `rmvg datavg` | `vgremove` |
| `df` | Disk free (filesystem usage) | `df -g` (in GB) | `df -h` |
| `du` | Directory disk usage | `du -sm /opt/*` | `du -sh` |
| `mount` / `umount` | Mount/unmount filesystems | `mount /dev/ldaplv /opt/ldap` | Same |
| `crfs` | Create a filesystem on a logical volume | `crfs -v jfs2 -d ldaplv -m /opt/ldap -A yes` | `mkfs` + `mount` |
| `chfs` | Change filesystem attributes (resize) | `chfs -a size=+1G /opt/ldap` | `resize2fs` |
| `rmfs` | Remove a filesystem | `rmfs /opt/ldap` | `umount` + manual |
| `lsfs` | List filesystems | `lsfs` | `findmnt` |
| `fsck` | Filesystem check | `fsck /dev/ldaplv` | Same |
| `/etc/filesystems` | Persistent mount config (like `/etc/fstab`) | `cat /etc/filesystems` | `/etc/fstab` |

---

## 10. Networking

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `ifconfig` | View/configure network interfaces | `ifconfig en0` | `ip addr` |
| `ifconfig en0 up/down` | Bring interface up/down | `ifconfig en0 down` | `ip link set eth0 down` |
| `netstat -rn` | Show routing table | `netstat -rn` | `ip route` |
| `route` | Manage routing table | `route add -net 10.0.0.0/24 10.0.0.1` | `ip route add` |
| `ping` | Test reachability | `ping -c 4 host` | Same |
| `traceroute` | Trace network path | `traceroute host` | Same |
| `netstat -an` | All connections and listening ports | `netstat -an \| grep LISTEN` | `ss -tulnp` |
| `host` / `nslookup` | DNS lookup | `host example.com` | `dig` |
| `no` | AIX network options (kernel tuning) | `no -a` | `sysctl -a` (net.*) |
| `entstat` | Ethernet adapter statistics | `entstat -d en0` | `ethtool` |
| `smit tcpip` | Configure TCP/IP via SMIT | `smit tcpip` | `nmtui` |
| `mktcpip` | Configure TCP/IP from command line | `mktcpip -h host -a 10.0.0.5 -m 255.255.255.0 -i en0` | `nmcli` |
| `lsattr -El en0` | Show NIC attributes | `lsattr -El en0` | `ethtool en0` |
| `iptrace` | Packet tracing (AIX) | `iptrace -i en0 /tmp/trace.out` | `tcpdump` |
| `ipreport` | Analyze `iptrace` output | `ipreport /tmp/trace.out` | `tcpdump -r` |

---

## 11. Package Management (installp, nim, rpm)

> AIX uses `installp` for native packages (`.bff` format) and `nim` for network installs. RPM is also supported for open-source software via the AIX Toolbox.

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `installp -aXgd` | Install a package from media | `installp -aXgd /dev/cd0 all` | `dnf install` |
| `installp -l` | List packages on media | `installp -l -d /dev/cd0` | `dnf list` |
| `installp -u` | Remove (uninstall) a package | `installp -u bos.net.tcp.client` | `dnf remove` |
| `lslpp -l` | List installed filesets | `lslpp -l \| grep openssh` | `rpm -qa` |
| `lslpp -f <fileset>` | List files in a fileset | `lslpp -f openssh.base` | `rpm -ql` |
| `lslpp -w <file>` | Find which fileset owns a file | `lslpp -w /usr/bin/ssh` | `rpm -qf` |
| `instfix -i` | List installed fixes/patches | `instfix -i \| grep ML` | `dnf history` |
| `emgr -l` | List interim fixes (iFixes) | `emgr -l` | N/A |
| `emgr -i` | Install an iFix | `emgr -i ifix.tar` | N/A |
| `rpm -qa` | List RPM packages (Toolbox software) | `rpm -qa \| grep curl` | Same |
| `rpm -ivh` | Install an RPM | `rpm -ivh package.rpm` | Same |
| `nim -o install` | NIM network install | `nim -o cust -a lpp_source=lpp_res -a filesets=bos.net target` | `dnf install` (remote) |

---

## 12. Services & System Control

> AIX uses **SRC (System Resource Controller)** to manage services — not systemd. Think of `startsrc`/`stopsrc`/`lssrc` as the AIX equivalents of `systemctl start/stop/status`.

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `startsrc -s <subsystem>` | Start a service | `startsrc -s slapd` | `systemctl start` |
| `stopsrc -s <subsystem>` | Stop a service | `stopsrc -s slapd` | `systemctl stop` |
| `refresh -s <subsystem>` | Reload a service config | `refresh -s slapd` | `systemctl reload` |
| `lssrc -s <subsystem>` | Show service status | `lssrc -s slapd` | `systemctl status` |
| `lssrc -a` | List all subsystem statuses | `lssrc -a` | `systemctl list-units` |
| `mkssys` | Register a new subsystem with SRC | `mkssys -s myapp -p /opt/myapp/bin/app -u 0` | `systemctl enable` |
| `rmssys` | Remove a subsystem from SRC | `rmssys -s myapp` | `systemctl disable` |
| `chssys` | Modify a subsystem definition | `chssys -s myapp -a "-flag"` | `systemctl edit` |
| `shutdown -h now` | Halt the system | `shutdown -h now` | Same |
| `shutdown -r now` | Reboot the system | `shutdown -r now` | `reboot` |
| `init` | Change runlevel | `init 6` (reboot) / `init 0` (halt) | `systemctl isolate` |
| `who -r` | Show current runlevel | `who -r` | `systemctl get-default` |
| `/etc/inittab` | Startup config (AIX's init system) | `cat /etc/inittab` | `/etc/systemd/system/` |
| `mkitab` | Add entry to `/etc/inittab` | `mkitab "myapp:2:respawn:/opt/myapp/start"` | `systemctl enable` |
| `chitab` | Modify an `/etc/inittab` entry | `chitab "myapp:2:off:/opt/myapp/start"` | `systemctl disable` |

---

## 13. Scheduling & Automation

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `crontab -e` | Edit cron jobs | `crontab -e` | Same |
| `crontab -l` | List cron jobs | `crontab -l` | Same |
| `/var/spool/cron/crontabs/` | Cron storage location | `ls /var/spool/cron/crontabs/` | `/var/spool/cron/` |
| `at` | Schedule one-time job | `at now + 1 hour` | Same |
| `atq` / `atrm` | List/remove `at` jobs | `atq` | Same |
| `batch` | Run when system load allows | `batch` | Same |

---

## 14. Logging & Auditing

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `errpt` | AIX system error report | `errpt -a` | `dmesg` / `journalctl` |
| `errpt -j <ID>` | Detail on a specific error | `errpt -j AA8AB241` | `journalctl -p err` |
| `errclear 0` | Clear all errors | `errclear 0` | N/A |
| `alog -o -t boot` | View boot log | `alog -o -t boot` | `journalctl -b` |
| `alog -o -t console` | View console log | `alog -o -t console` | `dmesg` |
| `alog -t syslog` | View syslog via alog | `alog -o -t syslog` | `journalctl` |
| `/var/log/syslog` | Syslog location | `tail -f /var/log/messages` | Same path (Linux) |
| `syslogd` | Syslog daemon | `lssrc -s syslogd` | `journald` |
| `audit start` | Start AIX auditing | `audit start` | `auditctl` |
| `audit query` | Show current audit status | `audit query` | `auditctl -s` |
| `auditselect` | Filter audit trail | `auditselect -e "event==USER_Login" /audit/trail` | `ausearch` |
| `auditpr` | Format audit records | `auditpr -t /audit/trail` | `aureport` |

---

## 15. Security & Certificates

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `openssl` | TLS/certificate toolkit | `openssl x509 -in cert.pem -noout -dates` | Same |
| `gsk8capicmd_64` | IBM GSKit certificate management | `gsk8capicmd_64 -cert -list -db key.kdb -pw pass` | `openssl` / `keytool` |
| `keytool` | Java keystore management | `keytool -list -keystore keystore.jks` | Same |
| `certutil` | NSS certificate utility | `certutil -L -d /etc/ldap/certs` | Same |
| `chsec` | Change security settings | `chsec -f /etc/security/user -s default -a maxage=12` | `chage` |
| `lssec` | List security settings | `lssec -f /etc/security/user -s default` | `chage -l` |
| `mkfilt` | Create IP filter rules | `mkfilt` | `iptables` |
| `lsfilt` | List IP filter rules | `lsfilt` | `iptables -L` |
| `genfilt` | Generate IP filter rules | `genfilt -v 4 -a D -s 0.0.0.0 -d 0.0.0.0` | `iptables -A` |

---

## 16. Backup & Recovery

| Command | Description | Example | Linux Equivalent |
|---------|-------------|---------|-----------------|
| `mksysb` | Full system backup to tape/file | `mksysb -i /dev/rmt0` | `dd` / `rsync` |
| `savevg` | Back up a volume group | `savevg -f /dev/rmt0 datavg` | `dd` / `tar` |
| `restvg` | Restore a volume group | `restvg -f /dev/rmt0` | N/A |
| `tar` | Archive files | `tar -cvf archive.tar /opt/ldap` | Same |
| `cpio` | Copy files in/out | `find . \| cpio -ovB > archive.cpio` | Same |
| `dd` | Low-level copy | `dd if=/dev/hdisk0 of=/dev/hdisk1` | Same |
| `rsync` | Sync files (if AIX Toolbox installed) | `rsync -avz src/ dest/` | Same |
| `nim -o mksysb` | NIM-based system backup | `nim -o mksysb -a mksysb_flags="-e" target` | N/A |
| `mkcd` | Create bootable CD/ISO | `mkcd -r -d /dev/cd0 -m /tmp/cd` | `genisoimage` |

---

## 17. SMIT — AIX's Admin Interface

**SMIT** (System Management Interface Tool) is AIX's menu-driven admin UI. Most things you'd do on Linux by editing config files directly are done in AIX through SMIT. It also generates the underlying command, which you can view or save for scripting.

| Command | Description |
|---------|-------------|
| `smit` | Full SMIT interface (text-based menus) |
| `smitty` | SMIT in curses/TUI mode (most common) |
| `smit user` | Jump straight to user management menus |
| `smit tcpip` | Jump to TCP/IP configuration |
| `smit storage` | Jump to storage/LVM management |
| `smit lvm` | Jump to LVM management specifically |
| `smit install` | Jump to software installation |
| `smit errlog` | Jump to error log management |
| `smit cron` | Jump to cron management |

> **Pro tip:** Every action you take in SMIT generates a command that gets saved to `/var/adm/smit.log` and `/var/adm/smit.script`. Mining `smit.script` is one of the best ways to learn the underlying AIX commands when you're new.

---

## 18. AIX-Specific Utilities

| Command | Description | Notes |
|---------|-------------|-------|
| `odmadd` | Add entries to ODM (Object Data Manager) | AIX stores device/system config in ODM, not flat files |
| `odmget` | Query ODM database | `odmget -q "name=en0" CuAt` |
| `odmchange` | Modify ODM entries | Handle with care — corruption can prevent boot |
| `odmdelete` | Delete ODM entries | Rarely needed; used for removing device definitions |
| `diag` | AIX hardware diagnostics | Requires console access; menu-driven |
| `snap` | Collect AIX support data bundle | `snap -ac` — equivalent of `sosreport` on RHEL |
| `geninstall` | Wrapper for install operations | Used by SMIT internally |
| `bosboot` | Recreate AIX boot image | `bosboot -ad /dev/hdisk0` — needed after kernel changes |
| `bootlist` | Set/view boot device list | `bootlist -m normal -o` |
| `slibclean` | Clean unused shared libraries from memory | Run before patching |
| `lquerylv` | Query logical volume info (low-level) | `lquerylv -L /dev/ldaplv` |
| `getconf` | Query system configuration variables | `getconf NPROCESSORS_ONLN` |

---

## 19. DB2 — IBM SDS Backend

> IBM Security Directory Server stores all directory data in a DB2 database. Basic DB2 administration knowledge is essential for an LDAP admin on AIX. DB2 commands are run as the DB2 instance owner (typically `ldapdb2`) — switch with `su - ldapdb2` before running them.

| Command | Description | Example |
|---------|-------------|---------|
| `db2start` | Start the DB2 instance | `db2start` |
| `db2stop` | Stop the DB2 instance | `db2stop force` |
| `db2 list db directory` | List all known databases | `db2 list db directory` |
| `db2 connect to <db>` | Connect to a database | `db2 connect to LDAPDB` |
| `db2 connect reset` | Disconnect from database | `db2 connect reset` |
| `db2 get dbm cfg` | Show database manager configuration | `db2 get dbm cfg` |
| `db2 get db cfg for <db>` | Show database configuration | `db2 get db cfg for LDAPDB` |
| `db2 update db cfg` | Change a database config parameter | `db2 update db cfg for LDAPDB using LOGFILSIZ 4096` |
| `db2 get snapshot for database on <db>` | Real-time database statistics | `db2 get snapshot for database on LDAPDB` |
| `db2 list applications` | Show active DB2 connections | `db2 list applications show detail` |
| `db2 force application all` | Disconnect all applications (before stop) | `db2 force application all` |
| `db2 backup db <db>` | Online database backup | `db2 backup db LDAPDB online to /var/ldap/backup` |
| `db2 restore db <db>` | Restore database from backup | `db2 restore db LDAPDB from /var/ldap/backup` |
| `db2 reorg table <table>` | Reorganise a fragmented table | `db2 reorg table LDAPDB2.LDAP_ENTRY` |
| `db2 runstats on table <table>` | Update optimizer statistics | `db2 runstats on table LDAPDB2.LDAP_ENTRY with distribution and detailed indexes all` |
| `db2 alter bufferpool` | Resize the buffer pool | `db2 alter bufferpool IBMDEFAULTBP size 50000` |
| `db2 list tablespaces` | Show tablespace usage | `db2 list tablespaces show detail` |
| `db2diag` | Parse the DB2 diagnostic log | `db2diag -gi msg::"SQL"` |
| `db2pd` | Real-time DB2 problem determination | `db2pd -db LDAPDB -locks` |
| `db2level` | Show DB2 version/fix pack level | `db2level` |

**Diagnostic log location:** `/home/ldapdb2/sqllib/db2dump/db2diag.log`

**Buffer pool hit ratio check** (should be >95% — low ratio means DB2 is reading from disk, not memory):
```bash
db2 get snapshot for database on LDAPDB | grep -i "buffer pool"
```

---

## 20. Quick One-Liners for AIX

| Goal | Command |
|------|---------|
| Show OS level with maintenance pack | `oslevel -s` |
| List all running subsystems (services) | `lssrc -a \| grep active` |
| Find which fileset owns a binary | `lslpp -w /usr/bin/slapd` |
| Check a specific hardware error in detail | `errpt -a \| head -100` |
| List all users and their shells | `lsuser -a shell ALL` |
| Show disk usage per filesystem in GB | `df -g` |
| Check network interface stats | `entstat -d en0 \| grep -i error` |
| List all volume groups and free space | `lsvg \| xargs lsvg` |
| Show LPAR CPU entitlement | `lparstat -i \| grep -i entitled` |
| Check if a port is listening | `netstat -an \| grep LISTEN \| grep 389` |
| View boot log | `alog -o -t boot \| tail -50` |
| Check installed maintenance level | `instfix -i \| grep "ML\|SP"` |
| Collect full diagnostic bundle for IBM support | `snap -ac && ls /tmp/ibmsupt/` |
| Show all users currently logged in | `who` |
| Find large files over 100MB | `find / -xdev -size +100000k -exec ls -lh {} \;` |
| View real-time performance overview | `nmon` |
| Tail system messages | `tail -f /var/log/messages` |
| Show all open files for a process | `lsof -p PID` |
| Force password change at next login | `pwdadm -f ADMCHG username` |

---

## See Also

- [commands.md](./commands.md) — Linux command reference
- [decision-guide.md](./decision-guide.md) — scenario-to-tool mapping
- [LICENSE](./LICENSE) — MIT
