require 'sinatra'
require 'jwt'
require 'rest_client'
require 'json'
require 'octokit'
require 'yaml'

$stdout.sync = true

begin
  yml = File.open('ghe-tommy.yaml')
  contents = YAML.load(yml)

  GITHUB_APP_KEY = File.read(contents["private_key"])
  GITHUB_APP_ID = contents["app_id"]
  JIRA_HOSTNAME = contents["jira_hostname"]
  if contents.has_key?('github_hostname')
    GITHUB_HOSTNAME = contents["github_hostname"]
  else
    GITHUB_HOSTNAME = ""
  end
rescue Exception => e
  begin
    GITHUB_APP_KEY = ENV.fetch("GITHUB_APP_KEY")
    GITHUB_APP_ID = ENV.fetch("GITHUB_APP_ID")
    GITHUB_HOSTNAME = ENV.fetch("GITHUB_HOSTNAME", NULL)
    JIRA_HOSTNAME = ENV.fetch("JIRA_HOSTNAME")
  rescue KeyError
    $stderr.puts "To run this script, please set the following environment variables:"
    $stderr.puts "- GITHUB_APP_KEY: GitHub App Private Key"
    $stderr.puts "- GITHUB_APP_ID: GitHub App ID"
    $stderr.puts "- JIRA_HOSTNAME: FQDN to a JIRA instance"
    exit 1
  end
end

if GITHUB_HOSTNAME != ''
  GITHUB_API_ENDPOINT = "#{GITHUB_HOSTNAME}/api/v3"
  # Configure GitHub Enterprise
  Octokit.configure do |c|
    c.api_endpoint = GITHUB_API_ENDPOINT
    c.web_endpoint = GITHUB_HOSTNAME

    # Allow untrusted certificates in Development
    c.connection_options[:ssl] = { :verify => false }
  end
else
  GITHUB_API_ENDPOINT = "https://api.github.com"
end

# GitHub Apps in preview require Accept header
Octokit.default_media_type = "application/vnd.github.machine-man-preview+json"
client = Octokit::Client.new

post '/payload' do
  github_event = request.env['HTTP_X_GITHUB_EVENT']
  if github_event == "issue_comment"
    replace_comment(request.body.read)
  elsif github_event == "issues"
    replace_issue_body(request.body.read, "issue")
  elsif github_event == "pull_request"
    replace_issue_body(request.body.read, "pull_request")
  else
    puts "New event #{github_event}"
  end
end

# Parse text matching common JIRA ID strings. e.g. `[SENG-1234]`
# Returns updated text with URL to JIRA ticket or empty string
def update_comment(comment_text, jira_hostname)
  found_results = false
  comment_text.scan(/(?<full>\[(?<id>\w+\-\w+)\])/) do | text, id  |
    found_results = true
    jira_link = "[#{text}](#{jira_hostname}/browse/#{id})"
    # optionally test link....
    comment_text = comment_text.gsub(text, jira_link)
  end

  return found_results ? comment_text : ""
end

def get_jira_hostname(access_token, repo_fullname)
  client = Octokit::Client.new(access_token: access_token)
  result = client.contents(repo_fullname, :path => 'JIRA_SETTINGS.yaml')

  yaml_content = YAML.load(Base64.decode64(result[:content]))
  return yaml_content['jira_hostname']
end

# Replace JIRA IDs when an Issue or Pull Request is created
def replace_issue_body(request, event_type)

  webhook_json = JSON.parse(request)
  webhook_action = webhook_json["action"]

  # Ignore Updated or Deleted comments
  if webhook_action == "opened"
    issue_body = webhook_json[event_type]["body"]

    repo_name = webhook_json["repository"]["full_name"]

    installation_id = webhook_json["installation"]["id"]
    access_tokens_url = url = "#{GITHUB_API_ENDPOINT}/installations/#{installation_id}/access_tokens"
    # Octokit does not support getting GitHub Enterprise access tokens
    access_token = get_app_token(access_tokens_url)
    jira_hostname = get_jira_hostname(access_token, repo_name)

    new_body = update_comment(issue_body, jira_hostname)

    if new_body != ""
      issue_number = webhook_json[event_type]["number"]


      if access_token != ""
        client = Octokit::Client.new(access_token: access_token )
        Octokit.default_media_type ="application/vnd.github.black-cat-preview"
        options = {
          body: new_body
        }
        update_result = client.update_issue(repo_name, issue_number, options)
        return 201
      end
    end
  end

  return 200
end

# Replace JIRA IDs when an Issue or Pull Request comment is created
def replace_comment(request)

  webhook_json = JSON.parse(request)
  webhook_action = webhook_json["action"]

  # Ignore Updated or Deleted comments
  if webhook_action == "created"
    issue_comment = webhook_json["comment"]["body"]
    repo_name = webhook_json["repository"]["full_name"]

    installation_id = webhook_json["installation"]["id"]
    access_tokens_url = "#{GITHUB_API_ENDPOINT}/installations/#{installation_id}/access_tokens"
    access_token = get_app_token(access_tokens_url)

    jira_hostname = get_jira_hostname(access_token, repo_name)
    new_comment = update_comment(issue_comment, jira_hostname)

    if new_comment != ""
      comment_id = webhook_json["comment"]["id"]

      if access_token != ""
        client = Octokit::Client.new(access_token: access_token )
        Octokit.default_media_type ="application/vnd.github.black-cat-preview"

        update_result = client.update_comment(repo_name, comment_id, new_comment)
        return 201
      end
    end
  end

  return 200
end


def get_jwt
  private_pem = GITHUB_APP_KEY
  private_key = OpenSSL::PKey::RSA.new(private_pem)

  payload = {
    # issued at time
    iat: Time.now.to_i,
    # JWT expiration time (10 minute maximum)
    exp: DateTime.now.new_offset('+00:10').to_time.to_i,
    # Integration's GitHub identifier
    iss: GITHUB_APP_ID
  }

  JWT.encode(payload, private_key, "RS256")
end

# TODO: Fix octokit.rb to allow generating token on GitHub Enterprise
def get_app_token(access_tokens_url)
  token = ""
  jwt = get_jwt
  headers = {
    authorization: "Bearer #{jwt}",
    accept: "application/vnd.github.machine-man-preview+json"
  }

  begin
    response = RestClient::Request.execute(
      :method => :post,
      :url => access_tokens_url,
      :headers => headers,
      :payload =>{},
      :verify_ssl => OpenSSL::SSL::VERIFY_NONE
    )
    app_token = JSON.parse(response)
    token = app_token["token"]
  rescue Exception => e
    puts e
    puts e.http_body
  end

  return token
end
