#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run.sh --cell CELL --gds GDS --cdl CDL [options]

Options:
  --lib-name NAME       Library name prefix. Default: CELL
  --source-cell NAME    Source .SUBCKT name in the CDL when it differs from CELL
  --process NAME        Default: tt
  --vdd VALUE           Default: 0.7
  --temp VALUE          Default: 25
  --run-drc 0|1         Default: 0
  --skip-lvs 0|1        Default: 1
  --skip-pvspex 0|1     Default: 1
  --skip-qtspex 0|1     Default: 1
  --skip-char 0|1       Default: 0
  --char-from MODE      pex|schematic. Default: schematic
  --smoke-char 0|1      Use a tiny characterization table. Default: 1
  --layer NUM           GDS boundary layer. Default: 100
  --texttype NUM        GDS pin texttype. Default: 251
EOF
}

find_bin() {
  local tool_name="$1"
  shift
  local candidate
  for candidate in "$@"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  if command -v "$tool_name" >/dev/null 2>&1; then
    command -v "$tool_name"
    return 0
  fi
  return 1
}

CELL=""
GDS_FILE=""
CDL_FILE=""
LIB_NAME=""
SOURCE_CELL=""
PROCESS="tt"
VDD="0.7"
TEMP="25"
RUN_DRC="0"
SKIP_LVS="1"
SKIP_PVSPEX="1"
SKIP_QTSPEX="1"
SKIP_CHAR="0"
CHAR_FROM="schematic"
SMOKE_CHAR="1"
GDS_LAYER="100"
GDS_TEXTTYPE="251"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cell) CELL="$2"; shift 2 ;;
    --gds) GDS_FILE="$2"; shift 2 ;;
    --cdl) CDL_FILE="$2"; shift 2 ;;
    --lib-name) LIB_NAME="$2"; shift 2 ;;
    --source-cell) SOURCE_CELL="$2"; shift 2 ;;
    --process) PROCESS="$2"; shift 2 ;;
    --vdd) VDD="$2"; shift 2 ;;
    --temp) TEMP="$2"; shift 2 ;;
    --run-drc) RUN_DRC="$2"; shift 2 ;;
    --skip-lvs) SKIP_LVS="$2"; shift 2 ;;
    --skip-pvspex) SKIP_PVSPEX="$2"; shift 2 ;;
    --skip-qtspex) SKIP_QTSPEX="$2"; shift 2 ;;
    --skip-char) SKIP_CHAR="$2"; shift 2 ;;
    --char-from) CHAR_FROM="$2"; shift 2 ;;
    --smoke-char) SMOKE_CHAR="$2"; shift 2 ;;
    --layer) GDS_LAYER="$2"; shift 2 ;;
    --texttype) GDS_TEXTTYPE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$CELL" || -z "$GDS_FILE" || -z "$CDL_FILE" ]]; then
  usage
  exit 2
fi

if [[ -z "$LIB_NAME" ]]; then
  LIB_NAME="$CELL"
fi

PEGASUS_BIN="${PEGASUS_BIN:-$(find_bin pegasus "/opt/cadence/PEGASUS232/bin/pegasus" "$HOME/bin/pegasus" "$HOME/bin/pegasus232" || true)}"
QUANTUS_BIN="${QUANTUS_BIN:-$(find_bin quantus "/opt/cadence/QUANTUS231/bin/quantus" "$HOME/bin/quantus" "$HOME/bin/quantus231" || true)}"
LIBERATE_BIN="${LIBERATE_BIN:-$(find_bin liberate "/opt/cadence/LIBERATE231/bin/liberate" "$HOME/bin/liberate" "$HOME/bin/liberate231" || true)}"
PYTHON_BIN="${PYTHON_BIN:-python}"

if [[ -z "$PEGASUS_BIN" || -z "$QUANTUS_BIN" || -z "$LIBERATE_BIN" ]]; then
  echo "ERROR: missing EDA executable(s)." >&2
  exit 2
fi

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_DIR="${BASE_DIR}/inputs"
SCRIPT_DIR="${BASE_DIR}/scripts"
RESULT_DIR="${BASE_DIR}/results"
LOG_DIR="${BASE_DIR}/logs"
DONE_DIR="${BASE_DIR}/done"
WORK_DIR="${RESULT_DIR}/work/${CELL}_${LIB_NAME}"
PEX_DIR="${RESULT_DIR}/pex/${CELL}_${LIB_NAME}"

mkdir -p "$RESULT_DIR" "$LOG_DIR" "$DONE_DIR" "$WORK_DIR" "$PEX_DIR" "${RESULT_DIR}/cell_info" "${RESULT_DIR}/libchar"

PVL_FILE="${INPUT_DIR}/lvs.pvl"
RENAMED_CDL="${WORK_DIR}/${CELL}.cdl"

required_files=("${INPUT_DIR}/PROBE.pm")
if [[ "${SKIP_LVS}" != "1" || "${SKIP_PVSPEX}" != "1" ]]; then
  required_files+=("${INPUT_DIR}/lvs.pvl")
fi
if [[ "${SKIP_QTSPEX}" != "1" ]]; then
  required_files+=("${INPUT_DIR}/stdqrc")
fi

for required_file in "${required_files[@]}"; do
  if [[ ! -e "${required_file}" ]]; then
    echo "ERROR: Missing local dependency: ${required_file}" >&2
    echo "Populate MAKE/POST_CELL_GEN/inputs with your local tech/model files before running PostCellGen." >&2
    exit 1
  fi
done

prepare_args=(
  --input "${CDL_FILE}"
  --output "${RENAMED_CDL}"
  --target-cell "${CELL}"
)
if [[ -n "${SOURCE_CELL}" ]]; then
  prepare_args+=(--source-cell "${SOURCE_CELL}")
