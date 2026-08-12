# Colima/Testcontainers configuration for macOS.
# This is split out of .zshrc to keep startup-specific logic isolated.

_colima_sock="${HOME}/.colima/default/docker.sock"

if [[ "$(uname)" == "Darwin" ]] && [[ -S "${_colima_sock}" ]]; then
    export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
    export DOCKER_HOST="unix://${_colima_sock}"
    unset TESTCONTAINERS_HOST_OVERRIDE
fi

unset _colima_sock
