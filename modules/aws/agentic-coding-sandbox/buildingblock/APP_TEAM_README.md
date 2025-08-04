Agentic Coding Sandbox provides access to agentic coding tools like Claude, enabling developers to leverage AI for code generation and experimentation.

**Usage Motivation:**

This building block is designed for developers who want to leverage AI for code generation, experimentation, and other coding tasks. It provides a pre-configured environment with access to approved agentic coding tools, allowing developers to explore the capabilities of AI-assisted coding without managing the underlying infrastructure.

**Usage Examples:**

Use Claude (via AWS Bedrock) to generate code snippets for common tasks, speeding up development time. Use it with tools like [aider](https://aider.chat/) or [cline](https://github.com/cline/cline).


**Shared Responsibility:**

| Responsibility                        | Platform Team ✅ | Application Team ✅/❌ |
|--------------------------------------|----------------|----------------------|
| Provides access to approved agentic coding models (e.g., Claude Sonnet 3.7 via AWS Bedrock) | ✅             | ❌                   |
| Enforces policies to ensure compliance with meshcloud rules | ✅             | ❌                   |
| Evaluate model compliance with meshcloud rules and makes only checked models available | ✅             | ❌                   |
| Provides easy-to-use budget alerts      | ✅             | ❌                   |
| Monitors usage quota and costs           | ❌             | ✅                   |

## Accessing Models via AWS Bedrock

Before you can start using models like Claude AI, you need to request access to them within the AWS Bedrock console.

Please use the `eu-central-1` (Frankfurt) region preferably. You may also use `eu-south-2`(Spain) where more models are available.

Follow these steps:

1.  **Log in to the AWS Console:** Access the AWS Management Console. You can use the direct link from your meshStack tenant to open the AWS Management Console.
2.  **Navigate to Amazon Bedrock:** Search for "Bedrock" in the AWS service search bar and select "Amazon Bedrock".
3.  **Request Model Access following the [official instructions](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html):**
    *   In the left navigation pane, click on "Model access".
    *   You will see a list of available models. Locate "Claude" (or other models you wish to use).
    *   Click the "Request access" button next to the desired model(s).
    *   Review the terms and conditions, and then submit your request.
4.  **Wait for Approval:** AWS will review your request.  Approval times may vary. You can check the status of your request in the "Model access" section of the Bedrock console.

## Using the Bedrock API

Once your model access request is approved, you can start using the Bedrock API to interact with the models.

Configure your AWS credentials (e.g., using `aws configure` or setting environment variables) to allow your applications to authenticate with AWS.  Ensure your IAM role or user has the necessary permissions to invoke Bedrock models.

Here's a quick example of how to set up the correct sso session


Example with the right config values.

```shellsession
$ aws configure sso-session
SSO session name: meshcloud-prod
SSO start URL [https://meshcloud-prod.awsapps.com/start/#]:
SSO region [eu-central-1]:
SSO registration scopes [sso:account:access]:

$ aws sso login --sso-session meshcloud-prod
```

You then need to create an aws cli profile using this session pointing into your AWS Account. The quickest way is to just edit your `~/.aws/config` directly

```
[profile ai-sandbox]
sso_session = meshcloud-prod
sso_account_id = <your aws account number>
sso_role_name = AdministratorAccess
region = eu-central-1
``

Verify that it works using

```shellsession
$ aws bedrock list-foundation-models --profile ai-sandbox
```
