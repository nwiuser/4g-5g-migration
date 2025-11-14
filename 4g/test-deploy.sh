#!/bin/sh
set -eu

echo "[test-deploy] Starting basic deployment tests"

# Show running containers
echo "[test-deploy] docker-compose ps:"
docker-compose ps

echo "[test-deploy] Waiting 5s for services to initialize..."
sleep 5

echo "[test-deploy] Verifying services are running"
# If there are no running services, fail
running=$(docker-compose ps --services --filter "status=running" || true)
if [ -z "$(echo "$running" | tr -d '[:space:]')" ]; then
  echo "[test-deploy] No running services found. Failing."
  docker-compose ps
  exit 1
fi

echo "[test-deploy] Running health checks for exposed ports (best-effort)"
failed=0
for svc in $running; do
  # Try common port 80, then attempt to discover any published port
  portpair=$(docker-compose port "$svc" 80 2>/dev/null || true)
  if [ -n "$portpair" ]; then
    host=$(echo "$portpair" | cut -d: -f1)
    port=$(echo "$portpair" | cut -d: -f2)
    echo "[test-deploy] Checking $svc at $host:$port"
    if ! curl -fsS --max-time 5 "http://$host:$port/" >/dev/null 2>&1; then
      echo "[test-deploy] Health check failed for $svc on $host:$port"
      failed=$((failed+1))
    fi
  else
    # If no port 80 mapping, try to list published ports via docker-compose ps (best-effort)
    ports=$(docker-compose ps --services | xargs -n1 -I{} sh -c 'docker-compose port {} 80 2>/dev/null || true' | tr -s '\n' ' ')
    if [ -n "$ports" ]; then
      echo "[test-deploy] Found published ports (best-effort): $ports"
    else
      echo "[test-deploy] No port mapping found for $svc; skipping HTTP check for this service"
    fi
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "[test-deploy] $failed health checks failed"
  exit 2
fi

echo "[test-deploy] All checks passed (basic)."
exit 0
