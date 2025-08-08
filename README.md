# 🏗️ SDXL Power Toolkit per ComfyUI

Toolkit completo per configurare **ComfyUI** con un workflow SDXL ad altissima qualità, pensato per generare **sfondi fotorealistici per arredamento** (cataloghi, ambienti interni, showroom) su RunPod o qualsiasi macchina con supporto GPU.

Lo script incluso installa in un colpo solo:
- **JuggernautXL** – checkpoint fotorealistico ottimizzato per ambienti
- **SDXL Refiner 1.0** – secondo pass per micro-dettaglio e transizioni di colore
- **VAE fixato** per massima fedeltà cromatica
- **ControlNet XL** (Depth, Canny, Tile) – per layout, prospettiva e upscaling coerente
- **IP-Adapter XL** – per mantenere palette e stile da immagine di riferimento
- **Upscaler ESRGAN** (UltraSharp, Remacri) – nitidezza extra senza perdere realismo

---

## 📦 Contenuto dello script

| Categoria      | Modello                              | Funzione principale |
|----------------|--------------------------------------|----------------------|
| Checkpoint     | JuggernautXL                         | Modello SDXL base fotorealistico |
| Refiner        | SDXL Refiner 1.0                     | Migliora micro-dettaglio in secondo pass |
| VAE            | sdxl-vae-fp16-fix                    | Colore/texture più fedeli |
| ControlNet XL  | Depth, Canny, Tile                    | Controllo prospettiva, bordi, upscaling coerente |
| IP-Adapter XL  | plus_sdxl_vit-h                       | Mantiene palette/stile da immagine di riferimento |
| Upscalers      | 4x-UltraSharp, 4x-Remacri             | Nitidezza e dettaglio aggiuntivo |

---

## 🚀 Installazione

### 1. Scarica ed esegui lo script
```bash
wget "URL_RAW_DEL_TUO_SCRIPT" -O setup_sdxl_env.sh
chmod +x setup_sdxl_env.sh
./setup_sdxl_env.sh
