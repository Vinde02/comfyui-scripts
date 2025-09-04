#!/usr/bin/env bash
# setup_runpod_comfyui.sh — Installatore modelli ComfyUI per RunPod (no prompt)
# - Lavora esclusivamente in ./ComfyUI (relativo a dove lanci lo script)
# - Usa HF_TOKEN se presente (no prompt login)
# - Retry, resume download, validazione .safetensors, riepilogo finale

set -euo pipefail
RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'; NC='\033[0m'
log(){ echo -e "${GRN}[INFO]${NC} $*"; }
warn(){ echo -e "${YEL}[WARN]${NC} $*" >&2; }
err(){ echo -e "${RED}[ERROR]${NC} $*" >&2; }
trap 'err "Fallito alla linea $LINENO"; exit 1' ERR

# ===== Config =====
# Puoi forzare il path così: COMFY=/workspace/ComfyUI ./setup_runpod_comfyui.sh
# Se non è impostato, prova a rilevarlo automaticamente.
if [[ -n "${COMFY:-}" ]]; then
  COMFY="$(realpath -m "$COMFY")"
else
  # Ordine di ricerca tipico su RunPod + repo vicine
  for cand in \
    "/workspace/ComfyUI" \
    "$PWD/../ComfyUI" \
    "$HOME/ComfyUI" \
    "$PWD/ComfyUI"
  do
    [[ -d "$cand" ]] && COMFY="$(realpath -m "$cand")" && break
  done
fi

[[ -z "${COMFY:-}" || ! -d "$COMFY" ]] && err "Cartella ComfyUI non trovata. Imposta COMFY=/percorso/ComfyUI oppure crea la cartella." && exit 5
log "ComfyUI: $COMFY"

ASSUME_YES="${ASSUME_YES:-1}"
MIN_FREE_GB="${MIN_FREE_GB:-10}"

# ===== Cartelle modelli =====
mkdir -p "$COMFY/models/"{checkpoints,vae,diffusers,controlnet,ipadapter,loras,upscale_models}

# ===== Dipendenze (non-interattive) =====
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends git git-lfs aria2 curl wget ca-certificates python3-pip python3-venv
  git lfs install --skip-repo || true
fi
python3 -m pip install --upgrade --no-input --root-user-action=ignore pip
python3 -m pip install --no-input --root-user-action=ignore huggingface_hub safetensors

# ===== Hugging Face (opzionale, no prompt) =====
if [[ -n "${HF_TOKEN:-}" ]]; then
  log "Configuro Hugging Face in modalità non-interattiva"
  huggingface-cli login --token "$HF_TOKEN" --add-to-git-credential || warn "Login HF: se serve accettare una licenza, fallo dal sito."
fi

# ===== Utility =====
free_gb(){ df -P "$COMFY" | awk 'NR==2{gsub("G","",$4); print int($4/1)}'; }
if [[ "$(free_gb)" -lt "$MIN_FREE_GB" ]]; then
  warn "Spazio libero < ${MIN_FREE_GB}GB: i download pesanti potrebbero fallire."
fi

# downloader con retry + header HF se necessario; usa aria2c > curl > wget
fetch(){
  local url="$1" out="$2" tries=5
  if [[ -s "$out" ]]; then log "Già presente: $(basename "$out") — skip"; return 0; fi
  mkdir -p "$(dirname "$out")"

  # Preferisci aria2c (multi-connessioni) con resume implicito
  if command -v aria2c >/dev/null 2>&1; then
    if [[ "$url" == *"huggingface.co"* && -n "${HF_TOKEN:-}" ]]; then
      aria2c -c -x8 -s8 -k1M --retry-wait=3 --max-tries="$tries" \
        --header="Authorization: Bearer $HF_TOKEN" -o "$out" "$url"
    else
      aria2c -c -x8 -s8 -k1M --retry-wait=3 --max-tries="$tries" \
        -o "$out" "$url"
    fi
    return $?
  fi

  # Fallback: curl con resume (-C -)
  if command -v curl >/dev/null 2>&1; then
    if [[ "$url" == *"huggingface.co"* && -n "${HF_TOKEN:-}" ]]; then
      curl -L --fail -C - --retry "$tries" --retry-delay 2 \
        -H "Authorization: Bearer $HF_TOKEN" -o "$out" "$url"
    else
      curl -L --fail -C - --retry "$tries" --retry-delay 2 \
        -o "$out" "$url"
    fi
    return $?
  fi

  # Ultima spiaggia: wget
  if [[ "$url" == *"huggingface.co"* && -n "${HF_TOKEN:-}" ]]; then
    wget -c --tries="$tries" --timeout=30 \
      --header="Authorization: Bearer $HF_TOKEN" -O "$out" "$url"
  else
    wget -c --tries="$tries" --timeout=30 -O "$out" "$url"
  fi
}

# validazione veloce .safetensors
validate_st(){
  local f="$1"
  [[ -s "$f" ]] || return 1
  python3 - "$f" <<'PY' || return 1
import sys
from safetensors import safe_open
with safe_open(sys.argv[1],"pt") as s:
    list(s.keys())
PY
}

# ===== Elenco modelli (URL corretti) =====
# Nota: i link Civitai possono scadere; se falliscono, sostituiscili con mirror HF stabili.
declare -a DL_URLS=(
  # Juggernaut XL Inpainting (cambia se usi un mirror stabile)
  "https://civitai.com/api/download/models/129549|$COMFY/models/checkpoints/juggernaut_xl_inpainting.safetensors"

  # IP-Adapter SDXL image encoder (pubblico)
  "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors|$COMFY/models/ipadapter/ipadapter_sdxl_image_encoder.safetensors"

  # IP-Adapter Plus SD15 (pubblico)
  "https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.safetensors|$COMFY/models/ipadapter/ip-adapter-plus_sd15.safetensors"

  # ✅ SDXL VAE (URL corretto)
  "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors|$COMFY/models/vae/sdxl_vae.safetensors"

  # ✅ Upscaler 4x-UltraSharp (mirror stabile)
  "https://huggingface.co/lokCX/4x-Ultrasharp/resolve/main/4x-UltraSharp.pth|$COMFY/models/upscale_models/4x-UltraSharp.pth"
)

# ===== Download & validazione =====
OK_LIST=(); SKIP_LIST=(); FAIL_LIST=(); CORRUPT_LIST=()
for item in "${DL_URLS[@]}"; do
  url="${item%%|*}"; out="${item##*|}"
  name="$(basename "$out")"

  if [[ -s "$out" ]]; then
    log "Skip (presente): $name"; SKIP_LIST+=("$name"); continue
  fi

  log "Scarico: $name"
  if fetch "$url" "$out"; then
    if [[ "$out" == *.safetensors ]]; then
      if validate_st "$out"; then
        log "OK validato: $name"; OK_LIST+=("$name")
      else
        warn "File corrotto: $name — ritento una volta…"
        rm -f "$out"
        if fetch "$url" "$out" && validate_st "$out"; then
          log "OK dopo retry: $name"; OK_LIST+=("$name")
        else
          err "Integrità non valida: $name"; CORRUPT_LIST+=("$name")
        fi
      fi
    else
      log "OK scaricato: $name"; OK_LIST+=("$name")
    fi
  else
    err "Download fallito: $name"; FAIL_LIST+=("$name")
  fi
done

# ===== Riepilogo =====
echo -e "\n${GRN}==== RIEPILOGO ====${NC}"
echo "Installati: ${#OK_LIST[@]}"; ((${#OK_LIST[@]})) && printf ' - %s\n' "${OK_LIST[@]}"
echo "Presenti/Skippati: ${#SKIP_LIST[@]}"; ((${#SKIP_LIST[@]})) && printf ' - %s\n' "${SKIP_LIST[@]}"
echo -e "${YEL}Falliti:${NC} ${#FAIL_LIST[@]}"; ((${#FAIL_LIST[@]})) && printf ' - %s\n' "${FAIL_LIST[@]}"
echo -e "${RED}Corrotti:${NC} ${#CORRUPT_LIST[@]}"; ((${#CORRUPT_LIST[@]})) && printf ' - %s\n' "${CORRUPT_LIST[@]}"

# Codici uscita semantici
((${#CORRUPT_LIST[@]})) && exit 3
((${#FAIL_LIST[@]})) && exit 6
exit 0

