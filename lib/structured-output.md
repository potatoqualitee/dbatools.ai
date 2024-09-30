
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

# Docs

## API Reference

### Structured Outputs

#### Introduction

JSON is one of the most widely used formats in the world for applications to exchange data. Structured Outputs is a feature that ensures the model will always generate responses that adhere to your supplied JSON Schema, so you don't need to worry about the model omitting a required key or hallucinating an invalid enum value.

#### Benefits of Structured Outputs

Some benefits of Structured Outputs include:

- **Reliable type-safety:** No need to validate or retry incorrectly formatted responses.
- **Explicit refusals:** Safety-based model refusals are now programmatically detectable.
- **Simpler prompting:** No need for strongly worded prompts to achieve consistent formatting.

In addition to supporting JSON Schema in the REST API, the OpenAI SDKs for Python and JavaScript make it easy to define object schemas using Pydantic and Zod, respectively. Below, you can see how to extract information from unstructured text that conforms to a schema defined in code.

### Getting a Structured Response

#### Node.js Example

```javascript
import OpenAI from "openai";
import { zodResponseFormat } from "openai/helpers/zod";
import { z } from "zod";

const openai = new OpenAI();

const CalendarEvent = z.object({
  name: z.string(),
  date: z.string(),
  participants: z.array(z.string()),
});

const completion = await openai.beta.chat.completions.parse({
  model: "gpt-4o-2024-08-06",
  messages: [
    { role: "system", content: "Extract the event information." },
    { role: "user", content: "Alice and Bob are going to a science fair on Friday." },
  ],
  response_format: zodResponseFormat(CalendarEvent, "event"),
});

const event = completion.choices[0].message.parsed;
```

### Supported Models

Structured Outputs are available in our latest large language models, starting with GPT-4o:

- `gpt-4o-mini-2024-07-18` and later
- `gpt-4o-2024-08-06` and later

Older models like `gpt-4-turbo` and earlier may use JSON mode instead.

### When to Use Structured Outputs

Structured Outputs is available in two forms in the OpenAI API:

1. **When using function calling:** Useful when building an application that bridges the models and functionality of your application, such as querying a database or interacting with a UI.
2. **When using a `json_schema` response format:** Suitable when you want a structured schema for the model's responses to users, not when the model calls a tool.

**Summary:**

- Use function calling if you're connecting the model to tools, functions, or data.
- Use structured `response_format` to structure the model's output when it responds to the user.

### Structured Outputs vs. JSON Mode

Structured Outputs is the evolution of JSON mode. While both ensure valid JSON is produced, only Structured Outputs ensure schema adherence. Both Structured Outputs and JSON mode are supported in the Chat Completions API, Assistants API, Fine-tuning API, and Batch API.

| Feature                       | Structured Outputs | JSON Mode                 |
|-------------------------------|--------------------|---------------------------|
| Outputs valid JSON            | Yes                | Yes                       |
| Adheres to schema             | Yes                | No                        |
| Compatible models             | `gpt-4o-mini`, `gpt-4o-2024-08-06`, and later | `gpt-3.5-turbo`, `gpt-4-*`, `gpt-4o-*` |
| Enabling                      | `response_format: { type: "json_schema", json_schema: {"strict": true, "schema": ...} }` | `response_format: { type: "json_object" }` |

### Examples

#### Chain of Thought: Math Tutoring

You can ask the model to output an answer in a structured, step-by-step way to guide the user through the solution.

##### Node.js Example

```javascript
import OpenAI from "openai";
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";

const openai = new OpenAI();

const Step = z.object({
  explanation: z.string(),
  output: z.string(),
});

const MathReasoning = z.object({
  steps: z.array(Step),
  final_answer: z.string(),
});

const completion = await openai.beta.chat.completions.parse({
  model: "gpt-4o-2024-08-06",
  messages: [
    { role: "system", content: "You are a helpful math tutor. Guide the user through the solution step by step." },
    { role: "user", content: "How can I solve 8x + 7 = -23?" },
  ],
  response_format: zodResponseFormat(MathReasoning, "math_reasoning"),
});

const math_reasoning = completion.choices[0].message.parsed;
```

##### Example Response

```json
{
  "steps": [
    {
      "explanation": "Start with the equation 8x + 7 = -23.",
      "output": "8x + 7 = -23"
    },
    {
      "explanation": "Subtract 7 from both sides to isolate the term with the variable.",
      "output": "8x = -23 - 7"
    },
    {
      "explanation": "Simplify the right side of the equation.",
      "output": "8x = -30"
    },
    {
      "explanation": "Divide both sides by 8 to solve for x.",
      "output": "x = -30 / 8"
    },
    {
      "explanation": "Simplify the fraction.",
      "output": "x = -15 / 4"
    }
  ],
  "final_answer": "x = -15 / 4"
}
```

