# AI Providers

## Supported Providers
1. **OpenAI**: Compatible with `/v1/chat/completions` (GPT-4, GPT-3.5).
2. **Anthropic**: Supports `/v1/messages` (Claude 3).
3. **Local**: Placeholder for offline models (e.g., Llama.cpp).

## Provider Configuration
```swift
struct AIProviderConfig: Codable {
    let id: UUID
    var name: String
    var baseURL: String
    var apiKey: String // Stored in Keychain
    var defaultModel: String
    var timeout: TimeInterval = 30
}
```

## Redaction
- Regex patterns detect secrets (e.g., `API_KEY=...`).
- User can toggle redaction in settings.

## Error Handling
- Retry policy: 3 attempts with exponential backoff.
- Fallback to local provider if primary fails.