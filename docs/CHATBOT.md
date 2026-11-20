# AI assistant (RAG) — `POST /api/v1/chat`

Backend-only; no app screen. Answers come from retrieval over `backend/src/CampusConnect.Api/knowledge/*.md` (BM25, in memory) plus the signed-in **student's own** latest 5 complaints, then Claude writes the reply (official Anthropic C# SDK).

## Configuration (environment, never committed)
| Variable | Meaning |
|---|---|
| `LLM_API_KEY` | Any OpenAI-compatible provider (free tiers: Groq, Google Gemini, OpenRouter). Enables `mode: "ai"`. Wins over `ANTHROPIC_API_KEY`. |
| `LLM_BASE_URL` | Default `https://api.groq.com/openai/v1`. Gemini: `https://generativelanguage.googleapis.com/v1beta/openai`. OpenRouter: `https://openrouter.ai/api/v1`. |
| `LLM_MODEL` | Default `llama-3.1-8b-instant` (Groq). |
| `ANTHROPIC_API_KEY` | Optional alternative (Claude). Used only when `LLM_API_KEY` is empty. Without it the endpoint still works and returns the best matching note (`mode: "retrieval"`). |
| `ANTHROPIC_MODEL` | Default `claude-haiku-5-5`. |
| `CHAT_MAX_TOKENS` | Default 700. |
| `Chat__PermitLimit` | Requests per minute per IP, default 20 (429 `RATE_LIMITED`). |

On the server add the variables to the systemd `EnvironmentFile`, then `sudo systemctl restart api`.

## Safety
Answers only from the retrieved notes and the caller's own complaints; other users' data is never sent; message ≤ 1000 chars; last 6 history turns; text in notes/messages is treated as data (prompt-injection rule in the system prompt). Add real university policies by editing the `.md` files in `knowledge/`.

## Demo (curl)
```bash
API=http://13.53.165.254/api/v1
TOKEN=$(curl -s $API/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"student@campusconnect.edu","password":"<SEED_PASSWORD>"}' | jq -r .token)
curl -s $API/chat -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"message":"How long until my complaint gets a response?"}' | jq
curl -s $API/chat -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"message":"What is the status of my latest complaint?"}' | jq
```
