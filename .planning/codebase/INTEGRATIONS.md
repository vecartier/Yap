# External Integrations

**Analysis Date:** 2026-03-21

## APIs & External Services

**LLM Providers:**
- [OpenRouter](https://openrouter.ai/api/v1/chat/completions) - Cloud LLM API supporting GPT-4o, Claude, Gemini, etc.
  - SDK/Client: Custom `OpenRouterClient` (actor-based streaming client)
  - Auth: Bearer token via `settings.openRouterApiKey`
  - Endpoint: `https://openrouter.ai/api/v1/chat/completions`
  - Implementation: `OpenOats/Sources/OpenOats/Intelligence/OpenRouterClient.swift`

- [Ollama](http://localhost:11434/api/chat) - Local LLM runtime (OpenAI-compatible)
  - SDK/Client: Custom `OpenRouterClient` (reused for OpenAI-compatible endpoints)
  - Auth: Optional bearer token (nil for local)
  - Endpoint: Configurable, defaults to `http://localhost:11434/v1/chat/completions`
  - Implementation: `OpenOats/Sources/OpenOats/Intelligence/SuggestionEngine.swift`

- MLX (OpenAI-compatible) - On-device inference via MLX framework
  - SDK/Client: Custom `OpenRouterClient`
  - Endpoint: Configurable MLX server URL
  - Implementation: `OpenOats/Sources/OpenOats/Intelligence/SuggestionEngine.swift`

- OpenAI-Compatible Endpoints - Generic `/v1/chat/completions` and `/v1/embeddings` support
  - Providers: llama.cpp, llamaswap, LiteLLM, vLLM
  - SDK/Client: Custom `OpenRouterClient`
  - Implementation: `OpenOats/Sources/OpenOats/Intelligence/SuggestionEngine.swift`

**Embeddings & Semantic Search:**
- [Voyage AI](https://api.voyageai.com/v1) - Cloud embeddings and reranking
  - SDK/Client: Custom `VoyageClient` (actor-based)
  - Auth: Bearer token via `settings.voyageAiApiKey`
  - Endpoints:
    - `/embeddings` - Convert text chunks to vector embeddings (model: voyage-4-lite, dimensions: 256)
    - `/rerank` - Rerank search results by relevance (model: rerank-2.5-lite)
  - Implementation: `OpenOats/Sources/OpenOats/Intelligence/VoyageClient.swift`
  - Rate limit handling: Auto-retry with 20s backoff on HTTP 429

- Ollama Embeddings - Local embeddings via `/v1/embeddings` endpoint
  - SDK/Client: Custom `OllamaEmbedClient` (actor-based)
  - Auth: Optional bearer token
  - Endpoint: Configurable Ollama base URL
  - Implementation: `OpenOats/Sources/OpenOats/Intelligence/OllamaEmbedClient.swift`

- OpenAI-Compatible Embeddings - Generic `/v1/embeddings` support
  - Implementation: `OpenOats/Sources/OpenOats/Intelligence/SuggestionEngine.swift`

## Data Storage

**Local Storage Only:**
- No cloud database integration
- Session transcripts stored as JSONL files in `~/Library/Application Support/OpenOats/sessions/`
- Metadata sidecars alongside session files
- Knowledge base chunks indexed locally (in-memory + disk cache)

**File System Structure:**
- Session store: `AppSettings` uses FileManager API
- Implementation: `SessionStore` actor in `OpenOats/Sources/OpenOats/Storage/SessionStore.swift`
- Session files auto-created with ISO8601 timestamp naming: `session_YYYY-MM-DD_HH-mm-ss`

## Authentication & Identity

**Auth Provider:**
- None for core app functionality
- Custom: User provides API keys for external services
  - OpenRouter API key stored in app preferences
  - Voyage AI API key stored in app preferences
  - No user account system required

**Key Management:**
- API keys stored in macOS Keychain via Security framework
- Implementation: `AppSettings` class uses `Codable` + local persistence
- No centralized auth backend

## Monitoring & Observability

**Error Tracking:**
- None (local-first application)

**Logs:**
- In-process stderr logging via `print()` statements
- Example: SuggestionEngine logs invalid LLM URLs to console
- Session transcripts auto-logged to JSONL files for audit trail

## CI/CD & Deployment

**Hosting:**
- GitHub releases page - DMG distribution
- Homebrew Cask repository - `yazinsai/openoats`

**CI Pipeline:**
- GitHub Actions workflows in `.github/workflows/` (present but not detailed)
- Build script: `./scripts/build_swift_app.sh`

**Update Mechanism:**
- Sparkle framework handles auto-updates
- Application checks for updates via Sparkle appcast (endpoint not exposed in code)

## Environment Configuration

**Required env vars / settings:**
- `OPENROUTER_API_KEY` - For cloud LLM via OpenRouter
- `VOYAGE_AI_API_KEY` - For Voyage AI embeddings/reranking
- `OLLAMA_BASE_URL` - For local Ollama (defaults to `http://localhost:11434`)
- `MLX_BASE_URL` - For MLX local inference
- `OPENAI_LLM_BASE_URL` - For OpenAI-compatible endpoint
- `OPENAI_LLM_API_KEY` - Optional auth for OpenAI-compatible endpoint

**Secrets location:**
- Stored in user preferences (Application Support directory)
- No `.env` file pattern used
- macOS Keychain integration available but not currently used

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Model Downloads

**First-Run Downloads:**
- WhisperKit speech models (~600 MB total)
  - Base variant: ~142 MB
  - Small variant: ~244 MB
- Downloads to `~/Library/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`
- Parakeet TDT v2 / v3 models downloaded on-demand via Ollama
- Qwen3 ASR 0.6B downloaded on-demand via Ollama

**Local Model Storage:**
- Hugging Face cache directory: `~/Library/Documents/huggingface/models/`
- WhisperKit-specific: `whisperkit-coreml` subdirectory
- Implementation: `WhisperKitBackend.clearModelCache()` in `OpenOats/Sources/OpenOats/Transcription/WhisperKitBackend.swift`

## Knowledge Base Integration

**File Input:**
- Reads `.md` (Markdown) and `.txt` (plain text) files from user-specified folder
- No API integration required
- Chunked and embedded locally or via remote API

**Chunking & Indexing:**
- Implemented by `KnowledgeBase` class (`OpenOats/Sources/OpenOats/Intelligence/KnowledgeBase.swift`)
- Supports caching of embeddings locally

**Search:**
- Semantic search via embeddings + optional reranking
- Returns top-K relevant chunks to LLM context window

---

*Integration audit: 2026-03-21*
