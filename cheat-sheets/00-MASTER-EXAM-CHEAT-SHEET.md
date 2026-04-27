# M300 MASTER EXAM CHEAT-SHEET
## Cross-Platform Service Integration
### Exam Date: April 28, 2026

─────────────────────────────────────────────────────

## QUICK REFERENCE INDEX

1. [SSH Essentials](#ssh-essentials)
2. [DNS Server (BIND9)](#dns-server-bind9)
3. [Traefik Reverse Proxy](#traefik-reverse-proxy)
4. [SSH Tunneling](#ssh-tunneling)
5. [TLS Certificates](#tls-certificates)
6. [Common Troubleshooting](#common-troubleshooting)
7. [Exam Workflow Checklist](#exam-workflow-checklist)

─────────────────────────────────────────────────────

## SSH ESSENTIALS

### Key Generation & Setup
```bash
# Generate SSH key pair (ECDSA recommended)
ssh-keygen -t ecdsa -b 521

# Copy public key to server (enables passwordless login)
ssh-copy-id vmadmin@192.168.220.13

# Copy for root access
ssh-copy-id root@192.168.220.13

# SSH config shortcut (~/.ssh/config)
Host vmls3
    HostName 192.168.220.13
    User vmadmin
    IdentityFile ~/.ssh/id_ecdsa
```

### Key Files
- `~/.ssh/id_ecdsa` - Private key (keep secret)
- `~/.ssh/id_ecdsa.pub` - Public key (copy to servers)
- `~/.ssh/authorized_keys` - Server stores allowed public keys
- `~/.ssh/config` - Client connection shortcuts

### Key Types (exam knowledge)
| Type | Security | Speed | Use |
|------|----------|-------|-----|
| ECDSA | High | Fast | Recommended |
| Ed25519 | Highest | Fastest | Modern systems |
| RSA | Good | Slower | Legacy compatibility |

─────────────────────────────────────────────────────

## DNS SERVER (BIND9)

### Container Setup
```bash
# Deploy DNS container with Webmin
docker compose up -d
# Container: eafxx/bind
# Webmin: http://192.168.220.13:10000 (root/sml12345)
```

### Configuration Files (in container /etc/bind/)

**named.conf.options** (forwarders, recursion):
```bind
options {
    directory "/var/cache/bind";
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    allow-recursion { 192.168.0.0/16; localhost; };
    dnssec-validation no;
    listen-on { any; };
    listen-on-v6 { any; };
};
```

**named.conf.local** (zone declarations):
```bind
zone "lan.m300.smartlearn.ch" {
    type master;
    file "/etc/bind/db.lan.m300.smartlearn.ch";
};

zone "210.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.210";
};

zone "220.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.220";
};
```

### Zone File Templates

**Forward Zone (db.lan.m300.smartlearn.ch)**:
```bind
$TTL    604800
@       IN      SOA     vmls3.lan.m300.smartlearn.ch. admin.lan.m300.smartlearn.ch. (
                        2024042701 ; Serial (increment on changes!)
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
@       IN      NS      vmls3.lan.m300.smartlearn.ch.
vmls3   IN      A       192.168.220.13
traefik IN      A       192.168.220.13
whoami  IN      A       192.168.220.13
vmlp1   IN      A       192.168.210.11
```

**Reverse Zone (db.192.168.220)**:
```bind
$TTL    604800
@       IN      SOA     vmls3.lan.m300.smartlearn.ch. admin.lan.m300.smartlearn.ch. (
                        2024042701
                        604800
                        86400
                        2419200
                        604800 )
;
@       IN      NS      vmls3.lan.m300.smartlearn.ch.
13      IN      PTR     vmls3.lan.m300.smartlearn.ch.
```

### DNS Operations
```bash
# Copy config into container
docker cp file.conf dns-bind-bind-1:/etc/bind/

# Restart container
docker compose restart

# Check logs
docker logs dns-bind-bind-1

# Test DNS resolution
nslookup traefik.lan.m300.smartlearn.ch 192.168.220.13
dig @192.168.220.13 vmls3.lan.m300.smartlearn.ch
```

### Critical Rules
- **Increment SOA serial** after every zone file change
- **Restart BIND** after configuration changes
- Don't use Webmin GUI for zone creation in containers (file path issues)

─────────────────────────────────────────────────────

## TRAEFIK REVERSE PROXY

### Initial Setup
```bash
# Create shared network (CRITICAL!)
docker network create traefik-proxy

# Create directory structure
mkdir -p traefik traefik/certs/default data

# Generate password hash
apt install -y apache2-utils
echo $(htpasswd -nB admin) | sed -e s/\\$/\\$\\$/g > pwfile
```

### Configuration Files

**.env** (environment variables):
```env
DOMAIN=m300.smartlearn.ch
CERT_RESOLVER=le
TRAEFIK_USER=admin
TRAEFIK_PASSWORD_HASH=$$2y$$05$$xxxxx...
```

**traefik/traefik.yml** (static config):
```yaml
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false
    network: traefik-proxy
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

certificatesResolvers:
  le:
    acme:

api:
  insecure: false
  debug: false
```

**traefik/dynamic.yml** (TLS config):
```yaml
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/certs/default/cert.pem
        keyFile: /etc/traefik/certs/default/privkey.pem
```

**docker-compose.yml** (abbreviated - key parts):
```yaml
services:
  traefik:
    image: "traefik:v3.6"
    container_name: "traefik"
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # HTTP → HTTPS redirect
      - "traefik.http.routers.to-https.rule=hostregexp(`.+.m300.smartlearn.ch`)"
      - traefik.http.routers.to-https.entrypoints=web
      - traefik.http.routers.to-https.middlewares=to-https
      - traefik.http.middlewares.to-https.redirectscheme.scheme=https
      # Dashboard access
      - traefik.http.routers.traefik.rule=Host(`traefik.m300.smartlearn.ch`)
      - traefik.http.routers.traefik.entrypoints=websecure
      - traefik.http.routers.traefik.middlewares=auth
      - traefik.http.middlewares.auth.basicauth.users=${TRAEFIK_USER}:${TRAEFIK_PASSWORD_HASH}
    ports:
      - 80:80
      - 443:443
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - ./data/letsencrypt:/letsencrypt
      - ./traefik:/etc/traefik

networks:
  traefik-proxy:
    external: true  # CRITICAL!
```

### Routing a Service

**Example docker-compose.yml for application:**
```yaml
services:
  whoami:
    image: traefik/whoami
    container_name: whoami
    networks:
      - traefik-proxy  # MUST be on traefik-proxy network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.whoami.rule=Host(`whoami.lan.m300.smartlearn.ch`)"
      - "traefik.http.routers.whoami.entrypoints=websecure"
      - "traefik.http.routers.whoami.tls=true"

networks:
  traefik-proxy:
    external: true
```

### Traefik Essential Labels
```yaml
traefik.enable=true                                    # Enable routing
traefik.http.routers.NAME.rule=Host(`domain.com`)      # Routing rule
traefik.http.routers.NAME.entrypoints=websecure        # Port (80=web, 443=websecure)
traefik.http.routers.NAME.tls=true                     # Enable HTTPS
traefik.http.routers.NAME.middlewares=auth             # Apply middleware
```

### Workflow for Adding Service
1. Add DNS A record: `newapp IN A 192.168.220.13`
2. Restart DNS container
3. Create service docker-compose.yml with Traefik labels
4. Ensure `network: traefik-proxy` and `external: true`
5. `docker compose up -d`
6. Check Traefik dashboard for route
7. Test: `https://newapp.lan.m300.smartlearn.ch`

### Dashboard Access
```
URL: https://traefik.m300.smartlearn.ch/dashboard/
Login: admin / sml12345
Note: Trailing slash required!
```

─────────────────────────────────────────────────────

## SSH TUNNELING

### Tunnel Types
| Type | Opens Port | Direction | Command Flag |
|------|-----------|-----------|--------------|
| Local | Local machine | Remote → Local | `-L` |
| Remote | Remote machine | Local → Remote | `-R` |
| Dynamic | Local SOCKS | All traffic | `-D` |

### Local Forward (-L)
**Access remote service locally**
```bash
# Pattern
ssh -L [local:]local_port:destination:dest_port user@gateway

# Example: Access remote MySQL
ssh -L 3306:localhost:3306 user@remote-server
# Now: mysql -h 127.0.0.1 connects to remote MySQL

# Example: Access web through jump host
ssh -L 8080:internal-server:80 user@gateway
# Browser: http://localhost:8080
```

### Remote Forward (-R) - EXAM CRITICAL
**Expose local service via remote server**
```bash
# Pattern
ssh -R [remote:]remote_port:destination:dest_port user@gateway

# EXAM SCENARIO: Expose vmLP1 webserver via vmLS3
ssh -R 8123:localhost:80 vmadmin@vmLS3
# vmLS3:8123 now routes to local machine port 80

# Make accessible externally (not just 127.0.0.1)
ssh -R 0.0.0.0:8123:localhost:80 vmadmin@vmLS3
```

### GatewayPorts Configuration (CRITICAL!)
**Problem:** Remote tunnels bind to 127.0.0.1 only by default

**Solution:** Enable on SSH SERVER (e.g., vmLS3)
```bash
# Edit SSH server config
sudo nano /etc/ssh/sshd_config

# Add or change:
GatewayPorts yes

# Restart SSH service
sudo systemctl restart ssh

# Verify port binding
ss -tlpn | grep 8123
# Should show: 0.0.0.0:8123 (not 127.0.0.1:8123)
```

### Tunnel to modulgw.smartlearn.ch
```bash
# Expose Traefik to internet
ssh -R 0.0.0.0:8443:192.168.220.13:443 vmadmin@modulgw.smartlearn.ch
# Access at: https://modulgw.smartlearn.ch:8443
```

### Background Tunnels
```bash
# Foreground (blocks terminal)
ssh -R 8123:localhost:80 user@gateway

# Background daemon
ssh -fN -R 8123:localhost:80 user@gateway
# -f: background after authentication
# -N: no command execution (tunnel only)

# Keep-alive
ssh -o ServerAliveInterval=60 -R 8123:localhost:80 user@gateway
```

### Memory Aid
- **-L** = "Local opens, reaches Remote"
- **-R** = "Remote opens, reaches Local"

─────────────────────────────────────────────────────

## TLS CERTIFICATES

### Why TLS/HTTPS?
- **Authentication** - Verify server identity
- **Encryption** - Protect data in transit
- **Integrity** - Detect tampering

### Certificate Components
| Component | Content | Share? |
|-----------|---------|--------|
| cert.pem | Certificate (public key + metadata) | Yes |
| privkey.pem | Private key | NEVER! |
| fullchain.pem | Certificate + intermediate chain | Yes |

### Trust Chain
```
Root CA (in browser)
    ↓ signs
Intermediate CA (e.g., Let's Encrypt R3)
    ↓ signs
Server Certificate (e.g., *.m300.smartlearn.ch)
```

### Encryption Types
| Type | Key Usage | Speed |
|------|-----------|-------|
| Symmetric | Same key encrypts & decrypts | 1000x faster |
| Asymmetric | Public encrypts, Private decrypts | Slower |

**HTTPS Strategy:** Asymmetric to exchange keys → Symmetric for data

### Public/Private Key Rules
- Encrypted with **PUBLIC** key → Only **PRIVATE** key can decrypt
- Encrypted with **PRIVATE** key → Only **PUBLIC** key can decrypt

### Let's Encrypt
- **Free** automated certificates
- **90-day validity** (forces automation)
- **ACME protocol** (Automatic Certificate Management Environment)
- ~80% of web traffic uses Let's Encrypt

### ACME Workflow
1. Client requests certificate for domain
2. Server issues challenge to prove ownership
3. Client completes challenge (HTTP-01, DNS-01, TLS-ALPN-01)
4. Server verifies and issues certificate
5. Client installs certificate
6. Auto-renewal before expiration

### Traefik Certificate Setup

**Static config (traefik.yml):**
```yaml
certificatesResolvers:
  le:
    acme:
      email: admin@example.com
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
```

**Service label:**
```yaml
- "traefik.http.routers.myapp.tls.certresolver=le"
```

**Lab Setup (pre-generated certs):**
```yaml
# dynamic.yml
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/certs/default/cert.pem
        keyFile: /etc/traefik/certs/default/privkey.pem
```

### Certificate Verification
```bash
# View certificate details
openssl x509 -in cert.pem -text -noout

# Check expiration
openssl x509 -in cert.pem -noout -dates

# Test HTTPS connection
openssl s_client -connect domain.com:443 -servername domain.com
```

─────────────────────────────────────────────────────

## COMMON TROUBLESHOOTING

### DNS Issues
```bash
# Problem: Service not resolving
nslookup service.lan.m300.smartlearn.ch 192.168.220.13
dig @192.168.220.13 service.lan.m300.smartlearn.ch

# Solution: Check zone file, increment SOA serial, restart BIND
docker logs dns-bind-bind-1
docker compose -f /root/dns-bind/docker-compose.yml restart
```

### Traefik Issues
```bash
# Problem: 503 Service Unavailable
# Solution: Container not on traefik-proxy network
docker inspect <container> | grep NetworkMode

# Problem: 404 Not Found
# Solution: Router rule doesn't match domain
# Check: Traefik dashboard → HTTP → Routers

# Problem: Certificate error
# Solution: Check cert files exist and are readable
ls -la traefik/certs/default/
docker logs traefik
```

### SSH Tunnel Issues
```bash
# Problem: Connection refused
# Check: Service running on target
curl http://localhost:80

# Problem: Tunnel only on 127.0.0.1
# Solution: Enable GatewayPorts on SSH server
ss -tlpn | grep <port>

# Problem: Permission denied
# Solution: Copy SSH keys
ssh-copy-id user@server

# Verbose debugging
ssh -vvv -R 8123:localhost:80 user@gateway
```

### Port Conflicts
```bash
# Check what's using a port
ss -tlpn | grep <port>
lsof -i :<port>

# Kill process using port
kill <PID>
```

### Docker Issues
```bash
# Container won't start
docker logs <container>
docker compose logs

# Network issues
docker network ls
docker network inspect traefik-proxy

# Restart everything
docker compose down
docker compose up -d
```

─────────────────────────────────────────────────────

## EXAM WORKFLOW CHECKLIST

### 1. Initial Server Setup (vmLS3)
```bash
☐ SSH key-based login configured (vmadmin & root)
☐ System updated (apt update && apt upgrade)
☐ Docker installed and running
☐ Portainer installed (optional)
☐ DNS client configured (nameserver 8.8.8.8)
```

### 2. DNS Server Setup
```bash
☐ DNS container deployed (eafxx/bind)
☐ named.conf.options created (forwarders, recursion)
☐ named.conf.local created (zone declarations)
☐ Forward zone created (lan.m300.smartlearn.ch)
☐ Reverse zones created (210/220.168.192.in-addr.arpa)
☐ A records added for all services
☐ PTR records added for reverse lookup
☐ Container restarted
☐ DNS tested from vmLP1
```

### 3. Traefik Setup
```bash
☐ traefik-proxy network created
☐ Directory structure created
☐ .env file created (credentials, domain)
☐ traefik.yml created (static config)
☐ dynamic.yml created (TLS config)
☐ Certificates copied (cert.pem, privkey.pem)
☐ docker-compose.yml created
☐ DNS A record added (traefik.lan.m300.smartlearn.ch)
☐ Container started
☐ Dashboard accessible
```

### 4. Service Routing
```bash
☐ DNS A record added for service
☐ docker-compose.yml with Traefik labels
☐ Network: traefik-proxy (external: true)
☐ Service started
☐ Route visible in Traefik dashboard
☐ HTTPS access tested
```

### 5. SSH Tunneling (if required)
```bash
☐ GatewayPorts enabled on SSH server
☐ SSH service restarted
☐ Reverse tunnel created
☐ Port binding verified (0.0.0.0, not 127.0.0.1)
☐ External access tested
```

### 6. Final Verification
```bash
☐ All DNS records resolve
☐ All services accessible via HTTPS
☐ Certificates valid (no browser warnings)
☐ HTTP redirects to HTTPS
☐ Traefik dashboard accessible
☐ All Docker containers running
```

─────────────────────────────────────────────────────

## CRITICAL COMMANDS QUICK REFERENCE

### Docker
```bash
docker ps                          # List running containers
docker logs <container>            # View logs
docker compose up -d               # Start services
docker compose down                # Stop services
docker compose restart             # Restart services
docker exec -it <container> bash   # Enter container
docker network ls                  # List networks
docker network create <name>       # Create network
```

### DNS
```bash
nslookup <domain> <dns-server>     # Query DNS
dig @<dns-server> <domain>         # Detailed DNS query
docker logs dns-bind-bind-1        # Check BIND logs
```

### SSH
```bash
ssh-keygen -t ecdsa -b 521         # Generate key pair
ssh-copy-id user@host              # Copy public key
ssh -L local:dest:port user@host   # Local forward
ssh -R remote:dest:port user@host  # Remote forward
ss -tlpn | grep <port>             # Check port binding
```

### System
```bash
systemctl restart ssh              # Restart SSH service
systemctl status <service>         # Check service status
apt update && apt upgrade          # Update system
nano /etc/ssh/sshd_config          # Edit SSH config
```

### Networking
```bash
ss -tlpn                           # Show listening ports
netstat -tlnp                      # Alternative to ss
lsof -i :<port>                    # What's using port
curl http://localhost:<port>       # Test HTTP
wget http://127.0.0.1:<port>       # Download via HTTP
```

─────────────────────────────────────────────────────

## EXAM ENVIRONMENT REFERENCE

### Network Layout
- **LAN**: 192.168.210.0/24 (vmLP1, vmWP1)
- **DMZ**: 192.168.220.0/24 (vmLS3, vmLS4, vmLS5)

### IP Addresses
- vmLP1: 192.168.210.11 (Linux GUI client)
- vmLS3: 192.168.220.13 (Multi-purpose server)

### Standard Credentials
- Username: vmadmin
- Root password: sml12345
- Service password: sml12345

### Container Ports
- Traefik: 80 (HTTP), 443 (HTTPS)
- Portainer: 9000
- Webmin: 10000
- DNS: 53

### Domain Structure
- Forward zone: lan.m300.smartlearn.ch
- Reverse zones: 210.168.192.in-addr.arpa, 220.168.192.in-addr.arpa

─────────────────────────────────────────────────────

## FINAL EXAM TIPS

### Time Management
1. **Read entire exam first** - understand all requirements
2. **Start with setup** - SSH, DNS, Traefik foundation
3. **Test incrementally** - verify each component before moving on
4. **Save debugging for end** - get working solution first

### Common Mistakes to Avoid
- ❌ Forgetting to increment SOA serial after DNS changes
- ❌ Not restarting services after config changes
- ❌ Missing `external: true` on traefik-proxy network
- ❌ Forgetting GatewayPorts for SSH reverse tunnels
- ❌ Wrong service name (ssh vs sshd)
- ❌ Not adding DNS records before testing services
- ❌ Confusing -L and -R tunnel directions
- ❌ Missing trailing slash in Traefik dashboard URL

### Quick Wins
- ✓ Use tab completion for file paths
- ✓ Check logs immediately if something doesn't work
- ✓ Use `docker ps` to verify containers running
- ✓ Test DNS resolution before troubleshooting services
- ✓ Keep cheat-sheet open for reference
- ✓ Document your IP addresses and passwords at start

### If Stuck
1. **Check logs**: `docker logs <container>`
2. **Verify DNS**: `nslookup service.domain DNS-server`
3. **Check networks**: `docker network inspect traefik-proxy`
4. **Test locally first**: `curl http://localhost:<port>`
5. **Read error messages carefully** - they usually tell you the problem

─────────────────────────────────────────────────────

**Good luck on your exam! You've got this! 🚀**

*All topics covered:*
*✓ SSH ✓ DNS ✓ Traefik ✓ Tunneling ✓ Certificates*

─────────────────────────────────────────────────────
