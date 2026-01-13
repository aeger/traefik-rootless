/ip firewall address-list
# Update Cloudflare IP ranges periodically.
# Ideally auto-sync via script, or at least re-import on changes.
# name=cloudflare
add list=cloudflare address=173.245.48.0/20 comment="Cloudflare"
add list=cloudflare address=103.21.244.0/22 comment="Cloudflare"
add list=cloudflare address=103.22.200.0/22 comment="Cloudflare"
add list=cloudflare address=103.31.4.0/22 comment="Cloudflare"
add list=cloudflare address=141.101.64.0/18 comment="Cloudflare"
add list=cloudflare address=108.162.192.0/18 comment="Cloudflare"
add list=cloudflare address=190.93.240.0/20 comment="Cloudflare"
add list=cloudflare address=188.114.96.0/20 comment="Cloudflare"
add list=cloudflare address=197.234.240.0/22 comment="Cloudflare"
add list=cloudflare address=198.41.128.0/17 comment="Cloudflare"
add list=cloudflare address=162.158.0.0/15 comment="Cloudflare"
add list=cloudflare address=104.16.0.0/13 comment="Cloudflare"
add list=cloudflare address=104.24.0.0/14 comment="Cloudflare"
add list=cloudflare address=172.64.0.0/13 comment="Cloudflare"
add list=cloudflare address=131.0.72.0/22 comment="Cloudflare"

# If you use IPv6 + Cloudflare, add the v6 ranges too.

# ---- NAT ----
/ip firewall nat
add chain=dstnat action=dst-nat in-interface-list=WAN protocol=tcp dst-port=8443 \
  to-addresses=192.168.1.181 to-ports=443 comment="Traefik HTTPS via Cloudflare (8443->443)"

# Optional hairpin (LAN clients hitting public hostname)
/ip firewall nat
add chain=dstnat action=dst-nat in-interface-list=LAN protocol=tcp dst-port=8443 \
  dst-address=70.190.70.223 to-addresses=192.168.1.181 to-ports=443 comment="Hairpin 8443->443 (adjust dst-address)"

add chain=srcnat action=masquerade out-interface-list=LAN src-address=192.168.1.0/24 \
  dst-address=192.168.1.181 protocol=tcp dst-port=443 comment="Hairpin srcnat"

# ---- FILTER (forward) ----
/ip firewall filter
add chain=forward action=accept connection-state=established,related comment="established/related"
add chain=forward action=drop connection-state=invalid comment="drop invalid"

# Allow only Cloudflare to reach the dstnat'ed service
add chain=forward action=accept in-interface-list=WAN protocol=tcp dst-address=192.168.1.181 dst-port=443 \
  src-address-list=cloudflare connection-nat-state=dstnat comment="Allow Cloudflare -> Traefik (dstnat)"

# Drop everyone else trying to hit that dstnat
add chain=forward action=drop in-interface-list=WAN protocol=tcp dst-address=192.168.1.181 dst-port=443 \
  connection-nat-state=dstnat comment="Drop non-Cloudflare -> Traefik (dstnat)"
