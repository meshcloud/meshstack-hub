Your team gets a Langfuse instance of its own: a URL you log in to with your normal company account, a project that is already set up, and an API keypair you point a tracing client at. Everything your applications send — prompts, responses, latencies, token counts and cost — lands there and stays separate from every other team's data.

## 🎯 When to use it

Use this building block when you:
- want to see what your application actually sends to a language model and what comes back
- need to find out why an answer was wrong, slow or expensive, on the level of a single request
- want to compare prompt versions or models against each other with real traffic
- have to show what a feature costs per user, per request or per month

## 💡 Usage examples

**Example 1: Find out why one answer was wrong**
A user reports a bad answer. You open your Langfuse instance, search for the trace by its id and see the exact prompt, the retrieved documents and the model's reply. You change the prompt and compare the two versions on the same input.

**Example 2: Trace everything through the AI gateway**
Your applications already call models through the platform's LiteLLM gateway. The platform team points that gateway at your Langfuse instance, so every call shows up as a trace without you adding a single line of code.

## 🔧 How to use it

Point the Langfuse SDK at your instance with the keypair you were given:

```python
from langfuse import Langfuse

langfuse = Langfuse(
    host="https://langfuse-my-team.example.com",
    public_key="pk-lf-...",
    secret_key="sk-lf-...",
)
```

Two things go wrong often enough to name them:

- **The secret key is a credential.** It grants full read and write access to your project's traces. Keep it in your secret store and rotate it in the Langfuse UI when it leaks.
- **Traces keep whatever you put in them.** Prompts and responses are stored as they were sent, so a prompt that carries personal data ends up in the trace. Decide what your application sends before you turn tracing on.

## 📊 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Run the Langfuse instance and its four backends | ✅ | ❌ |
| Keep one team's data separate from another's | ✅ | ❌ |
| Provide the URL, the login and the first API keypair | ✅ | ❌ |
| Upgrade Langfuse and run its migrations | ✅ | ❌ |
| Back up the trace data | ✅ | ❌ |
| Decide what the application sends into a trace | ❌ | ✅ |
| Keep the secret key safe and rotate it when it leaks | ❌ | ✅ |
| Name traces, sessions and users so they can be found | ❌ | ✅ |
| Delete traces that must not be retained | ❌ | ✅ |
