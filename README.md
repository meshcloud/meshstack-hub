# meshStack Hub

The meshStack Hub provides a collection of ready-to-use Terraform modules that can directly be
used in your meshStack as Building Blocks.

See what's out there on [hub.meshcloud.io](https://hub.meshcloud.io)!

![readme IMG](https://github.com/meshcloud/meshstack-hub/raw/main/.github/readme_img.png)

## 📦 Available Modules

We recommend looking at all available modules on [hub.meshcloud.io](https://hub.meshcloud.io).
Alternatively, you can find all available modules in the `modules/` directory separated by platform.

Example modules:

AWS S3 Module – Provision S3 buckets with encryption and logging.

## 🏢️ Structure

All Terraform modules are listed in the `modules/` directory.
This directory is split into subdirectories for each platform.
In a platform's directory, you will find all modules that are available for that platform.

A single module is structured as follows:

```
module_name/
    buildingblock/ -- This is the *actual* Terraform module that provisions resources for application teams.
        main.tf
        provider.tf
        outputs.tf
        variables.tf
        README.md -- This explains the module and how to use it from a platform engineering perspective.
        APP_TEAM_README.md -- This explains the module and how to use it from an application team perspective.
        logo.png -- This is the logo that is shown in the meshStack Hub and in the meshStack UI (if imported).
    backplane/ -- This is the Terraform code that provisions all supporting resources such as roles & techical users.
        <... Terraform files ...>
        README.md -- This explains the backplane module and how to use it. (optional)
```

## 🔧 Usage

Any module that you find works within meshStack.
The easiest option is to directly import the module from the [meshStack Hub](https://hub.meshcloud.io) into your own meshStack by clicking the "Import" button on the module page.

Refer to each module's README.md for specific usage instructions such as needed input variables.

## Community, Discussion & Support

The meshStack Hub is a 🌤️ [cloudfoundation.org community](https://cloudfoundation.org/?ref=github-collie-cli) project.
Reach out to us on the [cloudfoundation.org slack](http://cloudfoundationorg.slack.com).
