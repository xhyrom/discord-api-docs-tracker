# frozen_string_literal: true

require 'httparty'
require 'json'
require 'time'

current_check = Time.now

issue = HTTParty.get('https://api.github.com/repos/xhyrom/discord-api-docs-tracker/issues/1', format: :plain)
issue = JSON.parse issue, symbolize_names: true
old_check = issue[:body].to_i

response = HTTParty.get('https://api.github.com/repos/discord/discord-api-docs/pulls?state=all', format: :plain)
data = JSON.parse response, symbolize_names: true

def send_embed(embed)
  HTTParty.post(
    ENV['WEBHOOK_URL'],
    body: {
      username: 'api-docs',
      embeds: [embed]
    }.to_json,
    headers: { 'Content-Type' => 'application/json' }
  )
end

def hex_to_int(hex)
  hex[1..].to_i(16)
end

data = data.sort { |a, b| a[:number] <=> b[:number] }

data.each do |item|
  created_at = Time.parse(item[:created_at]).to_i
  merged_at = item[:merged_at] ? Time.parse(item[:merged_at]).to_i : nil

  next if created_at < old_check && (merged_at.nil? || (!merged_at.nil? && merged_at < old_check))

  embed = {
    author: {
      name: item[:user][:login],
      url: item[:user][:html_url],
      icon_url: item[:user][:avatar_url]
    },
    url: item[:html_url]
  }

  embed[:description] = item[:body] unless item[:body].nil?

  if created_at > old_check
    puts "Created #{item[:title]} at #{created_at}"

    embed[:color] = hex_to_int('#4adb40')
    embed[:title] = "Pull request opened: ##{item[:number]} #{item[:title]}"

    send_embed(embed)
  end

  next unless !merged_at.nil? && merged_at > old_check

  puts "Merged #{item[:title]} at #{merged_at}"

  embed[:color] = hex_to_int('#983ac7')
  embed[:title] = "Pull request merged: ##{item[:number]} #{item[:title]}"

  send_embed(embed)
end

HTTParty.patch(
  'https://api.github.com/repos/xhyrom/discord-api-docs-tracker/issues/1',
  body: {
    body: current_check.to_i.to_s
  }.to_json,
  headers: {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{ENV['GITHUB_TOKEN']}"
  }
)
