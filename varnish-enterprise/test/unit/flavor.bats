#!/usr/bin/env bats

load _helpers

@test "Flavor: Enterprise chart is flagged as enterprise" {
    cd "$(chart_dir)"
    local actual=$(yq -r '.annotations.flavor' Chart.yaml)
    [ "${actual}" == "enterprise" ]
}
