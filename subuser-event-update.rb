# Runs through all of an Parent's subusers, and updates subusers Event Webhook to version 3.
# DOES NOT update Parent.
# Settings push call requires all settings to be defined. This script properly queries each account's settings, and sends them back, with the version updated only.
# Could easily be modified to set all subusers to particular settings.
#
# Requires:
#    Credential for Parent account with API permission.
#    Folder named 'logs' in same folder as script.
#
# v2.0, 24 Oct 2013, Jacob @ SendGrid

require 'csv'
require 'json'
require 'net/https'
require 'uri'

def log(txt, silent = false)
  timestamp = Time.now.strftime("%y%m%d-%H.%M.%S.%L")
  txt = txt.to_s
  puts "#{timestamp}: " + txt unless silent
  @rawLog.write("#{timestamp}: " + txt + "\n")
end

def apiPost(uri)
  uri = URI.parse("#{uri}")
  http = Net::HTTP.new(uri.host, 443)
  http.read_timeout = 5000
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  answer = JSON.parse(response.body)
  log(answer, true)
  return answer
end

def getSubusers()
  subusers = []
  answer = apiPost("https://sendgrid.com/apiv2/customer.profile.json?&api_user=#{@api_user}&api_key=#{@api_key}&task=get")

  begin
    answer.each { |user| subusers << user["username"].to_s}
    log("Subusers: " + subusers.to_s)
    return subusers
  rescue
    log("Aborting: " + answer["error"]["message"])
    return nil
  end
end

def eventSettings(subuser)
  event_settings = apiPost("https://sendgrid.com/apiv2/customer.apps.json?api_user=#{@api_user}&api_key=#{@api_key}&name=eventnotify&task=getsettings&user=#{subuser}")
  log("Current: {user: #{subuser}, version: #{event_settings["settings"]["version"]}, url: #{event_settings["settings"]["url"]}, processed: #{event_settings["settings"]["processed"]}, dropped: #{event_settings["settings"]["dropped"]}, deferred: #{event_settings["settings"]["deferred"]}, delivered: #{event_settings["settings"]["delivered"]}, bounce: #{event_settings["settings"]["bounce"]}, click: #{event_settings["settings"]["click"]}, open: #{event_settings["settings"]["open"]}, unsubscribe: #{event_settings["settings"]["unsubscribe"]}, spamreport: #{event_settings["settings"]["spamreport"]}}")
  return event_settings
end

def subuserUpdate(subusers)
  subusers.each do |subuser|
    log("")
    event_settings = eventSettings(subuser)

    if event_settings["settings"]["version"] != "3"
      apiPost("https://sendgrid.com/apiv2/customer.apps.json?api_user=#{@api_user}&api_key=#{@api_key}&name=eventnotify&task=setup&user=#{subuser}&version=3&url=#{event_settings["settings"]["url"]}&processed=#{event_settings["settings"]["processed"]}&dropped=#{event_settings["settings"]["dropped"]}&deferred=#{event_settings["settings"]["deferred"]}&delivered=#{event_settings["settings"]["delivered"]}&bounce=#{event_settings["settings"]["bounce"]}&click=#{event_settings["settings"]["click"]}&open=#{event_settings["settings"]["open"]}&unsubscribe=#{event_settings["settings"]["unsubscribe"]}&spamreport=#{event_settings["settings"]["spamreport"]}")
    
      #verify settings by rerunning settings check & logging results
      eventSettings(subuser)
    else
      log("#{subuser} already version 3. not updating.")
    end
  end
end

puts "This is the SendGrid script to update all subusers to Event Webhook version 3."

print "\nPlease provide the Parent API User: "
@api_user = gets.chomp

print "Please provide the Parent API Key: "
@api_key = gets.chomp

#open log files
timestamp = Time.now.strftime("%y%m%d-%H.%M.%S")
@rawLog = File.new("logs/subuser-event-update_#{@api_user}_#{timestamp}.log", "a+")

log("api_user: #{api_user}", true)

subusers = getSubusers()

subuserUpdate(subusers) unless subusers == nil

log("Script done.")
#close log files
@rawLog.close()
