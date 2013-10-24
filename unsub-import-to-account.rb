# Upload a CSV into a Account's Unsubscribe list.
# DO NOT increase the spread value or the sleep time. These are safety measures to ensure performance no matter the size fo the file.
#
# Requires:
#    Credential for account with API permission.
#    Folder named 'logs' in same folder as script.
#    CSV containing email addresses in first column. All other columns will be ignored.
#
# v2.0, 24 Oct 2013, Jacob @ SendGrid

require 'json'
require 'net/https'
require 'uri'
require 'csv'

def log(txt, silent = false)
  timestamp = Time.now.strftime("%y%m%d-%H.%M.%S.%L")
  txt = txt.to_s
  puts "#{timestamp}: " + txt unless silent
  @rawLog.write("#{timestamp}: " + txt + "\n")
end

puts "This is the SendGrid Import CSV to Unsubscribe List script."

#get api_user
print "\nPlease provide the API User: "
api_user = gets.chomp.downcase

#get api_key
print "Please provide the API Key: "
api_key = gets.chomp

#open log files
timestamp = Time.now.strftime("%y%m%d-%H.%M.%S.%L")
@rawLog = File.new("logs/unsub-import_#{api_user}_#{timestamp}.log", "a+")

log("api_user: #{api_user}", true)

#get csv file
print "\nPlease provide the file to import: "
csv = gets.chomp
log("address file: #{csv}")

#split file to addresses
addresses = []
CSV.foreach(csv){|row| addresses << row[0]}
total = addresses.count
log("Total Addresses to Add: #{total}")
log(addresses)

offset = 0
emails = ""

while offset < total do 
  total > 100? spread = 100 : spread = total
  log("Uploading addresses #{offset} through #{offset + spread}")
  offset += spread

  while spread > 0
    spread -= 1
    begin
      emails << "&email="
      emails << addresses.pop
    rescue
      emails = emails
    end
  end
  log("Emails being added: #{emails}", true)

  #delete unsub
  uri = URI.parse("https://sendgrid.com/api/unsubscribes.add.json?&api_user=#{api_user}&api_key=#{api_key}#{emails}")
  http = Net::HTTP.new(uri.host, 443)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  #get response
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)

  #parse response
  answer = JSON.parse(response.body)
  #log response
  log(answer)

  log("Waiting 3 seconds after delete...")
  sleep(3)
end

log("Script done.")
#close log files
@rawLog.close()
