# TLS Certificates & Let's Encrypt

TLS (Transport Layer Security) certificates enable HTTPS, providing:
1. Authentication - verify server identity
2. Encryption - protect data in transit

Let's Encrypt automates free certificate issuance using the ACME protocol.

─────────────────────────────────────────────────────

## Why HTTPS/TLS Matters

| Purpose | What it does |
|---------|--------------|
| Authentication | Proves you're connected to the real server |
| Encryption | Prevents eavesdropping on network traffic |
| Integrity | Detects tampering with transmitted data |
| Trust | Browser shows padlock, users trust site |

**Without TLS:** http:// on port 80 - all data visible to network sniffers  
**With TLS:** https:// on port 443 - encrypted connection

## Encryption Types

| Type | How it works | Speed |
|------|--------------|-------|
| Symmetric | Same key encrypts & decrypts (AES, ChaCha20) | 1000x faster |
| Asymmetric | Public key encrypts, Private key decrypts (RSA, ECDSA, Ed25519) | Slower |

**HTTPS Strategy:** Asymmetric encryption to exchange keys, then symmetric for actual data.

─────────────────────────────────────────────────────

## Public/Private Key Pairs

| Component | Purpose | Location |
|-----------|---------|----------|
| Private Key | Kept secret, never shared | Server only |
| Public Key | Shared publicly, in certificate | Certificate |
| Certificate | Public key + metadata + signature | Sent to clients |

**Encryption Rules:**
- Encrypted with PUBLIC key → Only PRIVATE key can decrypt
- Encrypted with PRIVATE key → Only PUBLIC key can decrypt

Example: `ssh-keygen` creates a key pair: `id_ed25519` (private) and `id_ed25519.pub` (public)

## Certificate Components

| Field | Content |
|-------|---------|
| Common Name (CN) | Domain name (e.g., *.m300.smartlearn.ch) |
| Subject Alt Names | Additional domains covered |
| Public Key | Server's public key |
| Validity Period | Start and end dates |
| Issuer | Who signed it (CA name) |
| Signature | CA's encrypted hash of certificate |

## Certificate Files

| File | Content | Share? |
|------|---------|--------|
| cert.pem | Certificate (public key + meta) | Yes |
| privkey.pem | Private key | NEVER! |
| fullchain.pem | Certificate + intermediate chain | Yes |
| chain.pem | Intermediate CA certificates | Yes |

─────────────────────────────────────────────────────

## Certificate Trust Chain

