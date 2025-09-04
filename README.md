# 🚀 ComfyUI Setup Script for RunPod

[![Status](https://img.shields.io/badge/status-tested%20on%20RunPod-brightgreen)](https://www.runpod.io/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-lightgrey)](https://www.gnu.org/software/bash/)

Questo repository contiene **`setup_runpod_comfyui.sh`**, uno script **automatizzato** per installare modelli essenziali in **ComfyUI** su ambienti **RunPod** (GPU container) o Linux.  
👉 Lo script è stato **testato con successo su RunPod**.

---

## 🛠️ Funzionalità
- ✅ Crea tutte le cartelle `models/` necessarie:
  - `checkpoints`, `vae`, `controlnet`, `ipadapter`, `loras`, `upscale_models`
- ✅ Scarica e installa modelli essenziali:
  - Juggernaut XL Inpainting
  - IP-Adapter SDXL image encoder
  - IP-Adapter Plus SD15
  - SDXL VAE (corretto)
  - Upscaler 4x-UltraSharp (mirror stabile)
- ✅ Verifica integrità dei file `.safetensors`
- ✅ Supporto **retry, resume download**
- ✅ Compatibile con Hugging Face (`HF_TOKEN` opzionale)
- ✅ Nessun input interattivo (perfetto per container RunPod)

---

## 🔑 Hugging Face Token (Opzionale)
I modelli inclusi sono pubblici → non serve token.
Se però vuoi installare modelli da repo privati o con licenza accettata, esporta il tuo HF_TOKEN:

```
export HF_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
./setup_runpod_comfyui.sh
```

> 📌 Senza token, lo script funziona comunque per i modelli già inclusi.

## 📋 Script di utilizzo su runpod
Installazione completa (con token opzionale)
apri nano con 
```
nano start_setup.sh
```
questo file serve a clonare/aggiornare la repo e lanciare lo script di installazione

una volta aperto il nano in colla lo script di seguito e poi premi: "ctrl+o" --> "invio", e chiudi il nano con "ctrl+x"

```
#!/usr/bin/env bash
set -euo pipefail

# Configura qui il tuo repo e lo script
REPO_URL="https://github.com/Vinde02/comfyui-scripts.git"
REPO_DIR="comfyui-scripts"
SCRIPT_NAME="setup_runpod_comfyui.sh"

# 1. Clona o aggiorna repo
if [[ -d "$REPO_DIR" ]]; then
  echo "[INFO] Repo già presente, aggiorno..."
  git -C "$REPO_DIR" pull
else
  echo "[INFO] Clono repo..."
  git clone "$REPO_URL" "$REPO_DIR"
fi

# 2. Rendi eseguibile lo script
chmod +x "$REPO_DIR/$SCRIPT_NAME"

# 3. (Opzionale) Token Hugging Face non interattivo
# Esporta il token PRIMA di lanciare lo script
# export HF_TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# 4. Lancia lo script
echo "[INFO] Avvio installazione..."
"./$REPO_DIR/$SCRIPT_NAME"

```

poi usa il seguente comando

```
chmod +x start_setup.sh && 
./start_setup.sh
```

## ✅ Modelli inclusi nello script
- Juggernaut XL Inpainting (Civitai)

- IP-Adapter SDXL image encoder (h94)

- IP-Adapter Plus SD15 (h94)

- SDXL VAE (StabilityAI, URL corretto)

- Upscaler 4x-UltraSharp (lokCX, mirror stabile)

## 📌 Note importanti
Lo script lavora solo nella cartella ./ComfyUI → deve esistere già.

Se un link da Civitai scade, sostituiscilo con un mirror Hugging Face.

Le dipendenze necessarie (git, git-lfs, aria2c, wget, curl, huggingface_hub, safetensors) vengono installate automaticamente.

Warning di pip root user già soppressi con --root-user-action=ignore.

## 🧪 Testato su
 * RunPod GPU container (Ubuntu 22.04)

 * Altri ambienti Linux (non ancora testati)

## 📜 Licenza
Distribuito sotto licenza MIT.

