require 'sinatra'
require 'jwt'
require 'rest_client'
require 'json'
require 'active_support/all'
require 'octokit'
require 'yaml'

$stdout.sync = true

begin
  yml = File.open('ghe-tommy.yaml')
  contents = YAML.load(yml)
  # Load from YAML file
  GITHUB_HOSTNAME = "https://10.100.198.128/"

  GITHUB_CLIENT_ID = contents["client_id"]
  GITHUB_CLIENT_SECRET = contents["client_secret"]
  GITHUB_APP_KEY = File.read(contents["private_key"])
  GITHUB_APP_ID = contents["app_id"]
#  GITHUB_HOSTNAME = contents["github_hostname"]
rescue Exception => e
  begin
    GITHUB_CLIENT_ID = ENV.fetch("GITHUB_CLIENT_ID")
    GITHUB_CLIENT_SECRET =  ENV.fetch("GITHUB_CLIENT_SECRET")
    GITHUB_APP_KEY = ENV.fetch("GITHUB_APP_KEY")
    GITHUB_APP_ID = ENV.fetch("GITHUB_APP_ID")
    # Load from YAML file
    # GITHUB_HOSTNAME = ENV.fetch("GITHUB_APP_ID")
  rescue KeyError
    $stderr.puts "To run this script, please set the following environment variables:"
    $stderr.puts "- GITHUB_CLIENT_ID: GitHub Developer Application Client ID"
    $stderr.puts "- GITHUB_CLIENT_SECRET: GitHub Developer Application Client Secret"
    $stderr.puts "- GITHUB_APP_KEY: GitHub App Private Key"
    $stderr.puts "- GITHUB_APP_ID: GitHub App ID"
    exit 1
  end
end


Octokit.configure do |c|
  c.api_endpoint = "#{GITHUB_HOSTNAME}/api/v3/"
  c.web_endpoint = GITHUB_HOSTNAME
  c.auto_paginate = true
end

Octokit.default_media_type = "application/vnd.github.machine-man-preview+json"
client = Octokit::Client.new
client.connection_options[:ssl] = { :verify => false }

post '/payload' do
  github_event = request.env['HTTP_X_GITHUB_EVENT']
  if github_event == "issue_comment"
    replace_comment(request.body.read)
  else
    puts "New event #{github_event}"
  end
end

def update_comment(comment_text)
  new_comment = ""
  match_data = comment_text.match(/\[(?<id>\w+\-\w+)\]/)
  if match_data != nil
    jira_id = match_data[:id]
    match = match_data[0]
    if comment_text.index(match) >= 0
      jira_id = match_data[:id]
      jira_link = "[#{match}](https://osowskit.atlassian.net/browse/#{jira_id})"
      # optionally test link....
      new_comment = comment_text.gsub(match, jira_link)
      puts new_comment
    end
  end
  return new_comment
end

def replace_comment(request)

  webhook_json = JSON.parse(request)
  webhook_action = webhook_json["action"]

  # Ignore Updated or Deleted comments
  if webhook_action == "created"
    issue_comment = webhook_json["comment"]["body"]
    new_comment = update_comment(issue_comment)

    if new_comment != ""
      comment_id = webhook_json["comment"]["id"]
      repo_name = webhook_json["repository"]["full_name"]

      installation_id = webhook_json["installation"]["id"]
      access_tokens_url = "https://10.100.198.128/api/v3/installations/#{installation_id}/access_tokens"
      access_token = get_app_token(access_tokens_url)

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
    exp: 9.minutes.from_now.to_i,
    # Integration's GitHub identifier
    iss: GITHUB_APP_ID
  }

  JWT.encode(payload, private_key, "RS256")
end

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
    puts app_token = JSON.parse(response)
    token = app_token["token"]
  rescue Exception => e
    puts e
    puts e.http_body
  end

  return token
end
