## Performance & "Something Feels Slow"

| If you're trying to... | Use | Because |
|---|---|---|
| Get a quick overall health snapshot | `glances` or `btop` | One screen shows CPU, memory, disk, network, and processes together — faster than running 5 separate commands |
| See *why* CPU is high right now | `top` / `htop` sorted by `%CPU` | Immediate live view of which process is responsible |
| See *why* CPU was high an hour ago | `sar -u` | `sysstat` logs historical data even after the spike has passed |
| Check if the bottleneck is disk, not CPU | `iostat -xz 1` | Shows `%util` and await times per disk — high CPU but low disk util tells you it's compute-bound |
| Find which *process* is hammering the disk | `iotop -o` | Only shows processes actively doing I/O, filters out the noise |
| Check if it's a memory problem vs. a CPU problem | `vmstat 1` | Watch the `si`/`so` (swap in/out) columns — heavy swapping means memory pressure, not CPU |
| Profile exactly where CPU time goes inside an app | `perf top` | Function-level breakdown, not just process-level |
| Trace what syscalls a hung process is making | `strace -p <PID>` | Shows if it's stuck on a syscall (e.g., blocked on a `read()` from a dead NFS mount) |
| Check boot time and find slow-starting services | `systemd-analyze blame` | Ranks units by how long they took during boot |

---

## Disk Space & Storage

| If you're trying to... | Use | Because |
|---|---|---|
| Find out which filesystem is full | `df -hT` | Quick overview of all mounted filesystems and usage % |
| Find *what* is eating space inside that filesystem | `ncdu /path` | Interactive, navigable — far faster than repeated `du` commands |
| Find the single largest files system-wide | `find / -xdev -type f -size +500M -exec ls -lh {} \;` | Direct targeted search for big offenders |
| Check disk health before it fails | `smartctl -a /dev/sda` | S.M.A.R.T. data can warn of failure days/weeks in advance |
| Resize a filesystem after growing a virtual disk | `growpart` then `resize2fs` (ext4) or `xfs_growfs` (XFS) | Partition table and filesystem need separate resizing steps |
| Free up space from old kernels | `dnf remove $(dnf repoquery --installonly --latest-limit=-2)` (RHEL) or `apt autoremove` (Debian) | Old kernels in `/boot` are a very common silent space hog |
| Free up space from the systemd journal | `journalctl --vacuum-size=200M` | Journal logs can silently grow to gigabytes |
| Check inode exhaustion (disk shows space but "no space left") | `df -i` | A full filesystem can fail on inodes even with free bytes |

---

## Network & Connectivity

| If you're trying to... | Use | Because |
|---|---|---|
| Check if a host is reachable at all | `ping -c 4 host` | Simplest first step — confirms basic L3 connectivity |
| Check if it's connectivity vs. a specific service being down | `nc -zv host 443` | Tests if the *port* is open, isolating app-layer vs network-layer issues |
| Diagnose where packet loss is occurring along a path | `mtr host` | Combines ping + traceroute into a continuously updating per-hop view |
| See what's actually listening on this machine | `ss -tulnp` | Modern replacement for `netstat`, shows process names too |
| Capture and inspect traffic for a specific issue | `tcpdump -i eth0 port 443 -w capture.pcap` | Captures raw packets for deeper analysis |
| Analyze a capture with a GUI | `wireshark capture.pcap` (or `tshark` for CLI) | Protocol dissection, filtering, and visualization |
| Test actual throughput between two hosts | `iperf3 -s` (server) / `iperf3 -c host` (client) | `ping` only tells you latency, not bandwidth |
| Debug DNS resolution issues | `dig +trace domain` | Shows the full resolution path from root servers down |
| Quickly relay/test data between two hosts | `nc` or `socat` | Minimal setup for ad-hoc testing without standing up a real service |
| Check firewall rules currently in effect | `firewall-cmd --list-all` (firewalld) or `nft list ruleset` (nftables) | Confirms whether a port is blocked before debugging the app |

