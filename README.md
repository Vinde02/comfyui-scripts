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

## 📥 Installazione

Clona la repo dentro la tua area di lavoro RunPod (tipicamente `/workspace`):

```
cd /workspace
git clone https://github.com/Vinde02/comfyui-scripts.git
cd comfyui-scripts
```
## ▶️ Avvio script
Assicurati di avere la cartella ComfyUI dentro /workspace.

```
chmod +x setup_runpod_comfyui.sh
./setup_runpod_comfyui.sh
```

## 🔑 Hugging Face Token (Opzionale)
I modelli inclusi sono pubblici → non serve token.
Se però vuoi installare modelli da repo privati o con licenza accettata, esporta il tuo HF_TOKEN:

```
export HF_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
./setup_runpod_comfyui.sh
```

📌 Senza token, lo script funziona comunque per i modelli già inclusi.

📋 Script rapidi
Installazione completa (con token opzionale)

```
cd /workspace/comfyui-scripts
chmod +x setup_runpod_comfyui.sh
export HF_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   # ← opzionale
./setup_runpod_comfyui.sh
```
Aggiornare la repo

```
cd /workspace/comfyui-scripts
git pull
```

## ✅ Modelli inclusi nello script
Juggernaut XL Inpainting (Civitai)

IP-Adapter SDXL image encoder (h94)

IP-Adapter Plus SD15 (h94)

SDXL VAE (StabilityAI, URL corretto)

Upscaler 4x-UltraSharp (lokCX, mirror stabile)

## 📌 Note importanti
Lo script lavora solo nella cartella ./ComfyUI → deve esistere già.

Se un link da Civitai scade, sostituiscilo con un mirror Hugging Face.

Le dipendenze necessarie (git, git-lfs, aria2c, wget, curl, huggingface_hub, safetensors) vengono installate automaticamente.

Warning di pip root user già soppressi con --root-user-action=ignore.

## 🧪 Testato su
 RunPod GPU container (Ubuntu 22.04)

 Altri ambienti Linux (non ancora testati)

## 📜 Licenza
Distribuito sotto licenza MIT.

