require "net/http"
require "time"
require "json"
require "search_params.rb"
require "response.rb"
module SolrLite

  class DefaultLogger
    def self.info(msg)
      puts "SolrLite: #{msg}"
    end
  end

  class Solr
    # Creates an instance of the Solr class.
    # Parameters:
    #   solr_url: string with the URL to Solr ("http://localhost:8983/solr/bibdata")
    #   logger: an instance of Rails::logger if using Rails.
    #       Could also be SolrLite::DefaultLogger which defaults to the console.
    #       Or nil to omit logging.
    def initialize(solr_url, logger = nil)
      raise "No solr_url was indicated" if solr_url == nil
      @solr_url = solr_url
      @logger = logger
    end

    # Fetches a Solr document by id.
    # Parameters:
    #   id: ID of the document to fetch.
    #   q_field: Query field (defaults to "q")
    #   fl: list of fields to fetch (defaults to "*")
    #
    # Returns a hash with the document information or nil if no document was found.
    # Raises an exception if more than one document was found.
    def get(id, q_field = "q", fl = "*")
      query_string = "#{q_field}=id%3A#{id}"     # %3A => :
      query_string += "&fl=#{fl}"
      query_string += "&wt=json&indent=on"
      url = "#{@solr_url}/select?#{query_string}"
      solr_response = Response.new(http_get(url), nil)
      if solr_response.num_found > 1
        raise "More than one record found for id #{id}"
      end
      solr_response.solr_docs.first
    end

    # Issues a search request to Solr.
    # Parameters:
    #   params: an instance of SolrParams.
    #   extra_fqs: array of FilterQuery objects. This is used to
    #     add filters to the search that we don't want to allow the
    #     user to override.
    #   qf: Used to override the server's qf value.
    #   mm: Used to override the server's mm value.
    #   debug: true to include debugQuery info in the response. (defaults to false)
    #
    # Returns an instance of SolrLite::Response
    def search(params, extra_fqs = [], qf = nil, mm = nil, debug = false)
      if params.fl != nil
        query_string = "fl=#{params.fl.join(",")}"
      else
        query_string = "" # use Solr defaults
      end

      query_string += "&wt=json&indent=on"
      query_string += "&" + params.to_solr_query_string(extra_fqs)
      query_string += "&q.op=AND"

      if qf != nil
        query_string += "&qf=#{CGI.escape(qf)}"
      end

      if mm != nil
        query_string += "&mm=#{CGI.escape(mm)}"
      end

      if debug
        query_string += "&debugQuery=true"
      end

      url = "#{@solr_url}/select?#{query_string}"
      http_response = http_get(url)
      response = Response.new(http_response, params)
      response
    end

    # shortcut for search
    def search_text(terms)
      params = SearchParams.new(terms)
      search(params)
    end

    def start_row(page, page_size)
      (page - 1) * page_size
    end

    def update(json)
      url = @solr_url + "/update?commit=true"
      solr_response = http_post_json(url, json)
      solr_response
    end

    def delete_by_id(id)
      # Use XML format here because that's the only way I could get
      # the delete to recognize ids with a colon (e.g. bdr:123).
      # Using JSON caused the Solr parser to choke.
      #
      # Notice that they payload is XML but the response is JSON (wt=json)
      url = @solr_url + "/update?commit=true&wt=json"
      payload = "<delete><id>#{id}</id></delete>"
      http_response = http_post(url, payload, "text/xml")
      solr_response = Response.new(JSON.parse(http_response), nil)
      solr_response
    end

    def delete_by_query(query)
      url = @solr_url + "/update?commit=true"
      payload = '{ "delete" : { "query" : "' + query + '" } }'
      solr_response = http_post_json(url, payload)
      solr_response
    end

    def delete_all!()
      delete_by_query("*:*")
    end

    private
      def http_post_json(url, payload)
        content_type = "application/json"
        http_response = http_post(url, payload, content_type)
        Response.new(JSON.parse(http_response), nil)
      end

      def http_post(url, payload, content_type)
        start = Time.now
        log_msg("Solr HTTP POST #{url}")
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        if url.start_with?("https://")
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = content_type
        request.body = payload
        response = http.request(request)
        log_elapsed(start, "Solr HTTP POST")
        response.body
      end

      def http_get(url)
        start = Time.now
        log_msg("Solr HTTP GET #{url}")
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        if url.start_with?("https://")
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        request = Net::HTTP::Get.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        response = http.request(request)
        log_elapsed(start, "Solr HTTP GET")
        JSON.parse(response.body)
      end

      def elapsed_ms(start)
        ((Time.now - start) * 1000).to_i
      end

      def log_elapsed(start, msg)
        log_msg("#{msg} took #{elapsed_ms(start)} ms")
      end

      def log_msg(msg)
        if @logger != nil
          @logger.info(msg)
        end
      end
  end
end
