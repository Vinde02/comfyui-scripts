#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
#  SDXL POWER TOOLKIT – Setup modelli e asset per ComfyUI
#  JuggernautXL + SDXL Refiner + VAE + ControlNet XL + IP-Adapter XL + (ESRGAN opzionale)
#  Funziona con huggingface-cli; supporta HF_TOKEN per login automatico.
# ==========================================================

# --------- CONFIG DI BASE ----------
COMFY="${HOME}/ComfyUI"
MODELS="${COMFY}/models"

CKPT_DIR="${MODELS}/checkpoints"
VAE_DIR="${MODELS}/vae"
DIFFUSERS_DIR="${MODELS}/diffusers"
CTRL_DIR="${MODELS}/controlnet"
LORA_DIR="${MODELS}/loras"
IPADAPTER_DIR="${MODELS}/ipadapter"
UPSCALE_DIR="${MODELS}/upscale_models"

# Modelli / Repo Hugging Face (modificabili se preferisci alternative)
JUGGERNAUT_REPO="RunDiffusion/Juggernaut-XL"                     # checkpoint principale
REFINER_REPO="stabilityai/stable-diffusion-xl-refiner-1.0"       # SDXL Refiner (diffusers)
SDXL_VAE_REPO="madebyollin/sdxl-vae-fp16-fix"                    # VAE fixato per SDXL

# ControlNet SDXL – elenco candidati (il primo che esiste verrà usato)
CTRL_CANNY_CANDIDATES=("diffusers/controlnet-canny-sdxl-1.0" "thibaud/controlnet-sdxl-1.0-canny" "monster-labs/controlnet-canny-sdxl")
CTRL_DEPTH_CANDIDATES=("diffusers/controlnet-depth-sdxl-1.0" "thibaud/controlnet-sdxl-1.0-depth" "monster-labs/controlnet-depth-sdxl")
CTRL_TILE_CANDIDATES=("diffusers/controlnet-tile-sdxl-1.0" "thibaud/controlnet-sdxl-1.0-tile" "monster-labs/controlnet-tile-sdxl")

# IP-Adapter XL (scarica l’intero repo; userai i file plus_sdxl_vit-h)
IPADAPTER_REPO="h94/IP-Adapter"

# Upscaler ESRGAN (opzionale – se i modelli non esistono, mostra un messaggio)
ESRGAN_CANDIDATES=(
  "xinntao/Real-ESRGAN"            # repo generale (potrebbe non contenere i .pth community)
  "ljleb/pytorch-RealESRGAN"       # esempi
  "nmkd/real-esrgan"               # derivati
)
ESRGAN_TARGETS=("4x-UltraSharp.pth" "4x-Remacri.pth")

