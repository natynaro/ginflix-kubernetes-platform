#!/usr/bin/env bash
# Regression tests for GINFlix NetworkPolicies.
set -euo pipefail

NS=ginflix
PASS=0
FAIL=0

ok()   { echo "  ✅ $1"; PASS=$((PASS + 1)); }
bad()  { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

run_expect() {
  local desc=$1 expect=$2
  shift 2
  if "$@" >/dev/null 2>&1; then
    if [[ "$expect" == pass ]]; then
      ok "$desc"
    else
      bad "$desc (expected fail, got success)"
    fi
  else
    if [[ "$expect" == fail ]]; then
      ok "$desc"
    else
      bad "$desc (expected pass, got fail)"
    fi
  fi
}

echo "=== NetworkPolicy regression tests (namespace: ${NS}) ==="

# frontend must NOT reach MongoDB
run_expect "frontend → database:27017 blocked" fail \
  kubectl exec -n "$NS" deploy/frontend -- sh -c \
  'timeout 3 sh -c "echo | nc -w2 database.ginflix.svc.cluster.local 27017"'

# backend must reach MongoDB
run_expect "backend → database:27017 allowed" pass \
  kubectl exec -n "$NS" deploy/backend -- sh -c \
  'timeout 3 sh -c "echo | nc -w2 database.ginflix.svc.cluster.local 27017"'

# ingress → frontend HTTP
run_expect "ingress-nginx → frontend:80 allowed" pass \
  kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- \
  curl -sf --connect-timeout 3 --max-time 5 http://frontend.ginflix.svc.cluster.local/

# ingress → backend HTTP (404 on / is OK — server is up)
# Keep the script single-quoted so $code expands inside the pod.
# shellcheck disable=SC2016
run_expect "ingress-nginx → backend:8080 allowed" pass \
  kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- \
  sh -c 'code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 http://backend.ginflix.svc.cluster.local:8080/); test "$code" = "200" -o "$code" = "404"'

# public API via nginx path
run_expect "HTTPS /api/videos returns 200" pass \
  curl -skf --connect-timeout 5 --max-time 10 \
  --resolve ginflix.example.invalid:443:127.0.0.1 \
  https://ginflix.example.invalid/api/videos

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
