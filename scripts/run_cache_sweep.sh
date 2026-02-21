#!/usr/bin/env bash
set -Eeuo pipefail
NVSim_BIN="/home/skataoka26/COSC_498/MemSysExplorer/tech/ArrayCharacterization/nvsim"
OUT_ROOT="/home/skataoka26/COSC_498/devices/results/cache_sweep"

CFG_ROOT="/home/skataoka26/COSC_498/devices/config"
SRAM_DIR="${CFG_ROOT}/SRAM_configs"
MRAM_DIR="${CFG_ROOT}/MRAM_configs"

ASSOC="${ASSOC:-16}"
WORD_WIDTH="${WORD_WIDTH:-512}"
TEMP_K_OVERRIDE="${TEMP_K_OVERRIDE:-}"
JOBS="${JOBS:-4}"

OPT_TARGETS="${OPT_TARGETS:-ReadLatency ReadEDP WriteLatency WriteEDP}"
RUN_TAG="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_ROOT}/${RUN_TAG}"
TMP_DIR="${OUT_DIR}/_tmp"
mkdir -p "${TMP_DIR}"

[[ -x "${NVSim_BIN}" ]] || { echo "NVSim not executable at ${NVSim_BIN}" >&2; exit 1; }

supports_input_flag() { "${NVSim_BIN}" -h 2>&1 | grep -q -- '-input'; }

normalize_cfg() { # in_cfg out_cfg out_prefix opt_target
  local in="$1" out="$2" prefix="$3" opt_target="$4" cfg_dir cell_rel cell_abs
  cfg_dir="$(dirname "$in")"
  cell_rel="$(awk -F': ' '/^-MemoryCellInputFile:/ {print $2; exit}' "$in" || true)"
  if [[ -n "$cell_rel" ]]; then
    if [[ "$cell_rel" = /* ]]; then
      cell_abs="$cell_rel"
    else
      cell_abs="${cfg_dir}/${cell_rel}"
    fi
  fi

  cp "$in" "$out"

  # patch prefix, associativity, word width, optimization target
  sed -E -i \
    -e "s|^(-OutputFilePrefix:).*|\1 ${prefix}|" \
    -e "s|^(-Associativity \(for cache only\):).*|\1 ${ASSOC}|" \
    -e "s|^(-WordWidth \(bit\):).*|\1 ${WORD_WIDTH}|" \
    -e "s|^(-OptimizationTarget:).*|\1 ${opt_target}|" \
    "$out" || true

  # ensure these keys exist if missing
  grep -q '^-Associativity \(for cache only\):' "$out" || \
    printf -- "-Associativity (for cache only): %s\n" "$ASSOC" >> "$out"
  grep -q '^-WordWidth \(bit\):' "$out" || \
    printf -- "-WordWidth (bit): %s\n" "$WORD_WIDTH" >> "$out"
  grep -q '^-OptimizationTarget:' "$out" || \
    printf -- "-OptimizationTarget: %s\n" "$opt_target" >> "$out"

  # optional temperature override
  if [[ -n "$TEMP_K_OVERRIDE" ]]; then
    if grep -q '^-Temperature \(K\):' "$out"; then
      sed -E -i "s|^(-Temperature \(K\):).*|\1 ${TEMP_K_OVERRIDE}|" "$out"
    else
      printf -- "-Temperature (K): %s\n" "$TEMP_K_OVERRIDE" >> "$out"
    fi
  fi

  # absolutize MemoryCellInputFile
  if [[ -n "$cell_abs" ]]; then
    sed -E -i "s|^(-MemoryCellInputFile:).*|\1 ${cell_abs}|" "$out"
  fi
}

run_cfg() { # cfg path, runs all OPT_TARGETS sequentially
  local cfg="$1" base tech rest node size tech_dir prefix out_cfg opt

  base="$(basename "$cfg")"
  tech="${base%%_*}"                 # SRAM / MRAM
  rest="${base#${tech}_}"            # e.g., 32nm_8MB.cfg
  node="${rest%%_*}"                 # 32nm
  size="${rest%.cfg}"; size="${size##*_}"  # 8MB

  for opt in ${OPT_TARGETS}; do
    tech_dir="${OUT_DIR}/${tech}/${node}/${size}/${opt}"
    mkdir -p "${tech_dir}"

    prefix="${tech_dir}/${tech}_${node}_${size}_${opt}"
    out_cfg="${TMP_DIR}/${tech}_${node}_${size}_${opt}.cfg"

    normalize_cfg "$cfg" "$out_cfg" "$prefix" "$opt"

    echo "[NVSim] $(date -u +%F_%T) tech=${tech} node=${node} size=${size} opt=${opt} -> ${tech_dir}"
    if supports_input_flag; then
      "${NVSim_BIN}" -input "$out_cfg" | tee "${prefix}.stdout.txt"
    else
      "${NVSim_BIN}" "$out_cfg" | tee "${prefix}.stdout.txt"
    fi

    cp -f "$out_cfg" "${prefix}.cfg"
  done
}

# collect cfgs
mapfile -t CFGS < <(ls "${SRAM_DIR}"/SRAM_*nm_*MB.cfg "${MRAM_DIR}"/MRAM_*nm_*MB.cfg 2>/dev/null | sort)

# launch in parallel with a simple concurrency gate
pids=()
for cfg in "${CFGS[@]}"; do
  run_cfg "$cfg" &
  pids+=($!)
  # throttle
  while (( $(jobs -pr | wc -l) >= JOBS )); do sleep 0.2; done
done

# join & fail if any failed
fail=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    echo "A job failed (pid=$pid)" >&2
    fail=1
  fi
done

echo "Done. Results in ${OUT_DIR}"
exit $fail

