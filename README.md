# jira-link-updater

Ever add a JIRA ticket id to an Issue or Pull Request and wish it would link directly to the ticket. This GitHub App replaces JIRA IDs in comments with a URL to the JIRA issue. :tada:

## End User Instructions

Instructions to configure GitHub.com repositories.

1. Visit [jira-link-updater](https://github.com/apps/jira-link-updater) app and grant it access to your repositories.
1. Add a configuration file to each repository to set a path to your JIRA instance.
    - Filename: `JIRA_SETTINGS.yaml`
    - Example:
    ```
    jira_hostname: "https://[SERVERNAME].atlassian.net"
    ```
1. New Pull Requests and Issue comments with the format `[XYZ-123]` will be replaced with a hyperlink to the JIRA issue.

## GitHub Enterprise Instructions
1. Set up a new [GitHub App](https://developer.github.com/apps/) on your GitHub Enterprise +2.12 instance.
    - Issues permissions - **Read and Write**
    - Pull requests permissions - **Read and Write**
    - **Subscribe to events** 
        - Issues
        - Pull request event subscription
        - Issue Comments
1. Host this application on a network that allows traffic to/from the GitHub Enterprise instance. `ruby server.rb`
1. Install the App and grant it access to your repositories.
1. Add comments to Issues and Pull Requests in the format `[XYZ-123]` to be replaced with a hyperlink 