# --------- FUNZIONI UTILI -----------
sudo_if_available() {
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

msg() { echo -e "\n==> $*\n"; }

download_hf_repo() {
  local repo_id="$1"
  local target_dir="$2"
  msg "Download da Hugging Face: ${repo_id} -> ${target_dir}"
  huggingface-cli download "${repo_id}" --local-dir "${target_dir}" --local-dir-use-symlinks False
}

try_first_available() {
  # Tenta a scaricare il primo repo valido nella lista passata (array di candidati)
  local -n candidates_ref=$1     # nome dell'array (by reference)
  local target_dir="$2"
  local last_err=0
  for rid in "${candidates_ref[@]}"; do
    if download_hf_repo "${rid}" "${target_dir}"; then
      echo "${rid}" > "${target_dir}/.source_id.txt"
      return 0
    else
      last_err=$?
    fi
  done
  return ${last_err}
}

# --------- PREREQUISITI ------------
msg "Preparazione cartelle ComfyUI..."
mkdir -p "${CKPT_DIR}" "${VAE_DIR}" "${DIFFUSERS_DIR}" "${CTRL_DIR}" "${LORA_DIR}" "${IPADAPTER_DIR}" "${UPSCALE_DIR}"

msg "Aggiorno pacchetti di base (se possibile)..."
sudo_if_available apt-get update -y || true
sudo_if_available apt-get install -y git git-lfs python3-pip || true

msg "Inizializzo git-lfs..."
git lfs install --skip-repo || true

msg "Aggiorno pip e installo librerie Python..."
python3 -m pip install --upgrade pip
pip3 install --upgrade "huggingface_hub==0.23.*" safetensors

if [ -n "${HF_TOKEN:-}" ]; then
  msg "Login HF con token da variabile d'ambiente..."
  huggingface-cli login --token "$HF_TOKEN" --add-to-git-credential || true
else
  cat <<'INFO'

NOTA LICENZA / ACCESSO HUGGING FACE
- Se vedi errore 403 durante un download, accetta la licenza del modello nella sua pagina Hugging Face
  e poi esegui:  huggingface-cli login
INFO
fi

# --------- DOWNLOAD MODELLI ---------

# JuggernautXL (checkpoint .safetensors o diffusers – molti release forniscono .safetensors)
msg "Scarico JuggernautXL (checkpoint)..."
download_hf_repo "${JUGGERNAUT_REPO}" "${CKPT_DIR}/JuggernautXL" || {
  msg "ATTENZIONE: non sono riuscito a scaricare JuggernautXL. Verifica che il repo esista o modifica JUGGERNAUT_REPO."
}

# SDXL Refiner (diffusers)
msg "Scarico SDXL Refiner (diffusers)..."
download_hf_repo "${REFINER_REPO}" "${DIFFUSERS_DIR}/sdxl-refiner-1.0" || {
  msg "ERRORE: impossibile scaricare il Refiner. Accetta la licenza su HF e riprova."
  exit 1
}

# VAE fix
msg "Scarico VAE fixato per SDXL..."
download_hf_repo "${SDXL_VAE_REPO}" "${VAE_DIR}/sdxl-vae-fp16-fix" || {
  msg "ATTENZIONE: VAE non scaricato. Puoi comunque usare il VAE incluso nel checkpoint, ma la qualità potrebbe risentirne."
}

# ControlNet XL – Canny
msg "Scarico ControlNet XL (Canny)..."
try_first_available CTRL_CANNY_CANDIDATES "${CTRL_DIR}/sdxl-canny" || {
  msg "ATTENZIONE: impossibile scaricare ControlNet Canny XL. Modifica i candidati nello script con un repo esatto."
}

# ControlNet XL – Depth
msg "Scarico ControlNet XL (Depth)..."
try_first_available CTRL_DEPTH_CANDIDATES "${CTRL_DIR}/sdxl-depth" || {
  msg "ATTENZIONE: impossibile scaricare ControlNet Depth XL. Modifica i candidati nello script con un repo esatto."
}

# ControlNet XL – Tile
msg "Scarico ControlNet XL (Tile)..."
try_first_available CTRL_TILE_CANDIDATES "${CTRL_DIR}/sdxl-tile" || {
  msg "ATTENZIONE: impossibile scaricare ControlNet Tile XL. Modifica i candidati nello script con un repo esatto."
}

# IP-Adapter XL
msg "Scarico IP-Adapter XL..."
download_hf_repo "${IPADAPTER_REPO}" "${IPADAPTER_DIR}/IP-Adapter" || {
  msg "ATTENZIONE: impossibile scaricare IP-Adapter XL. Puoi proseguire senza, ma perderai coerenza di stile/palette."
}

# Upscalers ESRGAN (best effort)
msg "Provo a recuperare upscaler ESRGAN comuni (UltraSharp/Remacri) – best effort..."
for target in "${ESRGAN_TARGETS[@]}"; do
  if [ -f "${UPSCALE_DIR}/${target}" ]; then
    echo "• ${target} già presente, salto."
    continue
  fi
  found=0
  for repo in "${ESRGAN_CANDIDATES[@]}"; do
    if huggingface-cli ls "${repo}" 2>/dev/null | grep -q "${target}" ; then
      msg "Trovato ${target} in ${repo}, scarico..."
      huggingface-cli download "${repo}" "${target}" --local-dir "${UPSCALE_DIR}" --local-dir-use-symlinks False && found=1 && break
    fi
  done
  if [ "${found}" -eq 0 ]; then
    echo "• NON trovato automaticamente: ${target}"
    echo "  Inseriscilo tu in: ${UPSCALE_DIR}/${target} (opzionale)."
  fi
done

# --------- RIEPILOGO ---------------
msg "RIEPILOGO PERCORSI:"
cat <<EOF
Checkpoints:
  - ${CKPT_DIR}/JuggernautXL

Diffusers:
  - ${DIFFUSERS_DIR}/sdxl-refiner-1.0

VAE:
  - ${VAE_DIR}/sdxl-vae-fp16-fix

ControlNet (XL):
  - ${CTRL_DIR}/sdxl-canny
  - ${CTRL_DIR}/sdxl-depth
  - ${CTRL_DIR}/sdxl-tile

IP-Adapter:
  - ${IPADAPTER_DIR}/IP-Adapter

Upscalers ESRGAN (opzionale):
  - ${UPSCALE_DIR}  (cerca: 4x-UltraSharp.pth, 4x-Remacri.pth)
EOF

# --------- ISTRUZIONI USO ----------
cat <<'USAGE'

==> USO IN COMFYUI (SDXL due pass + upscaling a tile)

PASS 1 – Generazione base
  • Load Checkpoint: JuggernautXL (da ComfyUI/models/checkpoints/JuggernautXL)
  • Load VAE: sdxl-vae-fp16-fix
  • ControlNet XL: Depth (0.8–1.0), Canny (0.6–0.8)
  • Sampler: DPM++ 2M Karras, Steps 30–40, CFG 7–8
  • Output: ~1024/1536 lato lungo

PASS 2 – Refine (img2img)
  • Load Diffusion Model (Diffusers): models/diffusers/sdxl-refiner-1.0
  • Stessa immagine del Pass 1 → VAE Encode → KSampler (denoise 0.20–0.35)
  • Stessi ControlNet (se vuoi “inchiodare” layout)
  • Output: stessa risoluzione, ma con micro‑dettaglio migliore

PASS 3 – Upscaling a tile (SDXL)
  • ControlNet Tile XL (tile 512–768, weight ~0.9)
  • KSampler img2img (denoise ~0.2) con SDXL (JuggernautXL o Refiner)
  • Output: 2×/4×. Se vuoi extra nitidezza: ESRGAN 4x UltraSharp/Remacri.

NOTE:
  - Se incontri 403 in download, accetta la licenza del modello su HuggingFace e fai `huggingface-cli login`.
  - Puoi impostare il token senza prompt: `export HF_TOKEN=xxxxx` prima di eseguire lo script.

USAGE

msg "Setup completato."
