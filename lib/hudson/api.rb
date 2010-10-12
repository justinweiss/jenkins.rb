require 'httparty'
require 'cgi'
require 'uri'
require 'json'

module Hudson
  class Api
    include HTTParty

    headers 'content-type' => 'application/json'
    format :json
    # http_proxy 'localhost', '8888'
    
    def self.setup_base_url(options)
      # Thor's HashWithIndifferentAccess is based on string keys which URI::HTTP.build ignores
      options = options.inject({}) { |mem, (key, val)| mem[key.to_sym] = val; mem }
      options[:host] ||= ENV['HUDSON_HOST']
      options[:port] ||= ENV['HUDSON_PORT']
      return false unless options[:host] || Hudson::Config.config["base_uri"]
      uri = options[:host] ? URI::HTTP.build(options) : Hudson::Config.config["base_uri"]
      base_uri uri.to_s
      uri
    end
    
    # returns true if successfully create a new job on Hudson
    def self.create_job(name, job_config)
      res = post "/createItem/api/xml?name=#{CGI.escape(name)}", {
        :body => job_config.to_xml, :format => :xml, :headers => { 'content-type' => 'application/xml' }
      }
      if res.code == 200
        cache_base_uri
        true
      else
        require "hpricot"
        puts "Server error:"
        puts Hpricot(res.body).search("//body").text
        false
      end
    end
    
    def self.summary
      begin
        json = get "/api/json"
        cache_base_uri
        json
      rescue Errno::ECONNREFUSED => e
        false
      end
    end
    
    # Return hash of job statuses
    def self.job(name)
      begin
        json = get "/job/#{name}/api/json"
        cache_base_uri
        json
      rescue Errno::ECONNREFUSED => e
        false
      end
    end
    
    private
    def self.cache_base_uri
      Hudson::Config.config["base_uri"] = base_uri
      Hudson::Config.store!
    end
  end
end