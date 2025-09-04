#!/usr/bin/env bash
set -euo pipefail
RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'; NC='\033[0m'
log(){ echo -e "${GRN}[INFO]${NC} $*"; }
warn(){ echo -e "${YEL}[WARN]${NC} $*" >&2; }
err(){ echo -e "${RED}[ERROR]${NC} $*" >&2; }
trap 'err "Fallito alla linea $LINENO"; exit 1' ERR

# ===== Config principali =====
# Lavoriamo ESCLUSIVAMENTE in ./ComfyUI (richiesta utente)
COMFY="$(realpath -m ./ComfyUI)"
[[ -d "$COMFY" ]] || { err "Cartella '$COMFY' non trovata. Crea/posiziona qui la tua ComfyUI e rilancia."; exit 5; }

ASSUME_YES="${ASSUME_YES:-1}"   # non chiediamo conferme
MIN_FREE_GB="${MIN_FREE_GB:-10}"

log "ComfyUI: $COMFY"

# ===== Cartelle modelli =====
install -d -m 775 "$COMFY/models/"{checkpoints,vae,diffusers,controlnet,ipadapter,loras,upscale_models}

# ===== Dipendenze (non-interattive) =====
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends git git-lfs aria2 curl wget ca-certificates python3-pip python3-venv
  git lfs install --skip-repo || true
fi
python3 -m pip install --upgrade --no-input pip
python3 -m pip install --no-input huggingface_hub safetensors

# ===== Login Hugging Face (opzionale, no prompt) =====
if [[ -n "${HF_TOKEN:-}" ]]; then
  log "Configuro Hugging Face in modalità non-interattiva"
  huggingface-cli login --token "$HF_TOKEN" --add-to-git-credential || warn "Login HF: se serve accettare una licenza, fallo dal sito."
fi

# ===== Utility =====
free_gb(){ df -P "$COMFY" | awk 'NR==2{gsub("G","",$4); print int($4/1)}'; }
if [[ "$(free_gb)" -lt "$MIN_FREE_GB" ]]; then
  warn "Spazio libero < ${MIN_FREE_GB}GB: i download pesanti potrebbero fallire."
fi

fetch(){ # fetch URL OUTFILE (retry + header HF se necessario)
  local url="$1" out="$2" tries=5
  if [[ -s "$out" ]]; then log "Già presente: $(basename "$out") — skip"; return 0; fi
  mkdir -p "$(dirname "$out")"
  if command -v aria2c >/dev/null 2>&1; then
    if [[ "$url" == *"huggingface.co"* && -n "${HF_TOKEN:-}" ]]; then
      aria2c -x8 -s8 -k1M --retry-wait=3 --max-tries="$tries" --header="Authorization: Bearer $HF_TOKEN" -o "$out" "$url"
    else
      aria2c -x8 -s8 -k1M --retry-wait=3 --max-tries="$tries" -o "$out" "$url"
    fi
  elif command -v curl >/dev/null 2>&1; then
    if [[ "$url" == *"huggingface.co"* && -n "${HF_TOKEN:-}" ]]; then
      curl -L --fail --retry "$tries" --retry-delay 2 -H "Authorization: Bearer $HF_TOKEN" -o "$out" "$url"
    else
      curl -L --fail --retry "$tries" --retry-delay 2 -o "$out" "$url"
    fi
  else
    if [[ "$url" == *"huggingface.co"* && -n "${HF_TOKEN:-}" ]]; then
      wget --tries="$tries" --header="Authorization: Bearer $HF_TOKEN" -O "$out" "$url"
    else
      wget --tries="$tries" -O "$out" "$url"
    fi
  fi
}

validate_st(){ # valida safetensors veloce
  local f="$1"
  python3 - "$f" <<'PY' || return 1
import sys
from safetensors import safe_open
with safe_open(sys.argv[1],"pt") as s:
    list(s.keys())
PY
}

# ===== Elenco modelli da installare (puoi aggiungere/rimuovere) =====
# Nota: i link Civitai firmati scadono. Preferisci mirror HF stabili quando possibile.
declare -a DL_URLS=(
  # Juggernaut XL Inpainting (sostituisci con mirror stabile se il link scade)
  "https://civitai.com/api/download/models/129549|$COMFY/models/checkpoints/juggernaut_xl_inpainting.safetensors"
  # IP-Adapter SDXL image encoder (pubblico)
  "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors|$COMFY/models/ipadapter/ipadapter_sdxl_image_encoder.safetensors"
  # IP-Adapter Plus SD15 (pubblico)
  "https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.safetensors|$COMFY/models/ipadapter/ip-adapter-plus_sd15.safetensors"
  # SDXL VAE (StabilityAI)
  "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/vae.safetensors|$COMFY/models/vae/sdxl_vae.safetensors"
  # Upscaler 4x-UltraSharp (E/ESRGAN)
  "https://huggingface.co/crosstyan/4x-UltraSharp/resolve/main/4x-UltraSharp.pth|$COMFY/models/upscale_models/4x-UltraSharp.pth"
)

# ===== Download + validazione =====
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
((${#CORRUPT_LIST[@]})) && exit 3
((${#FAIL_LIST[@]})) && exit 6
exit 0
