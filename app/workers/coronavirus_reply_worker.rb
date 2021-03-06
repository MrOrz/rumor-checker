require 'line/bot'

class CoronavirusReplyWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(token, rumor, platform='line')
    @token = token
    @rumor = rumor
    @platform = platform

    answer_for_nonsense_query
    answer_for_query unless @answer
    answer_for_out_of_service_query unless @answer

    talk(@answer)
  end

  private

  def answer_for_nonsense_query
    @rumor = begin
               Integer(@rumor)
             rescue
               nil
             end

    return if @rumor
    @answer = invalid_answer
  end

  def answer_for_out_of_service_query
    @answer = invalid_answer
  end

  def invalid_answer
    '抱歉，這超出我的回答範圍，請輸入數字或是 0 回到選單，或是 ok 結束對話。'
  end

  def answer_for_query
    @answer = MENU[@rumor]
    @answer = eval(@answer) if @rumor == 1 # http request for latest data
  end

  def talk(reply)
    case @platform
    when 'line'
      client = initiate_client
      client.reply_message(@token, { type: "text", text: reply })
    when 'telegram'
      HTTParty.post(
        "https://api.telegram.org/bot#{ENV['telegram_app_token']}/sendMessage",
        headers: { "Content-Type": "application/json"},
        body: {
          chat_id: @token,
          text: reply
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
