import { OpenAI } from "@langchain/openai";

/**
 * localaiClient:
 * Example: connecting to LocalAI at localhost:8080
 * or via Docker DNS e.g. http://localai:8080/v1 if Compose is used.
 */
export const localaiClient = new OpenAI({
  // If LocalAI doesn't need an apiKey, omit or provide a dummy:
  apiKey: "dummy-localai-key",
  basePath: "http://localhost:8080/v1",
});

/**
 * getChatCompletion():
 * Example function that sends a prompt to LocalAI 
 * via LangChain's "call()" method.
 */
export async function getChatCompletion(prompt: string): Promise<string> {
  const response = await localaiClient.call(prompt, {
    // If needed: model: "gpt-3.5-turbo", maxTokens, etc.
  });
  return response;
}
