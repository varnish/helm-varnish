#!/usr/bin/env bats

load _helpers

@test "repoType: default (no global.repoType set)" {
  helm_template_compare \
    "global: {}" \
    "templates/deployment.yaml" \
    '.spec.template.spec.containers[0].image' \
    "\"quay.io/varnish-software/varnish-plus:$(app_version)\""
}

@test "repoType: public-enterprise" {
  helm_template_compare \
    "global: {repoType: public-enterprise}" \
    "templates/deployment.yaml" \
    '.spec.template.spec.containers[0].image' \
    "\"varnish/varnish-enterprise:$(app_version)\""
}

@test "repoType: private-enterprise" {
  helm_template_compare \
    "global: {repoType: private-enterprise}" \
    "templates/deployment.yaml" \
    '.spec.template.spec.containers[0].image' \
    "\"quay.io/varnish-software/varnish-plus:$(app_version)\""
}