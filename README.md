# Docker DNS-over-HTTPS Setup with Cloudflared and Unbound

This setup provides a privacy-focused DNS infrastructure using Cloudflare's DNS-over-HTTPS service with local caching via Unbound.

## Architecture

```
Client DNS Query (port 53) 
    ↓
Unbound Container (caching layer)
    ↓ (upstream to cloudflared:5353)
Cloudflared Container 
    ↓ (DoH to Cloudflare)
Internet (1.1.1.1 via HTTPS)
```

## Project Structure

```
├── docker-compose.yml          # Docker services definition
├── unbound.conf               # Unbound DNS server configuration
├── manage.sh                  # Local service management script
├── tools/                     # Deployment and management tools
│   ├── dns.sh                # Main deployment tool wrapper
│   ├── deploy.sh             # Remote deployment script
│   ├── setup.sh              # Configuration setup script
│   └── config/               # Configuration files
│       ├── deploy.config.template  # Configuration template
│       └── deploy.config     # Your configuration (gitignored)
├── README.md                  # This file
└── flow.excalidraw           # Architecture diagram
```

## Components

### Cloudflared Container
- **Purpose**: Converts DNS queries to DNS-over-HTTPS requests
- **Upstream**: Cloudflare's 1.1.1.1 and 1.0.0.1 DoH endpoints
- **Port**: 5353/UDP (internal Docker network)
- **Features**: Encrypted DNS queries, privacy protection

### Unbound Container  
- **Purpose**: DNS caching resolver and network gateway
- **Port**: 53/UDP and 53/TCP (exposed to host)
- **Features**: DNS caching, query optimization, DNSSEC validation
- **Upstream**: Routes to cloudflared:5353

## Quick Start

1. **Setup configuration**
   ```bash
   # Interactive configuration setup
   tools/dns.sh setup interactive
   
   # Or manually copy and edit template
   cp tools/config/deploy.config.template tools/config/deploy.config
   # Edit tools/config/deploy.config with your server details
   ```

2. **Test connection**
   ```bash
   tools/dns.sh setup test
   ```

3. **Deploy to remote server**
   ```bash
   # Full deployment (copies files + starts services)
   tools/dns.sh deploy full
   
   # Or step by step
   tools/dns.sh deploy deploy    # Copy files only
   tools/dns.sh deploy start     # Start services
   ```

4. **Check service status**
   ```bash
   tools/dns.sh deploy status
   ```

5. **Test DNS resolution**
   ```bash
   # Test from remote server
   tools/dns.sh deploy test
   ```

## Configuration

### Network Configuration
- **Docker Network**: `172.20.0.0/24`
- **Cloudflared IP**: `172.20.0.2`
- **Unbound IP**: `172.20.0.3`

### Deployment Configuration
Edit `tools/config/deploy.config` to customize:
- **Remote server details** (hostname, user, directory)
- **SSH configuration** (key, port, options)
- **Deployment options** (backup, auto-start, dependency checks)

## Management Commands

### Setup and Testing
```bash
# Interactive configuration
tools/dns.sh setup interactive

# Test SSH connection
tools/dns.sh setup test

# Validate configuration
tools/dns.sh setup validate
```

### Deployment
```bash
# Full deployment (recommended)
tools/dns.sh deploy full

# Individual steps
tools/dns.sh deploy deploy    # Copy files only
tools/dns.sh deploy start     # Start services
tools/dns.sh deploy stop      # Stop services
tools/dns.sh deploy restart   # Restart services
```

### Monitoring
```bash
# Check service status
tools/dns.sh deploy status

# View logs
tools/dns.sh deploy logs
tools/dns.sh deploy logs unbound

# Test DNS performance
tools/dns.sh deploy test
```

## Security Features

- **DNS-over-HTTPS**: All upstream queries encrypted
- **No Logging**: Cloudflare has a no-logs policy
- **DNSSEC**: Validation enabled in Unbound
- **Query Minimization**: Reduces information leakage
- **Access Control**: Restricted to local networks

## Performance Optimizations

- **Local Caching**: Unbound caches responses for faster subsequent queries
- **Prefetching**: Popular domains pre-cached
- **Multiple Threads**: Unbound configured for concurrent processing
- **Optimized Cache Sizes**: Tuned for typical home/small office use

## Customization

## Advanced Configuration

### Modify Cloudflared Upstream
Edit `docker-compose.yml` to change DoH providers:
```yaml
command: proxy-dns --address 0.0.0.0 --port 5353 --upstream https://dns.quad9.net/dns-query
```

### Adjust Unbound Cache
Edit `unbound.conf` cache sizes based on available RAM:
```
rrset-cache-size: 256m  # Increase for more memory
msg-cache-size: 128m    # Increase for more memory
```

### Add Custom DNS Records
Add to `unbound.conf`:
```
local-zone: "mylocal.domain" static
local-data: "myserver.mylocal.domain IN A 192.168.1.100"
```

## Local Development

For local testing without remote deployment:
```bash
# Start services locally
./manage.sh start

# Check status locally  
./manage.sh status

# Test DNS locally
dig @127.0.0.1 google.com
```

## Troubleshooting

Use the deployment tools for troubleshooting:
```bash
# Check service status
tools/dns.sh deploy status

# View logs
tools/dns.sh deploy logs

# Test DNS performance
tools/dns.sh deploy test

# SSH into remote server
tools/dns.sh deploy ssh
```

Common issues are automatically handled by the deployment scripts.

## Security Considerations

- This setup provides DNS privacy but doesn't replace a VPN for full traffic encryption
- Consider firewall rules to restrict access to port 53
- Monitor logs for unusual query patterns
- Keep containers updated for security patches

## License

This configuration is provided as-is under MIT license. Use at your own risk.
