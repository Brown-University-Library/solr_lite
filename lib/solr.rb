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

  # Represents a Solr instance.
  # This is the main public interface to submit commands (get, search, delete, update) to Solr.
  #
  class Solr

    # [String] Set this value if you want to send a query parser (defType) attribute to Solr
    # when submitting commands. Leave as nil to use the value configured on the server.
    attr_accessor :def_type

    # Creates an instance of the Solr class.
    #
    # @param solr_url [String] URL to Solr, e.g. "http://localhost:8983/solr/bibdata"
    # @param logger [Object] An object that provides an `info` method to log information about the requests.
    #     It could be an instance of Rails::logger if using Rails or an instance of SolrLite::DefaultLogger
    #     that outputs to the console. Use `nil` to omit logging.
    #
    def initialize(solr_url, logger = nil)
      raise "No solr_url was indicated" if solr_url == nil
      @solr_url = solr_url
      @logger = logger
      @def_type = nil
    end

    # Fetches a Solr document by id.
    #
    # @param id [String] ID of the document to fetch.
    # @param q_field [String] Query field.
    # @param fl [String] List of fields to fetch.
    #
    # @return [Hash] The document found or nil if no document was found.
    #     Raises an exception if more than one document was found.
    #
    def get(id, q_field = "q", fl = "*")
      query_string = "#{q_field}=id%3A#{id}"     # %3A => :
      query_string += "&fl=#{fl}"
      query_string += "&wt=json&indent=on"
      if @def_type != nil
        query_string += "&defType=#{@def_type}"
      end
      url = "#{@solr_url}/select?#{query_string}"
      solr_response = Response.new(http_get(url), nil)
      if solr_response.num_found > 1
        raise "More than one record found for id #{id}"
      end
      solr_response.solr_docs.first
    end

    def get_many(ids, q_field = "q", fl = "*", batch_size = 20)
      data = []
      batches = to_batches(ids, batch_size)
      batches.each do |batch|
        ids_string = batch.join(" OR ")
        query_string = "#{q_field}=id%3A(#{ids_string})"  # %3A => :
        query_string += "&fl=#{fl}"
        query_string += "&wt=json&indent=on"
        if @def_type != nil
          query_string += "&defType=#{@def_type}"
        end
        url = "#{@solr_url}/select?#{query_string}"
        solr_response = Response.new(http_get(url), nil)
        data += solr_response.solr_docs
      end
      data
    end

    # Issues a search request to Solr.
    #
    # @param params [SolrLite::SearchParams] Search parameters.
    # @param extra_fqs [Array] Array of {SolrLite::FilterQuery} objects. This is used to
    #     add filters to the search that we don't want to allow the
    #     user to override.
    # @param qf [String] Use to override the server's qf value.
    # @param mm [String] Use to override the server's mm value.
    # @param debug [Bool] Set to `true` to include `debugQuery` info in the response.
    #
    # @return [SolrLite::Response] The result of the search.
    #
    def search(params, extra_fqs = [], qf = nil, mm = nil, debug = false)
      http_response = search_core(params, extra_fqs, qf, mm, debug, nil, 0)
      response = Response.new(http_response, params)
      response
    end

    def search_group(params, extra_fqs = [], qf = nil, mm = nil, debug = false, group_field, group_limit)
      http_response = search_core(params, extra_fqs, qf, mm, debug, group_field, group_limit)
      response = Response.new(http_response, params)
      response
    end

    # Shortcut for the `search` method.
    #
    # @param terms [String] the value to use as the query (q) in Solr.
    # @return [SolrLite::Response] The result of the search.
    #
    def search_text(terms)
      params = SearchParams.new(terms)
      search(params)
    end

    # Calculates the starting row for a given page and page size.
    #
    # @param page [Integer] Page number.
    # @param page_size [Integer] Number of documents per page.
    #
    # @return [Integer] The row number to pass to Solr to start at the given page.
    #
    def start_row(page, page_size)
      (page - 1) * page_size
    end

    # Issues an update to Solr with the data provided.
    #
    # @param json [String] String the data in JSON format to sent to Solr.
    #     Usually in the form `"[{ f1:v1, f2:v2 }, { f1:v3, f2:v4 }]"`
    # @return [SolrLite::Response] The result of the update.
    #
    def update(json)
      url = @solr_url + "/update?commit=true"
      solr_response = http_post_json(url, json)
      solr_response
    end


    # Deletes a Solr document by id.
    #
    # @param id [String] ID of the document to delete.
    # @return [SolrLite::Response] The result of the delete.
    #
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

    # Deletes all documents that match a query in Solr.
    #
    # @param query [String] The query to pass to Solr.
    # @return [SolrLite::Response] The result of the delete.
    #
    def delete_by_query(query)
      url = @solr_url + "/update?commit=true"
      payload = '{ "delete" : { "query" : "' + query + '" } }'
      solr_response = http_post_json(url, payload)
      solr_response
    end

    # Deletes all documents in Solr.
    #
    # @return [SolrLite::Response] The result of the delete.
    #
    def delete_all!()
      delete_by_query("*:*")
    end

    private
      def search_core(params, extra_fqs, qf, mm, debug, group_field, group_limit)
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

        if group_field != nil
          # See https://lucene.apache.org/solr/guide/7_0/result-grouping.html
          #     and https://wiki.apache.org/solr/FieldCollapsing
          query_string += "&group=true&group.field=#{group_field}&group.limit=#{group_limit}"

          if params.group_count != nil
            # Adds an extra calculated facet to get the total number of groups. This is required
            # because Solr does not return this value in the response, instead Solr
            # returns the total number of documents found across all groups, but not
            # the total number of groups found.
            # See https://lucene.apache.org/solr/guide/7_7/json-facet-api.html#metrics-example
            #     and https://stackoverflow.com/a/56138991/446681
            query_string += '&json.facet={"' + params.group_count + '":"unique(' + group_field + ')"}'
          end
        end

        if @def_type != nil
          query_string += "&defType=#{@def_type}"
        end

        url = "#{@solr_url}/select?#{query_string}"
        http_response = http_get(url)
      end

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

      def to_batches(arr, batch_size)
        batch_count = (arr.count / batch_size)
        if (arr.count % batch_size) > 0
          batch_count += 1
        end

        batches = []
        (1..batch_count).each do |i|
          start = (i-1) * batch_size
          stop = start + batch_size - 1
          batch = arr[start..stop]
          batches << batch
        end

        batches
      end
  end
end
