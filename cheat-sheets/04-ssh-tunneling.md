# SSH Tunneling (Port Forwarding)

SSH tunneling creates encrypted network connections that forward traffic between ports on different machines. Critical for accessing services behind firewalls, NAT, or making local services publicly accessible.

─────────────────────────────────────────────────────

## SSH Tunneling Types

| Type | Direction | Use Case |
|------|-----------|----------|
| Local (-L) | Remote → Local | Access remote service locally |
| Remote (-R) | Local → Remote | Expose local service remotely |
| Dynamic (-D) | SOCKS proxy | Route all traffic through tunnel |

## Local Port Forwarding (-L)

**Command Structure:**
```
ssh -L [local_bind:]local_port:destination:destination_port user@ssh_server
```

**Example 1 - Access MySQL on remote server:**
```bash
ssh -L 3306:localhost:3306 user@remote-server
# Now: mysql -h 127.0.0.1 connects to remote MySQL
```

**Example 2 - Access service through jump host:**
```bash
ssh -L 8080:internal-server:80 user@gateway
# Browser: http://localhost:8080 → reaches internal-server:80
```

**Example 3 - Bind to specific interface:**
```bash
ssh -L 0.0.0.0:8080:target:80 user@gateway
# Makes port 8080 accessible from other machines (not just localhost)
```

**Key Points:**
- Command runs on client machine
- Opens port on LOCAL machine
- Traffic forwarded TO remote destination
- Default: binds to 127.0.0.1 (localhost only)

─────────────────────────────────────────────────────

## Remote Port Forwarding (-R)

**Command Structure:**
```
ssh -R [remote_bind:]remote_port:destination:destination_port user@ssh_server
```

**Example 1 - Expose local webserver (Exam Scenario):**
```bash
ssh -R 8123:localhost:80 vmadmin@vmLS3
# vmLS3:8123 now routes to your local machine port 80
```

**Example 2 - Expose service to internet via gateway:**
```bash
ssh -R 8080:localhost:3000 user@public-gateway
# public-gateway:8080 → your localhost:3000
```

**Example 3 - Make tunnel accessible from all interfaces:**
```bash
ssh -R 0.0.0.0:8080:localhost:80 user@gateway
# Requires GatewayPorts yes in server's sshd_config
```

**Key Points:**
- Command runs on client machine
- Opens port on REMOTE machine (SSH server)
- Traffic forwarded FROM remote TO local
- Default: binds to 127.0.0.1 on remote (localhost only)
- Requires GatewayPorts for external access

─────────────────────────────────────────────────────

## GatewayPorts Configuration

**Problem:** Remote tunnels (-R) only bind to 127.0.0.1 by default

**Solution:** Enable GatewayPorts on SSH SERVER

On SSH server (e.g., vmLS3):
```bash
sudo nano /etc/ssh/sshd_config
# Add or change:
GatewayPorts yes

# Restart SSH service:
sudo systemctl restart ssh

# Verification:
ss -tlpn | grep <port>
# Should show 0.0.0.0:<port> instead of 127.0.0.1:<port>
```

### GatewayPorts Options

| Setting | Behavior |
|---------|----------|
| `GatewayPorts no` | Default - localhost only (127.0.0.1) |
| `GatewayPorts yes` | All interfaces (0.0.0.0) - anyone can connect |
| `GatewayPorts clientspecified` | Client chooses bind address |

**Security Note:** GatewayPorts yes allows external access - only use in controlled environments!

─────────────────────────────────────────────────────

## Practical Exam Scenario

**Task:** Expose local webserver (vmLP1) through gateway (vmLS3)

**Step 1 - Start webserver on vmLP1:**
```bash
cd ~
echo 'Hello from vmLP1!' > index.html
sudo python3 -m http.server 80
```

**Step 2 - Configure SSH server (vmLS3):**
```bash
ssh root@vmLS3
nano /etc/ssh/sshd_config
# Add: GatewayPorts yes
systemctl restart ssh
exit
```

**Step 3 - Create reverse tunnel from vmLP1:**
```bash
ssh -R 8123:localhost:80 vmadmin@vmLS3
```

**Step 4 - Test from vmLS3 locally:**
```bash
wget http://127.0.0.1:8123
cat index.html
```

**Step 5 - Test from external machine:**
```
Browser: http://vmLS3-IP:8123
Should show: Hello from vmLP1!
```

**Step 6 - Verify port binding:**
```bash
ss -tlpn | grep 8123
# Output should show: 0.0.0.0:8123
```

─────────────────────────────────────────────────────

## Common Tunnel Scenarios

| Scenario | Command |
|----------|---------|
| Access remote MySQL locally | `ssh -L 3306:localhost:3306 user@db-server` |
| Access Traefik dashboard remotely | `ssh -L 8080:localhost:443 user@server` |
| Expose local dev server | `ssh -R 8000:localhost:3000 user@gateway` |
| Access service through bastion | `ssh -L 9000:internal:80 user@bastion` |
| Share local service with team | `ssh -R 0.0.0.0:8080:localhost:8080 user@shared` |