fi

"${PYTHON_BIN}" "${SCRIPT_DIR}/prepare_cell_cdl.py" "${prepare_args[@]}"

if [[ "${RUN_DRC}" == "1" && ! -e "${DONE_DIR}/${CELL}_${LIB_NAME}_drc.done" ]]; then
  (
    cd "${WORK_DIR}"
    "${PEGASUS_BIN}" -drc -gds "${GDS_FILE}" "${PVL_FILE}" |& tee "${LOG_DIR}/${CELL}_${LIB_NAME}.drc.log"
  )
  touch "${DONE_DIR}/${CELL}_${LIB_NAME}_drc.done"
fi

if [[ "${SKIP_LVS}" != "1" && ! -e "${DONE_DIR}/${CELL}_${LIB_NAME}_lvs.done" ]]; then
  (
    cd "${WORK_DIR}"
    "${PEGASUS_BIN}" \
      -lvs \
      -gds "${GDS_FILE}" \
      -source_cdl "${RENAMED_CDL}" \
      -spice "${CELL}_${LIB_NAME}.cdl" \
      -source_top_cell "${CELL}" \
      -layout_top_cell "${CELL}" \
      "${PVL_FILE}" |& tee "${LOG_DIR}/${CELL}_${LIB_NAME}.lvs.log"
  )
  touch "${DONE_DIR}/${CELL}_${LIB_NAME}_lvs.done"
fi

if [[ "${SKIP_PVSPEX}" != "1" && ! -e "${DONE_DIR}/${CELL}_${LIB_NAME}_pvspex.done" ]]; then
  (
    cd "${WORK_DIR}"
    "${PEGASUS_BIN}" \
      -ext \
      -gds "${GDS_FILE}" \
      -spice "${CELL}_${LIB_NAME}.cdl" \
      -rc_data \
      -top_cell "${CELL}" \
      "${PVL_FILE}" |& tee "${LOG_DIR}/${CELL}_${LIB_NAME}.pex.log"

    rm -rf "${PEX_DIR}/svdb"
    mv svdb "${PEX_DIR}/"
  )
  touch "${DONE_DIR}/${CELL}_${LIB_NAME}_pvspex.done"
fi

if [[ "${SKIP_QTSPEX}" != "1" && ! -e "${DONE_DIR}/${CELL}_${LIB_NAME}_qtspex.done" ]]; then
  echo "DEFINE ${LIB_NAME} ${INPUT_DIR}/stdqrc" > "${INPUT_DIR}/techlib.defs"
  (
    cd "${PEX_DIR}"
    rm -f "${CELL}_${LIB_NAME}.sp"
    QTS_DP_CPU="${QTS_DP_CPU:-1}" "${SCRIPT_DIR}/genQuantusCmd.tcl" "${LIB_NAME}" "${CELL}" "./svdb" "${TEMP}"
    "${QUANTUS_BIN}" \
      -multi_cpu "${QTS_MULTI_CPU:-1}" \
      -log_file "${LOG_DIR}/${CELL}_${LIB_NAME}.qtspex.log" \
      -cmd "run_quantus_${CELL}_${LIB_NAME}.cmd"
    test -f "${CELL}_${LIB_NAME}.sp"
    mv "${CELL}_${LIB_NAME}.sp" "${RESULT_DIR}/pex/"
  )
  touch "${DONE_DIR}/${CELL}_${LIB_NAME}_qtspex.done"
fi

if [[ "${SKIP_CHAR}" != "1" && ! -e "${DONE_DIR}/${CELL}_${LIB_NAME}_char.done" ]]; then
  TEMPLATE_FILE="${SCRIPT_DIR}/template_autocellgen.tcl"
  export INPUT_DIR SCRIPT_DIR RESULT_DIR TEMPLATE_FILE
  export AUTOCHAR_SMOKE="${SMOKE_CHAR}"

  if [[ "${CHAR_FROM}" == "schematic" ]]; then
    cp "${RENAMED_CDL}" "${RESULT_DIR}/pex/${CELL}_${LIB_NAME}.sp"
  elif [[ ! -f "${RESULT_DIR}/pex/${CELL}_${LIB_NAME}.sp" ]]; then
    echo "ERROR: Missing characterization netlist ${RESULT_DIR}/pex/${CELL}_${LIB_NAME}.sp" >&2
    exit 1
  fi

  "${PYTHON_BIN}" "${SCRIPT_DIR}/get_cell_info.py" \
    --gds "${GDS_FILE}" \
    --info_dir "${RESULT_DIR}/cell_info" \
    --layer "${GDS_LAYER}" \
    --texttype "${GDS_TEXTTYPE}"
  "${SCRIPT_DIR}/genLibTemplate.tcl" "${INPUT_DIR}" "${RESULT_DIR}" "${LIB_NAME}" "${CELL}"
  "${SCRIPT_DIR}/genCellList.tcl" "${RESULT_DIR}" "${SCRIPT_DIR}" "${LIB_NAME}" "${CELL}"
  (
    cd "${BASE_DIR}"
    "${LIBERATE_BIN}" --lorder TOKENS "${SCRIPT_DIR}/char.tcl" "${PROCESS}" "${VDD}" "${TEMP}" 6e-12 7e-11 1e-16 0.0003096
  ) 2>&1 | tee "${LOG_DIR}/${CELL}_${LIB_NAME}.char.log"
  touch "${DONE_DIR}/${CELL}_${LIB_NAME}_char.done"
fi

echo "Finished PostCellGen for ${CELL}"