| Level | Role | Trust |
|-------|------|-------|
| Root CA | Top-level authority (e.g., DigiCert, IdenTrust) | Pre-installed in browsers |
| Intermediate CA | Signs server certificates (e.g., Let's Encrypt R3) | Signed by Root CA |
| Server Certificate | Your website's certificate (e.g., *.m300.smartlearn.ch) | Signed by Intermediate |

### Chain Verification Flow

1. Browser connects to `https://traefik.m300.smartlearn.ch`
2. Server sends: [Server Cert] + [Intermediate Cert]
3. Browser checks: Server Cert signed by Intermediate CA?
4. Browser checks: Intermediate CA signed by Root CA?
5. Browser checks: Root CA in browser's trusted list?
6. ✓ All verified → Show padlock, establish connection

─────────────────────────────────────────────────────

## Certificate Signing Request (CSR)

**Purpose:** Request a CA to sign your certificate

**Process:**
1. Generate private key on server (keep secret!)
2. Create CSR with public key + domain info
3. Submit CSR to Certificate Authority
4. CA verifies you own the domain
5. CA signs certificate with their private key
6. Install signed certificate on server

**Generate CSR (manual method):**
```bash
openssl req -new -newkey rsa:2048 -nodes \
  -keyout privkey.pem -out request.csr
```

CA receives CSR → verifies ownership → signs → returns certificate

## Let's Encrypt

**What:** Free, automated certificate authority  
**Started:** 2014  
**Market share:** ~80% of web traffic uses Let's Encrypt certificates  
**URL:** https://letsencrypt.org/

**Why it exists:**  
After Edward Snowden's 2013 NSA revelations, HTTPS became critical. Let's Encrypt made certificates free and automatic.

**Key Features:**
- Free certificates
- 90-day validity (forces automation)
- Automated issuance and renewal
- Domain validation only (no organization validation)
- Rate limits to prevent abuse

─────────────────────────────────────────────────────

## ACME Protocol

**ACME** = Automatic Certificate Management Environment

**Purpose:** Standardized API for automated certificate management  
**RFC:** https://datatracker.ietf.org/doc/html/rfc8555

### ACME Workflow

1. Client requests certificate for domain
2. Server issues "challenge" to prove domain ownership
3. Client completes challenge
4. Server verifies challenge completion
5. Server issues certificate
6. Client installs certificate
7. (Repeat before expiration for renewal)

### ACME Clients (Software)

| Client | Used By | Notes |
|--------|---------|-------|
| Certbot | Manual/scripted | Official Let's Encrypt client |
| LEGO | Traefik | Go library, used internally |
| acme.sh | Shell scripts | Lightweight alternative |
| Caddy | Caddy web server | Built-in automation |

Traefik uses LEGO internally for automatic certificate management.

### Domain Validation Challenges

Let's Encrypt must verify you own the domain before issuing certificate.

| Challenge Type | How it works | Requirements |
|----------------|--------------|--------------|
| HTTP-01 | Place file at: `http://domain/.well-known/acme-challenge/<token>` | Port 80 accessible from internet |
| DNS-01 | Create TXT record: `_acme-challenge.domain.com` with validation token | API access to DNS provider |
| TLS-ALPN-01 | Special TLS handshake on 443 | Port 443 accessible |

**For M300 Lab:** Pre-generated certificates provided (can't do real validation from lab)

─────────────────────────────────────────────────────

## Traefik Certificate Management

Traefik handles certificates automatically using ACME/LEGO.

### traefik.yml Configuration

```yaml
certificatesResolvers:
  le:
    acme:
      email: admin@example.com
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
```

### Dynamic Certificate Assignment (via labels)

```yaml
labels:
  - "traefik.http.routers.myapp.tls.certresolver=le"
```

**Traefik will:**
1. Detect new service needs certificate
2. Request certificate from Let's Encrypt
3. Complete HTTP-01 challenge automatically
4. Store certificate in acme.json
5. Renew before expiration (30 days before)

### Default Certificates (Lab Setup)

For lab environments without internet access, use pre-generated certificates.

**dynamic.yml:**
```yaml
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/certs/default/cert.pem
        keyFile: /etc/traefik/certs/default/privkey.pem
```

This wildcard certificate (*.m300.smartlearn.ch) works for all subdomains.

─────────────────────────────────────────────────────

## Checking Certificates in Browser

**Firefox:** Click padlock → Connection Secure → More Information

**Look for:**
- Issued to: domain name
- Issued by: CA name (e.g., Let's Encrypt R3)
- Valid from/to: date range
- Certificate chain: Root → Intermediate → Server

**Green padlock** = Valid certificate  
**Warning/No padlock** = Invalid or self-signed certificate

## Certificate Expiration

| Issue | Solution |
|-------|----------|
| Let's Encrypt: 90 days | Automate renewal (Traefik does this) |
| Commercial CAs: 1-3 yrs | Manual renewal before expiration |
| Self-signed: Forever | Not trusted by browsers |

**Renewal Strategy:**
- Let's Encrypt: Renew 30 days before expiration
- Automation prevents forgotten renewals
- Traefik checks daily and renews automatically

## M300 Architecture Overview

| Component | Role | Location |
|-----------|------|----------|
| DNS Server | Resolves domain names | moduldns.smartlearn.ch, vmLS3 (lab DNS) |
| Tunnel Gateway | Public entry point, Receives SSH tunnels | modulgw.smartlearn.ch |
| Traefik (Gateway) | Routes traffic to services, Handles TLS termination | On modulgw |
| SSH Tunnel | Connects vmLS3 to modulgw | Reverse tunnel |
| Your Services | Run on vmLS3 (DNS, Traefik) | Lab environment |

### Traffic Flow

1. Client browser → DNS lookup → moduldns.smartlearn.ch
2. DNS returns → modulgw.smartlearn.ch IP
3. Browser → HTTPS to modulgw.smartlearn.ch
4. Traefik on modulgw → routes to SSH tunnel port
5. SSH tunnel → forwards to vmLS3:443
6. Traefik on vmLS3 → routes to correct service

─────────────────────────────────────────────────────

## Exam Scenarios

**Scenario 1: Install pre-generated certificates**
- Copy cert.pem and privkey.pem to traefik/certs/default/
- Configure dynamic.yml with certificate paths
- Restart Traefik container

**Scenario 2: Configure Let's Encrypt resolver**
- Add certificatesResolvers section to traefik.yml
- Specify email and challenge type
- Add certresolver label to service

**Scenario 3: Troubleshoot certificate issues**
- Check certificate validity dates
- Verify certificate chain
- Check file permissions (privkey.pem readable by Traefik)
- Review Traefik logs for ACME errors

## Common Certificate Errors

| Error | Cause | Solution |
|-------|-------|----------|
| NET::ERR_CERT_AUTHORITY_INVALID | Self-signed or untrusted CA | Accept risk or get valid cert |
| NET::ERR_CERT_COMMON_NAME_INVALID | Domain mismatch | Certificate CN must match domain |
| Certificate expired | Past validity date | Renew certificate |
| No certificate | Traefik can't find cert files | Check paths, permissions |

─────────────────────────────────────────────────────

## Security Best Practices

- ✓ Never commit private keys to version control
- ✓ Restrict privkey.pem to root:root 600 permissions
- ✓ Use strong encryption (RSA 2048+ or ECDSA 256+)
- ✓ Enable automatic renewal
- ✓ Monitor certificate expiration dates
- ✓ Use HTTPS Strict Transport Security (HSTS) headers
- ✓ Redirect HTTP to HTTPS (Traefik does this automatically)

## Quick Commands

**View certificate details:**
```bash
openssl x509 -in cert.pem -text -noout
```

**Check certificate expiration:**
```bash
openssl x509 -in cert.pem -noout -dates
```

**Verify certificate matches private key:**
```bash
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in privkey.pem | openssl md5
# MD5 hashes should match
```

**Test HTTPS connection:**
```bash
openssl s_client -connect domain.com:443 -servername domain.com
```

**Check certificate chain:**
```bash
openssl s_client -connect domain.com:443 -showcerts
```

─────────────────────────────────────────────────────

## Key Concepts for Exam

- TLS provides authentication and encryption for HTTPS
- Certificates contain public key + metadata, signed by CA
- Trust chain: Server Cert → Intermediate CA → Root CA (in browser)
- Let's Encrypt provides free automated certificates via ACME
- ACME challenges verify domain ownership before issuing
- Traefik automates certificate requests and renewals
- Lab uses pre-generated certificates (no internet validation)
- Private keys must NEVER be shared or committed
- Certificates expire - automation prevents outages

## Memory Anchor

**Public Key** = PUBLIC (anyone can have it, goes in certificate)  
**Private Key** = PRIVATE (keep secret, stays on server only)

**Certificate Chain** = Chain of Trust  
Root CA (browser trusts) → signs Intermediate → signs Your Cert

**ACME** = Automatic Certificate Management Environment  
(Makes certificates AUTOMATIC, not manual)
