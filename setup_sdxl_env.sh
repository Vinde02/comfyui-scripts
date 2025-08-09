#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
#  SDXL POWER TOOLKIT – ComfyUI setup (CivitAI + HF)
#  Juggernaut XL v9 (CivitAI) + VAE direct + ControlNet XL + IP-Adapter SDXL + encoder + (Refiner via HF)
# ==========================================================

# ---------- CONFIG ----------
COMFY="${COMFY:-$HOME/ComfyUI}"
MODELS="${COMFY}/models"

CKPT_DIR="${MODELS}/checkpoints"
VAE_DIR="${MODELS}/vae"
DIFFUSERS_DIR="${MODELS}/diffusers"
CTRL_DIR="${MODELS}/controlnet"
IPADAPTER_DIR="${MODELS}/ipadapter"
UPSCALE_DIR="${MODELS}/upscale_models"

# CivitAI URL fornito da te (Juggernaut XL v9)
CIVITAI_URL_JUGG="${CIVITAI_URL_JUGG:-https://civitai.com/api/download/models/357609}"
# opzionale: token CivitAI (se il file richiede auth o per velocità)
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"

# Hugging Face repos (non-gated, tranne Refiner)
REFINER_REPO="stabilityai/stable-diffusion-xl-refiner-1.0"   # GATED
IPADAPTER_REPO="h94/IP-Adapter"                               # Apache-2.0 (libero)
CLIP_BIGG_REPO="laion/CLIP-ViT-bigG-14-laion2B-39B-b160k"     # MIT (libero)
CTRL_CANNY="diffusers/controlnet-canny-sdxl-1.0"
CTRL_DEPTH="diffusers/controlnet-depth-sdxl-1.0"
CTRL_TILE_ALT="xinsir/controlnet-tile-sdxl-1.0"               # community affidabile

# ---------- UTILS ----------
sudo_if_available() {
  if command -v sudo >/dev/null 2>&1; then sudo "$@"; else "$@"; fi
}
msg(){ echo -e "\n==> $*\n"; }

civitai_dl () {
  local url="$1"; local out="$2"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x16 -s16 -c -o "$(basename "$out")" -d "$(dirname "$out")" \
      ${CIVITAI_TOKEN:+--header="Authorization: Bearer ${CIVITAI_TOKEN}"} \
      "$url"
  else
    # curl con ripresa (-C -)
    curl -L -C - \
      ${CIVITAI_TOKEN:+-H "Authorization: Bearer ${CIVITAI_TOKEN}"} \
      -o "$out" "$url"
  fi
}

download_hf_repo() {
  local repo_id="$1"; local target_dir="$2"
  msg "Download da Hugging Face: ${repo_id} -> ${target_dir}"
  huggingface-cli download "${repo_id}" \
    --local-dir "${target_dir}" --local-dir-use-symlinks False
}

# ---------- PRE-REQ ----------
msg "Preparazione cartelle in ${MODELS} ..."
mkdir -p "${CKPT_DIR}" "${VAE_DIR}" "${DIFFUSERS_DIR}" "${CTRL_DIR}" "${IPADAPTER_DIR}" "${UPSCALE_DIR}"

msg "Aggiorno pacchetti base (se possibile)..."
sudo_if_available apt-get update -y || true
sudo_if_available apt-get install -y git git-lfs python3-pip curl aria2 || true
git lfs install --skip-repo || true

msg "Aggiorno pip + libs..."
python3 -m pip install --upgrade pip
pip3 install --upgrade "huggingface_hub==0.23.*" safetensors || true

# hf_transfer fix automatico
if [ "${HF_HUB_ENABLE_HF_TRANSFER:-}" = "1" ]; then
  python3 - <<'PY' 2>/dev/null || { echo "==> Installo hf_transfer..."; pip install --no-cache-dir hf_transfer || export HF_HUB_ENABLE_HF_TRANSFER=0; }
try:
    import hf_transfer  # noqa
except Exception:
    raise SystemExit(1)
PY
fi

# ---------- DOWNLOADS ----------
# 1) Juggernaut XL v9 da CivitAI
msg "Scarico Juggernaut XL v9 da CivitAI..."
mkdir -p "${CKPT_DIR}/JuggernautXL"
civitai_dl "${CIVITAI_URL_JUGG}" "${CKPT_DIR}/JuggernautXL/JuggernautXL_v9.safetensors" \
  || msg "ATTENZIONE: download CivitAI fallito. Fornisci un nuovo URL o imposta CIVITAI_URL_JUGG."

