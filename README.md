# jira-link-updater

Ever add JIRA ticket id to an Issue or Pull Request and wish it would link directly to the ticket. This GitHub App replaces JIRA IDs in Issue comments with a URL to the JIRA issue.

## GitHub Enterprise Instructions

1. Set up a new [GitHub App](https://developer.github.com/apps/) on your GitHub Enterprise +2.12 instance.
    - Issues permissions - **Read and Write**
    - Pull requests permissions - **Read and Write**
    - Issues event subscription
    - Pull request event subscription
1. Host this application on a network that allows traffic to/from the GitHub Enterprise instance. `ruby server.rb`
1. Install the App and grant it access to your repositories.
1. Add comments to Issues and Pull Requests in the format `[XYZ-123]` to be replaced with a hyperlink 
