Your application reaches the large language models the platform team offers through one OpenAI-compatible endpoint. You get a virtual key and a model alias, and you point any OpenAI client at the gateway. The credentials of the model provider stay with the platform team, and your spend and rate limits are tracked against your own key.

## 🎯 When to use it

Use this building block when you:
- want to call a language model from your application without asking a provider for your own account and credential
- need to switch between models, or between providers, without changing your application code
- have to keep a budget per team or per application and see what has been spent
- want the same endpoint in every environment, so a change of model stays a configuration change

## 💡 Usage examples

**Example 1: Add a summarization feature**
Your service summarizes support tickets. You point the OpenAI SDK at the gateway URL, set your virtual key as the API key and ask for the model alias the platform team published. Nothing else in your code changes when the platform team moves that alias to another model.

**Example 2: Keep an experiment inside a budget**
Your team tries a retrieval feature and does not want to spend more than the budget it was given. The gateway counts every call against your virtual key and refuses further requests once the budget is used up, so an experiment cannot run away with cost.

## 🔧 How to use it

The gateway speaks the OpenAI API, so every OpenAI client works. Set the base URL to the gateway, including the `/v1` suffix, and use your virtual key as the API key.

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://litellm.litellm.svc.cluster.local:4000/v1",
    api_key="sk-your-virtual-key",
)

response = client.chat.completions.create(
    model="chat-large",
    messages=[{"role": "user", "content": "Summarize this ticket."}],
)
```

The same call with curl:

```bash
curl http://litellm.litellm.svc.cluster.local:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-your-virtual-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "chat-large", "messages": [{"role": "user", "content": "Hello"}]}'
```

Two things go wrong often enough to name them:

- **Keep the `/v1` in the base URL.** Without it every call answers "Not Found".
- **Use the alias, not the name of the model at the provider.** The gateway resolves the alias to a model and an endpoint, and the alias is the only name it accepts.

## 🔐 The admin console holds five users, and none of them is you

The gateway has a web console. It belongs to the platform team, and there is one console for the whole platform, because there is one gateway. You do not get a login to it, and this section explains why that is a rule and not an oversight.

**The console holds at most five users, platform-wide.** "User" here means one row in the gateway's user table. It is not your virtual key and it is not your team:

- Your virtual key costs **no** seat. The gateway creates no user when it issues a key.
- Your team on the gateway costs **no** seat either, with the setting this platform runs.
- A human who logs in to the console costs **one** seat, and there are five.

**The failure mode is worse than a refusal.** The sixth person to log in gets in and writes the sixth row. From that point every login attempt is refused, for all six of them, including the people who were working in the console the day before. Sessions already open keep working until they expire, and that is the whole grace period. Getting out of it means the platform team deleting a user from the gateway by hand, which is an incident rather than a ticket.

So there are two requests you should not make, however reasonable they look:

- **Do not ask to be added as a member of your team on the gateway.** That writes one row per member and takes one of the five seats. Your virtual key already carries your budget and your rate limit; a team membership adds nothing you need.
- **Do not ask for a user account on the gateway.** Same cost, same reason.

If you need to see what your key has spent, ask the platform team. A console login is not the way to get that number.

An Enterprise licence would lift the limit. This platform does not buy one, so the limit of five is a fixed property of the gateway you are using.

## 📊 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Run the gateway and its database | ✅ | ❌ |
| Hold the credentials of the model providers | ✅ | ❌ |
| Decide which models are available and under which alias | ✅ | ❌ |
| Issue virtual keys and set budgets and rate limits | ✅ | ❌ |
| Log in to the gateway's admin console | ✅ | ❌ |
| Keep the virtual key secret and rotate it when it leaks | ❌ | ✅ |
| Pick a model alias that fits the task and its cost | ❌ | ✅ |
| Handle rate limit and budget errors in the application | ❌ | ✅ |
| Decide what data the application sends to a model | ❌ | ✅ |
