require 'line/bot'

class ReplyWorker
  include Sidekiq::Worker
  sidekiq_options retry: false
  AIRTABLE_YAML = File.join(Rails.root, 'config', 'ignore_list.yml')

  def perform(token, rumor, platform='line')
    @token = token # chat_id for telegram
    @platform = platform
    return if not_rumor?(rumor)

    article = Rumors::Api::Client.search(rumor)
    return unless article

    reply = ReplyDecorator.new(article["articleReplies"], article["id"]).prettify

    talk(reply)
  end

  private

  def not_rumor?(rumor)
    return false unless File.exist?(AIRTABLE_YAML)
    not_rumores = YAML.load_file(AIRTABLE_YAML).values
    not_rumores.include?(rumor)
  end

  def talk(reply)
    case @platform
    when 'line'
      client = initiate_client
      client.reply_message(@token, reply)
    when 'telegram'
      HTTParty.post(
        "https://api.telegram.org/bot#{ENV['telegram_app_token']}/sendMessage",
        headers: { "Content-Type": "application/json"},
        body: {
          chat_id: @token,
          text: reply[:text]
        }.to_json
      )
    end
  end

  def initiate_client
    Line::Bot::Client.new do |config|
      config.channel_secret = ENV['line_channel_secret']
      config.channel_token = ENV['line_channel_token']
    end
  end
end
