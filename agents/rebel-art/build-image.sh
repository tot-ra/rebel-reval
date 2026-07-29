#!/usr/bin/env bash
set -euo pipefail

readonly AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly IMAGE="${REBEL_ART_IMAGE:-a2gent-rebel-art:blender-4.3}"
readonly BASE_IMAGE="${A2GENT_BRUTE_IMAGE:-a2gent-brute:latest}"

docker image inspect "${BASE_IMAGE}" >/dev/null 2>&1 || {
  printf 'Base image %s is missing. Build a2gent-brute:latest in ~/git/a2gent/brute first.\n' "${BASE_IMAGE}" >&2
  exit 1
}

docker build \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --tag "${IMAGE}" \
  "${AGENT_DIR}"

docker run --rm --entrypoint sh "${IMAGE}" -lc '
  set -eu
  blender --version | head -1
  python3 --version
  python3 -c "import numpy, PIL; print(\"NumPy \" + numpy.__version__ + \", Pillow \" + PIL.__version__)"
'

printf 'Built %s\n' "${IMAGE}"
