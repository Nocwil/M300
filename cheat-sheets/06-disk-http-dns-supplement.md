# Disk Management, HTTP Server & DNS Record Types

Disk partitioning and mounting for persistent storage, Apache2 HTTP server with name-based virtual hosts, and DNS record types for various services (CNAME, MX, TXT).

─────────────────────────────────────────────────────

## DISK MANAGEMENT

### Workflow: Partition, Format, Mount

**Step 1 - Identify Available Disks:**
```bash
lsblk
```

Output shows:
- Mounted disks (MOUNTPOINT column has path like /)
- Unmounted disks (empty MOUNTPOINT)
- Disk size and partitions

**Step 2 - Partition Disk with fdisk:**
```bash
fdisk /dev/sdd
```

Interactive commands:
- `n` → Create new partition
- `p` → Primary partition (default)
- Enter → Accept defaults (partition number, first sector, last sector)
- `w` → Write changes and exit

Verify:
```bash
lsblk
# Should show new partition (e.g., sdd1 under sdd)
```

**Step 3 - Format Partition:**
```bash
mkfs -t ext4 -L m300data /dev/sdd1
```

Options:
- `-t ext4` → Filesystem type (ext4 is Linux standard)
- `-L m300data` → Label for easy identification

Verify formatting:
```bash
blkid | grep sdd1
# Shows: LABEL, UUID, TYPE, PARTUUID
```

**Step 4 - Create Mount Point:**
```bash
mkdir /m300data
```

**Step 5 - Mount Partition:**
```bash
mount /dev/sdd1 /m300data
```

Verify:
```bash
df -h | grep m300data
# Shows disk usage and mount point
```

Test:
```bash
echo "Test file" > /m300data/test.txt
cat /m300data/test.txt
```

**Step 6 - Make Mount Persistent (rebootfest):**
```bash
nano /etc/fstab
```

Add line at end:
```
LABEL=m300data  /m300data  ext4  defaults  0  2
```

### Explanation of fstab fields

| Field | Value | Meaning |
|-------|-------|---------|
| Device | LABEL=m300data | Use label (better than /dev/sdd1) |
| Mount Point | /m300data | Where to mount |
| Filesystem Type | ext4 | Filesystem format |
| Options | defaults | Standard mount options (rw, auto) |
| Dump | 0 | No backup needed (0=skip) |
| Pass | 2 | Filesystem check order (0=skip, 1=root, 2=other) |

Test fstab without rebooting:
```bash
mount -a
# No output = success
```
# Error output = fix fstab syntax

Verify persistent mount:
```bash
reboot
df -h | grep m300data
# Should still be mounted after reboot
```

─────────────────────────────────────────────────────

### Common Commands

| Command | Purpose |
|---------|---------|
| `lsblk` | List all block devices |
| `blkid` | Show UUIDs and labels |
| `fdisk -l` | List all disks and partitions |
| `df -h` | Show mounted filesystems and usage |
| `mount` | Show all mounted filesystems |
| `umount /m300data` | Unmount filesystem |
| `mkfs -t ext4 /dev/sdd1` | Format partition |
| `mount -a` | Mount all filesystems in /etc/fstab |

### Filesystem Types

| Type | Use Case | OS |
|------|----------|-----|
| ext4 | Linux standard, journaling | Linux |
| ext3 | Older Linux, still reliable | Linux |
| xfs | Large files, high performance | Linux (RHEL default) |
| btrfs | Advanced features, snapshots | Linux |
| ntfs | Windows compatibility | Windows/Linux |
| fat32 | USB drives, cross-platform | All OS |

### Mount Point Conventions

| Location | Purpose | Example |
|----------|---------|---------|
| `/mnt/` | Temporary manual mounts | /mnt/usb, /mnt/backup |
| `/media/` | Removable media (auto-mount) | /media/user/USB_DRIVE |
| `/` | Permanent system/application data | /m300data, /data |
| `/home/user/` | AVOID - bad practice | Don't use |

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Device busy (umount fails) | `lsof \| grep /m300data` (find processes), `fuser -m /m300data` (kill processes) |
| Mount fails at boot | Check /etc/fstab syntax, Verify LABEL or UUID is correct |
| Wrong permissions | `chown -R user:group /m300data` |
| Filesystem corrupt | `fsck /dev/sdd1` (unmount first!) |

