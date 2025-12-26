#!/usr/bin/env node
/**
 * NVM Node.js Edge Case Example
 *
 * This script makes a simple OpenAI API call.
 * When run with NVM-installed Node.js, the OISP Sensor may not
 * capture the SSL traffic due to static OpenSSL linking.
 */

const OpenAI = require("openai");

async function main() {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
        console.error("ERROR: OPENAI_API_KEY not set");
        process.exit(1);
    }

    console.log("=== NVM Node.js Edge Case Test ===");
    console.log();
    console.log("Node.js Version:", process.version);
    console.log("Node.js Path:", process.execPath);
    console.log();

    // Check if this looks like an NVM installation
    if (process.execPath.includes(".nvm")) {
        console.log("WARNING: This appears to be an NVM-installed Node.js");
        console.log("         SSL capture may not work due to static OpenSSL linking.");
        console.log();
    }

    console.log("Making OpenAI API call...");

    const client = new OpenAI({ apiKey });

    try {
        const response = await client.chat.completions.create({
            model: "gpt-4o-mini",
            messages: [
                {
                    role: "user",
                    content: "Say 'Hello from NVM Node.js!' in exactly those words."
                }
            ]
        });

        const content = response.choices[0].message.content;
        const usage = response.usage;

        console.log();
        console.log("Response:", content);
        console.log();
        console.log("Usage:");
        console.log("  Prompt tokens:", usage.prompt_tokens);
        console.log("  Completion tokens:", usage.completion_tokens);
        console.log("  Total tokens:", usage.total_tokens);
        console.log();
        console.log("API call completed successfully!");
        console.log();
        console.log("Check if the sensor captured this call:");
        console.log("  cat output/events.jsonl");

    } catch (error) {
        console.error("API call failed:", error.message);
        process.exit(1);
    }
}

main();