# 2) VAE SDXL (direct link, no gate)
msg "Scarico VAE SDXL (direct link)..."
mkdir -p "${VAE_DIR}/sdxl-vae-fp16-fix"
wget -q --show-progress -O "${VAE_DIR}/sdxl-vae-fp16-fix/sdxl.vae.safetensors" \
  "https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl.vae.safetensors?download=true" \
  || msg "ATTENZIONE: VAE non scaricato. Usa quello del checkpoint se necessario."

# 3) ControlNet SDXL (Canny/Depth/Tile)
msg "Scarico ControlNet SDXL (Canny, Depth, Tile)..."
download_hf_repo "${CTRL_CANNY}" "${CTRL_DIR}/sdxl-canny" || msg "Canny XL non scaricato"
download_hf_repo "${CTRL_DEPTH}" "${CTRL_DIR}/sdxl-depth" || msg "Depth XL non scaricato"
download_hf_repo "${CTRL_TILE_ALT}" "${CTRL_DIR}/sdxl-tile" || msg "Tile XL non scaricato"

# 4) IP-Adapter SDXL + encoder CLIP
msg "Scarico IP-Adapter SDXL (weights)..."
mkdir -p "${IPADAPTER_DIR}/IP-Adapter/sdxl_models"
huggingface-cli download "${IPADAPTER_REPO}" "sdxl_models/ip-adapter-plus_sdxl_vit-h.bin" \
  --local-dir "${IPADAPTER_DIR}/IP-Adapter" --local-dir-use-symlinks False \
  || msg "ATTENZIONE: ip-adapter-plus_sdxl_vit-h.bin non scaricato"

msg "Scarico encoder CLIP (ViT-bigG-14) per SDXL..."
mkdir -p "${IPADAPTER_DIR}/IP-Adapter/sdxl_models/image_encoder"
download_hf_repo "${CLIP_BIGG_REPO}" "${IPADAPTER_DIR}/IP-Adapter/sdxl_models/image_encoder" \
  || msg "ATTENZIONE: encoder CLIP bigG non scaricato (puoi usare ViT-H o specificare path manualmente)."

# 5) Refiner SDXL (HF, GATED) – opzionale ma consigliatissimo
msg "Refiner SDXL è GATED. Accetta la licenza su HF e usa un token."
if [ -n "${HF_TOKEN:-}" ]; then
  huggingface-cli login --token "$HF_TOKEN" --add-to-git-credential || true
  download_hf_repo "${REFINER_REPO}" "${DIFFUSERS_DIR}/sdxl-refiner-1.0" \
    || msg "Refiner non scaricato (controlla licenza/token)."
else
  msg "Salto il download del Refiner (manca HF_TOKEN). Puoi installarlo dopo."
fi

# ---------- RIEPILOGO ----------
msg "RIEPILOGO PERCORSI:"
cat <<EOF
Checkpoints:
  ${CKPT_DIR}/JuggernautXL/JuggernautXL_v9.safetensors

VAE:
  ${VAE_DIR}/sdxl-vae-fp16-fix/sdxl.vae.safetensors

ControlNet (XL):
  ${CTRL_DIR}/sdxl-canny
  ${CTRL_DIR}/sdxl-depth
  ${CTRL_DIR}/sdxl-tile

IP-Adapter:
  ${IPADAPTER_DIR}/IP-Adapter/sdxl_models/ip-adapter-plus_sdxl_vit-h.bin
  ${IPADAPTER_DIR}/IP-Adapter/sdxl_models/image_encoder  (CLIP ViT-bigG)

Refiner (se installato):
  ${DIFFUSERS_DIR}/sdxl-refiner-1.0
EOF

# ---------- NOTE USO ----------
cat <<'USAGE'

==> USO RAPIDO IN COMFYUI
PASS 1 – JuggernautXL (checkpoint) + VAE sdxl
  • Sampler: DPM++ 2M Karras, Steps 30–40, CFG 7–8
  • ControlNet XL: Depth (0.8–1.0), Canny (0.6–0.8)
PASS 2 – Refiner SDXL (img2img, denoise 0.20–0.35)  [opzionale]
PASS 3 – Tile (ControlNet Tile XL, denoise ~0.2) → 2×/4×
  • ESRGAN (UltraSharp/Remacri) opzionale per nitidezza extra

TIPS:
  • Se il download CivitAI si interrompe, rilancia: aria2c/curl riprenderanno (-c / -C -).
  • Per Refiner: accetta licenza su HF e export HF_TOKEN prima di rilanciare lo script.

USAGE

msg "Setup completato."

