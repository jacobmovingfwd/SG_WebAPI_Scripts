# Quereis Accounts Suppression lists. 
# Removes those addresses from the Marketing Campaign Beta Contact Database, to avoid overcharge.
#
# Requires: SG Account Credential with API Permissions.
# Optional: Epoch Timestamp to begin cleanup from, so that the script doesn't iterate through the full list the entire time.
#
# takes an argument for a tmp file that has a JSON array of keys & values for api_user, api_key, and timestamp.
# defaults to querying those if needed.

require 'rubygems'
require 'json'
require 'httparty'
require 'uri'
require 'csv'

def timestamp(x = nil)
	timestamp = Time.now.to_i if x == 1
	timestamp ||= Time.now.strftime("%Y-%m-%d %H:%M:%S")

	return timestamp
end

def log(txt)
	puts "#{timestamp()}: " + txt.to_s
end

def errLog(txt)
	log(txt)
	File.write(@out_log.to_s, txt)
end

module HttpToJSON
  include HTTParty
  base_uri 'https://api.sendgrid.com'
  format :json
  headers 'Accept' => 'application/json', 'Content-Type' => 'application/json'
  #debug_output
end

def supGet(sup)
	emails = []
	response = HttpToJSON.get("/api/#{sup}.count.json?api_user=#{@api_user}&api_key=#{@api_key}")
  answer = response.parsed_response # since SG APIv1 has the wrong Content-Type header

	if answer["error"]
   		errLog("Error: #{answer}\nskipping #{sup}.")
   		return
	else
		offset = 0
   	offset_max = answer["count"]
   	log("Total Addresses on #{sup}: #{offset_max}")
	
   	until offset >= offset_max
   		log("List: #{sup}  Offset: #{offset}  Max: #{offset_max}  Remaining: #{(offset_max.to_i - offset.to_i)}")
   	
   		#get addresses
    	response = HttpToJSON.get("/api/#{sup}.get.json?&api_user=#{@api_user}&api_key=#{@api_key}#{@suppression_start}&offset=#{offset}&limit=1000")
      response.parsed_response.each do |a| # since SG APIv1 has the wrong Content-Type header
        emails << a["email"].to_s
        @total_count[sup] += 1
      end
    	offset += 1000
		end
	end
	return emails
end

# Initialize. Get user account info, get option start date as Epoch timestamp
script_start = timestamp(1)
@out_log = "campaign_cleanup_errors_#{timestamp(1)}.txt"

if ARGV[0]
	#{api_user: "username", api_key: "password", timestamp: 1400000000}
	data = JSON.parse(File.read(ARGV[0].to_s), symbolize_names: true)
	log(data)
	@api_user = data[:api_user]
	@api_key = data[:api_key]
	@suppression_start = data[:timestamp].nil? ? "" : "&start_time=#{Time.at(data[:timestamp].to_i).strftime("%Y-%m-%d")}" 
else
	print "\nPlease provide the API User: "
	@api_user = gets.chomp.downcase

	print "Please provide the API Key: "
	@api_key = gets.chomp
end

@total_count = {bounces: 0, invalidemails: 0, unsubscribes: 0, spamreports: 0}
@clear_count = {bounces: 0, invalidemails: 0, unsubscribes: 0, spamreports: 0}

#iterate through suppressions lists
suppressions = %i(bounces invalidemails unsubscribes spamreports)
#suppressions = %i(unsubscribes)

#for each suppression list, iterate through in 1000 address steps
suppressions.each do |sup|
	log("Working through #{sup}...")
	email_array = supGet(sup)
  sup_total = @total_count[sup]
  log("Total addresses logged from #{sup}: #{sup_total}")

	#for each address chunk, remove from contact db
  email_array.each_slice(1000) do |e| 

    response = HttpToJSON.delete("/v3/contactdb/recipients", {body: e.to_json, basic_auth: {username: @api_user, password: @api_key}})
    
    if response.code == 204
      #if successful, increment clear_count, continue     
      @clear_count[sup] += e.count
    elsif response.code == 400 && response[:body] == "{\"errors\":[{\"message\":\"No recipients found\"}]}"
        @clear_count[sup] += e.count
    else
      #otherwise, log errors and move on
      errLog(response[:body])
    end

    #if we hit rate limit, wait for reset
    sleep( response.headers["X-RateLimit-Reset"].to_i - Time.now().to_i ) unless response.headers["X-RateLimit-Remaining"].nil? || response.headers["X-RateLimit-Remaining"] > 1
  end
end

#on complete, print log filename, number of errors, number of successes.
script_end = timestamp(1)
log("Finished. #{Time.at(script_end - script_start).utc.strftime("%H hours, %M minutes, %S seconds")} to complete. \nTotal addresses queried: #{@total_count} \nTotal addresses removed: #{@clear_count}")
