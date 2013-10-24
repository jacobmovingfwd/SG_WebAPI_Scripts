# Queries Account's Suppression Lists & removed entries based on domain, Full matches only. Writes removed addresses to CSV.
#
# Requires:
#    Credential for account with API permission.
#    Folder named 'logs' in same folder as script.
#
# v2.0, 24 Oct 2013, Jacob @ SendGrid

require 'json'
require 'net/https'
require 'uri'
require 'mail'
require 'csv'

def log(txt, silent = false)
  timestamp = Time.now.strftime("%y%m%d-%H.%M.%S.%L")
  txt = txt.to_s
  puts "#{timestamp}: " + txt unless silent
  @rawLog.write("#{timestamp}: " + txt + "\n")
end

puts "This is the SendGrid domain-based Suppression Match & Remove script."

#get api_user
print "\nPlease provide the API User: "
api_user = gets.chomp.downcase

#get api_key
print "Please provide the API Key: "
api_key = gets.chomp

#open log files
timestamp = Time.now.strftime("%y%m%d-%H.%M.%S.%L")
@rawLog = File.new("logs/domain-match-clear_#{api_user}_#{timestamp}.log", "a+")

log("api_user: #{api_user}", true)

#get suppressions to check
puts "\nPlease provide the suppression lists to check, using only the 1-letter reference, as a string.\n b : bounces. i : invalidemails.\n Ex: bi"
supIn = gets.chomp.downcase

# build suppression array
suppressions = [] # ["bounces", "invalidemails"]
suppressions << "bounces" if supIn.include? "b"
suppressions << "invalidemails" if supIn.include? "i"
log("Suppression lists to check: #{suppressions}")

#get Reason to check for
puts "Please provide the domain to check for, as domain.com"
checkDomain = gets.to_s.chomp.strip.downcase

#Script start
log("Searching suppression lists.")

suppressions.each do |sup|
  log("Searching #{sup} list.")
  out_csv = "#{api_user}-#{sup}_removed_#{timestamp}.csv"

  i = 0

  answer={}
  #query SG
  uri = URI.parse("https://sendgrid.com/api/#{sup}.get.json?&api_user=#{api_user}&api_key=#{api_key}")
  http = Net::HTTP.new(uri.host, 443)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  #get response
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)

  #parse response
  answer = JSON.parse(response.body)
  #log response
  log(answer, true)

  if answer.include?("error")
    wrong = answer["error"]
    log(wrong, true)
    abort("ERROR: " + wrong)
  end

  # Check if address matches what you're looking for
  answer.each do |entry|
    addr = entry["email"]
    resDomain = Mail::Address.new(entry["email"]).domain.downcase

    if resDomain == checkDomain
      log("#{addr} match.")

      i += 1

      # Log removal
      log("Deleting #{addr} from #{sup} list.")

      #delete bounce
      uri = URI.parse("https://sendgrid.com/api/#{sup}.delete.json?&api_user=#{api_user}&api_key=#{api_key}&email=#{addr}")
      http = Net::HTTP.new(uri.host, 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      #get response
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      #parse response
      answer = JSON.parse(response.body)
      #log response
      log("Answer: #{answer}")

      #log address to CSV
      if answer["message"] == "success"
          CSV.open(out_csv, "a+"){|csv| csv << [addr]}
          log("#{addr} written to CSV.")
      end

      log("Waiting 1 second after delete...")
      sleep(1)
    end
  end
  log("Total matches: #{i}")
  log("Waiting 3 seconds before checking next list...")
  sleep(3)
end

log("Script done.")
#close log files
@rawLog.close()
