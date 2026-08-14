The platform team runs one ClickHouse cluster for the whole AI platform, and your Langfuse instance stores its traces in it. You get a database and a user of your own inside that cluster, so no other team can read or change your data. You never connect to ClickHouse yourself: Langfuse does it for you.

## 🎯 When to use it

Use this building block when you:
- run the AI platform and need the column store that Langfuse writes traces, observations and scores to
- want one ClickHouse for every tenant instead of one cluster per team, because a cluster per team costs several gigabytes of memory each
- need a ClickHouse release that Langfuse v4 accepts, which the version bundled with the Langfuse chart is not

## 💡 Usage examples

**Example 1: A team gets a Langfuse instance**
Your team orders a Langfuse instance. The platform creates a database named after your team in the shared cluster and a user that can only touch that database. Your traces land there and stay separate from every other team's.

**Example 2: A trace query stays fast as volume grows**
Your application sends a few million spans a month. ClickHouse is a column store, so the dashboard queries that scan those spans stay fast without you tuning anything, and the platform team grows the volume when it fills up.

## 📊 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Run the ClickHouse operator and the cluster | ✅ | ❌ |
| Size the replicas, the memory and the volumes | ✅ | ❌ |
| Create a database and a scoped user per tenant | ✅ | ❌ |
| Hold the administrative credential | ✅ | ❌ |
| Upgrade ClickHouse and ClickHouse Keeper | ✅ | ❌ |
| Decide what the application sends to Langfuse | ❌ | ✅ |
| Keep the trace volume inside the agreed quota | ❌ | ✅ |
| Delete traces that must not be retained | ❌ | ✅ |