─────────────────────────────────────────────────────────────

## APACHE2 HTTP SERVER

### Installation and Basic Setup

**Install:**
```bash
apt install -y apache2
```

**Start and enable:**
```bash
systemctl start apache2
systemctl enable apache2
```

**Check status:**
```bash
systemctl status apache2
```

**Test default page:**
```
http://192.168.220.13
# Should show "It works!" page
```

**Default DocumentRoot:** `/var/www/html/`  
**Default config location:** `/etc/apache2/`

─────────────────────────────────────────────────────

### Name-Based Virtual Hosts

**Purpose:** Host multiple websites on one server, one IP address  
**Distinction:** Server Name (hostname in HTTP request)

**Workflow:**

**Step 1 - Create directories and content:**
```bash
mkdir -p /var/www/site1
mkdir -p /var/www/site2

echo "<h1>Welcome to Site 1</h1>" > /var/www/site1/index.html
echo "<h1>Welcome to Site 2</h1>" > /var/www/site2/index.html

chown -R www-data:www-data /var/www/site1
chown -R www-data:www-data /var/www/site2
```

**Step 2 - Create virtual host configs:**
```bash
nano /etc/apache2/sites-available/site1.conf
```

```apache
<VirtualHost *:80>
    ServerName site1.lan.m300.smartlearn.ch
    DocumentRoot /var/www/site1
    ErrorLog ${APACHE_LOG_DIR}/site1_error.log
    CustomLog ${APACHE_LOG_DIR}/site1_access.log combined
</VirtualHost>
```

```bash
nano /etc/apache2/sites-available/site2.conf
```

```apache
<VirtualHost *:80>
    ServerName site2.lan.m300.smartlearn.ch
    DocumentRoot /var/www/site2
    ErrorLog ${APACHE_LOG_DIR}/site2_error.log
    CustomLog ${APACHE_LOG_DIR}/site2_access.log combined
</VirtualHost>
```

**Step 3 - Enable sites:**
```bash
a2ensite site1
a2ensite site2
```

**Optional - Disable default:**
```bash
a2dissite 000-default
```

**Step 4 - Reload Apache:**
```bash
systemctl reload apache2
```

**Step 5 - Add DNS records:**
```bind
site1   IN  A   192.168.220.13
site2   IN  A   192.168.220.13
```

Don't forget to increment SOA serial!

**Step 6 - Test:**
```
http://site1.lan.m300.smartlearn.ch
http://site2.lan.m300.smartlearn.ch
```

### Virtual Host Configuration Directives

| Directive | Purpose | Example |
|-----------|---------|---------|
| ServerName | Primary hostname | site1.example.com |
| ServerAlias | Additional hostnames | www.site1.example.com |
| DocumentRoot | Directory containing web files | /var/www/site1 |
| ErrorLog | Error log file location | /var/log/apache2/error.log |
| CustomLog | Access log file location | /var/log/apache2/access.log |
| DirectoryIndex | Default file to serve | index.html index.php |

─────────────────────────────────────────────────────

### Apache Commands

| Command | Purpose |
|---------|---------|
| `systemctl start apache2` | Start Apache |
| `systemctl stop apache2` | Stop Apache |
| `systemctl restart apache2` | Full restart (brief downtime) |
| `systemctl reload apache2` | Reload config (no downtime) |
| `systemctl status apache2` | Check status |
| `a2ensite site1` | Enable site configuration |
| `a2dissite site1` | Disable site configuration |
| `a2enmod rewrite` | Enable module |
| `a2dismod rewrite` | Disable module |
| `apache2ctl -t` | Test configuration syntax |
| `apache2ctl -S` | Show virtual host configuration |

### Apache Directory Structure

