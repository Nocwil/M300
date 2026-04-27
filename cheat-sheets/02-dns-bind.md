CHEAT-SHEET — DNS with BIND9
─────────────────────────────────────────────────────
Core Concept:
  BIND (Berkeley Internet Name Domain) is the most widely used DNS server.
  It translates domain names to IP addresses (forward zones) and IP addresses
  to domain names (reverse zones). Essential for service discovery in M300.

DNS Container Setup (eafxx/bind with Webmin):
────────────────────────────────────────────────────────────
Step                                     │ Command/Config
─────────────────────────────────────────┼──────────────────────────────────
Create docker-compose.yml                │ See full config below
Start container                          │ docker compose up -d
Access Webmin GUI                        │ http://IP:10000 (root/sml12345)
Check container logs                     │ docker logs dns-bind-bind-1
Restart after config changes             │ docker compose restart
Enter container shell                    │ docker exec -it dns-bind-bind-1 bash

Key Configuration Files:
────────────────────────────────────────────────────────────
File                          │ Purpose
──────────────────────────────┼─────────────────────────────────────
/etc/bind/named.conf.options  │ Global settings (forwarders, recursion)
/etc/bind/named.conf.local    │ Zone declarations
/etc/bind/db.[zonename]       │ Zone data files (A, PTR, NS, SOA records)

named.conf.options Template:
────────────────────────────────────────────────────────────
options {
    directory "/var/cache/bind";
    forwarders {
        8.8.8.8;                    # Upstream DNS for external queries
    };
    allow-recursion {
        192.168.210.0/24;           # LAN network
        192.168.220.0/24;           # DMZ network
    };
    dnssec-validation no;
    listen-on-v6 { };
    auth-nxdomain no;
    empty-zones-enable no;
};

named.conf.local Template:
────────────────────────────────────────────────────────────
// Forward zone
zone "lan.m300.smartlearn.ch" {
    type master;
    file "/etc/bind/db.lan.m300.smartlearn.ch";
};

// Reverse zones
zone "220.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.220";
};

zone "210.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.210";
};

Forward Zone File (db.lan.m300.smartlearn.ch):
────────────────────────────────────────────────────────────
$ttl 3600
lan.m300.smartlearn.ch. IN  SOA  ns.m300.smartlearn.ch. root.m300.smartlearn.ch. (
                        2024020802  ; Serial (increment on changes!)
                        3600        ; Refresh
                        600         ; Retry
                        1209600     ; Expire
                        3600 )      ; Negative TTL
lan.m300.smartlearn.ch. IN  NS   ns.m300.smartlearn.ch.

; A Records (hostname → IP)
ns          IN  A   192.168.220.13
vmls3       IN  A   192.168.220.13
vmls4       IN  A   192.168.220.14
vmlp1       IN  A   192.168.210.11

Reverse Zone File (db.192.168.220):
────────────────────────────────────────────────────────────
; BIND data file for 220.168.192.in-addr.arpa
$TTL 86400
@       IN  SOA  ns.m300.smartlearn.ch. root.m300.smartlearn.ch. (
                        2024020801
                        14400
                        1800
                        1209600
                        3600 )
@       172800  IN  NS   ns.m300.smartlearn.ch.

; PTR Records (IP → hostname)
13      IN  PTR  vmls3.lan.m300.smartlearn.ch.
14      IN  PTR  vmls4.lan.m300.smartlearn.ch.

DNS Record Types (Exam Important):
────────────────────────────────────────────────────────────
Type    │ Purpose                           │ Example
────────┼───────────────────────────────────┼────────────────────────────
SOA     │ Start of Authority (zone metadata)│ See templates above
NS      │ Name Server (authoritative DNS)   │ IN NS ns.m300.smartlearn.ch.
A       │ Address (hostname → IPv4)         │ vmls3 IN A 192.168.220.13
PTR     │ Pointer (IP → hostname, reverse)  │ 13 IN PTR vmls3.lan.m300.smartlearn.ch.
CNAME   │ Alias (hostname → hostname)       │ www IN CNAME webserver

Testing DNS:
────────────────────────────────────────────────────────────
Test Type                │ Command
─────────────────────────┼──────────────────────────────────────────────
Forward lookup           │ nslookup vmls3.lan.m300.smartlearn.ch 192.168.220.13
Reverse lookup           │ nslookup 192.168.220.13 192.168.220.13
External domain          │ nslookup google.com 192.168.220.13
Check all DNS records    │ dig @192.168.220.13 lan.m300.smartlearn.ch ANY

Workflow for Adding New DNS Record:
────────────────────────────────────────────────────────────
1. Create config files on host in /tmp/dns-config/
2. Edit zone file (e.g., db.lan.m300.smartlearn.ch)
3. Increment serial number in SOA record (important!)
4. Add A record: newhost IN A 192.168.220.99
5. Copy to container: docker cp file.db dns-bind-bind-1:/etc/bind/
6. Restart: docker compose restart
7. Test: nslookup newhost.lan.m300.smartlearn.ch 192.168.220.13

Common Mistakes:
────────────────────────────────────────────────────────────
• Forgetting to increment serial number (DNS won't reload zone)
• Missing trailing dots in FQDN: "ns.m300.smartlearn.ch." (dot required!)
• Wrong reverse zone syntax: use last octet only (13, not 192.168.220.13)
• Typos in zone file (one syntax error breaks entire zone)
• Forgetting to restart BIND after changes

Troubleshooting:
────────────────────────────────────────────────────────────
Issue                        │ Solution
─────────────────────────────┼─────────────────────────────────────
Zone not loading             │ Check logs: docker logs dns-bind-bind-1
Syntax errors                │ Look for line numbers in error messages
Container keeps restarting   │ Config file syntax error, check logs
DNS not resolving            │ Verify allow-recursion includes client network
Changes not taking effect    │ Did you increment serial? Did you restart?

Docker Compose Config (dns-bind/docker-compose.yml):
────────────────────────────────────────────────────────────
version: '3.6'
services:
  bind:
    image: eafxx/bind
    restart: unless-stopped
    ports:
      - 53:53/tcp
      - 53:53/udp
      - 10000:10000
    volumes:
      - 'bind:/data'
    environment:
      - WEBMIN_ENABLED=true
      - WEBMIN_INIT_SSL_ENABLED=false
      - WEBMIN_INIT_REFERERS=vmls3.m300.smartlearn.ch
      - WEBMIN_INIT_REDIRECT_PORT=10000
      - ROOT_PASSWORD=sml12345
      - TZ=Europe/Zurich
volumes:
  bind:

Quick Reference - Zone Name to File Mapping:
────────────────────────────────────────────────────────────
Zone Name                    │ Reverse Zone Name            │ File Name
─────────────────────────────┼──────────────────────────────┼─────────────────────
lan.m300.smartlearn.ch       │ -                            │ db.lan.m300.smartlearn.ch
-                            │ 210.168.192.in-addr.arpa     │ db.192.168.210
-                            │ 220.168.192.in-addr.arpa     │ db.192.168.220

Memory Aid:
────────────────────────────────────────────────────────────
SOA = "Start Of Authority" - always first record in zone
Serial format: YYYYMMDDNN (year, month, day, revision number)
Reverse zone: write IP backwards + ".in-addr.arpa"
  Example: 192.168.220.0/24 → 220.168.192.in-addr.arpa
─────────────────────────────────────────────────────────────
