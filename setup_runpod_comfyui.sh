#!/usr/bin/env bash
set -euo pipefail

# ========== Logging ==========
err(){ printf "\e[31m[ERR]\e[0m %s\n" "$*" >&2; }
warn(){ printf "\e[33m[WARN]\e[0m %s\n" "$*"; }
log(){ printf "\e[36m[INFO]\e[0m %s\n" "$*"; }
trap 'err "Linea $LINENO fallita (exit $?)"' ERR

# ========== Defaults sicuri ==========
: "${ASSUME_YES:=1}"        # 1 = non chiedere conferme
: "${MIN_FREE_GB:=10}"      # soglia di spazio libero in GB per avviso
: "${MAX_RETRIES:=5}"       # tentativi per download
: "${DL_TIMEOUT:=0}"        # 0 = nessun timeout curl; altrimenti secondi
: "${FORCE_REDOWNLOAD:=0}"  # 1 = forza riscarico anche se file presente

# ========== Percorso ComfyUI (normalizzato, niente doppio /workspace) ==========
COMFY="${COMFY:-/workspace/ComfyUI}"
COMFY="$(realpath -m "$COMFY")"
[[ -d "$COMFY" ]] || { err "Cartella ComfyUI non trovata: $COMFY"; exit 5; }
log "ComfyUI: $COMFY"

# ========== Utility ==========
# Spazio libero in GB interi (evita float/scientific notation)
free_gb(){ df -PBG "$COMFY" | awk 'NR==2{print $4+0}'; }
ensure_dir(){ mkdir -p "$1"; }
ask(){ (( ASSUME_YES )) && return 0; read -rp "$1 [y/N] " a; [[ "${a,,}" == y ]]; }

# Download robusto con resume, retry e file temporaneo .part
download(){ # usage: download URL DEST
  local url="${1:-}"; local dest="${2:-}"
  [[ -n "$url" && -n "$dest" ]] || { err "download(): url/dest mancanti"; return 2; }
  local tmp="${dest}.part"
  ensure_dir "$(dirname "$dest")"
  if [[ -f "$dest" && $FORCE_REDOWNLOAD -eq 0 ]]; then
    log "Già presente: $(basename "$dest") (skip)"
    return 0
  fi
  local tries=0
  while (( tries < MAX_RETRIES )); do
    ((tries++))
    if curl -fL --retry "$MAX_RETRIES" --retry-delay 2 --continue-at - \
         ${DL_TIMEOUT:+--max-time "$DL_TIMEOUT"} -o "$tmp" "$url"; then
      # controllo dimensione minima > 1MB per evitare file troncati
      if [[ "$(stat -c%s "$tmp" 2>/dev/null || echo 0)" -gt $((1*1024*1024)) ]]; then
        mv -f "$tmp" "$dest"
        log "OK: $(basename "$dest")"
        return 0
      else
        warn "File troppo piccolo, ritento ($tries/$MAX_RETRIES)…"
      fi
    else
      warn "Tentativo $tries fallito, ritento…"
    fi
    sleep 1
  done
  err "Impossibile scaricare: $url"
  return 1
}

validate_safetensor(){ # controllo base anti-file troncati
  local f="${1:-}"
  [[ -f "$f" ]] || { err "Manca file: $f"; return 1; }
  (( $(stat -c%s "$f") > 10*1024*1024 )) || { err "Probabile file corrotto (<10MB): $f"; return 1; }
}

# ========== Check spazio ==========
if (( $(free_gb) < MIN_FREE_GB )); then
  warn "Spazio libero < ${MIN_FREE_GB}GB: i download pesanti potrebbero fallire."
  ask "Continuare?" || { warn "Interrotto."; exit 0; }
fi

# ========== Install dipendenze minime Python (idempotente) ==========
log "Installo/aggiorno pacchetti Python necessari…"
python3 -m pip install -q --upgrade pip
python3 -m pip install -q --no-cache-dir safetensors huggingface_hub

# ========== Struttura cartelle ComfyUI ==========
CKPT="$COMFY/models/checkpoints"
VAE="$COMFY/models/vae"
LORAS="$COMFY/models/loras"
CN="$COMFY/models/controlnet"
IPA="$COMFY/models/ipadapter"
UPS="$COMFY/models/upscale_models"
ensure_dir "$CKPT"; ensure_dir "$VAE"; ensure_dir "$LORAS"; ensure_dir "$CN"; ensure_dir "$IPA"; ensure_dir "$UPS"
log "Cartelle modelli pronte."

# ========== (OPZ) Download modelli ==========
# Puoi personalizzare via env VARS prima di lanciare lo script.
# Esempi (lasciati disattivati se non ti servono):

# Juggernaut XL Inpainting (Civitai; la URL può cambiare)
JXL_INP_URL="${JXL_INP_URL:-https://civitai.com/api/download/models/129549}"
JXL_INP_DST="$CKPT/juggernaut_aftermath-inpainting.safetensors"
if [[ -n "${JXL_INP_URL:-}" ]]; then
  log "Download Juggernaut XL Inpainting…"
  download "$JXL_INP_URL" "$JXL_INP_DST" || true
  validate_safetensor "$JXL_INP_DST" || warn "Verifica JXL Inpainting fallita — valuta ri-download."
fi

# IP-Adapter SDXL encoder (se necessario)
# IPA_URL="${IPA_URL:-https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors}"
# [[ -n "${IPA_URL:-}" ]] && download "$IPA_URL" "$IPA/sdxl_image_encoder.safetensors"

# Upscaler (esempio Real-ESRGAN x4)
# UPS_URL="${UPS_URL:-https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4plus.pth}"
# [[ -n "${UPS_URL:-}" ]] && download "$UPS_URL" "$UPS/RealESRGAN_x4plus.pth"

log "Setup RunPod/ComfyUI completato."
