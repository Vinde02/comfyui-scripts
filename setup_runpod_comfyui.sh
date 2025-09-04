#!/usr/bin/env bash
set -euo pipefail

# ========== Logging ==========
err(){ printf "\e[31m[ERR]\e[0m %s\n" "$*" >&2; }
warn(){ printf "\e[33m[WARN]\e[0m %s\n" "$*"; }
log(){ printf "\e[36m[INFO]\e[0m %s\n" "$*"; }
trap 'err "Linea $LINENO (exit $?)"' ERR

# ========== Defaults ==========
: "${ASSUME_YES:=1}"
: "${MIN_FREE_GB:=10}"
: "${MAX_RETRIES:=5}"
: "${DL_TIMEOUT:=0}"
: "${FORCE_REDOWNLOAD:=1}"

# Abilita/Disabilita “pacchetti”
: "${ENABLE_JXL_INP:=1}"
: "${ENABLE_IP_ADAPTER:=1}"
: "${ENABLE_UPSCALERS:=1}"
: "${ENABLE_CONTROLNET:=0}"   # metti a 1 quando aggiungi URL reali sotto
: "${ENABLE_VAE:=0}"          # idem

# ========== Percorsi ==========
COMFY="${COMFY:-/workspace/ComfyUI}"
COMFY="$(realpath -m "$COMFY")"
[[ -d "$COMFY" ]] || { err "Cartella ComfyUI non trovata: $COMFY"; exit 5; }
log "ComfyUI: $COMFY"

CKPT="$COMFY/models/checkpoints"
VAE="$COMFY/models/vae"
LORAS="$COMFY/models/loras"
CN="$COMFY/models/controlnet"
IPA="$COMFY/models/ipadapter"
UPS="$COMFY/models/upscale_models"
mkdir -p "$CKPT" "$VAE" "$LORAS" "$CN" "$IPA" "$UPS"

# ========== Utility ==========
free_gb(){ df -PBG "$COMFY" | awk 'NR==2{print $4+0}'; }
ask(){ (( ASSUME_YES )) && return 0; read -rp "$1 [y/N] " a; [[ "${a,,}" == y ]]; }
download(){ # download URL DEST
  local url="${1:-}"; local dest="${2:-}"
  [[ -n "$url" && -n "$dest" ]] || { err "download(): url/dest mancanti"; return 2; }
  local tmp="${dest}.part"; mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" && $FORCE_REDOWNLOAD -eq 0 ]]; then
    log "Già presente: $(basename "$dest") (skip)"
    return 0
  fi
  local tries=0
  while (( tries < MAX_RETRIES )); do
    ((tries++))
    if curl -fL --retry "$MAX_RETRIES" --retry-delay 2 --continue-at - \
         ${DL_TIMEOUT:+--max-time "$DL_TIMEOUT"} -o "$tmp" "$url"; then
      if [[ "$(stat -c%s "$tmp" 2>/dev/null || echo 0)" -gt $((1*1024*1024)) ]]; then
        mv -f "$tmp" "$dest"; log "OK: $(basename "$dest")"; return 0
      else
        warn "File troppo piccolo, ritento ($tries/$MAX_RETRIES)…"
      fi
    else
      warn "Tentativo $tries fallito, ritento…"
    fi
    sleep 1
  done
  err "Impossibile scaricare: $url"; return 1
}
validate_safetensor(){ local f="${1:-}"; [[ -f "$f" ]] || { err "Manca $f"; return 1; }; (( $(stat -c%s "$f") > 10*1024*1024 )) || { err "File sospetto (<10MB): $f"; return 1; }; }

# ========== Check spazio ==========
if (( $(free_gb) < MIN_FREE_GB )); then
  warn "Spazio libero < ${MIN_FREE_GB}GB: i download pesanti potrebbero fallire."
  ask "Continuare?" || { warn "Interrotto."; exit 0; }
fi

# ========== Dipendenze minime ==========
python3 -m pip install -q --upgrade pip
python3 -m pip install -q --no-cache-dir safetensors huggingface_hub

log "Cartelle modelli pronte."

# ------------------------------------------------------------------------------
# MANIFEST: aggiungi qui tutti i modelli che vuoi scaricare.
# Formato: add_item "URL" "/destinazione/assoluta/del/file"
# ------------------------------------------------------------------------------

items=()

add_item(){ items+=("$1|$2"); }

# --- 1) Juggernaut XL Inpainting (checkpoint) ---
if (( ENABLE_JXL_INP )); then
  # Nota: i link Civitai sono spesso temporanei. Puoi passare una URL via env:
  # JXL_INP_URL="https://..." ./setup_runpod_comfyui.sh
  JXL_INP_URL="${JXL_INP_URL:-https://civitai.com/api/download/models/129549}"
  add_item "$JXL_INP_URL" "$CKPT/juggernaut_aftermath-inpainting.safetensors"
fi

# --- 2) IP-Adapter (encoder + modello SD15 plus) ---
if (( ENABLE_IP_ADAPTER )); then
  # Questi sono link Hugging Face (stabili al momento):
  add_item "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" \
           "$IPA/sd15_image_encoder.safetensors"
  add_item "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors" \
           "$IPA/sdxl_image_encoder.safetensors"
  add_item "https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.safetensors" \
           "$IPA/ip-adapter-plus_sd15.safetensors"
fi

# --- 3) Upscalers (Real-ESRGAN esempi) ---
if (( ENABLE_UPSCALERS )); then
  # Se vuoi cambiare, passa UPS_URL_* via env.
  add_item "${UPS_URL_X4PLUS:-https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4plus.pth}" \
           "$UPS/RealESRGAN_x4plus.pth"
  add_item "${UPS_URL_X4_ANIME:-https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4plus_anime_6B.pth}" \
           "$UPS/RealESRGAN_x4plus_anime_6B.pth"
fi

# --- 4) ControlNet SDXL (placeholder: aggiungi i tuoi URL reali) ---
if (( ENABLE_CONTROLNET )); then
  # Esempi (SOSTITUISCI con URL reali dei tuoi modelli .safetensors o .pth):
  # add_item "https://tuo-host/controlnet/sdxl-canny.safetensors" "$CN/sdxl_canny.safetensors"
  # add_item "https://tuo-host/controlnet/sdxl-depth.safetensors" "$CN/sdxl_depth.safetensors"
  :
fi

# --- 5) VAE (placeholder) ---
if (( ENABLE_VAE )); then
  # Esempio (SOSTITUISCI con il tuo VAE preferito):
  # add_item "https://tuo-host/vae/sdxl_fp16_fix.safetensors" "$VAE/sdxl_fp16_fix.safetensors"
  :
fi

# ------------------------------------------------------------------------------
# ESECUZIONE MANIFEST
# ------------------------------------------------------------------------------
if ((${#items[@]}==0)); then
  warn "Manifest vuoto: nessun modello da scaricare (controlla le opzioni ENABLE_*)."
else
  log "Scarico ${#items[@]} elemento/i dal manifest…"
fi

for entry in "${items[@]}"; do
  url="${entry%%|*}"
  dest="${entry##*|}"
  download "$url" "$dest" || true
  [[ "$dest" == *.safetensors ]] && validate_safetensor "$dest" || true
done

log "Setup RunPod/ComfyUI COMPLETATO."