---

## Processes & Resource Hogs

| If you're trying to... | Use | Because |
|---|---|---|
| Find the top memory consumer right now | `ps aux --sort=-%mem \| head` | Quick one-liner, no extra tools needed |
| Watch resource usage live, interactively | `htop` or `btop` | Sortable, killable, scrollable — much nicer than raw `ps` |
| Find what's holding a file open (e.g., "device busy" errors) | `lsof /path/to/file` or `fuser -v /path` | Identifies the exact PID blocking unmount/delete |
| Kill a runaway process by name (not PID) | `pkill -f processname` | Avoids hunting for the PID manually |
| See the parent/child relationship of a stuck process tree | `pstree -p` | Helps identify if a zombie parent is the real problem |
| Run something that must survive a logout | `tmux` + `systemd-run --user` or `nohup` | `nohup` for simple cases; `tmux` if you need to reattach interactively |
| Check container resource usage | `ctop` or `docker stats` | `ctop` gives a `top`-like view across all containers |

---

## Logs & Historical Investigation

| If you're trying to... | Use | Because |
|---|---|---|
| Tail a single service's logs live | `journalctl -u servicename -f` | Modern systemd-native equivalent of `tail -f` on a log file |
| Search logs across multiple files at once | `lnav /var/log/` | Auto-detects formats, merges timeline, supports SQL-like queries |
| Watch several log files side-by-side | `multitail file1 file2` | Split-screen view, easier than multiple terminal panes |
| Find what happened around a specific timestamp | `journalctl --since "09:00" --until "09:15"` | Precise time-window filtering |
| Search for a pattern across huge log files fast | `rg "pattern" /var/log` | `ripgrep` is dramatically faster than `grep -r` on large trees |
| Check what changed in `/etc` recently | `etckeeper` (if installed) → `cd /etc && git log -p` | Gives you a real diff history of config changes |
| Investigate a crash after the fact | `journalctl -b -1` | View logs from the *previous* boot, useful after a crash/reboot |

---

## Users, Access & Permissions

| If you're trying to... | Use | Because |
|---|---|---|
| See what a user can `sudo` | `sudo -l -U username` | Shows effective sudo rules without reading raw sudoers files |
| Audit who has SSH key access to an account | `cat ~user/.ssh/authorized_keys` | Often the real source of "who can log in," more than `/etc/passwd` |
| Find all files owned by a user (e.g., before deleting their account) | `find / -xdev -user username` | Prevents orphaned files with dangling UIDs |
| Check password expiry / last change | `chage -l username` | Useful for compliance audits |
| See active sessions across the system | `w` or `who` | Quickly spot unexpected logged-in users |
| Check group membership | `id username` or `groups username` | Confirms access without trial-and-error |

---

## Security & Suspicious Activity

| If you're trying to... | Use | Because |
|---|---|---|
| Get a general security health check | `lynis audit system` | Produces a prioritized list of hardening suggestions |
| Check for rootkits | `rkhunter --check` or `chkrootkit` | Different detection databases/heuristics — running both is common |
| Scan for malware in user-uploaded files | `clamscan -r /path` | Signature-based scanning for known malicious files |
| Check failed login attempts | `lastb` or `journalctl -u sshd \| grep "Failed"` | Surfaces brute-force attempts |
| Auto-block repeat offenders | `fail2ban-client status sshd` | Confirms fail2ban is actively banning, and shows current ban list |
| Investigate an SELinux "permission denied" that seems wrong | `ausearch -m avc -ts recent` | Shows the exact denial, which `audit2allow` can then turn into a policy |
| Check open ports against what *should* be open | `ss -tulnp` + compare to firewall rules | Unexpected listeners are a common compromise indicator |
| Verify a file hasn't been tampered with | `sha256sum file` vs. known-good hash | Simple integrity check; for full coverage use `aide` |

---

## Configuration & Change Management

