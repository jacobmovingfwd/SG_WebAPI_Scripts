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
require 'pry'

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
  base_uri 'api.sendgrid.com'
  format :json
  basic_auth 'username', 'password'
  debug_output
end

module ApiToJSON
	def self.construct_uri(path)
		return URI.parse(path)
	end

	def self.get(path)
 		uri = construct_uri path
		http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 5000
    http.use_ssl = true
		req = Net::HTTP::Get.new(uri.request_uri)
		req["Authorization"] ='SOMEAUTH'
    print http.request(req)
  end

  def self.post(path, payload)
    uri = construct_uri path
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 5000
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req.body = payload.to_json
    req["Authorization"] ='SOMEAUTH'
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    print http.request(req)
  end

  def self.delete(path, payload)
    uri = construct_uri path 
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 5000
    http.use_ssl = true
    req = Net::HTTP::Delete.new(uri.request_uri)
    req.body = payload.to_json
    req["Authorization"] ='SOMEAUTH'
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    print http.request(req)
  end
 
  def self.print(response)
    begin
      #puts JSON.pretty_generate(JSON.parse(response.body))
      resp_hash = {code: response.code, body: JSON.parse(response.body), limit: response['X-RateLimit-Remaining'], reset: response['X-RateLimit-Reset']}
      #return JSON.parse(response.body)
      return resp_hash
    rescue
      puts response
    end
  end
end

def supGet(sup)
	emails = []
	response = HttpToJSON.get("/api/#{sup}.count.json?api_user=#{@api_user}&api_key=#{@api_key}")
  binding.pry()
  puts response.body, response.code, response.message, response.headers.inspect
  answer = JSON.parse(response.body)


	if answer["error"]
   		errLog("Error: #{answer}\nskipping #{sup}.")
   		return
	else
		offset = 0
   	offset_max = answer["count"]
   	log("Total Addresses on #{sup}: #{offset_max}")
	
   	until offset >= offset_max
   		log("List: #{sup}  Offset: #{offset}  Max: #{offset_max}  Remaining: #{(offset_max.to_i - offset.to_i)}")
    	answer={}
   	
   		#get addresses ##UPDATE
    	answer = HttpToJSON.get("/api/#{sup}.get.json?&api_user=#{@api_user}&api_key=#{@api_key}#{@suppression_start}&offset=#{offset}&limit=1000")
    	answer[:body].each do |a| 
        emails << a["email"].to_s
        @total_count[sup.to_sym] += 1
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
	api_user = gets.chomp.downcase

	print "Please provide the API Key: "
	api_key = gets.chomp
end

@total_count = {bounces: 0, invalidemails: 0, unsubscribes: 0, spamreports: 0}
@clear_count = {bounces: 0, invalidemails: 0, unsubscribes: 0, spamreports: 0}
#iterate through suppressions lists
suppressions = %w[bounces invalidemails unsubscribes spamreports]

#for each suppression list, iterate through in 1000 address steps
suppressions.each do |sup|
	log("Working through #{sup}...")
	email_array = supGet(sup)
  sup_total = @total_count[sup.to_sym]
  log("Total addresses logged from #{sup}: #{sup_total}")

	#for each address chunk, remove from contact db
  email_array.each_slice(100) do |e| 
    
    response = HttpToJSON.delete("/v3/contactdb/recipients", e)

    #if we hit rate limit, wait for reset
    sleep( response[:reset] - Time.now() ) if response[:limit] <= 1

    #log errors and move on
    unless response[:code] == "204"
      errLog(response[:body])
    end

    #if successful, increment clear_count, continue

  end

end

#if an error, log the call and skip.

#on complete, print log filename, number of errors, number of successes.