### How to Use Structured Outputs with `response_format`

1. **Define your object.**
2. **Supply your object in the API call.**
3. **Handle edge cases.**
4. **Use the generated structured data in a type-safe way.**

#### Refusals with Structured Outputs

When using Structured Outputs with user-generated input, OpenAI models may occasionally refuse to fulfill the request for safety reasons. The API response will include a new field called `refusal` to indicate that the model refused to fulfill the request.

##### Node.js Example

```javascript
const Step = z.object({
  explanation: z.string(),
  output: z.string(),
});

const MathReasoning = z.object({
  steps: z.array(Step),
  final_answer: z.string(),
});

const completion = await openai.beta.chat.completions.parse({
  model: "gpt-4o-2024-08-06",
  messages: [
    { role: "system", content: "You are a helpful math tutor. Guide the user through the solution step by step." },
    { role: "user", content: "How can I solve 8x + 7 = -23?" },
  ],
  response_format: zodResponseFormat(MathReasoning, "math_reasoning"),
});

const math_reasoning = completion.choices[0].message;

if (math_reasoning.refusal) {
  console.log(math_reasoning.refusal);
} else {
  console.log(math_reasoning.parsed);
}
```

#### Example API Response for a Refusal

```json
{
  "id": "chatcmpl-9nYAG9LPNonX8DAyrkwYfemr3C8HC",
  "object": "chat.completion",
  "created": 1721596428,
  "model": "gpt-4o-2024-08-06",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "refusal": "I'm sorry, I cannot assist with that request."
      },
      "logprobs": null,
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 81,
    "completion_tokens": 11,
    "total_tokens": 92
  },
  "system_fingerprint": "fp_3407719c7f"
}
```

### Tips and Best Practices

- **Handling user-generated input:** Ensure your prompt includes instructions on how to handle situations where the input cannot result in a valid response.
- **Handling mistakes:** Adjust instructions, provide examples, or split tasks into simpler subtasks if mistakes occur. Refer to the prompt engineering guide for more guidance.
- **Avoid JSON schema divergence:** Use native Pydantic/Zod SDK support to prevent divergence.
- **Supported schemas:** Structured Outputs support a subset of the JSON Schema language, including types like String, Number, Boolean, Integer, Object, Array, and Enum.

#### Key Ordering

When using Structured Outputs, outputs will be produced in the same order as the ordering of keys in the schema.

### Handling Edge Cases

- Use structured refusals to handle cases where the model declines a request.
- Include instructions on how to respond to incompatible inputs.
- Adjust schema to handle exceptions gracefully.

### Resources

To learn more about Structured Outputs, consider exploring the following:

- **Introductory cookbook on Structured Outputs**
- **Building multi-agent systems with Structured Outputs**

### Supported Schemas

Structured Outputs support a subset of the JSON Schema language, which includes the following types:

- **String**
- **Number**
- **Boolean**
- **Integer**
- **Object**
- **Array**
- **Enum**
- **anyOf** (Note: Root objects must not use `anyOf`)

#### Limitations and Requirements

1. **Root Object Requirement:** The root level object of a schema must be an `object`, and not use `anyOf`. Patterns like discriminated unions that produce `anyOf` at the top level will not work.

2. **Required Fields:** All fields or function parameters must be specified as required. While all fields must be required, you can emulate optional parameters using a union type with `null`.

    ```json
    {
        "type": "object",
        "properties": {
            "location": {
                "type": "string"
            },
            "unit": {
                "type": ["string", "null"],
                "enum": ["F", "C"]
            }
        },
        "required": ["location", "unit"]
    }
    ```

3. **Nesting and Size Limitations:** Schemas may have up to 100 object properties total, with a maximum of 5 levels of nesting.

4. **`additionalProperties`:** This must always be set to `false` in objects to ensure only specified keys/values are generated.

    ```json
    {
        "type": "object",
        "properties": {
            "location": {
                "type": "string"
            },
            "unit": {
                "type": "string",
                "enum": ["F", "C"]
            }
        },
        "additionalProperties": false,
        "required": ["location", "unit"]
    }
    ```

