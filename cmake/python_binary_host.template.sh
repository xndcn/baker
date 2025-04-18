#!/bin/env bash
SOURCE_DIR="$<TARGET_PROPERTY:SOURCE_DIR>"
MAIN_PY="$<IF:$<BOOL:$<TARGET_PROPERTY:main>>,$<TARGET_PROPERTY:main>,$<TARGET_PROPERTY:NAME>.py>"
PYTHONPATH="${SOURCE_DIR}:${PYTHONPATH}"
python3 "${SOURCE_DIR}/${MAIN_PY}" "$@"