```
/etc/apache2/
├── apache2.conf              # Main configuration file
├── ports.conf                # Port listening configuration
├── sites-available/          # Available site configs
│   ├── 000-default.conf
│   ├── site1.conf
│   └── site2.conf
├── sites-enabled/            # Enabled site configs (symlinks)
│   ├── site1.conf -> ../sites-available/site1.conf
│   └── site2.conf -> ../sites-available/site2.conf
└── mods-available/           # Available modules
    └── mods-enabled/         # Enabled modules

/var/www/                     # Web content root
├── html/                     # Default site
├── site1/                    # Site 1 content
└── site2/                    # Site 2 content

/var/log/apache2/             # Log files
├── access.log
├── error.log
├── site1_access.log
└── site1_error.log
```

### Testing HTTP Servers

**Browser:**
```
http://site1.lan.m300.smartlearn.ch
```

**Command line:**
```bash
curl http://site1.lan.m300.smartlearn.ch
wget http://site1.lan.m300.smartlearn.ch -O -
telnet site1.lan.m300.smartlearn.ch 80
```

**Check if port 80 is listening:**
```bash
ss -tlpn | grep :80
netstat -tlnp | grep :80
```

─────────────────────────────────────────────────────

### Troubleshooting Apache

| Problem | Solution |
|---------|----------|
| Port 80 already in use | `ss -tlpn \| grep :80`, Stop conflicting service (e.g., Traefik) |
| Apache won't start | `apache2ctl -t` (check syntax), `systemctl status apache2` (view errors) |
| 403 Forbidden | Check file permissions, `chown -R www-data:www-data /var/www/site1` |
| 404 Not Found | Check DocumentRoot path, Verify index.html exists |
| Site shows default page | Check ServerName matches DNS, Reload Apache after config changes |
| Changes not taking effect | `systemctl reload apache2`, Clear browser cache |

### Quick Test Servers (Alternatives to Apache)

**Python (simple, built-in):**
```bash
python3 -m http.server 8080
# Serves current directory on port 8080
```

**PHP:**
```bash
php -S localhost:8080
# Serves current directory with PHP support
```

**Docker whoami (testing/debugging):**
```bash
docker run -d -p 8080:80 traefik/whoami
# Returns client/server info, great for reverse proxy testing
```

─────────────────────────────────────────────────────────────

## DNS RECORD TYPES

### Record Types Overview

| Type | Purpose | Value Format |
|------|---------|--------------|
| A | Domain → IPv4 address | 192.168.220.13 |
| AAAA | Domain → IPv6 address | 2001:db8::1 |
| CNAME | Alias to another domain | vmls3.lan.m300.smartlearn.ch. |
| MX | Mail server (with priority) | 10 mail.example.com. |
| TXT | Arbitrary text data | "v=spf1 mx -all" |
| NS | Name server for zone | ns.m300.smartlearn.ch. |
| SOA | Zone authority information | (multiple fields) |
| PTR | Reverse lookup (IP → domain) | vmls3.lan.m300.smartlearn.ch. |
| SRV | Service location | 10 5 5060 sip.example.com. |

─────────────────────────────────────────────────────

### A Record - Address

**Purpose:** Map domain name to IPv4 address

**Syntax:**
```bind
hostname    IN  A   192.168.220.13
```

**Examples:**
```bind
vmls3       IN  A   192.168.220.13
www         IN  A   192.168.220.13
site1       IN  A   192.168.220.13
```

**Use Case:** Primary DNS record for most services

### AAAA Record - IPv6 Address

**Purpose:** Map domain name to IPv6 address

**Syntax:**
```bind
hostname    IN  AAAA   2001:db8::1
```

**Example:**
```bind
vmls3       IN  AAAA   2001:0db8:85a3::8a2e:0370:7334
```

**Use Case:** IPv6 connectivity

### CNAME Record - Canonical Name (Alias)

**Purpose:** Create alias pointing to another domain name

**Syntax:**
```bind
alias       IN  CNAME  target.domain.com.
```

