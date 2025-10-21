#!/usr/bin/env bats

load _helpers

@test "ConfigMap/mse: disabled by default" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --namespace default \
        --show-only templates/configmap-mse.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r 'length > 0' | tee -a /dev/stderr)

    [ "${actual}" == "false" ]
}

@test "ConfigMap/mse: can be enabled with auto-configuration" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --set 'server.mse.persistence.storageSize=10Gi' \
        --namespace default \
        --show-only templates/configmap-mse.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data."mse.conf"' | tee -a /dev/stderr)

    local expectedMseConfig='env: {
  id = "mse";
  memcache_size = "auto";

  books = ( {
    id = "book";
    directory = "/var/lib/mse/book";
    database_size = "107374182";

    stores = ( {
      id = "store";
      filename = "/var/lib/mse/store.dat";
      size = "9771050598";
    } );
  } );
};'

    [ "${actual}" == "${expectedMseConfig}" ]
}

@test "ConfigMap/mse: can be enabled with auto-configuration with bookSize and storeSize" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --set 'server.mse.persistence.storageSize=80Gi' \
        --set 'server.mse.persistence.bookSize=10Gi' \
        --set 'server.mse.persistence.storeSize=70Gi' \
        --namespace default \
        --show-only templates/configmap-mse.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data."mse.conf"' | tee -a /dev/stderr)

    local expectedMseConfig='env: {
  id = "mse";
  memcache_size = "auto";

  books = ( {
    id = "book";
    directory = "/var/lib/mse/book";
    database_size = "10737418240";

    stores = ( {
      id = "store";
      filename = "/var/lib/mse/store.dat";
      size = "75161927680";
    } );
  } );
};'

    [ "${actual}" == "${expectedMseConfig}" ]
}

@test "ConfigMap/mse: can be enabled with auto-configuration with bookSize and storeSize as integer" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --set 'server.mse.persistence.storageSize=80Gi' \
        --set 'server.mse.persistence.bookSize=10737418240' \
        --set 'server.mse.persistence.storeSize=75161927680' \
        --namespace default \
        --show-only templates/configmap-mse.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data."mse.conf"' | tee -a /dev/stderr)

    local expectedMseConfig='env: {
  id = "mse";
  memcache_size = "auto";

  books = ( {
    id = "book";
    directory = "/var/lib/mse/book";
    database_size = "10737418240";

    stores = ( {
      id = "store";
      filename = "/var/lib/mse/store.dat";
      size = "75161927680";
    } );
  } );
};'

    [ "${actual}" == "${expectedMseConfig}" ]
}

@test "ConfigMap/mse: can be enabled with auto-configuration with bookSize and storeSize as percentage" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --set 'server.mse.persistence.storageSize=80Gi' \
        --set 'server.mse.persistence.bookSize=10%' \
        --set 'server.mse.persistence.storeSize=85%' \
        --namespace default \
        --show-only templates/configmap-mse.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data."mse.conf"' | tee -a /dev/stderr)

    local expectedMseConfig='env: {
  id = "mse";
  memcache_size = "auto";

  books = ( {
    id = "book";
    directory = "/var/lib/mse/book";
    database_size = "8589934592";

    stores = ( {
      id = "store";
      filename = "/var/lib/mse/store.dat";
      size = "73014444032";
    } );
  } );
};'

    [ "${actual}" == "${expectedMseConfig}" ]
}

@test "ConfigMap/mse: can be enabled with auto-configuration with bookSize and storeSize as both percentage and number" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --set 'server.mse.persistence.storageSize=100Gi' \
        --set 'server.mse.persistence.bookSize=10%' \
        --set 'server.mse.persistence.storeSize=90Gi' \
        --namespace default \
        --show-only templates/configmap-mse.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data."mse.conf"' | tee -a /dev/stderr)

    local expectedMseConfig='env: {
  id = "mse";
  memcache_size = "auto";

  books = ( {
    id = "book";
    directory = "/var/lib/mse/book";
    database_size = "10737418240";

    stores = ( {
      id = "store";
      filename = "/var/lib/mse/store.dat";
      size = "96636764160";
    } );
  } );
};'

    [ "${actual}" == "${expectedMseConfig}" ]
}

@test "ConfigMap/mse: can be enabled with manual configuration" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --set 'server.mse.persistence.storageSize=80Gi' \
        --set 'server.mse.persistence.bookSize=10%' \
        --set 'server.mse.persistence.storeSize=85%' \
        --set 'server.mse.config=env:{}' \
        --namespace default \
        --show-only templates/configmap-mse.yaml \
        . || echo "---") | tee -a /dev/stderr |
        yq -r '.data."mse.conf"' | tee -a /dev/stderr)

    [ "${actual}" == "env:{}" ]
}

@test "ConfigMap/mse: cannot be enabled when bookSize and storeSize exceed storageSize" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --set 'server.mse.persistence.storageSize=80Gi' \
        --set 'server.mse.persistence.bookSize=11Gi' \
        --set 'server.mse.persistence.storeSize=70Gi' \
        --namespace default \
        --show-only templates/configmap-mse.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.mse.persistence.bookSize' and 'server.mse.persistence.storeSize' cannot exceed 'server.mse.persistence.storageSize'"* ]]
}

@test "ConfigMap/mse: cannot be enabled when bookSize and storeSize as percentage exceed storageSize" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --set 'server.mse.persistence.storageSize=80Gi' \
        --set 'server.mse.persistence.bookSize=11%' \
        --set 'server.mse.persistence.storeSize=90%' \
        --namespace default \
        --show-only templates/configmap-mse.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.mse.persistence.bookSize' and 'server.mse.persistence.storeSize' cannot exceed 'server.mse.persistence.storageSize'"* ]]
}

@test "ConfigMap/mse: cannot be enabled when mixed bookSize and storeSize as percentage and number exceed storageSize" {
    cd "$(chart_dir)"

    local actual=$((helm template \
        --set 'server.kind=StatefulSet' \
        --set 'server.mse.persistence.enabled=true' \
        --set 'server.mse.persistence.storageSize=100Gi' \
        --set 'server.mse.persistence.bookSize=11%' \
        --set 'server.mse.persistence.storeSize=90Gi' \
        --namespace default \
        --show-only templates/configmap-mse.yaml \
        . || echo "---") 2>&1 |
        tee -a /dev/stderr)

    [[ "${actual}" == *"'server.mse.persistence.bookSize' and 'server.mse.persistence.storeSize' cannot exceed 'server.mse.persistence.storageSize'"* ]]
}