/** Minimal client for a self-hosted Ollama server's chat API. */

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface ChatOptions {
  format?: 'json';
  temperature?: number;
  signal?: AbortSignal;
}

function body(model: string, messages: ChatMessage[], stream: boolean, options: ChatOptions) {
  return JSON.stringify({
    model,
    messages,
    stream,
    format: options.format,
    // Ollama's default window (4096 on small GPUs) is smaller than an answer
    // prompt with sources, and it silently drops the start — the instructions.
    options: { temperature: options.temperature ?? 0.3, num_ctx: 8192 },
  });
}

export async function chat(baseUrl: string, model: string, messages: ChatMessage[], options: ChatOptions = {}): Promise<string> {
  const response = await fetch(`${baseUrl}/api/chat`, {
    method: 'POST',
    body: body(model, messages, false, options),
    signal: options.signal,
  });
  if (!response.ok) throw new Error(`Ollama responded ${response.status}`);
  const data = (await response.json()) as { message?: { content?: string } };
  return data.message?.content ?? '';
}

/** Yields the answer as it's generated (Ollama streams NDJSON lines). */
export async function* chatStream(
  baseUrl: string,
  model: string,
  messages: ChatMessage[],
  options: ChatOptions = {},
): AsyncGenerator<string> {
  const response = await fetch(`${baseUrl}/api/chat`, {
    method: 'POST',
    body: body(model, messages, true, options),
    signal: options.signal,
  });
  if (!response.ok || !response.body) throw new Error(`Ollama responded ${response.status}`);

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffered = '';
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buffered += decoder.decode(value, { stream: true });
    const lines = buffered.split('\n');
    buffered = lines.pop() ?? '';
    for (const line of lines) {
      if (!line.trim()) continue;
      const chunk = JSON.parse(line) as { message?: { content?: string }; error?: string };
      if (chunk.error) throw new Error(chunk.error);
      if (chunk.message?.content) yield chunk.message.content;
    }
  }
}

/** One vector per input, in order (Ollama's batch embed endpoint). */
export async function embed(baseUrl: string, model: string, input: string[], signal?: AbortSignal): Promise<number[][]> {
  const response = await fetch(`${baseUrl}/api/embed`, {
    method: 'POST',
    body: JSON.stringify({ model, input }),
    signal,
  });
  if (!response.ok) throw new Error(`Ollama embed responded ${response.status}`);
  const data = (await response.json()) as { embeddings?: number[][] };
  if (data.embeddings?.length !== input.length) throw new Error('Ollama returned the wrong number of embeddings');
  return data.embeddings;
}
