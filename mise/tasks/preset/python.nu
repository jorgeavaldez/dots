#!/usr/bin/env nu
#MISE description="Create a Python and uv project config"
#MISE dir="{{cwd}}"

# we need to initialize w/ uv first so that it has the uv.lock file
# otherwise mise won't handle the venv
if not ("pyproject.toml" | path exists) {
    print "initializing uv project"
    mise x -- uv init .
}

if not ("uv.lock" | path exists) {
    print "generating uv lockfile"
    mise x -- uv lock
}

let mise_config = "mise.toml"

if ($mise_config | path exists) {
    error make -u {
        msg: $"($mise_config) already exists"
        help: "merge the preset manually"
    }
}

let python_preset_conf = {
    settings: {
        python: {uv_venv_auto: "create|source"}
        idiomatic_version_file_enable_tools: ["python"]
    }
    env: {
        UV_PYTHON: {value: "{{ tools.python.path }}", tools: true}
    }
    tools: {python: "3.14", uv: "latest"}
    tasks: {
        sync: {run: "uv sync"}
        test: {run: "uv run pytest"}
        lint: {run: "uv run ruff check ."}
        format: {run: "uv run ruff format ."}
        check: {run: "uv run ty check"}
    }
}

$python_preset_conf | to toml | save $mise_config

mise trust
