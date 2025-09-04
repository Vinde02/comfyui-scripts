# 🚀 Setup RunPod ComfyUI Scripts

Questo repository contiene **`setup_runpod_comfyui.sh`**, uno script automatico pensato per installare e configurare **modelli essenziali per ComfyUI** in ambiente **RunPod** (o qualsiasi container Linux).

## 🛠️ Cosa fa lo script
- Crea automaticamente tutte le cartelle `models/` necessarie (`checkpoints`, `vae`, `controlnet`, `ipadapter`, `loras`, `upscale_models`).
- Scarica i modelli principali (Juggernaut XL Inpainting, IP-Adapter, SDXL VAE, Upscaler 4x-UltraSharp).
- Verifica l’integrità dei file `.safetensors`.
- Gestisce download con retry, resume e supporto Hugging Face.
- Non richiede input interattivi → perfetto per RunPod.

---

## 📥 Clonare la repo

```bash
cd /workspace
git clone https://github.com/Vinde02/comfyui-scripts.git
cd comfyui-scripts
▶️ Avviare l’installazione
Assicurati di avere la cartella ComfyUI in /workspace (o nella stessa directory da cui lanci).

bash
Copia codice
chmod +x setup_runpod_comfyui.sh
./setup_runpod_comfyui.sh
🔑 (Opzionale) Hugging Face Token
Alcuni modelli pubblici non richiedono token.
👉 Se invece vuoi scaricare modelli da repo privati o con licenza accettata, devi esportare il tuo HF_TOKEN.

Come aggiungere il token
bash
Copia codice
export HF_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
./setup_runpod_comfyui.sh
📌 Nota: senza HF_TOKEN lo script funziona comunque per i modelli pubblici già inclusi.

📋 Script veloci
Installazione completa (con token se serve)
bash
Copia codice
cd /workspace/comfyui-scripts
chmod +x setup_runpod_comfyui.sh
export HF_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   # ← opzionale
./setup_runpod_comfyui.sh
Solo update repo
bash
Copia codice
cd /workspace/comfyui-scripts
git pull
✅ Modelli inclusi nello script
Juggernaut XL Inpainting (Civitai)

IP-Adapter SDXL image encoder (h94)

IP-Adapter Plus SD15 (h94)

SDXL VAE (StabilityAI)

Upscaler 4x-UltraSharp (lokCX)

📌 Note
Lo script lavora solo nella cartella ./ComfyUI → deve esistere già.

Se un download da Civitai scade, sostituisci con un mirror Hugging Face.

Tutte le dipendenze (git, aria2c, wget, curl, huggingface_hub, safetensors) vengono installate automaticamente.

yaml
Copia codice

Copia

Vuoi che ti apra direttamente una PR con questo README aggiornato così fai “Merge” al volo?
::contentReference[oaicite:0]{index=0}
