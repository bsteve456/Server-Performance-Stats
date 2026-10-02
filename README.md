# server-stats.sh

[![Repo](https://img.shields.io/badge/github-bsteve456/Server--Performance--Stats-181717?logo=github)](https://github.com/bsteve456/Server-Performance-Stats)
[![Bash](https://img.shields.io/badge/bash-5.x%2B-green?logo=gnu%20bash)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/OS-Linux%20only-333333?logo=linux)](https://www.kernel.org/)

A single-file Bash script that prints a quick performance snapshot of a Linux
server: CPU, memory, disk, and the top processes by CPU and memory.

No installation, no dependencies beyond the tools that ship with every Linux
distribution. Copy it, `chmod +x`, run it.

## Project URL

https://github.com/bsteve456/Server-Performance-Stats

## Quick start

```bash
git clone https://github.com/bsteve456/Server-Performance-Stats.git
cd Server-Performance-Stats
chmod +x server-stats.sh
./server-stats.sh
```

To drop it onto a server that already runs something else:

```bash
curl -sSL https://raw.githubusercontent.com/bsteve456/Server-Performance-Stats/main/server-stats.sh \
     -o server-stats.sh && chmod +x server-stats.sh && ./server-stats.sh
```

## What it reports

| # | Stat | Tool used |
|---|---|---|
| 1 | Total CPU usage (used vs idle) | `top` |
| 2 | Total memory usage (used vs available, with %) | `free` |
| 3 | Total disk usage (free vs used, with %) | `df` |
| 4 | Top 5 processes by CPU | `ps` |
| 5 | Top 5 processes by memory | `ps` |

## Sample output

```text
===== SERVER STATS =====
Date: Fri Oct  2 17:32:18 CEST 2026
Host: parrot
OS:   Parrot Security 7.4 (echo)

--- 1. TOTAL CPU USAGE ---
Used: 19.2%
Idle: 80.8%

--- 2. TOTAL MEMORY USAGE ---
Total:     15734 MB
Used:      6154 MB (39.1%)
Available: 9580 MB (60.9%)

--- 3. TOTAL DISK USAGE ---
Filesystem     Type   Size  Used Avail Use% Mounted on
/dev/nvme0n1p2 btrfs  477G  264G  209G  56% /
/dev/nvme0n1p2 btrfs  477G  264G  209G  56% /home
/dev/nvme0n1p1 vfat   300M  612K  299M   1% /boot/efi

--- 4. TOP 5 PROCESSES BY CPU ---
  duma999   22378     17.8%    1.6%      254MB  codium
  duma999   22124     13.6%    1.3%      215MB  codium
  duma999   22172     10.2%    2.5%      404MB  codium
  duma999    7477       5.6%    3.4%      545MB  firefox-bin
  duma999    7609       5.4%    4.5%      722MB  WebExtensions

--- 5. TOP 5 PROCESSES BY MEMORY ---
  duma999    7609       5.4%    4.5%      722MB  WebExtensions
  duma999   22294       3.2%    3.4%      550MB  codium
  duma999    7477       5.6%    3.4%      545MB  firefox-bin
  root      1441       0.7%    2.6%      410MB  nessusd
  duma999   22172     10.2%    2.5%      404MB  codium
```

## Requirements

Linux only. The script shells out to four standard tools:

| Tool | Used for | Provided by |
|---|---|---|
| `top` | CPU usage | procps-ng |
| `free` | memory | procps-ng |
| `df` | disk | GNU coreutils |
| `ps` | processes | procps-ng |

It also reads `/etc/os-release` for the OS name.

**Root is not required.** The script runs fine as an unprivileged user.

**Tested on:** Parrot Security 7.4 (Debian 13), kernel 7.1.13, 8 cores,
Bash 5.2.37, coreutils 9.7, procps-ng 4.0.4.

## Usage

```bash
chmod +x server-stats.sh
./server-stats.sh
```

To save a report:

```bash
./server-stats.sh > report-$(date +%F).txt
```

To check it before running:

```bash
bash -n server-stats.sh    # syntax check
```

## How each section works

### 1. Total CPU usage

`top` is run **twice**, one second apart, and the second reading is used:

```bash
top -bn2 -d 1 | grep '%Cpu' | tail -1
```

The first reading is averaged **since boot**, which is useless — it reports
what the CPU has done since the machine started, not what it is doing now. The
second reading is a real one-second average.

`Used` is calculated as `100 − idle`.

### 2. Total memory usage

Reports **Available**, not **Free**. These are very different numbers:

```text
               total        used        free      shared  buff/cache   available
Mem:           15734        6154         657         799       10322        9580
                                        ^^^^ misleading       ^^^^^^^^^^^ the real number
```

Linux deliberately fills spare RAM with page cache to make future reads fast.
A server with 650 MB "free" and 10 GB of cache is **healthy**, not running out
of memory. `Available` is the kernel's own estimate of how much RAM can be
handed to a new process without swapping, so it is the number to trust.

Reporting `free` would have shown the machine above as 96% full.

### 3. Total disk usage

Filters out pseudo-filesystems:

```bash
df -hT -x tmpfs -x devtmpfs -x efivarfs -x squashfs
```

Snap packages and firmware partitions are **read-only** and therefore always
report 100% used. Without these filters the output was 12 rows, 9 of them
noise, and the real disk at 56% was buried in the middle.

`-T` adds the filesystem type column so each row is self-explanatory.

### 4 & 5. Top 5 processes

Uses `comm` (the program name) rather than the full command line. A browser
command line can be 2000+ characters wide, which makes the table unreadable.

`rss` is divided by 1024 to show MB instead of KB.

> **Note on the CPU percentages:** `ps --sort=-pcpu` sorts by each process's
> **lifetime average**, not its current usage. A process running for six hours
> at 5% will rank above a process that started a minute ago and is using 90%
> right now. This is a known trade-off: `top -b -n1` gives a true instantaneous
> sample but is heavier and needs two iterations to compute deltas. The script
> favours the lighter option.

## The `LC_ALL=C` line

This line at the top of the script is the most important one:

```bash
export LC_ALL=C
```

Many non-English locales use a **comma** as the decimal separator. On such a
system `top` prints:

```text
%Cpu(s): 33,3 us, 10,0 sy, 0,0 ni, 54,4 id, 2,2 wa, ...
```

The script's number parsing expects `33.3`. Without `LC_ALL=C` the parse
silently returns nothing, and `100 − (empty)` produces the nonsense result
`Used: 100.0%`.

`LC_ALL=C` forces English formatting on every tool the script calls. Keep this
line even if your server currently uses an English locale — the script gets
copied around.

## Troubleshooting

**CPU shows 100% or a blank value.** Locale problem. Confirm the first lines of
the script are `export LC_ALL=C`.

**Disk section is empty or shows odd types.** Some `df` versions do not
support `-x`. Remove the exclusions to see the unfiltered list.

**Process table is empty.** `ps` is missing (minimal containers sometimes lack
procps). Install `procps-ng`.

**`df` reports a filesystem as 100% on a read-only partition.** That is
expected — see section 3 above.

## Project layout

```text
Server-Performance-Stats/
├── server-stats.sh   # the script
└── README.md         # this file
```

## Possible next steps

- Colour-code the output, green/yellow/red by threshold, and disable colours
  when piping to a file.
- Add uptime, load average, logged-in users, and failed login attempts.
- Exit non-zero when CPU or disk crosses a threshold, so it can drive a
  monitoring alert from cron.

