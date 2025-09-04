🚀 ComfyUI Setup Script for RunPod






Questo repository contiene setup_runpod_comfyui.sh, uno script automatizzato per installare modelli essenziali in ComfyUI su ambienti RunPod (GPU container) o Linux.
👉 Lo script è stato testato con successo su RunPod.

🛠️ Funzionalità

✅ Crea le cartelle models/ necessarie:
checkpoints, vae, controlnet, ipadapter, loras, upscale_models

✅ Scarica e installa modelli essenziali:

Juggernaut XL Inpainting

IP-Adapter SDXL image encoder

IP-Adapter Plus SD15

SDXL VAE (URL corretto)

Upscaler 4x-UltraSharp (mirror stabile)

✅ Verifica integrità dei .safetensors

✅ Retry e resume dei download

✅ Supporto Hugging Face (HF_TOKEN opzionale)

✅ Nessun input interattivo (perfetto per RunPod)

📥 Installazione

Clona la repo dentro la tua area di lavoro RunPod (tipicamente /workspace):

cd /workspace
git clone https://github.com/Vinde02/comfyui-scripts.git
cd comfyui-scripts

▶️ Avvio script

Assicurati di avere la cartella ComfyUI dentro /workspace (es.: /workspace/ComfyUI), quindi:

chmod +x setup_runpod_comfyui.sh
./setup_runpod_comfyui.sh

🔑 Hugging Face Token (Opzionale)

I modelli inclusi sono pubblici → non serve token.
Se però vuoi installare modelli da repo privati o con licenza accettata, esporta il tuo HF_TOKEN:

export HF_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
./setup_runpod_comfyui.sh


📌 Senza token, lo script funziona comunque per i modelli già inclusi.

📋 Script rapidi

Installazione completa (token opzionale):

cd /workspace/comfyui-scripts
chmod +x setup_runpod_comfyui.sh
export HF_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   # ← opzionale
./setup_runpod_comfyui.sh


Aggiornare la repo:

cd /workspace/comfyui-scripts
git pull

✅ Modelli inclusi

Juggernaut XL Inpainting (Civitai)

IP-Adapter SDXL image encoder (h94)

IP-Adapter Plus SD15 (h94)

SDXL VAE (StabilityAI)

Upscaler 4x-UltraSharp (lokCX)

📌 Note

Lo script lavora solo nella cartella ./ComfyUI → deve esistere già.

Se un link da Civitai scade, sostituiscilo con un mirror Hugging Face.

Dipendenze installate automaticamente: git, git-lfs, aria2c, wget, curl, huggingface_hub, safetensors.

Warning di pip come root soppressi con --root-user-action=ignore.

🧪 Testato su

 RunPod GPU container (Ubuntu 22.04)

 Altri ambienti Linux (non ancora testati)

📜 Licenza

Distribuito sotto licenza MIT. Vedi il file LICENSE
.
