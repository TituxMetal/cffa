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
│   └── docker.list                # Docker official repository
├── exim/
│   └── update-exim4.conf.conf     # Exim4 smarthost mail relay
├── logrotate/
│   ├── docker-container           # Docker container log rotation
│   ├── fail2ban                   # Fail2ban log rotation
│   └── nginx                      # Nginx and Nginx Proxy Manager log rotation
├── ssh/
│   └── authorized_keys            # SSH public key for remote access
└── user/
    ├── .bashrc                    # Shell environment configuration
    └── .config/
        └── htop/
            └── htoprc             # htop process monitor settings
```

## Deployment Mapping

The following table shows where each configuration file is deployed on the target server.

| Source File                      | Target Path on Server                          | Owner | Permissions |
|----------------------------------|------------------------------------------------|-------|-------------|
| `apt/sources.list`              | `/etc/apt/sources.list`                        | root  | 644         |
| `apt/docker.list`               | `/etc/apt/sources.list.d/docker.list`          | root  | 644         |
| `exim/update-exim4.conf.conf`   | `/etc/exim4/update-exim4.conf.conf`            | root  | 644         |
| `logrotate/docker-container`    | `/etc/logrotate.d/docker-container`            | root  | 644         |
| `logrotate/fail2ban`            | `/etc/logrotate.d/fail2ban`                    | root  | 644         |
| `logrotate/nginx`               | `/etc/logrotate.d/nginx`                       | root  | 644         |
| `ssh/authorized_keys`           | `~/.ssh/authorized_keys`                       | user  | 600         |
| `user/.bashrc`                  | `~/.bashrc`                                    | user  | 644         |
| `user/.config/htop/htoprc`      | `~/.config/htop/htoprc`                        | user  | 644         |

## Configuration Details

### apt/sources.list

Debian Bookworm package repositories with all four components enabled: `main`, `contrib`,
`non-free`, and `non-free-firmware`. Includes binary and source entries for:

- Main Bookworm repository
- Security updates (`bookworm-security`)
- Point release updates (`bookworm-updates`)
- Backports (`bookworm-backports`)

### apt/docker.list

Docker official APT repository for Debian Bookworm on the `amd64` architecture. Uses a GPG
key stored at `/etc/apt/keyrings/docker.asc` for package verification. Only the `stable`
channel is enabled.

**Prerequisite:** The Docker GPG key must be present at `/etc/apt/keyrings/docker.asc` before
this source is usable. The Ansible playbook handles this step.

### exim/update-exim4.conf.conf

Exim4 mail transfer agent configured as a **smarthost**, relaying all outbound mail through
`mail.infomaniak.com` on port 587 (STARTTLS). The MTA listens only on the loopback
interfaces (`127.0.0.1` and `::1`), making it suitable for sending system notifications
without accepting external connections.

Key settings:

| Parameter                     | Value                         | Description                        |
|-------------------------------|-------------------------------|------------------------------------|
| `dc_eximconfig_configtype`    | `smarthost`                   | Relay mode, no local delivery      |
| `dc_smarthost`                | `mail.infomaniak.com::587`    | Upstream SMTP relay with STARTTLS  |
| `dc_local_interfaces`         | `127.0.0.1 ; ::1`            | Loopback only                      |
| `dc_localdelivery`            | `mail_spool`                  | Local delivery format              |

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

2. **Nginx Proxy Manager logs** (`/srv/logs/nginx-proxy-manager/fallback_*.log` and
   `proxy-host-*.log`) -- Standard rotation with no post-rotate hook required.

Both sections use daily rotation, 7-day retention, 10 MB size limit, and delayed compression.

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

**Target servers must run Debian 12 (Bookworm)** on the `amd64` architecture.

The following packages should be installed (or will be installed by the Ansible playbook) for
the configuration files to take effect:

| Package / Service     | Required By                        |
|-----------------------|------------------------------------|
| `apt`                 | `apt/sources.list`, `apt/docker.list` |
| `docker-ce`           | `apt/docker.list`, `logrotate/docker-container` |
| `exim4`               | `exim/update-exim4.conf.conf`      |
| `logrotate`           | `logrotate/*`                      |
| `fail2ban` (Docker)   | `logrotate/fail2ban`               |
| `nginx` (Docker)      | `logrotate/nginx`                  |
| `openssh-server`      | `ssh/authorized_keys`              |
| `bash`                | `user/.bashrc`                     |
| `htop`                | `user/.config/htop/htoprc`         |
| `colordiff`           | `user/.bashrc` (diff alias)        |
| `nano`                | `user/.bashrc` (editor config)     |

## Customization Guide

Before deploying to your own infrastructure, review and update the following files:

### Must Change

| File                           | What to Change                                              |
|--------------------------------|-------------------------------------------------------------|
| `ssh/authorized_keys`          | Replace with your own SSH public key(s)                     |
| `exim/update-exim4.conf.conf`  | Update `dc_smarthost` with your SMTP relay provider and port |

### May Change

| File                           | What to Change                                              |
|--------------------------------|-------------------------------------------------------------|
| `apt/sources.list`             | Adjust if targeting a different Debian release               |
| `apt/docker.list`              | Change architecture if not `amd64`; update release codename  |
| `logrotate/fail2ban`           | Update container name filter if your naming convention differs |
| `logrotate/nginx`              | Update log paths or container name filters as needed         |
| `user/.bashrc`                 | Modify aliases, prompt colors, or history settings to taste  |
| `user/.config/htop/htoprc`     | Adjust columns, layout, or refresh interval                  |

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