| If you're trying to... | Use | Because |
|---|---|---|
| Track changes to system config files over time | `etckeeper` | Auto-commits `/etc` to git on package installs and manual edits |
| Test a config change before applying it broadly | `ansible --check` (dry run) | Shows what *would* change without applying it |
| Roll out the same change to many servers | `ansible-playbook` | Idempotent, repeatable, auditable vs. manual SSH loops |
| Compare configs between two servers | `diff <(ssh host1 cat /etc/file) <(ssh host2 cat /etc/file)` | Quick ad-hoc drift detection |
| Parse/edit a JSON or YAML config from the CLI | `jq` / `yq` | Avoids fragile `sed`/`awk` on structured data |
| Re-run a command automatically when a config file changes | `entr` or `watchexec` | Useful for iterating on configs (e.g., reload nginx on save) |

---

## Backups & Data Safety

| If you're trying to... | Use | Because |
|---|---|---|
| Sync files to another server or disk | `rsync -avz --delete src/ dest/` | Only transfers changed blocks, preserves permissions/timestamps |
| Take encrypted, deduplicated backups | `restic` or `borg` | Far more space-efficient than repeated full tarballs |
| Back up to cloud storage (S3, B2, GDrive, etc.) | `rclone sync /data remote:bucket` | `rsync`-like syntax but for cloud providers |
| Image an entire disk before a risky operation | `dd if=/dev/sda of=/path/disk.img bs=4M status=progress` | Full byte-for-byte backup, useful before partitioning changes |
| Verify a backup is actually restorable | `restic check` / test-restore to a scratch dir | Untested backups are not backups |

---

## Containers & Services

| If you're trying to... | Use | Because |
|---|---|---|
| Manage containers without memorizing `docker` flags | `lazydocker` | TUI for start/stop/logs/exec across all containers |
| Check container resource usage | `docker stats` or `ctop` | Per-container CPU/mem/network, like `top` for containers |
| Inspect/copy images without pulling them locally | `skopeo inspect docker://image` | Saves bandwidth/disk when you just need metadata |
| Debug a container that won't start | `docker logs <container>` then `docker run -it --entrypoint sh image` | Logs first, then drop into a shell to poke around |
| Manage a service's startup behavior | `systemctl edit servicename` | Creates a drop-in override without editing the original unit file |

---

## Automation & Repetition

| If you're trying to... | Use | Because |
|---|---|---|
| Run the same command on many servers | `ansible all -m shell -a "command"` | Parallel execution with consolidated output |
| Schedule a recurring job | `systemd timers` (preferred) or `crontab -e` | Timers give better logging via `journalctl`; cron is simpler for quick one-offs |
| Provision cloud infrastructure repeatably | `terraform apply` | Declarative, versioned, plan-before-apply |
| Bootstrap a new server's base config | `cloud-init` (cloud) or an `ansible-playbook` (bare metal) | Avoids manual "golden image" drift |
| Build a custom VM/container image | `packer build template.json` | Same image definition can target multiple platforms |

---

## Working Faster in the Terminal

| If you're trying to... | Use | Because |
|---|---|---|
| Find a file by name without remembering the exact path | `fd partialname` | Faster and simpler syntax than `find` |
| Search file *contents* recursively | `rg "text"` | Skips `.git`, binary files, and is significantly faster than `grep -r` |
| Recall a command you ran last week | `Ctrl+R` with `fzf` enabled | Fuzzy-searches shell history interactively |
| View a config file with line numbers and syntax highlighting | `bat file.conf` | Easier to read than raw `cat`, especially for YAML/JSON |
| Jump to a frequently-used directory instantly | `z partial-name` (zoxide) | Learns your habits, no need to `cd` through the full path |
| Remember the syntax for a command you rarely use | `tldr command` | Practical examples instead of a full man page |
| Keep a long task running after closing your laptop lid | `tmux new -s task` then detach (`Ctrl+b d`) | Session persists on the server independent of your local connection |

---

## See Also

- [commands.md](./commands.md) — full command syntax reference


