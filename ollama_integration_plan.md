# TradingAI System: Ollama Local AI Integration Plan

This document outlines the architecture, data models, integration steps, and proposed workflows to leverage **Ollama** (a local, offline large language and vision model runner) with the TradingAI flight recorder system.

---

## 1. High-Level Vision

The TradingAI system currently functions as an advanced sensory capture system. It logs raw time series snapshots and trade events (deals) from MetaTrader 5, aligns them in real-time, and packages them alongside multi-timeframe screenshots (`M1`, `M5`, `M15`, `H1`, `H4`, `D1`).

By integrating **Ollama**, we transition the project from **Stage 1 (Sensory Capture)** to **Stage 2 (Local AI Assessment & Feature Engineering)**. Since the dataset contains both tabular events and visual charts, we can leverage local Vision-Language Models (VLMs) and LLMs to critique setups, label market structures, and engineer advanced synthetic features without any cloud dependencies, costs, or data privacy concerns.

```
                  ┌──────────────────────────────┐
                  │      MT5 Trading System      │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │    Python Dataset Builder    │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │  ollama_integration_plan.md  │
                  └──────────────┬───────────────┘
                                 │
         ┌───────────────────────┴───────────────────────┐
         ▼                                               ▼
┌──────────────────────────────┐                ┌──────────────────────────────┐
│  A: Post-Trade Critic        │                │  B: Real-time Trade Copilot │
│  - Offline back-analysis     │                │  - Pre-trade validation      │
│  - Vision LLM rates charts   │                │  - Multi-timeframe grading   │
│  - Outputs structured score  │                │  - Live prompt output        │
└──────────────────────────────┘                └──────────────────────────────┘
```

---

## 2. Recommended Local Models

Ollama provides lightweight, performant open models that run locally on standard consumer GPUs (or high-end CPUs). The following models are recommended for this system:

| Model Category | Model Name | Size | RAM/VRAM Required | Key Strengths |
|---|---|---|---|---|
| **Vision-Language (VLM)** | `llama3.2-vision:11b` | ~7.9 GB | 12GB+ | Superior chart comprehension, trend analysis, and OCR for reading text/coordinates from charts. |
| **Vision-Language (VLM)** | `llava:7b` | ~4.7 GB | 8GB+ | Fast inference, robust visual pattern recognition. |
| **Vision-Language (VLM)** | `moondream` | ~800 MB | 2GB+ | Ultra-lightweight, extremely fast. Perfect for CPU-only systems or low-end hardware. |
| **Reasoning & Labeling** | `qwen2.5-coder:7b` / `llama3:8b` | ~4.7 GB | 8GB+ | Excellent structured JSON output generation, coding support, and step-by-step logic. |

---

## 3. Integration Strategies

We propose three main strategies for Ollama integration.

### Strategy A: Post-Trade Critic & Quality Scorer (Dataset Enrichment)
This strategy runs offline on your compiled dataset (`dataset/tradingai_dataset.parquet`). A Python script reads each finished trade, retrieves its entry/exit screenshots, presents them to Ollama, and appends AI ratings back into the dataset.

#### Data Flow:
1. Load `tradingai_dataset.parquet`.
2. For each trade:
   - Load the `M15` or `H1` entry screenshot.
   - Package trade parameters (Symbol, Direction, Entry/Exit prices, Risk-to-Reward ratio, holding duration).
   - Prompt `llama3.2-vision` to grade the technical setup.
3. Parse the structured JSON response.
4. Save the enriched dataset as `dataset/tradingai_enriched_dataset.parquet`.

#### Enriched Schema Fields:
* `ai_quality_score` (Integer 1-10) — Graded technical entry quality.
* `ai_market_condition` (String) — e.g., "Trending", "Consolidating", "Retest of broken support".
* `ai_critique` (Text) — Detailed description of why the trade was rated so.

---

### Strategy B: Local Real-Time Trade Copilot (Live Signal Evaluator)
This strategy helps you evaluate potential trades in real-time. Before pulling the trigger in MT5, you run a validation command or click an EA button that triggers Ollama's assessment.

#### Workflow:
1. Trader detects a potential setup on a specific symbol.
2. The EA is triggered to take a temporary "pre-entry context" screenshot across `M5`, `M15`, and `H1`.
3. The watcher script detects these images and calls Ollama.
4. Ollama processes the images using **Multi-Timeframe Analysis Rules**:
   - Is `H1` showing bullish structure (higher highs/lows)?
   - Is `M15` pulling back to a key demand zone?
   - Is `M5` showing a candlestick rejection pattern?
