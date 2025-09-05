#!/usr/bin/env bash
set -euo pipefail

# ===== Path canonico (forzato) =====
COMFY="/workspace/ComfyUI"
mkdir -p "$COMFY"
ln -sfn "$COMFY" /ComfyUI  # /ComfyUI -> /workspace/ComfyUI

# ===== Cartelle modelli =====
for d in checkpoints vae diffusers controlnet ipadapter loras upscale_models; do
  mkdir -p "$COMFY/models/$d"
done

# ===== Mappa esplicita per ComfyUI =====
cat > "$COMFY/extra_model_paths.yaml" <<'YAML'
checkpoints: ["/workspace/ComfyUI/models/checkpoints"]
vae: ["/workspace/ComfyUI/models/vae"]
controlnet: ["/workspace/ComfyUI/models/controlnet"]
ipadapter: ["/workspace/ComfyUI/models/ipadapter"]
loras: ["/workspace/ComfyUI/models/loras"]
upscale_models: ["/workspace/ComfyUI/models/upscale_models"]
YAML

# ===== Downloader minimale ma robusto (curl) =====
_download(){ # _download URL DEST
  local url="$1" dest="$2" tries=5
  [[ -s "$dest" ]] && { echo "[OK] Presente: $(basename "$dest")"; return 0; }
  mkdir -p "$(dirname "$dest")"
  local hdr=()
  [[ "$url" == *"huggingface.co"* && -n "${HF_TOKEN:-}" ]] && hdr=(-H "Authorization: Bearer $HF_TOKEN")
  curl -L --fail -C - --retry "$tries" --retry-delay 2 "${hdr[@]}" -o "$dest" "$url"
}

_ok_file(){ # rifiuta HTML/JSON o file minuscoli
  local f="$1" mt sz; [[ -s "$f" ]] || return 1
  mt="$(file --mime-type -b "$f" 2>/dev/null || true)"
  sz="$(stat -c%s "$f" 2>/dev/null || echo 0)"
  [[ "$mt" != "text/html" && "$mt" != "application/json" && "$sz" -ge $((5*1024*1024)) ]]
}

fetch(){ # fetch URL DEST (retry 1 volta se sospetto)
  local url="$1" dest="$2"
  _download "$url" "$dest" || return 1
  _ok_file "$dest" && { echo "[OK] Scaricato: $(basename "$dest")"; return 0; }
  echo "[WARN] File sospetto, ritento: $(basename "$dest")"
  rm -f "$dest"
  _download "$url" "$dest" || return 1
  _ok_file "$dest"
}

# ===== Lista modelli (URL|DEST) — directory GIUSTE =====
DL=(
  # ---- CHECKPOINTS ----
  "https://civitai.com/api/download/models/129549|$COMFY/models/checkpoints/juggernaut_xl_inpainting.safetensors"
  # (Opzionali — rimuovi # per abilitarli)
  # "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors|$COMFY/models/checkpoints/sd_xl_base_1.0.safetensors"
  # "https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors|$COMFY/models/checkpoints/sd_xl_refiner_1.0.safetensors"

  # ---- VAE ----
  "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors|$COMFY/models/vae/sdxl_vae.safetensors"

  # ---- IP-ADAPTER ----
  "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors|$COMFY/models/ipadapter/ipadapter_sd15_image_encoder.safetensors"
  "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors|$COMFY/models/ipadapter/ipadapter_sdxl_image_encoder.safetensors"
  "https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter-plus_sd15.safetensors|$COMFY/models/ipadapter/ip-adapter-plus_sd15.safetensors"

  # ---- UPSCALER ----
  "https://huggingface.co/lokCX/4x-Ultrasharp/resolve/main/4x-UltraSharp.pth|$COMFY/models/upscale_models/4x-UltraSharp.pth"
)

# ===== Esecuzione =====
OK=() SKIP=() FAIL=()
for it in "${DL[@]}"; do
  url="${it%%|*}"; dst="${it##*|}"; name="$(basename "$dst")"
  if [[ -s "$dst" ]]; then
    echo "[SKIP] $name"; SKIP+=("$name"); continue
  fi
  if fetch "$url" "$dst"; then OK+=("$name"); else echo "[ERR] $name"; FAIL+=("$name"); fi
done

# ===== Riepilogo =====
echo -e "\n==== RIEPILOGO ===="
echo "Installati: ${#OK[@]}"; ((${#OK[@]})) && printf ' - %s\n' "${OK[@]}"
echo "Skippati:  ${#SKIP[@]}"; ((${#SKIP[@]})) && printf ' - %s\n' "${SKIP[@]}"
echo "Falliti:   ${#FAIL[@]}"; ((${#FAIL[@]})) && printf ' - %s\n' "${FAIL[@]}"
((${#FAIL[@]})) && exit 6 || exit 0
