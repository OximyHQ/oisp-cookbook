/**
 * Simple OpenAI API call for OISP testing.
 *
 * This makes a single, non-streaming chat completion request.
 */

const OpenAI = require("openai");

async function main() {
  // Get API key from environment
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    console.error("ERROR: OPENAI_API_KEY not set");
    process.exit(1);
  }

  console.log("Creating OpenAI client...");
  const client = new OpenAI({ apiKey });

  console.log("Making chat completion request...");
  const response = await client.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "You are a helpful assistant." },
      { role: "user", content: "Say 'Hello OISP!' and nothing else." },
    ],
    max_tokens: 50,
  });

  // Print response
  const content = response.choices[0].message.content;
  console.log(`Response: ${content}`);

  // Print usage
  const usage = response.usage;
  console.log(
    `Tokens - Input: ${usage.prompt_tokens}, Output: ${usage.completion_tokens}, Total: ${usage.total_tokens}`
  );

  console.log("Done!");
}

main().catch((err) => {
  console.error("Error:", err);
  process.exit(1);
});