**Examples:**
```bind
www         IN  CNAME  vmls3.lan.m300.smartlearn.ch.
ftp         IN  CNAME  vmls3.lan.m300.smartlearn.ch.
blog        IN  CNAME  vmls3.lan.m300.smartlearn.ch.
```

**Result:** `www.lan.m300.smartlearn.ch` → resolves to vmls3's IP

**Rules:**
- CNAME points to NAME, not IP address
- Cannot use CNAME at zone apex (@)
- Cannot mix CNAME with other records for same hostname
- Adds extra DNS lookup (slight performance cost)

**Common Use Cases:**
- CDN endpoints (cdn.example.com CNAME provider.cloudfront.net)
- Service aliases (www, ftp, mail)
- Load balancer frontends

### MX Record - Mail Exchange

**Purpose:** Specify mail servers for domain with priority

**Syntax:**
```bind
@           IN  MX  priority  mailserver.domain.com.
```

**Examples:**
```bind
@           IN  MX  10  mail1.example.com.
@           IN  MX  20  mail2.example.com.
```

**Priority:** Lower number = higher priority
- Try mail1 first (priority 10)
- If mail1 fails, try mail2 (priority 20)

**Real-world example (Google Workspace):**
```bind
example.com.    IN  MX  1   aspmx.l.google.com.
example.com.    IN  MX  5   alt1.aspmx.l.google.com.
example.com.    IN  MX  5   alt2.aspmx.l.google.com.
example.com.    IN  MX  10  alt3.aspmx.l.google.com.
```

**Common Priorities:**
- 10 = Primary mail server
- 20 = Secondary mail server (backup)
- 30+ = Tertiary and beyond

**Use Case:** Email routing and redundancy

### TXT Record - Text Data

**Purpose:** Store arbitrary text information

**Syntax:**
```bind
hostname    IN  TXT  "text string"
```

**Common Uses:**

**1. SPF (Sender Policy Framework) - Email authentication**
```bind
@           IN  TXT  "v=spf1 mx include:_spf.google.com ~all"
```

SPF explained:
- `v=spf1` → SPF version 1
- `mx` → Allow servers in MX records
- `include:domain` → Include another domain's policy
- `~all` → Soft fail for others (accept but mark)
- `-all` → Hard fail for others (reject)

**2. DKIM (DomainKeys Identified Mail) - Email signing**
```bind
default._domainkey  IN  TXT  "v=DKIM1; k=rsa; p=MIGfMA0GCS..."
```

**3. DMARC (Domain-based Message Authentication)**
```bind
_dmarc      IN  TXT  "v=DMARC1; p=quarantine; rua=mailto:admin@example.com"
```