5. **Unsupported Type-Specific Keywords:** Notable keywords that are not supported include:
    - For strings: `minLength`, `maxLength`, `pattern`, `format`
    - For numbers: `minimum`, `maximum`, `multipleOf`
    - For objects: `patternProperties`, `unevaluatedProperties`, `propertyNames`, `minProperties`, `maxProperties`
    - For arrays: `unevaluatedItems`, `contains`, `minContains`, `maxContains`, `minItems`, `maxItems`, `uniqueItems`

6. **AnyOf Requirement:** Nested schemas within `anyOf` must each be valid JSON Schema per the supported subset.

### Examples of Supported Schemas

#### AnyOf Schema

```json
{
    "type": "object",
    "properties": {
        "item": {
            "anyOf": [
                {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string"
                        },
                        "age": {
                            "type": "number"
                        }
                    },
                    "additionalProperties": false,
                    "required": ["name", "age"]
                },
                {
                    "type": "object",
                    "properties": {
                        "number": {
                            "type": "string"
                        },
                        "street": {
                            "type": "string"
                        },
                        "city": {
                            "type": "string"
                        }
                    },
                    "additionalProperties": false,
                    "required": ["number", "street", "city"]
                }
            ]
        }
    },
    "additionalProperties": false,
    "required": ["item"]
}
```

#### Use of Definitions

Definitions can be used to define subschemas that are referenced throughout the main schema.

```json
{
    "type": "object",
    "properties": {
        "steps": {
            "type": "array",
            "items": {
                "$ref": "#/$defs/step"
            }
        },
        "final_answer": {
            "type": "string"
        }
    },
    "$defs": {
        "step": {
            "type": "object",
            "properties": {
                "explanation": {
                    "type": "string"
                },
                "output": {
                    "type": "string"
                }
            },
            "required": ["explanation", "output"],
            "additionalProperties": false
        }
    },
    "required": ["steps", "final_answer"],
    "additionalProperties": false
}
```

### Recursive Schemas

#### Example Using `#` for Root Recursion

```json
{
    "name": "ui",
    "description": "Dynamically generated UI",
    "strict": true,
    "schema": {
        "type": "object",
        "properties": {
            "type": {
                "type": "string",
                "enum": ["div", "button", "header", "section", "field", "form"]
            },
            "label": {
                "type": "string"
            },
            "children": {
                "type": "array",
                "items": {
                    "$ref": "#"
                }
            },
            "attributes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string"
                        },
                        "value": {
                            "type": "string"
                        }
                    },
                    "additionalProperties": false,
                    "required": ["name", "value"]
                }
            }
        },
        "required": ["type", "label", "children", "attributes"],
        "additionalProperties": false
    }
}
```

#### Explicit Recursion Example

```json
{
    "type": "object",
    "properties": {
        "linked_list": {
            "$ref": "#/$defs/linked_list_node"
        }
    },
    "$defs": {
        "linked_list_node": {
            "type": "object",
            "properties": {
                "value": {
                    "type": "number"
                },
                "next": {
                    "anyOf": [
                        { "$ref": "#/$defs/linked_list_node" },
                        { "type": "null" }
                    ]
                }
            },
            "additionalProperties": false,
            "required": ["value", "next"]
        }
    },
    "additionalProperties": false,
    "required": ["linked_list"]
}
```

### JSON Mode

JSON mode is a more basic version of the Structured Outputs feature. While JSON mode ensures that model output is valid JSON, Structured Outputs reliably matches the model's output to the schema you specify. We recommend using Structured Outputs if it is supported for your use case.

#### Important Notes for JSON Mode

- Always instruct the model to produce JSON via some message in the conversation, for example, in your system message.
- JSON mode will not guarantee the output matches any specific schema, only that it is valid JSON and parses without errors. Use Structured Outputs to ensure schema adherence.
- Handle edge cases where the model output might not be a complete JSON object.

#### Example of Enabling JSON Mode

To enable JSON mode with the Chat Completions or Assistants API, set the `response_format` to:

```json
{ "type": "json_object" }
```

### Handling Edge Cases

- **Resources:** To learn more about Structured Outputs, we recommend browsing the following resources:
    - **Introductory cookbook on Structured Outputs**
    - **How to build multi-agent systems with Structured Outputs**

### Conclusion

Structured Outputs provide a robust way to ensure model responses adhere to a predefined JSON Schema, offering enhanced safety, consistency, and reliability. When working with models that support this feature, it is strongly recommended to use Structured Outputs over JSON mode to leverage the benefits of schema adherence. By following best practices and leveraging the examples provided, developers can effectively integrate structured responses into their applications, making data exchange more reliable and structured.