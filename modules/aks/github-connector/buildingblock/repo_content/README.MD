# ${github_repo}

This GitHub repository was created via a meshStack building block and is automatically connected to both your development and production AKS namespaces through GitHub Actions. The GitHub Actions pipeline deploys the docker container (Dockerfile in your repository) from the repository to the respective AKS namespaces.

## Deploy Your Application
1. **Push your application code** including the required Dockerfile to this GitHub repository main branch
2. **Your app will be deployed automatically** to the development AKS namespace via GitHub Actions when a commit is pushed to the main branch
3. **To deploy to production**, create a pull request to merge the main branch into the release branch and merge the pull request. The GitHub Actions workflow will automatically deploy the application to the production AKS namespace.
4. **Monitor deployments** in the [GitHub Actions tab](/actions) of your repository
