job [[ template "job_name" . ]] {

  [[ template "region" . ]]
  datacenters = [[ .keycloak.datacenters | toJson ]]
  namespace   = [[ .keycloak.namespace | quote ]]
  type        = "service"

  [[ template "constraints" .keycloak.constraints ]]

  group "keycloak" {
    network {
      mode = [[ .keycloak.network.mode | quote ]]
      [[- range $port := .keycloak.network.ports ]]
      port [[ $port.name | quote ]] {
        to = [[ $port.to ]]
        [[- if $port.static ]]
        static = [[ $port.static ]]
        [[- end ]]
      }
      [[- end ]]
    }

    task "keycloak" {
      driver = "docker"

      [[- if .keycloak.keycloak_service ]]
      [[ template "service" .keycloak.keycloak_service ]]
      [[- end ]]

      config {
        image = "quay.io/keycloak/keycloak:[[ .keycloak.keycloak_image_tag ]]"
        args = [[ .keycloak.container_args | toJson ]]
      }
      [[ template "resources" .keycloak.keycloak_resources ]]

      env {
        [[- template "env_vars" .keycloak.env_vars]]

        [[- if .keycloak.include_database_task -]]
        [[template "env_vars" .keycloak.db_env_vars]]
        [[- end ]]
      }
    }

    [[ if .keycloak.include_database_task -]]
    task "database" {
      driver = "docker"

      [[- if .keycloak.db_service ]]
      [[ template "service" .keycloak.db_service ]]
      [[- end ]]

      config {
        image = "postgres:[[.keycloak.postgres_image_tag]]"

        [[- if gt (len .keycloak.postgres_mounts) 0 ]]
        [[ template "mounts" .keycloak.postgres_mounts ]]
        [[- end ]]
      }

      env {
        [[- template "env_vars" .keycloak.db_env_vars]]
        PGDATA="/appdata/postgres"
      }

      [[ template "resources" .keycloak.db_resources ]]
    }
    [[- end ]]

    [[ if .keycloak.prestart_directory_creation -]]
    task "create-data-dirs" {
      lifecycle {
        hook = "prestart"
        sidecar = false
      }

      driver = "raw_exec"

      config {
        command = "sh"
        args = ["-c", "mkdir -p [[.keycloak.db_volume_source_path]] && chown 1001:1001 [[.keycloak.db_volume_source_path]]"]
      }

      resources {
        cpu    = 50
        memory = 50
      }
    }
    [[- end ]]
  }
}
