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

1. **Clone and navigate to directory**
   ```bash
   cd /home/krismyid/private/docker-cloudflaredoh-unbound
   ```

2. **Start the services**
   ```bash
   docker-compose up -d
   ```

3. **Check service status**
   ```bash
   docker-compose ps
   docker-compose logs -f
   ```

4. **Test DNS resolution**
   ```bash
   # Test from host
   nslookup google.com 127.0.0.1
   dig @127.0.0.1 cloudflare.com
   
   # Test with specific record types
   dig @127.0.0.1 TXT cloudflare.com
   dig @127.0.0.1 AAAA google.com
   ```

## Configuration

### Network Configuration
- **Docker Network**: `172.20.0.0/24`
- **Cloudflared IP**: `172.20.0.2`
- **Unbound IP**: `172.20.0.3`

### System DNS Configuration (Optional)

To use this as your system DNS resolver:

**Ubuntu/Debian:**
```bash
# Edit resolv.conf
sudo nano /etc/systemd/resolved.conf

# Add:
[Resolve]
DNS=127.0.0.1
#FallbackDNS=
#Domains=
#LLMNR=no
#MulticastDNS=no
#DNSSEC=no
#DNSOverTLS=no
#Cache=no
#DNSStubListener=yes

# Restart resolved
sudo systemctl restart systemd-resolved
```

**Manual resolv.conf:**
```bash
# Backup current config
sudo cp /etc/resolv.conf /etc/resolv.conf.backup

# Set new nameserver
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
```

## Monitoring and Troubleshooting

### Check Service Health
```bash
# View container status
docker-compose ps

# Check logs
docker-compose logs cloudflared
docker-compose logs unbound

# Follow logs in real-time
docker-compose logs -f
```

### Performance Testing
```bash
# Test query response time
time dig @127.0.0.1 google.com

# Test cache performance (should be faster on second query)
time dig @127.0.0.1 example.com
time dig @127.0.0.1 example.com
```

### Network Testing
```bash
# Test cloudflared directly
nslookup google.com 127.0.0.1 -port=5353

# Test unbound
nslookup google.com 127.0.0.1

# Verify DoH is working
docker exec cloudflared-doh nslookup google.com 127.0.0.1
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

## Maintenance

### Update Containers
```bash
docker-compose pull
docker-compose up -d
```

### Backup Configuration
```bash
tar -czf dns-backup-$(date +%Y%m%d).tar.gz docker-compose.yml unbound.conf
```

### Reset Cache
```bash
# Restart unbound to clear cache
docker-compose restart unbound
```

## Ports Used

- **53/TCP, 53/UDP**: DNS service (exposed to host)
- **5353/UDP**: Cloudflared DoH proxy (internal only)

## Troubleshooting

### Common Issues

1. **Port 53 already in use**
   ```bash
   # Check what's using port 53
   sudo netstat -tulpn | grep :53
   
   # Stop systemd-resolved if needed
   sudo systemctl stop systemd-resolved
   ```

2. **DNS not resolving**
   ```bash
   # Check container connectivity
   docker exec unbound-resolver ping cloudflared-doh
   
   # Verify cloudflared is responding
   docker exec cloudflared-doh nslookup google.com 127.0.0.1
   ```

3. **Slow DNS responses**
   ```bash
   # Check cache hit rates in logs
   docker-compose logs unbound | grep cache
   
   # Increase cache sizes in unbound.conf
   ```

## Security Considerations

- This setup provides DNS privacy but doesn't replace a VPN for full traffic encryption
- Consider firewall rules to restrict access to port 53
- Monitor logs for unusual query patterns
- Keep containers updated for security patches

## License

This configuration is provided as-is under MIT license. Use at your own risk.
