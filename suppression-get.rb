# Queries Account Suppression Lists, logging all addresses to CSV, one per suppression list, then tar-zips file.
#
# Requires:
#   Credential for account with API permission.
#
# v2.2, 19 Mar 2014, Jacob @ SendGrid

require 'json'
require 'net/https'
require 'uri'
require 'csv'

def log(txt, silent = false)
  timestamp = Time.now.strftime("%y%m%d-%H.%M.%S.%L")
  txt = txt.to_s
  puts "#{timestamp}: " + txt unless silent
end

puts "This is the SendGrid Supression List Retrieval script."

#get api_user
print "\nPlease provide the API User: "
api_user = gets.chomp.downcase

#get api_key
print "Please provide the API Key: "
api_key = gets.chomp

#open log files
timestamp = Time.now.strftime("%y%m%d-%H.%M.%S")

log("api_user: #{api_user}", true)

#get suppressions to check
puts "\nPlease provide the suppression lists to check, using only the 1-letter reference, as a string.\n b : Bounces. i : Invalidemails. u : Unsubscribes. s : Spamreports. k : BlocKs.\n Ex: biusk"
supIn = gets.chomp.downcase

# build suppression array
suppressions = [] # ["bounces", "invalidemails", "unsubscribes", "spamreports"]
suppressions << "bounces" if supIn.include? "b"
suppressions << "invalidemails" if supIn.include? "i"
suppressions << "unsubscribes" if supIn.include? "u"
suppressions << "spamreports" if supIn.include? "s"
suppressions << "blocks" if supIn.include? "k"
log("Suppression lists to check: #{suppressions}")

suppressions.each do |sup|
  #create output file
  out_csv = "#{api_user}-#{sup}.csv"

	#log checking list
	log("Getting #{sup}...")

  #answer={}
  #get count of list for cycling through
  uri = URI.parse("https://sendgrid.com/api/#{sup}.count.json?api_user=#{api_user}&api_key=#{api_key}")
  http = Net::HTTP.new(uri.host, 443)
  http.read_timeout = 5000
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  #get response
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  #puts response

  #parse response
  answer = JSON.parse(response.body)

  if answer["error"]
    log("Answer: #{answer}")
  else
    offset_max = answer["count"]
    log("Total Addresses on List: #{offset_max}")

    offset = 0	
    until offset >= offset_max
      log("Offset: #{offset}, Max: #{offset_max}, Remaining: #{(offset_max.to_i - offset.to_i)}")
	    answer={}
      #get addresses ##UPDATE
	    uri = URI.parse("https://sendgrid.com/api/#{sup}.get.json?&api_user=#{api_user}&api_key=#{api_key}&date=1&offset=#{offset}&limit=1000")
	    http = Net::HTTP.new(uri.host, 443)
      http.read_timeout = 5000
	    http.use_ssl = true
	    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

	    #get response
	    request = Net::HTTP::Get.new(uri.request_uri)
	    response = http.request(request)
      
	    #parse response
	    answer = JSON.parse(response.body)
	    #log raw response
      log("Answer: #{answer}", true)

      headers = %w{email created status reason}

      #convert response to CSV
      log("writing to CSV...")
      answer.each do |hash|
        if !File.exist?(out_csv)
          CSV.open(out_csv, "a+") do |csv|
            csv << headers
            csv << headers.map { |h| hash[h] }
          end
        #if csv does exist, append data
        else
          CSV.open(out_csv, "a+") do |csv|
            csv << headers.map { |h| hash[h] }
          end
        end
      end

      offset += 1000
      sleep(1)
    end

    if offset_max > 0
      log("Tarring CSV...")
     log(%x(tar -czvf #{out_csv}.tgz #{out_csv}))
    end
  end
end

log("Script done.")
#close log files

