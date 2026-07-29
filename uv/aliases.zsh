export UV_ENVS="$HOME/.venvs"

uv-create() { uv venv "$UV_ENVS/$1" "${@:2}"; }
uv-activate() { source "$UV_ENVS/$1/bin/activate"; }
uv-ls() { ls "$UV_ENVS"; }
uv-rm() { rm -rf "$UV_ENVS/$1"; }

# uv-latest: print the versions of one or more packages resolved by uv.
# This installs the packages ephemerally with uv, then prints the resolved versions.
# Usage:
#   uv-latest numpy scipy pandas
#
function uv-latest () {
  if [ $# -eq 0 ]; then
    echo "usage: uv-latest <package> [package...]" >&2
    return 2
  fi

  # join all arguments with commas
  local joined
  joined=$(printf ",%s" "$@")
  joined=${joined:1}   # strip leading comma

  uv run --with "$joined" -- python -c '
import sys
from importlib.metadata import version, PackageNotFoundError

exit_code = 0
for dist in sys.argv[1:]:
    try:
        print(f"{dist}=={version(dist)}")
    except PackageNotFoundError:
        print(f"{dist} <not installed>", file=sys.stderr)
        exit_code = 1
sys.exit(exit_code)
' "$@"
}