5. Ollama outputs a trading recommendation: **CONFIRMED (Strong Alignment)**, **REJECTED (Counter-Trend Risk)**, or **HOLD (Wait for Close)**.

---

### Strategy C: Chart-to-Text Feature Generator (Semantic Embeddings)
Machine learning algorithms (such as XGBoost, random forests, or neural networks) cannot natively understand raw chart images. This strategy uses Ollama's vision model to "verbalize" the charts into structured technical text descriptions, which are then converted into high-dimensional vector embeddings.

#### Implementation:
1. Query Ollama's VLM on entry screenshots with: *"Describe this technical setup in detail, including support/resistance, trendlines, and candlestick patterns."*
2. Run a small local text-embedding model (like Ollama's `nomic-embed-text`) to generate a 768-dimension vector embedding of that description.
3. Append this vector directly to the trade table.
4. Downstream machine learning models can now train directly on high-fidelity visual context represented as numeric vectors.

---

## 4. Implementation Blueprint (Step-by-Step)

To integrate Ollama, we will implement three new python files under `python/`:
1. `python/ollama_client.py` — Wraps Ollama library, handles connection, model pulling, and API retries.
2. `python/enrich_dataset.py` — The batch offline processing script for Strategy A.
3. `python/prompts.py` — Standardized system prompt and template files for vision/reasoning models.

### Step 1: Add Requirements
Install the official Ollama python client and image processing helper:
```bash
pip install ollama pillow
```

### Step 2: Create standard Client Wrapper (`python/ollama_client.py`)
```python
import ollama
import base64
from pathlib import Path
from typing import Optional, Any

class OllamaClient:
    def __init__(self, model_name: str = "llama3.2-vision"):
        self.model_name = model_name
        self._ensure_model()

    def _ensure_model(self):
        """Checks if model exists locally; pulls it if missing."""
        print(f"Checking for local model '{self.model_name}'...")
        try:
            ollama.show(self.model_name)
            print("Model is available.")
        except ollama.ResponseError:
            print(f"Model '{self.model_name}' not found locally. Pulling now...")
            ollama.pull(self.model_name)
            print("Pull complete!")

    def analyze_chart(self, image_path: Path, prompt: str) -> str:
        """Sends an image and a textual prompt to Ollama."""
        if not image_path.exists():
            raise FileNotFoundError(f"Image not found at {image_path}")
            
        with open(image_path, "rb") as f:
            img_bytes = f.read()

        response = ollama.generate(
            model=self.model_name,
            prompt=prompt,
            images=[img_bytes],
            options={"temperature": 0.2} # low temperature for consistency
        )
        return response.get("response", "")
```

### Step 3: Create Prompt Templates (`python/prompts.py`)
```python
TECHNICAL_CRITIC_PROMPT = """You are an expert institutional trading evaluator and technical analyst.
Analyze the attached chart screenshot for {symbol} ({timeframe}) taken at trade entry.

Trade Execution Context:
- Position Direction: {deal_type}
- Entry Price: {entry_price}
- Stop Loss: {sl}
- Take Profit: {tp}
- Realized Outcome: {win_loss} ({profit} USD profit/loss)

Tasks:
1. Examine the visual price action, support/resistance zones, trend direction, and indicators on this chart.
2. Evaluate if the entry was positioned well or if it violated core rules (e.g., buying directly into resistance, counter-trend without structure shift).
3. Score the trade technical quality on a scale of 1 to 10 (1 = random gamble, 10 = picture-perfect setup).

Response Format:
Return your response ONLY as a valid JSON object matching this structure (do not include markdown block quotes):
{{
  "quality_score": <int>,
  "setup_category": "<string_describing_pattern>",
  "trend_alignment": "aligned" | "counter-trend" | "sideways",
  "key_findings": ["point 1", "point 2"],
  "critique": "<paragraph describing the positive or negative elements of the setup>"
}}
"""
```

### Step 4: Batch Dataset Enricher (`python/enrich_dataset.py`)
```python
import json
import pandas as pd
from pathlib import Path
from ollama_client import OllamaClient
from prompts import TECHNICAL_CRITIC_PROMPT

def enrich_dataset(dataset_path: Path, screenshots_dir: Path, output_path: Path):
    df = pd.read_parquet(dataset_path)
    client = OllamaClient(model_name="llama3.2-vision")
    
    enriched_rows = []
    
    for idx, row in df.iterrows():
        # Get primary entry screenshot (usually first entry screenshot from M15 or H1)
        shots = str(row.get("entry_screenshots", "")).split("|")
        primary_shot = None
        for shot in shots:
            if "M15" in shot or "H1" in shot: # Prefer higher timeframes for analysis
                primary_shot = shot
                break
        
        if not primary_shot and shots:
            primary_shot = shots[0]
            
        if not primary_shot:
            print(f"Skipping trade {row['position_ticket']}: No entry screenshots found.")
            continue
            
        full_image_path = screenshots_dir / primary_shot
        if not full_image_path.exists():
            print(f"Skipping trade {row['position_ticket']}: File {full_image_path} does not exist.")
            continue
            
        # Parse timeframe from screenshot path
        # e.g., screenshots/XAUUSD/M15/screenshot.png
        timeframe = "M15"
        for tf in ["M1", "M5", "M15", "H1", "H4", "D1"]:
            if f"/{tf}/" in primary_shot or f"\\{tf}\\" in primary_shot:
                timeframe = tf
                break

        # Fill prompt
        prompt = TECHNICAL_CRITIC_PROMPT.format(
            symbol=row["symbol"],
            timeframe=timeframe,
            deal_type=row["deal_type"],
            entry_price=row["entry_price"],
            sl=row.get("sl", "None"),
            tp=row.get("tp", "None"),
            win_loss=row["win_loss"],
            profit=row["profit"]
        )
        
        print(f"Analyzing trade {row['position_ticket']} ({row['symbol']})...")
        try:
            raw_response = client.analyze_chart(full_image_path, prompt)
            analysis = json.loads(raw_response)
            
            # Merge original row data with analysis
            row_dict = row.to_dict()
            row_dict.update({
                "ai_quality_score": analysis.get("quality_score"),
                "ai_setup_category": analysis.get("setup_category"),
                "ai_trend_alignment": analysis.get("trend_alignment"),
                "ai_critique": analysis.get("critique"),
            })
            enriched_rows.append(row_dict)
        except Exception as e:
            print(f"Error parsing response for trade {row['position_ticket']}: {e}")
            
    # Save enriched dataset
    enriched_df = pd.DataFrame(enriched_rows)
    enriched_df.to_parquet(output_path, index=False)
    enriched_df.to_csv(output_path.with_suffix(".csv"), index=False)
    print(f"Enriched dataset successfully written to {output_path}")

if __name__ == "__main__":
    enrich_dataset(
        dataset_path=Path("dataset/tradingai_dataset.parquet"),
        screenshots_dir=Path("screenshots"),
        output_path=Path("dataset/tradingai_enriched_dataset.parquet")
    )
```

---

## 5. Technical Considerations & Edge Cases

* **VRAM Limitations**: Local Vision-Language Models can be resource-intensive. If your computer does not have a dedicated GPU with at least 8-12GB VRAM, using standard `llama3.2-vision` can take up to 30-60 seconds per trade. For lower-end hardware, we should configure the system to fall back to `moondream` (extremely lightweight, < 1GB VRAM).
* **Malformed JSON Output**: LLMs sometimes output conversational text around the requested JSON blocks. The parser should use strict regex extraction or use Ollama's native JSON schema parameter (`format="json"`) to ensure error-free loading.
* **Overfitting Warning**: AI scores are opinions based on technical patterns. They are incredibly useful features, but downstream machine learning models should combine them with hard tabular stats (spread, volume, duration) rather than relying solely on AI scores.
* **Image Downscaling**: Large screenshots (e.g., 1080p or 4K) can exceed the maximum token length of vision encoders. The client wrapper should automatically check and downscale image sizes to optimal processing dimensions (e.g., `672x672` or `1280x720`) before querying Ollama to maximize processing speed.

---

## 6. Success Criteria

- [ ] Successful installation of Ollama on the local host machine.
- [ ] Retrieval and validation of the selected model (e.g., `llama3.2-vision` or `moondream`).
- [ ] Clean programmatic extraction of visual chart paths from the compiled trade dataset.
- [ ] Safe JSON extraction of model responses without script failure.
- [ ] Generation of an enriched dataset file `dataset/tradingai_enriched_dataset.parquet` including quality scores and structural critique columns.
