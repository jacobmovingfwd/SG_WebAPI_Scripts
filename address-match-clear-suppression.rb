# Queries Account Suppression Lists, removing all addresses in provided CSV.
#
# Requires:
#   Credential for account with API permission.
#   CSV containing email addresses in first column. All other columns will be ignored.
#   Folder named 'logs' in same folder as script.
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

puts "This is the SendGrid address-based Suppression Match & Remove script."

#get api_user
print "\nPlease provide the API User: "
api_user = gets.chomp.downcase

#get api_key
print "Please provide the API Key: "
api_key = gets.chomp

#open log files
timestamp = Time.now.strftime("%y%m%d-%H.%M.%S")
@rawLog = File.new("logs/address-match-clear_#{api_user}_#{timestamp}.log", "a+")

log("api_user: #{api_user}", true)

#get csv file
print "\nPlease provide the file to run against: "
csv = gets.chomp
log("address file: #{csv}")

#split file to addresses
addresses = []
CSV.foreach(csv){|row| addresses << row[0]}
total = addresses.count
log("Total Addresses to Remove: #{total}")
log("Addresses: #{addresses}", true)

#get suppressions to check
puts "\nPlease provide the suppression lists to check, using only the 1-letter reference, as a string.\n b : Bounces. i : Invalidemails. u : Unsubscribes. s : Spamreports.\n Ex: bius"
supIn = gets.chomp.downcase

# build suppression array
suppressions = [] # ["bounces", "invalidemails", "unsubscribes", "spamreports"]
suppressions << "bounces" if supIn.include? "b"
suppressions << "invalidemails" if supIn.include? "i"
suppressions << "unsubscribes" if supIn.include? "u"
suppressions << "spamreports" if supIn.include? "s"
log("Suppression lists to check: #{suppressions}")

clear_count = {"bounces" => 0, "invalidemails" => 0, "unsubscribes" => 0, "spamreports" => 0}

#check lists
addresses.each do |email|
	suppressions.each do |sup|
		log("Searching #{sup} for #{email}...")
		out_csv = "#{api_user}-#{sup}_removed_#{timestamp}.csv"
	
		answer={}
		#get bounces
		uri = URI.parse("https://sendgrid.com/api/#{sup}.delete.json?&api_user=#{api_user}&api_key=#{api_key}&email=#{email}")
		http = Net::HTTP.new(uri.host, 443)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE

		#get response
		request = Net::HTTP::Get.new(uri.request_uri)
		response = http.request(request)

		#parse response
		answer = JSON.parse(response.body)
		#log raw response
		log("Answer: #{answer}")

		#log address to CSV
    if answer["message"] == "success"
    	clear_count[sup] += 1

      CSV.open(out_csv, "a+"){|csv| csv << [addr]}
      log("#{addr} written to CSV.")
    end
  log("Removed so far: #{clear_count}")
	end
	log("1 second pause...")
	sleep(1)
end

log("Total Removed: #{clear_count}")
log("Script done.")
#close log files
@rawLog.close()
