require 'sinatra'
require 'line/bot'
require 'net/https'

# 微小変更部分！確認用。
get '/' do
  "Hello world"
end
def post_chatwork_api(message)
  url = "https://api.chatwork.com/v2/rooms/#{ENV["CHATWORK_ROOM_ID"]}/messages"
  uri = URI.parse(url)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true # HTTPSでよろしく
  request = Net::HTTP::Post.new(uri.request_uri)
  request.add_field "X-ChatWorkToken", ENV["CHATWORK_API_KEY"]
  request.set_form_data :body => message
  response = https.request(request)
  puts response.body
end

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

def user_name(user_id, group_id)
  response = nil
  if group_id.nil? || ( group_id.strip.length == 0 )
    response = client.get_profile(user_id)
  else
    end_point = "/bot/group/#{group_id}/member/#{user_id}"
    response = client.get(end_point)
  end
  case response
  when Net::HTTPSuccess then
    contact = JSON.parse(response.body)
    return contact['displayName']
  else
  end
  return "名前取得エラー"
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  p events
  events.each { |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        user_name = "名前取得エラー"
        user_name = user_name(event["source"]["userId"], event["source"]["groupId"]) rescue nil
        post_chatwork_api(user_name + ":" + event.message['text'])
      when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
        post_chatwork_api("LINEに画像、動画が追加されました。")
      end
    end
  }

  "OK"
end
