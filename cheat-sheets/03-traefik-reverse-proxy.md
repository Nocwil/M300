CHEAT-SHEET — Traefik Reverse Proxy
─────────────────────────────────────────────────────
Core Concept:
  Traefik is a modern reverse proxy that automatically routes HTTP/HTTPS
  traffic to Docker containers based on domain names. It reads container
  labels to configure routing dynamically without manual config file editing.

Key Terminology:
────────────────────────────────────────────────────────────
Term              │ Definition
──────────────────┼─────────────────────────────────────────────────
EntryPoint        │ Network port Traefik listens on (80=web, 443=websecure)
Router            │ Rules that match incoming requests to services
Service           │ The backend container handling the request
Middleware        │ Modifies requests/responses (auth, redirect, headers)
Provider          │ Source of configuration (Docker, file, etc.)
Certificate       │ TLS/SSL certificate for HTTPS
Resolver          │ Method to obtain certificates (Let's Encrypt, default)

Traefik Setup (Docker Compose):
────────────────────────────────────────────────────────────
Step                                     │ Command/Action
─────────────────────────────────────────┼──────────────────────────────────
Create shared network                    │ docker network create traefik-proxy
Create directory structure               │ mkdir -p traefik traefik/certs/default data
Install password tool                    │ apt install -y apache2-utils
Generate password hash                   │ htpasswd -nB admin > pwfile
Create .env file                         │ See template below
Create traefik.yml (static config)       │ See template below
Create dynamic.yml (TLS config)          │ See template below
Add certificates                         │ Copy cert.pem and privkey.pem
Start Traefik                            │ docker compose up -d
Access dashboard                         │ https://traefik.m300.smartlearn.ch/dashboard/

.env File Template:
────────────────────────────────────────────────────────────
DOMAIN=m300.smartlearn.ch
CERT_RESOLVER=le
TRAEFIK_USER=admin
TRAEFIK_PASSWORD_HASH=$2y$05$xxxxx...

traefik.yml (Static Configuration):
────────────────────────────────────────────────────────────
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false      # Only containers with traefik.enable=true
    network: traefik-proxy        # Default network for routing

  file:
    filename: /etc/traefik/dynamic.yml
    watch: true                   # Auto-reload on changes

certificatesResolvers:
  le:                             # Let's Encrypt resolver
    acme:

api:
  insecure: false
  debug: false

dynamic.yml (TLS Configuration):
────────────────────────────────────────────────────────────
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/certs/default/cert.pem
        keyFile: /etc/traefik/certs/default/privkey.pem

docker-compose.yml (Traefik Service):
────────────────────────────────────────────────────────────
services:
  traefik:
    image: "traefik:v3.6"
    container_name: "traefik"
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      
      # HTTP to HTTPS redirect for all *.m300.smartlearn.ch
      - "traefik.http.routers.to-https.rule=hostregexp(`.+.m300.smartlearn.ch`)"
      - traefik.http.routers.to-https.entrypoints=web
      - traefik.http.routers.to-https.middlewares=to-https
      
      # Dashboard access
      - traefik.http.routers.traefik.rule=Host(`traefik.m300.smartlearn.ch`)
      - traefik.http.routers.traefik.entrypoints=websecure
      - traefik.http.routers.traefik.middlewares=auth
      - traefik.http.routers.traefik.service=api@internal
      - traefik.http.routers.traefik.tls=true
      - traefik.http.routers.traefik.tls.certresolver=${CERT_RESOLVER}
      
      # Middleware definitions
      - traefik.http.middlewares.to-https.redirectscheme.scheme=https
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
    external: true    # CRITICAL: Must be external

Routing an Application Through Traefik:
────────────────────────────────────────────────────────────
Example: whoami test service

services:
  whoami:
    image: traefik/whoami
    container_name: whoami
    networks:
      - traefik-proxy              # MUST be on traefik-proxy network
    labels:
      - "traefik.enable=true"      # Enable Traefik routing
      - "traefik.http.routers.whoami.rule=Host(`whoami.lan.m300.smartlearn.ch`)"
      - "traefik.http.routers.whoami.entrypoints=websecure"
      - "traefik.http.routers.whoami.tls=true"

networks:
  traefik-proxy:
    external: true

Essential Docker Labels for Routing:
────────────────────────────────────────────────────────────
Label                                    │ Purpose
─────────────────────────────────────────┼──────────────────────────────────
traefik.enable=true                      │ Enable routing for this container
traefik.http.routers.NAME.rule           │ Routing rule (Host, Path, etc.)
traefik.http.routers.NAME.entrypoints    │ Which port (web=80, websecure=443)
traefik.http.routers.NAME.tls            │ Enable HTTPS
traefik.http.routers.NAME.middlewares    │ Apply middleware (auth, redirect)
traefik.http.routers.NAME.service        │ Backend service to route to

Common Routing Rules:
────────────────────────────────────────────────────────────
Rule Type         │ Example
──────────────────┼─────────────────────────────────────────────────
Single host       │ Host(`app.m300.smartlearn.ch`)
Wildcard subdomain│ hostregexp(`.+.m300.smartlearn.ch`)
Path-based        │ Host(`example.com`) && Path(`/api`)
Multiple hosts    │ Host(`app1.com`, `app2.com`)

Workflow for Adding New Service:
────────────────────────────────────────────────────────────
1. Create DNS A record: newapp IN A 192.168.220.13
2. Restart DNS: docker compose -f /root/dns-bind/docker-compose.yml restart
3. Add service to docker-compose.yml with labels
4. Ensure network: traefik-proxy and external: true
5. Start service: docker compose up -d
6. Check Traefik dashboard for new route
7. Test: https://newapp.lan.m300.smartlearn.ch

Troubleshooting:
────────────────────────────────────────────────────────────
Issue                          │ Solution
───────────────────────────────┼─────────────────────────────────────
503 Service Unavailable        │ Container not on traefik-proxy network
404 Not Found                  │ Router rule doesn't match request
Connection refused             │ Traefik container not running
Certificate error              │ Check cert files in traefik/certs/default/
Service not in dashboard       │ traefik.enable=true missing
                               │ OR exposedByDefault: false in traefik.yml

Checking Traefik Status:
────────────────────────────────────────────────────────────
Command                           │ Purpose
──────────────────────────────────┼─────────────────────────────────────
docker ps | grep traefik          │ Check if container is running
docker logs traefik               │ View Traefik logs
docker logs traefik --tail 50     │ Last 50 log lines
Dashboard → HTTP → Routers        │ See all active routes
Dashboard → HTTP → Services       │ See all backend services
Dashboard → HTTP → Middlewares    │ See all middleware

Key Concepts for Exam:
────────────────────────────────────────────────────────────
• Traefik reads Docker labels to auto-configure routing
• All routed containers MUST be on traefik-proxy network
• network: external: true prevents Docker from creating new network
• EntryPoints define which ports Traefik listens on
• Routers match requests and forward to services
• Middleware modifies requests (redirect HTTP→HTTPS, add auth, etc.)
• Static config (traefik.yml) requires restart to apply
• Dynamic config (dynamic.yml, Docker labels) applies immediately

HTTP to HTTPS Redirect:
────────────────────────────────────────────────────────────
Done via middleware in Traefik labels:

- traefik.http.routers.to-https.rule=hostregexp(`.+.m300.smartlearn.ch`)
- traefik.http.routers.to-https.entrypoints=web
- traefik.http.routers.to-https.middlewares=to-https
- traefik.http.middlewares.to-https.redirectscheme.scheme=https

This catches all HTTP requests to *.m300.smartlearn.ch and redirects to HTTPS.

Common Mistakes:
────────────────────────────────────────────────────────────
• Forgetting to add DNS record before testing
• Not including traefik-proxy network in service
• Using network: external: false (creates duplicate network)
• Missing trailing slash in dashboard URL (/dashboard/)
• Wrong label syntax (quotes, spacing)
• Container exposed on wrong port internally
• Certificate files not readable by Traefik container

Directory Structure:
────────────────────────────────────────────────────────────
/root/traefik/
├── .env
├── docker-compose.yml
├── data/
│   └── letsencrypt/          # Let's Encrypt certificate storage
└── traefik/
    ├── traefik.yml           # Static configuration
    ├── dynamic.yml           # Dynamic TLS configuration
    └── certs/
        └── default/
            ├── cert.pem      # TLS certificate
            └── privkey.pem   # Private key

Testing Checklist:
────────────────────────────────────────────────────────────
☐ DNS record exists and resolves
☐ Container on traefik-proxy network
☐ traefik.enable=true label present
☐ Router rule matches domain name
☐ TLS certificates in place
☐ Service appears in Traefik dashboard
☐ Browser can access service via domain name
─────────────────────────────────────────────────────────────