**4. Domain Verification (Google, Microsoft, Let's Encrypt)**
```bind
@           IN  TXT  "google-site-verification=abc123xyz..."
@           IN  TXT  "MS=ms12345678"
```

**5. General Information**
```bind
@           IN  TXT  "Contact: admin@example.com"
```

**Use Case:** Email security, domain verification, configuration data

─────────────────────────────────────────────────────

### NS Record - Name Server

**Purpose:** Delegate zone to name server

**Syntax:**
```bind
@           IN  NS  ns.domain.com.
```

**Example:**
```bind
@           IN  NS  ns.m300.smartlearn.ch.
@           IN  NS  ns2.m300.smartlearn.ch.
```

**Use Case:** Define authoritative name servers for zone

### SOA Record - Start of Authority

**Purpose:** Define zone authority and settings

**Syntax:**
```bind
@           IN  SOA  ns.domain.com. admin.domain.com. (
                        2024042801  ; Serial (YYYYMMDDNN)
                        3600        ; Refresh (1 hour)
                        600         ; Retry (10 minutes)
                        1209600     ; Expire (2 weeks)
                        3600 )      ; Negative Cache TTL (1 hour)
```

**Fields explained:**
- **Serial** → Version number, increment after every change
- **Refresh** → Secondary checks primary every N seconds
- **Retry** → Retry after failed refresh attempt
- **Expire** → Secondary stops answering after this time
- **Neg Cache** → How long to cache NXDOMAIN responses

**CRITICAL:** Always increment serial after zone file changes!

### PTR Record - Pointer (Reverse DNS)

**Purpose:** Reverse lookup - IP address to domain name

Zone file: `db.192.168.220`

**Syntax:**
```bind
13          IN  PTR  vmls3.lan.m300.smartlearn.ch.
```

Corresponds to: `192.168.220.13` → `vmls3.lan.m300.smartlearn.ch`

**Use Case:** Email server verification, logging, diagnostics

─────────────────────────────────────────────────────

### DNS Record Examples - Complete Zone

**Forward Zone (db.lan.m300.smartlearn.ch):**

```bind
$TTL 3600
@       IN  SOA  ns.m300.smartlearn.ch. admin.m300.smartlearn.ch. (
                 2024042801 ; Serial
                 3600       ; Refresh
                 600        ; Retry
                 1209600    ; Expire
                 3600 )     ; Negative Cache

; Name Servers
@       IN  NS   ns.m300.smartlearn.ch.

; A Records (Domain → IP)
ns      IN  A    192.168.220.13
vmls3   IN  A    192.168.220.13
vmls4   IN  A    192.168.220.14
mail    IN  A    192.168.220.15

; CNAME Records (Aliases)
www     IN  CNAME vmls3.lan.m300.smartlearn.ch.
ftp     IN  CNAME vmls3.lan.m300.smartlearn.ch.

; MX Records (Mail)
@       IN  MX   10 mail.lan.m300.smartlearn.ch.

; TXT Records
@       IN  TXT  "v=spf1 mx -all"
@       IN  TXT  "google-site-verification=abc123"
```

**Reverse Zone (db.192.168.220):**

```bind
$TTL 3600
@       IN  SOA  ns.m300.smartlearn.ch. admin.m300.smartlearn.ch. (
                 2024042801
                 3600
                 600
                 1209600
                 3600 )

@       IN  NS   ns.m300.smartlearn.ch.

; PTR Records (IP → Domain)
13      IN  PTR  vmls3.lan.m300.smartlearn.ch.
14      IN  PTR  vmls4.lan.m300.smartlearn.ch.
15      IN  PTR  mail.lan.m300.smartlearn.ch.
```

### DNS Testing Commands

**nslookup:**
```bash
nslookup vmls3.lan.m300.smartlearn.ch 192.168.220.13
nslookup -type=MX example.com 8.8.8.8
nslookup -type=TXT example.com
```

**dig (more detailed):**
```bash
dig @192.168.220.13 vmls3.lan.m300.smartlearn.ch
dig @8.8.8.8 example.com MX
dig @8.8.8.8 example.com TXT +short
dig @8.8.8.8 example.com ANY
```

**host (simple):**
```bash
host vmls3.lan.m300.smartlearn.ch 192.168.220.13
host -t MX example.com
```

─────────────────────────────────────────────────────

### Exam Quick Reference

| Task | Record Type | Example |
|------|-------------|---------|
| Point domain to IP | A | `web IN A 1.2.3.4` |
| Create www alias | CNAME | `www IN CNAME web` |
| Configure email server | MX | `@ IN MX 10 mail.example.com` |
| Add email security policy | TXT (SPF) | `@ IN TXT "v=spf1 mx -all"` |
| Verify domain ownership | TXT | `@ IN TXT "verification=xyz"` |
| Reverse DNS | PTR | `13 IN PTR vmls3.example.com` |

## Common Mistakes

- Forgetting trailing dot in FQDN (`vmls3.lan.m300.smartlearn.ch.`)
- Not incrementing SOA serial after changes
- Using IP address in CNAME (must be hostname)
- Missing @ for zone apex records
- Wrong priority logic in MX (lower = higher priority)
- Forgetting quotes around TXT record values

## Memory Anchor

- **A** = Address (IPv4)
- **CNAME** = Canonical Name (Alias)
- **MX** = Mail eXchange
- **TXT** = TeXT data
- **PTR** = PoinTeR (reverse)
- **SOA** = Start Of Authority
- **NS** = Name Server
