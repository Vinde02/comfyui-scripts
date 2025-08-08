# 🏗️ SDXL Power Toolkit per ComfyUI – Workflow fotorealistico per arredamento e cataloghi

Toolkit completo per configurare **ComfyUI** con un workflow SDXL ad altissima qualità, pensato per generare **sfondi fotorealistici per arredamento** (cataloghi, ambienti interni, showroom) su RunPod o su qualsiasi macchina con GPU.

Lo script incluso installa in un colpo solo:
- **JuggernautXL** – checkpoint fotorealistico ottimizzato per interni
- **SDXL Refiner 1.0** – secondo pass per micro‑dettaglio e transizioni cromatiche
- **VAE fixato** per massima fedeltà colore/texture
- **ControlNet XL** (Depth, Canny, Tile) – per prospettiva, bordi e upscaling coerente
- **IP‑Adapter XL** – per mantenere palette/stile da immagine di riferimento
- **Upscaler ESRGAN** (UltraSharp, Remacri) – nitidezza extra senza perdere realismo

---

## 🚀 Installazione rapida

```bash
wget "https://raw.githubusercontent.com/emazeck/comfyui-scripts/refs/heads/main/setup_sdxl_env.sh" -O setup_sdxl_env.sh
chmod +x setup_sdxl_env.sh
./setup_sdxl_env.sh
Licenze / accesso Hugging Face

Se un download restituisce 403 Forbidden, apri la pagina del modello su Hugging Face e accetta la licenza.

Puoi autenticarti in modo non interattivo esportando il token:

bash
Copia
export HF_TOKEN=il_tuo_token
./setup_sdxl_env.sh
🔧 Prerequisiti
Lo script proverà a installare automaticamente: git, git-lfs, python3-pip, huggingface_hub, safetensors.

Se preferisci, puoi installarli tu prima di eseguire lo script.

📍 Percorso di ComfyUI (variabile COMFY)
Per default lo script usa: ~/ComfyUI.

Se ComfyUI è altrove, prima di lanciare lo script imposta la variabile:

bash
Copia
export COMFY="/percorso/assoluto/alla/tuacomfy/ComfyUI"
./setup_sdxl_env.sh
Lo script creerà le cartelle necessarie se mancanti.

📦 Cosa installa e dove
bash
Copia
ComfyUI/
 └── models/
     ├── checkpoints/       → JuggernautXL
     ├── vae/               → sdxl-vae-fp16-fix
     ├── diffusers/         → sdxl-refiner-1.0 (SDXL Refiner)
     ├── controlnet/        → sdxl-canny, sdxl-depth, sdxl-tile
     ├── ipadapter/         → IP-Adapter (repo completo)
     ├── loras/             → (facoltativo, per i tuoi stili/brand)
     └── upscale_models/    → 4x-UltraSharp.pth, 4x-Remacri.pth (se trovati)
Nota upscaler: alcuni .pth community non sono sempre disponibili via HF API.
Se 4x-UltraSharp.pth o 4x-Remacri.pth non vengono trovati automaticamente,
scaricali manualmente e mettili in ComfyUI/models/upscale_models/.

🧠 Modelli usati (indicativi)
Checkpoint principale: RunDiffusion/Juggernaut-XL

Refiner (diffusers): stabilityai/stable-diffusion-xl-refiner-1.0

VAE: madebyollin/sdxl-vae-fp16-fix

ControlNet XL (candidati auto‑detect nello script):

Canny: es. diffusers/controlnet-canny-sdxl-1.0

Depth: es. diffusers/controlnet-depth-sdxl-1.0

Tile: es. diffusers/controlnet-tile-sdxl-1.0

IP‑Adapter XL: h94/IP-Adapter

ESRGAN: tentativo automatico di 4x-UltraSharp.pth e 4x-Remacri.pth

Se un repo candidato non esistesse o richiedesse accesso, lo script mostra un avviso:
puoi modificare gli ID direttamente in setup_sdxl_env.sh.

🖼️ Workflow consigliato (3 passaggi)
Pass 1 – Generazione base (SDXL)
Modello: JuggernautXL (checkpoint)

VAE: sdxl-vae-fp16-fix

ControlNet:

Depth 0.8–1.0 (prospettiva/volumi)

Canny 0.6–0.8 (bordi/layout)

Sampler: DPM++ 2M Karras, 30–40 steps, CFG 7–8

Risoluzione: 1024–1536px lato lungo

Output: immagine base pulita e coerente

Pass 2 – Raffinamento (Refiner)
Modello: SDXL Refiner (Diffusers)

Modalità: img2img sul risultato del Pass 1

Denoise: 0.20–0.35

(Opzionale) riapplica ControlNet se vuoi “inchiodare” il layout

Output: micro‑dettaglio e transizioni migliorate

Pass 3 – Upscaling a tile (SDXL)
ControlNet: Tile XL (tile size 512–768, weight ~0.9)

KSampler: img2img con denoise ~0.2 usando SDXL (JuggernautXL o Refiner)

Output: 2× / 4×. Facoltativo: ESRGAN UltraSharp o Remacri per nitidezza extra

📋 Prompting e consigli
Prompt breve e prescrittivo: soggetto → materiali → luce → camera → palette.

Negative severi (esempi): blurry, overexposed, distorted geometry, color banding, lowres.

Se non segue il prompt:

Aumenta peso dei ControlNet chiave

Ripulisci gli aggettivi superflui

Prova CFG 8–9 (con eventuale CFG rescale)

Usa il pass 2 con denoise più basso (0.2–0.25)

🧪 Esempio Comandi (RunPod / SSH)
bash
Copia
# 1) Imposta (opzionale) posizione di ComfyUI
export COMFY="$HOME/ComfyUI"

# 2) (Opzionale) token Hugging Face per modelli con licenza
export HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 3) Scarica ed esegui setup
wget "https://raw.githubusercontent.com/emazeck/comfyui-scripts/refs/heads/main/setup_sdxl_env.sh" -O setup_sdxl_env.sh
chmod +x setup_sdxl_env.sh
./setup_sdxl_env.sh
❗ Troubleshooting
403 Forbidden (HF): accetta la licenza del modello su Hugging Face e fai huggingface-cli login o esporta HF_TOKEN.

Percorsi diversi: imposta COMFY prima di eseguire lo script.

ESRGAN mancanti: posiziona manualmente i .pth in models/upscale_models/.

VRAM limitata: genera a 1024px e scala in più step (Tile 2× + ESRGAN).

📜 Licenze
I modelli mantengono le loro licenze originali su Hugging Face.
Verifica sempre termini e condizioni prima dell’uso in produzione.

perl
Copia

Vuoi che ti apra direttamente una PR con questo README aggiornato così fai “Merge” al volo?
::contentReference[oaicite:0]{index=0}
