# Colima/Testcontainers configuration for macOS.
# This is split out of .zshrc to keep startup-specific logic isolated.

_colima_sock="${HOME}/.colima/default/docker.sock"
_colima_host_cache="${HOME}/.cache/colima-testcontainers-host"

if [[ "$(uname)" == "Darwin" ]] && [[ -S "${_colima_sock}" ]]; then
    export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
    export DOCKER_HOST="unix://${_colima_sock}"

    if [[ -z "${TESTCONTAINERS_HOST_OVERRIDE:-}" ]]; then
        _cached_colima_addr=""
        if [[ -r "${_colima_host_cache}" ]] && [[ ! "${_colima_sock}" -nt "${_colima_host_cache}" ]]; then
            _cached_colima_addr="$(<"${_colima_host_cache}")"
        fi

        if [[ -n "${_cached_colima_addr}" ]]; then
            export TESTCONTAINERS_HOST_OVERRIDE="${_cached_colima_addr}"
        else
            _colima_json="$(colima ls -j 2>/dev/null)"
            _colima_addr="${_colima_json#*\"address\":\"}"
            _colima_addr="${_colima_addr%%\"*}"

            if [[ -n "${_colima_addr}" ]] && [[ "${_colima_addr}" != "${_colima_json}" ]]; then
                export TESTCONTAINERS_HOST_OVERRIDE="${_colima_addr}"
                mkdir -p "${HOME}/.cache"
                print -r -- "${_colima_addr}" >|"${_colima_host_cache}"
            fi
        fi
    fi
fi

unset _colima_sock _colima_host_cache _cached_colima_addr _colima_json _colima_addr
