#!/usr/bin/with-contenv bashio
set -e

CONFIG_DIR=/config/cliproxyapi
AUTH_DIR="${CONFIG_DIR}/.cli-proxy-api"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
EXAMPLE_CONFIG=/usr/share/cliproxyapi/config.example.yaml

API_TOKEN="$(bashio::config 'api_token')"

if [ -z "${API_TOKEN}" ]; then
    bashio::log.error "API token is not configured. Set api_token in the app configuration."
    exit 1
fi

mkdir -p "${AUTH_DIR}"

if [ ! -f "${CONFIG_FILE}" ]; then
    bashio::log.warning "No config.yaml found in ${CONFIG_DIR}."
    bashio::log.warning "Seeding from example."
    cp "${EXAMPLE_CONFIG}" "${CONFIG_FILE}"
fi

# Keep the user-managed runtime configuration, but make the API key in it follow
# the Home Assistant app option. A single-quoted YAML scalar only needs embedded
# single quotes doubled; all other token characters remain literal.
YAML_API_TOKEN="${API_TOKEN//\'/\'\'}"
export YAML_API_TOKEN
TEMP_CONFIG="$(mktemp)"
awk '
    /^api-keys:$/ {
        print
        print "  - \047" ENVIRON["YAML_API_TOKEN"] "\047"
        replacing = 1
        found = 1
        next
    }
    replacing && /^[^[:space:]#]/ {
        replacing = 0
    }
    !replacing {
        print
    }
    END {
        if (!found) {
            exit 1
        }
    }
' "${CONFIG_FILE}" > "${TEMP_CONFIG}" || {
    rm -f "${TEMP_CONFIG}"
    unset YAML_API_TOKEN API_TOKEN
    bashio::log.error "Could not configure api-keys in ${CONFIG_FILE}."
    exit 1
}
chmod 600 "${TEMP_CONFIG}"
mv "${TEMP_CONFIG}" "${CONFIG_FILE}"
unset YAML_API_TOKEN API_TOKEN

bashio::log.info "Auth dir:   ${AUTH_DIR}"
bashio::log.info "Config:     ${CONFIG_FILE}"
bashio::log.info "Auth shell: click \"Open Web UI\" to bootstrap OAuth credentials."