## Tunnel with modulgw.smartlearn.ch

**Purpose:** Expose your M300 services to internet for demonstration

**Example - Expose Traefik to public:**
```bash
ssh -R 0.0.0.0:8443:192.168.220.13:443 vmadmin@modulgw.smartlearn.ch
```

This makes your Traefik accessible at: `https://modulgw.smartlearn.ch:8443`

**Requirements:**
- SSH access to modulgw.smartlearn.ch
- GatewayPorts enabled on modulgw
- Firewall permits the chosen port
- DNS points to modulgw for your domain

─────────────────────────────────────────────────────

## Background vs Foreground Tunnels

**Foreground (interactive):**
```bash
ssh -L 8080:remote:80 user@gateway
# Keeps terminal open, closes when you exit
```

**Background (daemon):**
```bash
ssh -fN -L 8080:remote:80 user@gateway
# -f: background after auth
# -N: no command execution (tunnel only)
```

**Keep-alive:**
```bash
ssh -o ServerAliveInterval=60 -R 8123:localhost:80 user@gateway
# Sends keep-alive every 60 seconds
```

**Auto-reconnect (using autossh):**
```bash
autossh -M 0 -R 8123:localhost:80 user@gateway
# Automatically reconnects if connection drops
```

## Checking Active Tunnels

| Command | Purpose |
|---------|---------|
| `ss -tlpn` | Show all listening TCP ports |
| `ss -tlpn \| grep <port>` | Check specific port binding |
| `netstat -tlnp \| grep <port>` | Alternative to ss |
| `ps aux \| grep ssh` | Show active SSH connections |
| `lsof -i :<port>` | Show what's using a port |

### Reading ss Output

```
LISTEN 0  128  0.0.0.0:8123  0.0.0.0:*
           │      │            └─ Any source can connect
           │      └─ Listening on all interfaces (external access OK)
           └─ Queue size

LISTEN 0  128  127.0.0.1:8123  0.0.0.0:*
                    │
                    └─ Only localhost can connect (BLOCKED externally)
```

## Troubleshooting SSH Tunnels

| Problem | Solution |
|---------|----------|
| Connection refused | Check service is running on target |
| bind: Cannot assign requested... | Port already in use locally |
| Connection to X closed | Check firewall, verify SSH keys |
| Remote tunnel only on 127.0.0.1 | Enable GatewayPorts on SSH server |
| Tunnel works but no response | Check destination service is accessible |
| Permission denied (publickey) | Copy SSH keys with ssh-copy-id |

**Verbose mode for debugging:**
```bash
ssh -v -R 8123:localhost:80 user@gateway
ssh -vv ...  # More verbose
ssh -vvv ... # Maximum verbosity
```

## SSH Config for Persistent Tunnels

`~/.ssh/config` on client:

```
Host tunnel-to-gateway
    HostName vmLS3.m300.smartlearn.ch
    User vmadmin
    RemoteForward 8123 localhost:80
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Usage:
```bash
ssh tunnel-to-gateway
# Automatically creates the tunnel with all settings
```

## Multiple Tunnels in One Session

```bash
ssh -L 3306:db:3306 \
    -L 8080:web:80 \
    -R 8000:localhost:8000 \
    user@gateway

# Creates:
# - Local forward: localhost:3306 → db:3306
# - Local forward: localhost:8080 → web:80
# - Remote forward: gateway:8000 → localhost:8000
```

─────────────────────────────────────────────────────

## Security Considerations

- Never expose sensitive services without authentication
- Use 127.0.0.1 binding when possible (localhost only)
- Enable GatewayPorts only when necessary
- Consider using firewall rules to restrict port access
- Monitor active tunnels with ss or netstat
- Use SSH key authentication, not passwords
- Consider VPN for permanent remote access needs

## Exam Quick Reference

**Local tunnel (access remote service):**
```bash
ssh -L 8080:target:80 user@gateway
```

**Remote tunnel (expose local service):**
```bash
ssh -R 8080:localhost:80 user@gateway
```

**Enable external access to remote tunnel:**
1. Edit `/etc/ssh/sshd_config` → `GatewayPorts yes`
2. `systemctl restart ssh`
3. Verify: `ss -tlpn | grep <port>` shows 0.0.0.0

**Test tunnel:**
```bash
wget http://127.0.0.1:<port>
curl http://127.0.0.1:<port>
```

## Common Mistakes

- Confusing -L and -R direction
- Forgetting GatewayPorts for external remote tunnel access
- Using sshd instead of ssh for service name
- Not restarting SSH service after config changes
- Wrong order of ports in command (local:destination:dest-port)
- Not checking if port is already in use
- Closing terminal and losing foreground tunnel
- Forgetting to start the actual service being tunneled

## Memory Anchor

**-L** = "Local opens, reaches Remote"  
**-R** = "Remote opens, reaches Local"

Think: "Where does the PORT open?"  
-L opens port locally (on your machine)  
-R opens port remotely (on SSH server)
