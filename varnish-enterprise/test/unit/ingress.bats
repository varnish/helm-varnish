#!/usr/bin/env bats

load _helpers

@test "Ingress/clusterIP: use service port" {
  cd "$(chart_dir)"

  local actual=$((helm template \
    --set 'server.service.http.port=8888' \
    --set 'server.ingress.enabled=true' \
    --set 'server.ingress.hosts[0].host=example.com' \
    --namespace default \
    --show-only templates/ingress.yaml \
    . || echo "---") | tee -a /dev/stderr |
    yq -r '.spec.rules[0].http.paths[0].backend.service.port.number' | tee -a /dev/stderr)

  [ "${actual}" == "8888" ]
}

@test "Ingress/clusterIP: use container port for headless ClusterIP" {
  cd "$(chart_dir)"

  local actual=$((helm template \
    --set 'server.http.port=8080' \
    --set 'server.service.http.port=8888' \
    --set 'server.service.type=ClusterIP' \
    --set 'server.service.clusterIP=None' \
    --set 'server.ingress.enabled=true' \
    --set 'server.ingress.hosts[0].host=example.com' \
    --namespace default \
    --show-only templates/ingress.yaml \
    . || echo "---") | tee -a /dev/stderr |
    yq -r '.spec.rules[0].http.paths[0].backend.service.port.number' | tee -a /dev/stderr)

  [ "${actual}" == "8080" ]
}
