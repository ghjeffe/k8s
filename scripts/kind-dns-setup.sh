#!/usr/bin/env bash
#
# kind-dns-setup.sh
# Automatically configures /etc/hosts and displays Istio ingress gateway
# port mappings for all running kind clusters.
#
# Usage:
#   sudo ./kind-dns-setup.sh          # update /etc/hosts + show port info
#   sudo ./kind-dns-setup.sh --clean  # remove managed entries from /etc/hosts

set -euo pipefail

HOSTS_FILE="/etc/hosts"
MARKER_START="# >>> KIND CLUSTERS (managed by kind-dns-setup.sh) >>>"
MARKER_END="# <<< KIND CLUSTERS <<<"
DOMAIN_SUFFIX="local"

# --- helpers ---
remove_managed_block() {
    if grep -q "$MARKER_START" "$HOSTS_FILE"; then
        sed -i "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE"
        echo "Removed existing managed DNS entries."
    fi
}

# --- clean mode ---
if [[ "${1:-}" == "--clean" ]]; then
    remove_managed_block
    echo "Done."
    exit 0
fi

# --- preflight ---
if [[ $EUID -ne 0 ]]; then
    echo "This script modifies /etc/hosts. Please run with sudo."
    exit 1
fi

for cmd in kind docker kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not found."
        exit 1
    fi
done

# --- discover clusters ---
mapfile -t CLUSTERS < <(kind get clusters 2>/dev/null)

if [[ ${#CLUSTERS[@]} -eq 0 ]]; then
    echo "No kind clusters found."
    exit 0
fi

echo "Found ${#CLUSTERS[@]} kind cluster(s): ${CLUSTERS[*]}"
echo

# --- build /etc/hosts entries ---
remove_managed_block

{
    echo "$MARKER_START"
    for cluster in "${CLUSTERS[@]}"; do
        node="${cluster}-control-plane"
        ip=$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' "$node" 2>/dev/null || echo "")
        if [[ -z "$ip" ]]; then
            echo "# ${cluster}: container not running"
            continue
        fi
        echo "${ip}  pyapp.${cluster}.${DOMAIN_SUFFIX}"
    done
    echo "$MARKER_END"
} >> "$HOSTS_FILE"

echo "Updated $HOSTS_FILE:"
sed -n "/$MARKER_START/,/$MARKER_END/p" "$HOSTS_FILE"
echo

# --- display ingress gateway info ---
echo "=== Istio Ingress Gateway Mappings ==="
printf "%-12s  %-16s  %-10s  %s\n" "CLUSTER" "NODE IP" "NODEPORT" "URL"
printf "%-12s  %-16s  %-10s  %s\n" "-------" "-------" "--------" "---"

for cluster in "${CLUSTERS[@]}"; do
    context="kind-${cluster}"
    node="${cluster}-control-plane"
    ip=$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' "$node" 2>/dev/null || echo "n/a")

    nodeport=$(kubectl --context "$context" get svc -n istio-system istio-ingressgateway \
        -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}' 2>/dev/null || echo "n/a")

    if [[ "$nodeport" == "n/a" || -z "$nodeport" ]]; then
        printf "%-12s  %-16s  %-10s  %s\n" "$cluster" "$ip" "n/a" "(no istio ingress)"
    else
        printf "%-12s  %-16s  %-10s  %s\n" "$cluster" "$ip" "$nodeport" \
            "curl -H 'Host: pyapp.${cluster}.${DOMAIN_SUFFIX}' http://${ip}:${nodeport}/"
    fi
done

echo
echo "=== Port-Forward Commands (alternative) ==="
port=8081
for cluster in "${CLUSTERS[@]}"; do
    context="kind-${cluster}"
    has_ns=$(kubectl --context "$context" get ns pyapp --no-headers 2>/dev/null || echo "")
    if [[ -n "$has_ns" ]]; then
        echo "kubectl --context ${context} port-forward -n pyapp svc/pyapp ${port}:80 &  # http://localhost:${port}"
    else
        echo "# ${cluster}: pyapp namespace not found — skipping"
    fi
    ((port++))
done
