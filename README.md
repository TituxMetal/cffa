# Configuration Files For Ansible

Centralized repository of system configuration files deployed to Debian-based Linux servers
via [Ansible](https://github.com/TituxMetal/ansibleToolByTuxi). Each file in this repository
maps to a specific path on the target server and is copied as-is during provisioning.

This project does not contain playbooks or roles. It serves strictly as a source of
configuration files consumed by the Ansible project.

## Repository Structure

```
cffa/
├── apt/
│   ├── sources.list               # Debian package repositories
│   ├── docker.list                # Docker official repository
│   ├── 22ansible-auto-upgrades     # APT periodic behaviour
│   └── 52ansible-unattended-upgrades # Security-only unattended upgrades
├── exim/
│   └── update-exim4.conf.conf     # Exim4 smarthost mail relay
├── logrotate/
│   ├── docker-container           # Docker container log rotation
│   ├── fail2ban                   # Fail2ban log rotation
│   └── nginx                      # Nginx and Nginx Proxy Manager log rotation
├── scripts/
│   └── patch-report               # Daily security upgrade mail report
├── ssh/
│   └── authorized_keys            # SSH public key for remote access
├── systemd/
│   ├── apt-daily-timer.conf       # Moves apt-daily.timer to 02:30
│   ├── apt-daily-upgrade-timer.conf # Moves apt-daily-upgrade.timer to 03:00
│   ├── patch-report.service       # Runs the report as the admin user
│   └── patch-report.timer         # Runs the report at 03:40
└── user/
    ├── .bashrc                    # Shell environment configuration
    └── .config/
        └── htop/
            └── htoprc             # htop process monitor settings
```

## Deployment Mapping

The following table shows where each configuration file is deployed on the target server.

| Source File                            | Target Path on Server                                         | Owner | Permissions |
| -------------------------------------- | ------------------------------------------------------------- | ----- | ----------- |
| `apt/sources.list`                     | `/etc/apt/sources.list.d/sources.list`                        | root  | 644         |
| `apt/docker.list`                      | `/etc/apt/sources.list.d/docker.list`                         | root  | 644         |
| `apt/22ansible-auto-upgrades`          | `/etc/apt/apt.conf.d/22ansible-auto-upgrades`                | root  | 644         |
| `apt/52ansible-unattended-upgrades`    | `/etc/apt/apt.conf.d/52ansible-unattended-upgrades`          | root  | 644         |
| `exim/update-exim4.conf.conf`          | `/etc/exim4/update-exim4.conf.conf`                           | root  | 644         |
| `logrotate/docker-container`           | `/etc/logrotate.d/docker-container`                           | root  | 644         |
| `logrotate/fail2ban`                   | `/etc/logrotate.d/fail2ban`                                   | root  | 644         |
| `logrotate/nginx`                      | `/etc/logrotate.d/nginx`                                      | root  | 644         |
| `scripts/patch-report`                 | `~/bin/patch-report`                                          | user  | 755         |
| `ssh/authorized_keys`                  | `~/.ssh/authorized_keys`                                      | user  | 600         |
| `systemd/apt-daily-timer.conf`         | `/etc/systemd/system/apt-daily.timer.d/schedule.conf`         | root  | 644         |
| `systemd/apt-daily-upgrade-timer.conf` | `/etc/systemd/system/apt-daily-upgrade.timer.d/schedule.conf` | root  | 644         |
| `systemd/patch-report.service`         | `/etc/systemd/system/patch-report.service`                    | root  | 644         |
| `systemd/patch-report.timer`           | `/etc/systemd/system/patch-report.timer`                      | root  | 644         |
| `user/.bashrc`                         | `~/.bashrc`                                                   | user  | 644         |
| `user/.config/htop/htoprc`             | `~/.config/htop/htoprc`                                       | user  | 644         |

## Configuration Details

### apt/sources.list

Debian Trixie (Debian 13) package repositories with all four components enabled: `main`,
`contrib`, `non-free`, and `non-free-firmware`. Includes binary and source entries for:

- Main Trixie repository
- Security updates (`trixie-security`)
- Point release updates (`trixie-updates`)
- Backports (`trixie-backports`)

**Target path.** Ansible does not write `/etc/apt/sources.list`: it writes
`/etc/apt/sources.list.d/sources.list` (`aptRepoName: sources` in
`roles/apt/repository/defaults/main.yaml`), and moves the distribution file to
`/etc/apt/sources.list.backup` first. The same file lands on every host, whatever the
provider image shipped.

### apt/docker.list

Docker official APT repository for Debian Trixie on the `amd64` architecture. Uses a GPG
key stored at `/etc/apt/keyrings/docker.asc` for package verification. Only the `stable`
channel is enabled.

**Prerequisite:** The Docker GPG key must be present at `/etc/apt/keyrings/docker.asc` before
this source is usable. The Ansible playbook handles this step.

### apt/22ansible-auto-upgrades and apt/52ansible-unattended-upgrades

APT periodic behaviour and the unattended-upgrade policy, in two files so the
schedule and the policy can be changed independently.

`22ansible-auto-upgrades` turns the periodic runs on.

`52ansible-unattended-upgrades` restricts the runs to `Debian-Security` only.
`trixie-updates`, backports and `contrib`/`non-free` stay manual, which is what
the `patch` shell alias already covers. `Automatic-Reboot` is off.
`Remove-Unused-Dependencies` is off, since `clean` already handles it under supervision.
`Remove-Unused-Kernel-Packages` is on: the kernel chain is pruned after each
upgrade, otherwise the old images pile up. The value is upstream's default, written
here so a future version cannot change it silently.

`#clear` comes first on purpose: the `Origins-Pattern` Debian ships in
`50unattended-upgrades` is a list, and apt appends to a list instead of
replacing it, so without the clear the main `trixie` repository would stay
allowed alongside `trixie-security`.

There is deliberately no `Unattended-Upgrade::Mail`: unattended-upgrades calls
`sendmail -t` without `-f`, so the envelope becomes `root@<provider hostname>`
and the relay rejects it (`450 Sender address rejected: Domain not found`). The
`patch-report` timer below sends the mail instead.

### exim/update-exim4.conf.conf

Exim4 mail transfer agent configured as a **smarthost**, relaying all outbound mail through
`mail.infomaniak.com` on port 587 (STARTTLS). The MTA listens only on the loopback
interfaces (`127.0.0.1` and `::1`), making it suitable for sending system notifications
without accepting external connections.

Key settings:

| Parameter                  | Value                      | Description                       |
| -------------------------- | -------------------------- | --------------------------------- |
| `dc_eximconfig_configtype` | `smarthost`                | Relay mode, no local delivery     |
| `dc_smarthost`             | `mail.infomaniak.com::587` | Upstream SMTP relay with STARTTLS |
| `dc_local_interfaces`      | `127.0.0.1 ; ::1`          | Loopback only                     |
| `dc_localdelivery`         | `mail_spool`               | Local delivery format             |

### logrotate/docker-container

Rotates Docker container JSON log files located in `/var/lib/docker/containers/*/*.log`.
Uses `copytruncate` to avoid restarting containers during rotation.

- **Schedule:** Daily
- **Retention:** 7 rotations
- **Size limit:** 10 MB
- **Compression:** Enabled with delayed compression

### logrotate/fail2ban

Rotates the Fail2ban log at `/srv/logs/fail2ban/fail2ban.log`. After rotation, a
`postrotate` script flushes the Fail2ban logs inside the running Docker container:

```
docker exec $(docker ps --filter "name=^/fail2ban-" --quiet) fail2ban-client flushlogs
```

The command is guarded with `|| true` to prevent failures when the container is stopped.

### logrotate/nginx

Handles two sets of log files:

1. **Nginx logs** (`/srv/logs/nginx/access.log` and `/srv/logs/nginx/error.log`) -- After
   rotation, sends a `SIGUSR1` signal to the Nginx process inside its Docker container so it
   reopens log files gracefully. Uses `sharedscripts` to run the post-rotate hook only once
   for both files.

   These two files are written by the **web server container** (`main-site-<host>`, formerly
   `nginx-<host>`), not by Nginx Proxy Manager: NPM keeps its own logs under
   `/srv/logs/nginx-proxy-manager/`. The container filter matches both names
   (`name=^/(main-site|nginx)-`) so hosts that have not been renamed yet are still covered.
   The signal matters even with `copytruncate`: without a reopen, Nginx keeps writing at its
   previous offset and leaves a sparse file.

2. **Nginx Proxy Manager logs** (`/srv/logs/nginx-proxy-manager/fallback_*.log` and
   `proxy-host-*.log`) -- Standard rotation with no post-rotate hook required.

Both sections use daily rotation, 7-day retention, 10 MB size limit, and delayed compression.

### scripts/patch-report

Mails one report after the nightly security upgrade run: the packages that were
installed, and whether a reboot is pending. Deployed to `~/bin`.

- **Reboot detection:** compares `uname -r` with the newest installed
  `linux-image-*`. Debian 13 has no `/var/run/reboot-required`: the package that
  used to write it, `update-notifier-common`, does not exist in trixie.
- **One mail per run, not per day:** the stamp in `~/.cache` means the log has to
  move, so a night without updates stays silent.
- **`sudo` use:** only for reading the root-owned upgrade log and for setting the
  envelope sender, which exim honours only for a trusted user. This is the same
  pattern as the `patch` and `clean` shell aliases.

The envelope sender is `server+<hostname>@lgdweb.fr` and the recipient is
`server+notif@lgdweb.fr`, matching the fail2ban jail settings
(`destemail` / `sender`).

### systemd/apt-daily-timer.conf and systemd/apt-daily-upgrade-timer.conf

Drop-ins that move the two Debian apt timers off their default 06:00, when the
operator is already at work. `apt-daily.timer` refreshes the package lists at
02:30, `apt-daily-upgrade.timer` installs the security upgrades at 03:00.

`OnCalendar` is a list: an empty assignment comes first so the drop-in replaces
the 06:00 entry instead of appending to it.

### systemd/patch-report.service and systemd/patch-report.timer

The timer fires at 03:40, right after the upgrade run. The service is a one-shot running as the
admin user (`User=supertux`, `ExecStart=%h/bin/patch-report`).

### ssh/authorized_keys

Contains a single RSA 4096-bit public key identified by the OpenPGP key ID `0xB4C0BAB3`.
Deployed to `~/.ssh/authorized_keys` on the target server to enable passwordless SSH access.

### user/.bashrc

Custom Bash shell configuration featuring:

- **256-color prompt** with username, hostname, working directory, and timestamp
- **Root detection** with distinct prompt symbol (`#` vs `$`)
- **Aliases** for common commands: color-enabled `ls`, `grep`, `dir`; human-readable `df`,
  `du`, `free`; `nano` with safe defaults
- **System management shortcuts:** `patch` (full apt upgrade), `clean` (apt cleanup),
  `installed` (list installed packages)
- **Auto-listing `cd`** that runs `ls` after every directory change
- **Systemd helper functions:** `start`, `stop`, `restart`, `enable`, `disable`, `status`
- **History:** Stores up to 9,000,000 entries, ignores duplicates and common commands
- **Bash completion** with sudo support

### user/.config/htop/htoprc

Htop v3.2.2 configuration with:

- Two-column header layout (CPU meters, memory, swap, network I/O, disk I/O, tasks, load
  average, uptime)
- Main screen sorted by CPU percentage (descending)
- Dedicated I/O screen with read/write rates and delay percentages
- Kernel threads hidden, deleted executables highlighted
- 1.5-second refresh interval, mouse support enabled

## Prerequisites

**Target servers must run Debian 13 (Trixie)** on the `amd64` architecture.

The following packages should be installed (or will be installed by the Ansible playbook) for
the configuration files to take effect:

| Package / Service   | Required By                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| `apt`               | `apt/sources.list`, `apt/docker.list`, `apt/22ansible-auto-upgrades`, `apt/52ansible-unattended-upgrades` |
| `docker-ce`         | `apt/docker.list`, `logrotate/docker-container`                                                  |
| `exim4`             | `exim/update-exim4.conf.conf`                                                                    |
| `logrotate`         | `logrotate/*`                                                                                    |
| `fail2ban` (Docker) | `logrotate/fail2ban`                                                                             |
| `nginx` (Docker)    | `logrotate/nginx`                                                                                |
| `openssh-server`    | `ssh/authorized_keys`                                                                            |
| `bash`              | `user/.bashrc`, `scripts/patch-report`                                                           |
| `htop`              | `user/.config/htop/htoprc`                                                                       |
| `colordiff`         | `user/.bashrc` (diff alias)                                                                      |
| `nano`              | `user/.bashrc` (editor config)                                                                   |

## Customization Guide

Before deploying to your own infrastructure, review and update the following files:

### Must Change

| File                          | What to Change                                               |
| ----------------------------- | ------------------------------------------------------------ |
| `ssh/authorized_keys`         | Replace with your own SSH public key(s)                      |
| `exim/update-exim4.conf.conf` | Update `dc_smarthost` with your SMTP relay provider and port |

### May Change

| File                                          | What to Change                                                  |
| --------------------------------------------- | --------------------------------------------------------------- |
| `apt/sources.list`                            | Adjust if targeting a different Debian release                  |
| `apt/docker.list`                             | Change architecture if not `amd64`; update release codename     |
| `apt/52ansible-unattended-upgrades`           | Wide the origins if `trixie-updates` or backports should follow |
| `logrotate/fail2ban`                          | Update container name filter if your naming convention differs  |
| `scripts/patch-report`                        | Update the `lgdweb.fr` sender and recipient addresses           |
| `systemd/*.timer`, `systemd/apt-*-timer.conf` | Adjust the hours                                                |
| `logrotate/nginx`                             | Update log paths or container name filters as needed            |
| `user/.bashrc`                                | Modify aliases, prompt colors, or history settings to taste     |
| `user/.config/htop/htoprc`                    | Adjust columns, layout, or refresh interval                     |

### Log Paths

The logrotate configurations expect logs to be stored under `/srv/logs/`. If your Docker
containers mount log volumes to different paths, update the glob patterns in the
corresponding logrotate files.

## Relationship with Ansible

This repository is used as a file source by the
[ansibleToolByTuxi](https://github.com/TituxMetal/ansibleToolByTuxi) Ansible project. The
playbooks and roles in that project reference files from this repository and copy them to the
appropriate locations on the target servers.

The separation keeps configuration data independent from deployment logic, making it possible
to version, review, and update configuration files without modifying Ansible playbooks.

## License

See the [ansibleToolByTuxi](https://github.com/TituxMetal/ansibleToolByTuxi) repository for
license information.
