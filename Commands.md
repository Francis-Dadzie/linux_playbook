# Linux Sysadmin Command Reference

A practical workflow/command reference for Linux System Administrators on what you actually use starting with "what is this box and what's on it," moving through day-to-day administration, and ending with modern tooling and quick one-liner recipes.

Useful for daily ops work, troubleshooting, and certification prep (RHCSA/LFCS).

## Table of Contents

- [Quick System Overview](#1-quick-system-overview)
- [Hardware & Devices](#2-hardware--devices)
- [Users, Groups & Authentication](#3-users-groups--authentication)
- [Files & Directories](#4-files--directories)
- [Permissions, Ownership & ACLs](#5-permissions-ownership--acls)
- [Text Processing & Editors](#6-text-processing--editors)
- [Processes & Job Control](#7-processes--job-control)
- [Performance & Troubleshooting](#8-performance--troubleshooting)
- [Package Management](#9-package-management)
- [systemd: Services, Timers & Logs](#10-systemd-services-timers--logs)
- [Networking Basics](#11-networking-basics)
- [Networking — Advanced & Firewalls](#12-networking--advanced--firewalls)
- [Storage, Filesystems & LVM](#13-storage-filesystems--lvm)
- [Archiving, Compression & Backup](#14-archiving-compression--backup)
- [Security & SELinux](#15-security--selinux)
- [SSH & Remote Access](#16-ssh--remote-access)
- [Kernel & Boot Management](#17-kernel--boot-management)
- [Scheduling Tasks](#18-scheduling-tasks)
- [Containers & Virtualization](#19-containers--virtualization)
- [Modern CLI Alternatives](#20-modern-cli-alternatives)
- [Cloud & Automation Tooling](#21-cloud--automation-tooling)
- [Quick One-Liner Recipes](#22-quick-one-liner-recipes)

---

## Quick System Overview

The first commands to run on any unfamiliar box.

| Command | Description | Example |
|---------|-------------|---------|
| `hostnamectl` | Show hostname, OS, kernel, architecture in one shot | `hostnamectl` |
| `uname` | Display system information | `uname -a` |
| `cat /etc/os-release` | Show OS distro/version | `cat /etc/os-release` |
| `lsb_release` | Display Linux Standard Base info | `lsb_release -a` |
| `uptime` | How long the system has been running + load average | `uptime` |
| `who -b` | Show last boot time | `who -b` |
| `date` | Display or set date and time | `date` |
| `timedatectl` | Control/inspect system time, timezone, NTP sync | `timedatectl status` |
| `hostname` | Show or set system hostname | `hostname -f` (FQDN) |
| `getent` | Query name service databases (passwd, hosts, etc.) | `getent passwd username` |

---

## Hardware & Devices

| Command | Description | Example |
|---------|-------------|---------|
| `lscpu` | Display CPU architecture details | `lscpu` |
| `free` | Show memory and swap usage | `free -h` |
| `lsblk` | List block devices in tree form | `lsblk -f` (with filesystems) |
| `lsusb` | List USB devices | `lsusb` |
| `lspci` | List PCI devices | `lspci -k` (with kernel drivers) |
| `lshw` | List detailed hardware info | `lshw -short` |
| `dmidecode` | Read hardware info from BIOS/DMI | `dmidecode -t system` |
| `vmstat` | Report virtual memory statistics | `vmstat 1` |
| `nproc` | Print number of available CPU cores | `nproc` |
| `inxi` | Friendly system/hardware summary (if installed) | `inxi -Fxz` |
| `sensors` | Show hardware temperature/voltage sensors | `sensors` |

---

## Users, Groups & Authentication

| Command | Description | Example |
|---------|-------------|---------|
| `whoami` | Display current effective username | `whoami` |
| `id` | Display user and group IDs | `id username` |
| `useradd` | Create a new user | `useradd -m -s /bin/bash username` |
| `usermod` | Modify a user account | `usermod -aG wheel username` |
| `userdel` | Delete a user | `userdel -r username` |
| `passwd` | Change a user's password | `passwd username` |
| `chage` | View/change password aging policy | `chage -l username` |
| `groupadd` | Create a new group | `groupadd groupname` |
| `groupmod` | Modify a group | `groupmod -n newname oldname` |
| `groupdel` | Delete a group | `groupdel groupname` |
| `gpasswd` | Administer group membership | `gpasswd -a user group` |
| `su` | Switch user | `su - username` |
| `sudo` | Run a command as another user | `sudo command` |
| `visudo` | Safely edit `/etc/sudoers` | `visudo` |
| `w` | Who is logged in and what they're doing | `w` |
| `who` | Show who is logged in | `who` |
| `last` | Show login history | `last -20` |
| `lastlog` | Show last login per user | `lastlog` |
| `lastb` | Show failed login attempts | `lastb` |
| `pinky` | Lightweight `finger`-like user info | `pinky username` |
| `realm` | Discover/join Active Directory domains | `realm list` |
| `sssctl` | SSSD diagnostics | `sssctl domain-list` |

---

## Files & Directories

| Command | Description | Example |
|---------|-------------|---------|
| `ls` | List directory contents | `ls -lah` |
| `pwd` | Print working directory | `pwd` |
| `cd` | Change directory | `cd /var/log` |
| `mkdir` | Create directories | `mkdir -p a/b/c` |
| `rmdir` | Remove empty directories | `rmdir dir` |
| `touch` | Create empty file / update timestamp | `touch file.txt` |
| `cp` | Copy files and directories | `cp -r src/ dest/` |
| `mv` | Move/rename files | `mv old new` |
| `rm` | Remove files or directories | `rm -rf dir/` |
| `ln` | Create hard or symbolic links | `ln -s target linkname` |
| `find` | Search for files by criteria | `find /var -mtime -1 -type f` |
| `locate` | Quickly find files by name (DB-backed) | `locate filename` |
| `updatedb` | Refresh the `locate` database | `updatedb` |
| `stat` | Display detailed file metadata | `stat file` |
| `file` | Determine file type | `file binaryfile` |
| `readlink` | Resolve symbolic links | `readlink -f link` |
| `realpath` | Print canonical absolute path | `realpath ./file` |
| `tree` | Show directory structure as a tree | `tree -L 2` |
| `basename` / `dirname` | Strip path / strip filename | `basename /a/b/c.txt` |
| `shred` | Securely overwrite a file before deletion | `shred -u file` |

---

## Permissions, Ownership & ACLs

| Command | Description | Example |
|---------|-------------|---------|
| `chmod` | Change file permissions | `chmod 750 file` |
| `chown` | Change file owner/group | `chown user:group file` |
| `chgrp` | Change group ownership | `chgrp group file` |
| `umask` | View/set default permission mask | `umask 022` |
| `getfacl` | View ACL entries | `getfacl file` |
| `setfacl` | Set ACL entries | `setfacl -m u:user:rwx file` |
| `lsattr` | List extended file attributes | `lsattr file` |
| `chattr` | Change extended file attributes | `chattr +i file` |
| `namei` | Show ownership/permissions along a path | `namei -l /var/www/html/index.html` |

---

## Text Processing & Editors

| Command | Description | Example |
|---------|-------------|---------|
| `cat` / `tac` | Print file (forward / reversed) | `cat file` |
| `less` / `more` | Page through file content | `less /var/log/messages` |
| `head` / `tail` | Show first/last lines | `tail -f /var/log/syslog` |
| `grep` / `egrep` | Search text with patterns | `grep -ri 'error' /var/log` |
| `sed` | Stream editor for find/replace | `sed -i 's/old/new/g' file` |
| `awk` | Pattern scanning & field processing | `awk -F: '{print $1}' /etc/passwd` |
| `cut` | Extract columns/fields | `cut -d: -f1 /etc/passwd` |
| `sort` / `uniq` | Sort and deduplicate lines | `sort file | uniq -c` |
| `wc` | Count lines, words, bytes | `wc -l file` |
| `diff` / `vimdiff` | Compare files | `diff file1 file2` |
| `tr` | Translate/delete characters | `tr 'a-z' 'A-Z' < file` |
| `tee` | Write stdin to file(s) and stdout | `command | tee -a log.txt` |
| `column` | Format text into columns | `cat /etc/passwd | column -t -s:` |
| `xargs` | Build commands from stdin | `find . -name "*.log" | xargs rm` |
| `vim` / `nano` / `emacs` | Text editors | `vim file` |
| `jq` | JSON processor | `curl ... | jq '.data[0]'` |

---

## Processes & Job Control

| Command | Description | Example |
|---------|-------------|---------|
| `ps` | Report process status | `ps aux --sort=-%mem` |
| `top` / `htop` | Live process viewer | `htop` |
| `pgrep` / `pkill` | Find/kill processes by name | `pkill -f myscript.py` |
| `kill` / `killall` | Send signals to processes | `kill -9 PID` |
| `pstree` | Display process tree | `pstree -p` |
| `pidof` | Find PID of a running program | `pidof nginx` |
| `nice` / `renice` | Set/adjust process priority | `renice -n 5 -p PID` |
| `nohup` | Run a command immune to hangups | `nohup ./script.sh &` |
| `jobs` / `fg` / `bg` | Manage shell jobs | `bg %1` |
| `disown` | Detach a job from the shell | `disown -h %1` |
| `time` / `timeout` | Time or limit command execution | `timeout 30s curl host` |
| `lsof` | List open files/sockets by process | `lsof -i :443` |
| `fuser` | Identify processes using files/mounts | `fuser -mv /mnt/data` |

---

## Performance & Troubleshooting

| Command | Description | Example |
|---------|-------------|---------|
| `vmstat` | Virtual memory / CPU stats | `vmstat 1 5` |
| `iostat` | CPU and disk I/O statistics | `iostat -xz 1` |
| `mpstat` | Per-CPU statistics | `mpstat -P ALL 1` |
| `sar` | Historical system activity reporting | `sar -u 1 5` |
| `dstat` | Combined resource statistics | `dstat -cdngy` |
| `iotop` | Per-process disk I/O | `iotop -o` |
| `nethogs` | Per-process network usage | `nethogs eth0` |
| `iftop` | Live bandwidth usage by connection | `iftop -i eth0` |
| `strace` | Trace system calls | `strace -p PID` |
| `ltrace` | Trace library calls | `ltrace command` |
| `ldd` | Show shared library dependencies | `ldd /usr/bin/bash` |
| `pmap` | Show process memory map | `pmap -x PID` |
| `slabtop` | Kernel slab cache usage | `slabtop` |
| `dmesg` | Kernel ring buffer messages | `dmesg -T | tail -50` |
| `sosreport` | Collect a full diagnostic bundle (RHEL) | `sosreport` |
| `perf` | CPU profiling | `perf top` |
| `numastat` | NUMA memory statistics | `numastat` |

---

## Package Management

### RPM-based (RHEL, CentOS, Rocky, Fedora)

| Command | Description | Example |
|---------|-------------|---------|
| `dnf install` | Install a package | `dnf install httpd` |
| `dnf update` / `upgrade` | Update packages | `dnf update` |
| `dnf remove` | Remove a package | `dnf remove httpd` |
| `dnf search` | Search for a package | `dnf search nginx` |
| `dnf repolist` | List enabled repositories | `dnf repolist` |
| `dnf history` | Show transaction history | `dnf history list` |
| `rpm -qa` | List all installed packages | `rpm -qa | grep kernel` |
| `rpm -qi` | Show package info | `rpm -qi httpd` |
| `rpm -ql` | List files owned by a package | `rpm -ql httpd` |
| `rpm -qf` | Find which package owns a file | `rpm -qf /usr/bin/vim` |
| `createrepo` | Build a local RPM repo | `createrepo /path/to/repo` |

### DEB-based (Debian, Ubuntu)

| Command | Description | Example |
|---------|-------------|---------|
| `apt update` | Refresh package index | `apt update` |
| `apt upgrade` | Upgrade installed packages | `apt upgrade` |
| `apt install` | Install a package | `apt install nginx` |
| `apt remove` / `purge` | Remove a package (with/without config) | `apt purge nginx` |
| `apt autoremove` | Remove unused dependencies | `apt autoremove` |
| `apt search` | Search for a package | `apt search nginx` |
| `dpkg -l` | List installed packages | `dpkg -l | grep nginx` |
| `dpkg -L` | List files owned by a package | `dpkg -L nginx` |
| `dpkg -S` | Find which package owns a file | `dpkg -S /usr/bin/vim` |
| `apt-cache policy` | Show available versions/priority | `apt-cache policy nginx` |
| `add-apt-repository` | Add a PPA/repo | `add-apt-repository ppa:name/ppa` |

---

## systemd: Services, Timers & Logs

| Command | Description | Example |
|---------|-------------|---------|
| `systemctl status` | Show unit status | `systemctl status sshd` |
| `systemctl start/stop/restart` | Control a service | `systemctl restart nginx` |
| `systemctl enable/disable` | Toggle start-on-boot | `systemctl enable --now nginx` |
| `systemctl is-active/is-enabled` | Quick state checks | `systemctl is-active sshd` |
| `systemctl daemon-reload` | Reload unit file changes | `systemctl daemon-reload` |
| `systemctl list-units` | List active units | `systemctl list-units --type=service` |
| `systemctl list-unit-files` | List all unit files & states | `systemctl list-unit-files` |
| `systemctl list-timers` | List scheduled systemd timers | `systemctl list-timers` |
| `systemctl mask/unmask` | Prevent a unit from starting at all | `systemctl mask bluetooth` |
| `systemd-analyze` | Analyze boot performance | `systemd-analyze blame` |
| `systemd-cgls` | View the control group tree | `systemd-cgls` |
| `journalctl` | Query the systemd journal | `journalctl -u nginx -f` |
| `journalctl -b` | Logs since current/previous boot | `journalctl -b -1` |
| `journalctl --since/--until` | Filter logs by time | `journalctl --since "1 hour ago"` |
| `journalctl --disk-usage` | Show journal disk usage | `journalctl --disk-usage` |

---

## Networking Basics

| Command | Description | Example |
|---------|-------------|---------|
| `ip addr` | Show/configure IP addresses | `ip addr show` |
| `ip link` | Show/configure network interfaces | `ip link set eth0 up` |
| `ip route` | Show/manipulate routing table | `ip route show` |
| `ip neigh` | Show ARP/neighbor table | `ip neigh show` |
| `ss` | Modern socket statistics | `ss -tulnp` |
| `ping` | Test reachability | `ping -c 4 host` |
| `traceroute` / `tracepath` | Trace the route to a host | `traceroute host` |
| `dig` / `host` / `nslookup` | DNS lookups | `dig +short example.com` |
| `whois` | Domain registration lookup | `whois example.com` |
| `hostnamectl` | Set/show hostname | `hostnamectl set-hostname web01` |
| `nmcli` | NetworkManager CLI | `nmcli con show` |
| `nmtui` | NetworkManager TUI | `nmtui` |
| `ethtool` | Query/configure NIC settings | `ethtool eth0` |
| `curl` / `wget` | Transfer data from/to servers | `curl -I https://example.com` |
| `nc` | Netcat — test ports, simple transfers | `nc -zv host 443` |

---

## Networking — Advanced & Firewalls

| Command | Description | Example |
|---------|-------------|---------|
| `tcpdump` | Capture and inspect network traffic | `tcpdump -i eth0 port 443` |
| `nmap` | Network/port scanning | `nmap -sV host` |
| `ip route add/del` | Add/remove static routes | `ip route add 10.0.0.0/24 via 10.0.0.1` |
| `bridge` | Manage bridges/FDB | `bridge link show` |
| `brctl` | Legacy bridge administration | `brctl addbr br0` |
| `vconfig` | VLAN configuration | `vconfig add eth0 10` |
| `tc` | Traffic shaping/control | `tc qdisc add dev eth0 root netem delay 100ms` |
| `firewall-cmd` | firewalld management | `firewall-cmd --permanent --add-port=8080/tcp` |
| `iptables` / `iptables-save` | Legacy packet filtering | `iptables -L -n -v` |
| `nft` | nftables packet filtering | `nft list ruleset` |
| `ufw` | Uncomplicated firewall (Debian/Ubuntu) | `ufw allow 22/tcp` |
| `openvpn` | VPN client/server | `openvpn --config client.ovpn` |
| `wg` | WireGuard VPN management | `wg show` |

---

## Storage, Filesystems & LVM

| Command | Description | Example |
|---------|-------------|---------|
| `df` | Report filesystem disk usage | `df -hT` |
| `du` | Estimate directory space usage | `du -sh /var/*` |
| `lsblk` | List block devices | `lsblk -f` |
| `blkid` | Show block device attributes (UUID, type) | `blkid` |
| `fdisk` / `gdisk` | Partition tables (MBR/GPT) | `fdisk -l` |
| `parted` | Partition manipulation | `parted -l` |
| `mkfs` | Create a filesystem | `mkfs.ext4 /dev/sdb1` |
| `mount` / `umount` | Mount/unmount filesystems | `mount /dev/sdb1 /mnt` |
| `findmnt` | Inspect mounted filesystems | `findmnt /mnt` |
| `/etc/fstab` | Persistent mount definitions | `cat /etc/fstab` |
| `mkswap` / `swapon` / `swapoff` | Manage swap space | `swapon /swapfile` |
| `tune2fs` | Tune ext filesystem parameters | `tune2fs -l /dev/sda1` |
| `fsck` / `xfs_repair` | Check/repair filesystems | `fsck /dev/sda1` |
| `resize2fs` / `xfs_growfs` | Resize filesystems | `resize2fs /dev/sda1` |
| `smartctl` | Disk health (S.M.A.R.T.) | `smartctl -a /dev/sda` |
| `badblocks` | Scan for bad sectors | `badblocks -v /dev/sda` |
| `pvcreate/vgcreate/lvcreate` | Create LVM PV/VG/LV | `lvcreate -L 10G -n data vg0` |
| `pvdisplay/vgdisplay/lvdisplay` | Show LVM details | `vgdisplay` |
| `lvextend` / `vgextend` | Grow LVM volumes/groups | `lvextend -L +5G /dev/vg0/lv0` |
| `lvreduce` | Shrink a logical volume | `lvreduce -L 5G /dev/vg0/lv0` |
| `mdadm` | Manage software RAID arrays | `mdadm --detail /dev/md0` |

---

## Archiving, Compression & Backup

| Command | Description | Example |
|---------|-------------|---------|
| `tar` | Archive (and optionally compress) files | `tar -czvf backup.tar.gz /etc` |
| `gzip` / `gunzip` | Compress/decompress (.gz) | `gzip file` |
| `bzip2` / `bunzip2` | Compress/decompress (.bz2) | `bzip2 file` |
| `xz` / `unxz` | Compress/decompress (.xz) | `xz file` |
| `zip` / `unzip` | Zip archives | `zip -r archive.zip dir/` |
| `7z` | 7-Zip archiver | `7z a archive.7z dir/` |
| `cpio` | Archive via cpio format | `find . | cpio -ov > archive.cpio` |
| `rsync` | Efficient file sync (local/remote) | `rsync -avz --delete src/ dest/` |
| `dd` | Low-level copy / disk imaging | `dd if=/dev/sda of=disk.img bs=4M status=progress` |
| `restic` | Modern encrypted backup tool | `restic -r /repo backup /data` |
| `borg` | Deduplicating backup tool | `borg create ::archive /data` |
| `duplicity` | Encrypted, incremental backups | `duplicity /data scp://user@host/backup` |
| `rdiff-backup` | Remote incremental backup | `rdiff-backup /src host::/dest` |

---

## Security & SELinux

| Command | Description | Example |
|---------|-------------|---------|
| `getenforce` / `setenforce` | Get/set SELinux mode | `setenforce 0` (permissive) |
| `sestatus` | SELinux status summary | `sestatus` |
| `semanage` | Manage SELinux policy (ports, contexts) | `semanage port -l` |
| `setsebool` / `getsebool` | Manage SELinux booleans | `setsebool -P httpd_can_network_connect on` |
| `chcon` / `restorecon` | Set/restore SELinux file contexts | `restorecon -Rv /var/www` |
| `audit2allow` / `audit2why` | Translate SELinux denials into policy | `audit2allow -a -M mymodule` |
| `ausearch` / `aureport` | Search/summarize audit logs | `ausearch -m avc -ts recent` |
| `apparmor_status` / `aa-status` | AppArmor profile status (Debian/Ubuntu) | `aa-status` |
| `fail2ban-client` | Manage fail2ban jail status | `fail2ban-client status sshd` |
| `openssl` | TLS/crypto toolkit | `openssl x509 -in cert.pem -noout -dates` |
| `clamscan` | Antivirus scanning (ClamAV) | `clamscan -r /home` |
| `rkhunter` | Rootkit detection | `rkhunter --check` |
| `lynis` | Security auditing tool | `lynis audit system` |

---

## SSH & Remote Access

| Command | Description | Example |
|---------|-------------|---------|
| `ssh` | Connect to a remote host | `ssh user@host` |
| `ssh-keygen` | Generate an SSH key pair | `ssh-keygen -t ed25519` |
| `ssh-copy-id` | Install a public key on a remote host | `ssh-copy-id user@host` |
| `ssh-agent` / `ssh-add` | Manage cached SSH keys | `ssh-add ~/.ssh/id_ed25519` |
| `scp` | Secure file copy | `scp file user@host:/path` |
| `sftp` | Secure FTP session | `sftp user@host` |
| `sshfs` | Mount a remote dir over SSH | `sshfs user@host:/path /mnt` |
| `rsync` | Sync files over SSH | `rsync -avz -e ssh src/ user@host:dest/` |
| `tmux` / `screen` | Persistent terminal sessions | `tmux new -s work` |
| `mosh` | Mobile shell — resilient SSH alternative | `mosh user@host` |
| `xrdp` / `rdesktop` | RDP server/client | `rdesktop host` |

---

## Kernel & Boot Management

| Command | Description | Example |
|---------|-------------|---------|
| `uname -r` | Show running kernel version | `uname -r` |
| `lsmod` | List loaded kernel modules | `lsmod` |
| `modinfo` | Show info about a module | `modinfo e1000e` |
| `modprobe` / `rmmod` | Load/unload kernel modules | `modprobe nf_conntrack` |
| `depmod` | Regenerate module dependency list | `depmod -a` |
| `sysctl` | View/set kernel parameters at runtime | `sysctl -w net.ipv4.ip_forward=1` |
| `dmesg` | View kernel ring buffer | `dmesg -T` |
| `grub2-mkconfig` | Regenerate GRUB config | `grub2-mkconfig -o /boot/grub2/grub.cfg` |
| `grubby` | Inspect/edit GRUB entries | `grubby --default-kernel` |
| `dracut` | Build initramfs images | `dracut -f` |
| `bootctl` | Manage systemd-boot (UEFI) | `bootctl status` |
| `efibootmgr` | Manage UEFI boot entries | `efibootmgr -v` |
| `systemd-analyze blame` | Find slow-starting boot units | `systemd-analyze blame` |
| `kexec` | Boot directly into another kernel | `kexec -l /boot/vmlinuz --reuse-cmdline` |

---

## Scheduling Tasks

| Command | Description | Example |
|---------|-------------|---------|
| `crontab -e` | Edit current user's cron jobs | `crontab -e` |
| `crontab -l` | List current user's cron jobs | `crontab -l` |
| `/etc/crontab`, `/etc/cron.d/` | System-wide cron jobs | `cat /etc/crontab` |
| `at` | Schedule a one-time job | `at now + 1 hour` |
| `atq` / `atrm` | List / remove `at` jobs | `atq` |
| `batch` | Run when system load permits | `batch <<< "command"` |
| `anacron` | Catch-up scheduler for non-24/7 systems | `anacron -n` |
| `systemd-run` | Run a transient unit on a schedule | `systemd-run --on-calendar="daily" command` |
| `systemctl list-timers` | List active systemd timers | `systemctl list-timers --all` |

---

## Containers & Virtualization

| Command | Description | Example |
|---------|-------------|---------|
| `docker` | Manage containers/images | `docker ps -a` |
| `docker-compose` | Multi-container app definitions | `docker compose up -d` |
| `podman` | Daemonless container engine | `podman ps -a` |
| `buildah` | Build OCI images | `buildah bud -t name .` |
| `skopeo` | Inspect/copy container images between registries | `skopeo inspect docker://image` |
| `crictl` | CRI-compatible container debugging (k8s nodes) | `crictl ps` |
| `virsh` | Manage libvirt VMs | `virsh list --all` |
| `virt-install` | Create a new VM | `virt-install --name vm1 ...` |
| `virt-clone` | Clone an existing VM | `virt-clone --original vm1 --name vm2 ...` |
| `qemu-img` | Create/convert disk images | `qemu-img create -f qcow2 disk.qcow2 20G` |
| `VBoxManage` | VirtualBox CLI management | `VBoxManage list vms` |

---

## Modern CLI Alternatives

Newer tools that have become common on modern servers and dev workstations — useful to know even if the classics remain the lowest-common-denominator default.

| Command | Replaces | Description | Example |
|---------|----------|-------------|---------|
| `bat` | `cat` | Syntax-highlighted file viewer | `bat file.conf` |
| `eza` / `exa` | `ls` | Colorized, git-aware listing | `eza -lah --git` |
| `fd` | `find` | Faster, simpler file search | `fd pattern /path` |
| `rg` (ripgrep) | `grep` | Much faster recursive search | `rg "error" /var/log` |
| `fzf` | — | Fuzzy finder for files/history/processes | `fzf` |
| `ncdu` | `du` | Interactive disk usage analyzer | `ncdu /var` |
| `duf` | `df` | Friendlier disk free output | `duf` |
| `btop` / `glances` | `top`/`htop` | Modern resource monitors | `btop` |
| `zoxide` | `cd` | Smarter directory jumping | `z project-name` |
| `httpie` | `curl` | Human-friendly HTTP client | `http GET example.com` |
| `yq` | — | YAML processor (like `jq` for YAML) | `yq '.spec.replicas' deploy.yaml` |
| `delta` | `diff` | Syntax-highlighted diffs | `git diff | delta` |

---

## Cloud & Automation Tooling

| Command | Description | Example |
|---------|-------------|---------|
| `aws` | AWS CLI | `aws ec2 describe-instances` |
| `az` | Azure CLI | `az vm list -o table` |
| `gcloud` | Google Cloud CLI | `gcloud compute instances list` |
| `terraform` | Infrastructure as Code | `terraform plan` |
| `ansible` | Ad-hoc remote execution | `ansible all -m ping` |
| `ansible-playbook` | Run automation playbooks | `ansible-playbook site.yml` |
| `kubectl` | Kubernetes cluster management | `kubectl get pods -A` |
| `helm` | Kubernetes package manager | `helm install release chart/` |
| `packer` | Build machine images | `packer build template.json` |
| `vault` | Secrets management (HashiCorp Vault) | `vault kv get secret/app` |
| `cloud-init` | First-boot instance configuration | `cloud-init status` |

---

## Quick One-Liner Recipes

Practical combinations for everyday troubleshooting.

| Goal | Command |
|------|---------|
| Find the 10 largest files under a path | `find /var -type f -exec du -h {} + | sort -rh | head -10` |
| Find the 10 largest directories | `du -h --max-depth=1 /var | sort -rh | head -10` |
| Show top 10 memory-hungry processes | `ps aux --sort=-%mem | head -11` |
| Show top 10 CPU-hungry processes | `ps aux --sort=-%cpu | head -11` |
| List all listening ports with owning process | `ss -tulnp` |
| Watch a log file with highlighting | `tail -f /var/log/syslog | grep --color=auto -i error` |
| Count files in a directory | `find . -maxdepth 1 -type f | wc -l` |
| Find files modified in the last 24 hours | `find /etc -mtime -1 -type f` |
| Find world-writable files | `find / -xdev -type f -perm -0002` |
| Find SUID/SGID binaries | `find / -xdev -perm /6000 -type f` |
| Kill all processes matching a name | `pkill -f process_name` |
| Show disk usage by filesystem, human-readable | `df -hT` |
| Test if a remote port is open | `nc -zv host 443` |
| Show all environment variables | `printenv | sort` |
| Check which package owns a binary (RPM/DEB) | `rpm -qf $(which cmd)` / `dpkg -S $(which cmd)` |
| Tail the journal for a service, last hour | `journalctl -u nginx --since "1 hour ago"` |
| Show effective sudo rules for current user | `sudo -l` |
| Generate a quick SSH key (modern, recommended) | `ssh-keygen -t ed25519 -C "comment"` |
| Recursively chmod only directories | `find /path -type d -exec chmod 750 {} +` |
| Recursively chmod only files | `find /path -type f -exec chmod 640 {} +` |

---

## License

MIT — see [LICENSE](LICENSE).
