
# Introducing Structured Outputs in the API

We are introducing Structured Outputs in the API—model outputs now reliably adhere to developer-supplied JSON Schemas.

Last year at DevDay, we introduced JSON mode—a useful building block for developers looking to build reliable applications with our models. While JSON mode improves model reliability for generating valid JSON outputs, it does not guarantee that the model's response will conform to a particular schema. Today we're introducing Structured Outputs in the API, a new feature designed to ensure model-generated outputs will exactly match JSON Schemas provided by developers.

Generating structured data from unstructured inputs is one of the core use cases for AI in today's applications. Developers use the OpenAI API to build powerful assistants that have the ability to fetch data and answer questions via function calling, extract structured data for data entry, and build multi-step agentic workflows that allow LLMs to take actions. Developers have long been working around the limitations of LLMs in this area via open source tooling, prompting, and retrying requests repeatedly to ensure that model outputs match the formats needed to interoperate with their systems. Structured Outputs solves this problem by constraining OpenAI models to match developer-supplied schemas and by training our models to better understand complicated schemas.

On our evals of complex JSON schema following, our new model gpt-4o-2024-08-06 with Structured Outputs scores a perfect 100%. In comparison, gpt-4-0613 scores less than 40%.

### How to use Structured Outputs

We're introducing Structured Outputs in two forms in the API:

1. * * Function calling:** Structured Outputs via tools is available by setting `strict: true` within your function definition. This feature works with all models that support tools, including all models gpt-4-0613 and gpt-3.5-turbo-0613 and later. When Structured Outputs are enabled, model outputs will match the supplied tool definition.

2. * * Response format parameter:** Developers can now supply a JSON Schema via `json_schema`, a new option for the `response_format` parameter. This is useful when the model is not calling a tool, but rather, responding to the user in a structured way. This feature works with our newest GPT-4o models: gpt-4o-2024-08-06, released today, and gpt-4o-mini-2024-07-18. When a `response_format` is supplied with `strict: true`, model outputs will match the supplied schema.

### Safe Structured Outputs

Safety is a top priority for OpenAI—the new Structured Outputs functionality will abide by our existing safety policies and will still allow the model to refuse an unsafe request. To make development simpler, there is a new refusal string value on API responses which allows developers to programmatically detect if the model has generated a refusal instead of output matching the schema. When the response does not include a refusal and the model's response has not been prematurely interrupted (as indicated by `finish_reason`), then the model's response will reliably produce valid JSON matching the supplied schema.

### Native SDK support

Our Python and Node SDKs have been updated with native support for Structured Outputs. Supplying a schema for tools or as a response format is as easy as supplying a Pydantic or Zod object, and our SDKs will handle converting the data type to a supported JSON schema, deserializing the JSON response into the typed data structure automatically, and parsing refusals if they arise.

The following examples show native support for Structured Outputs with function calling.

### Additional use cases

Developers frequently use OpenAI's models to generate structured data for various use cases. Some additional examples include:

- **Dynamically generating user interfaces based on the user's intent**: For example, developers can use Structured Outputs to create code- or UI-generating applications.

- * * Separating a final answer from supporting reasoning or additional commentary**: It can be useful to give the model a separate field for chain of thought to improve the final quality of the response.

- * * Extracting structured data from unstructured data**: For example, instructing the model to extract things like to-dos, due dates, and assignments from meeting notes.

### Under the hood

We took a two-part approach to improving reliability for model outputs that match JSON Schema. First, we trained our newest model gpt-4o-2024-08-06 to understand complicated schemas and how best to produce outputs that match them. However, model behavior is inherently non-deterministic—despite this model's performance improvements (93% on our benchmark), it still did not meet the reliability that developers need to build robust applications. So we also took a deterministic, engineering-based approach to constrain the model's outputs to achieve 100% reliability.

### Constrained decoding

Our approach is based on a technique known as constrained sampling or constrained decoding. By default, when models are sampled to produce outputs, they are entirely unconstrained and can select any token from the vocabulary as the next output. This flexibility is what allows models to make mistakes; for example,they are generally free to sample a curly brace token at any time, even when that would not produce valid JSON. In order to force valid outputs, we constrain our models to only tokens that would be valid according to the supplied schema, rather than all available tokens.

### Alternate approaches

Alternate approaches to this problem often use finite state machines (FSMs) or regexes (generally implemented with FSMs) for constrained decoding. These function similarly in that they dynamically update which tokens are valid after each token is produced, but they have some key differences from the CFG approach.

### Limitations and restrictions

There are a few limitations to keep in mind when using Structured Outputs:

- Structured Outputs allows only a subset of JSON Schema.
- The first API response with a new schema will incur additional latency, but subsequent responses will be fast with no latency penalty.
- The model can fail to follow the schema if the model chooses to refuse an unsafe request.
- The model can fail to follow the schema if the generation reaches max_tokens or another stop condition before finishing.
- Structured Outputs doesn't prevent all kinds of model mistakes.
- Structured Outputs is not compatible with parallel function calls.
- JSON Schemas supplied with Structured Outputs aren't Zero Data Retention (ZDR) eligible.

### Availability

Structured Outputs is generally available today in the API.

Structured Outputs with function calling is available on all models that support function calling in the API. This includes our newest models (gpt-4o,gpt-4o-mini), all models after and including gpt-4-0613 and gpt-3.5-turbo-0613, and any fine-tuned models that support function calling. This functionality is available on the Chat Completions API, Assistants API, and Batch API. Structured Outputs with function calling is also compatible with vision inputs.

Structured Outputs with response formats is available on gpt-4o-mini and gpt-4o-2024-08-06 and any fine tunes based on these models. This functionality is available on the Chat Completions API, Assistants API, and Batch API. Structured Outputs with response formats is also compatible with vision inputs.

By switching to the new gpt-4o-2024-08-06, developers save 50% on inputs ($2.50 / 1M input tokens) and 33% on outputs ($10.00 / 1M output tokens) compared to gpt-4o-2024-05-13.

To start using Structured Outputs, check out our docs.
