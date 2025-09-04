#!/usr/bin/env bash
set -euo pipefail

# ========= Trap & logging =========
err(){ printf "\e[31m[ERR]\e[0m %s\n" "$*" >&2; }
warn(){ printf "\e[33m[WARN]\e[0m %s\n" "$*"; }
log(){ printf "\e[36m[INFO]\e[0m %s\n" "$*"; }
trap 'err "Linea $LINENO fallita (exit $?)"' ERR

# ========= Defaults sicuri (DEVONO stare prima di qualunque uso) =========
: "${ASSUME_YES:=1}"        # 1 = non chiedere conferme
: "${MIN_FREE_GB:=10}"      # soglia avviso spazio libero (GB)
: "${MAX_RETRIES:=5}"       # retry per download
: "${DL_TIMEOUT:=0}"        # 0 = senza timeout; altrimenti secondi
: "${FORCE_REDOWNLOAD:=0}"  # 1 = forza riscarico anche se esiste

# ========= Config percorso ComfyUI (normalizzazione senza doppio /workspace) =========
COMFY="${COMFY:-/workspace/ComfyUI}"
COMFY="$(realpath -m "$COMFY")"
[[ -d "$COMFY" ]] || { err "Cartella ComfyUI non trovata: $COMFY"; exit 5; }
log "ComfyUI: $COMFY"

# ========= Funzioni utili =========
free_gb(){ df -Pk "$COMFY" | awk 'NR==2{print int($4/1024/1024)}'; }
ensure_dir(){ mkdir -p "$1"; }
ask(){
  local q="$1"
  if (( ASSUME_YES )); then return 0; fi
  read -rp "$q [y/N] " a; [[ "${a,,}" == y ]]
}

# Download atomico con curl, retry e resume
download(){
  # usage: download URL DEST
  local url="$1" dest="$2" tmp="${dest}.part"
  if [[ -f "$dest" && $FORCE_REDOWNLOAD -eq 0 ]]; then
    log "Già presente: $(basename "$dest") (skip)"
    return 0
  fi
  ensure_dir "$(dirname "$dest")"
  log "Scarico $(basename "$dest")"
  local tries=0
  while (( tries < MAX_RETRIES )); do
    ((tries++))
    if curl -fL --retry "$MAX_RETRIES" --retry-delay 2 --continue-at - \
        ${DL_TIMEOUT:+--max-time "$DL_TIMEOUT"} \
        -o "$tmp" "$url"; then
      # file minimale > 1MB per evitare truncate banali
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
  err "Impossibile scaricare $(basename "$dest")"
  return 1
}

# (Opzionale) controllo molto semplice sulle .safetensors: verifica estensione e dimensione > 10MB
validate_safetensor(){
  # usage: validate_safetensor FILE
  local f="$1"
  if [[ ! -f "$f" ]]; then err "Manca file: $f"; return 1; fi
  local size; size=$(stat -c%s "$f" 2>/dev/null || echo 0)
  if (( size < 10*1024*1024 )); then
    err "Probabile download corrotto (dimensione < 10MB): $f"
    return 1
  fi
  return 0
}

# ========= Check spazio libero (dopo defaults!) =========
if (( $(free_gb) < MIN_FREE_GB )); then
  warn "Spazio libero < ${MIN_FREE_GB}GB: i download pesanti potrebbero fallire."
  ask "Continuare comunque?" || { warn "Interrotto dall'utente."; exit 0; }
fi

# ========= Struttura cartelle modelli =========
CKPT="$COMFY/models/checkpoints"
VAE="$COMFY/models/vae"
LORAS="$COMFY/models/loras"
CN="$COMFY/models/controlnet"
IPA="$COMFY/models/ipadapter"
UPS="$COMFY/models/upscale_models"

for d in "$CKPT" "$VAE" "$LORAS" "$CN" "$IPA" "$UPS"; do ensure_dir "$d"; done
log "Cartelle modelli pronte."

# ========= Esempi di download (modifica o commenta secondo bisogno) =========

# 1) Juggernaut XL Inpainting (esempio Civitai – URL variabile; se ne hai uno stabile, sostituiscilo)
JXL_INP_URL="${JXL_INP_URL:-https://civitai.com/api/download/models/129549}"
JXL_INP_DST="$CKPT/juggernaut_aftermath-inpainting.safetensors"
download "$JXL_INP_URL" "$JXL_INP_DST" || true
validate_safetensor "$JXL_INP_DST" || { warn "JXL Inpainting potrebbe essere corrotto: valutare il ri-download."; }

# 2) (Opzionale) IP-Adapter SDXL encoder (se ti serve; sostituisci se usi mirror):
# IPA_URL="${IPA_URL:-https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors}"
# download "$IPA_URL" "$IPA/sdxl_image_encoder.safetensors"

# 3) (Opzionale) Modello di upscale 4x (ad esempio Real-ESRGAN 4x)
# UPS_URL="${UPS_URL:-https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4plus.pth}"
# download "$UPS_URL" "$UPS/RealESRGAN_x4plus.pth"

log "Setup completato."
