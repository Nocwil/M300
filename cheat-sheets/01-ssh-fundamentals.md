# SSH Fundamentals

SSH (Secure Shell) provides encrypted remote access to servers. It uses public/private key pairs for authentication instead of passwords, enabling secure automated access and tunneling.

─────────────────────────────────────────────────────

## Key Commands

| Command | Purpose |
|---------|---------|
| `ssh user@host` | Connect to remote host as user |
| `ssh -l user host` | Alternative syntax for login |
| `ssh root@192.168.220.13` | Connect as root to specific IP |
| `ssh-keygen -t ecdsa` | Generate SSH keypair (ECDSA) |
| `ssh-keygen -t ed25519` | Generate SSH keypair (ED25519) |
| `ssh-copy-id user@host` | Copy public key to remote host |
| `ssh user@host command` | Execute command and disconnect |
| `scp file user@host:path` | Copy file to remote host |
| `scp user@host:file local` | Copy file from remote host |
| `ssh -L local:dest:port user@host` | Local port forward (tunnel) |
| `ssh -R remote:dest:port user@host` | Remote port forward (tunnel) |
| `ss -tlpn` | Show listening ports/services |

## Important Files

| File | Purpose |
|------|---------|
| `~/.ssh/id_ecdsa` | Private key (keep secret!) |
| `~/.ssh/id_ecdsa.pub` | Public key (share with servers) |
| `~/.ssh/authorized_keys` | List of allowed public keys |
| `~/.ssh/known_hosts` | Server fingerprints you've accepted |
| `~/.ssh/config` | SSH client configuration shortcuts |
| `/etc/ssh/sshd_config` | SSH server configuration |

## Key Algorithms (Best to Worst)

| Algorithm | Key Size | Notes |
|-----------|----------|-------|
| ed25519 | 256 bit | Best: fast, secure, small keys |
| ecdsa | 256 bit | Good: secure, small keys |
| rsa | 4096 bit | Legacy: needs large keys for security |

─────────────────────────────────────────────────────

## SSH Tunneling Quick Reference

| Type | Flag | Use Case |
|------|------|----------|
| Local (-L) | `-L` | Access remote service through local port |
| Remote (-R) | `-R` | Expose local service to remote network |
| Dynamic (-D) | `-D` | SOCKS proxy for multiple connections |

### Tunnel Syntax
```
-L [bind_addr:]local_port:destination_host:destination_port
-R [bind_addr:]remote_port:destination_host:destination_port
```

### Example
Access MySQL on vmLS3 (bound to 127.0.0.1) from vmLP1:
```bash
ssh -L 127.0.0.1:13306:127.0.0.1:3306 vmadmin@192.168.220.13
# Then:
mysql -h 127.0.0.1 -P 13306 -u root -p
```

## Interface Binding

| Address | Meaning |
|---------|---------|
| 127.0.0.1 | Localhost only (same machine) |
| 0.0.0.0 | All interfaces on this machine |
| 192.168.x.x | Specific interface only |

─────────────────────────────────────────────────────

## Common Mistakes

- Using wrong key permissions (must be 600 for private keys)
- Forgetting to copy public key to remote `~/.ssh/authorized_keys`
- Confusing -L (local) with -R (remote) tunnel directions
- Not setting GatewayPorts yes for remote tunnels to bind 0.0.0.0
- Mixing up port numbers vs bind addresses (port is "which service", bind address is "which network interface")

## Setup Checklist for New Server

- ☐ Generate keypair on client: `ssh-keygen -t ecdsa`
- ☐ Copy public key to server: `ssh-copy-id user@server`
- ☐ Test passwordless login: `ssh user@server`
- ☐ Copy keys to root (optional): `sudo cp ~/.ssh/authorized_keys /root/.ssh/`
- ☐ Test root access: `ssh root@server`

## Security Notes

- Production: ALWAYS use passphrase on private keys
- Lab environment: Can skip passphrase for convenience
- Never share private keys
- Use ssh-agent to cache passphrase (avoid repeated entry)
- Disable password auth in `/etc/ssh/sshd_config` after key setup
