
require "filter_query.rb"
require "facet_field.rb"
module SolrLite

  # Represents the parameters to send to Solr during a search.
  class SearchParams

    # [String] The q value to pass to Solr.
    attr_accessor :q

    # [Array] Array of {SolrLite::FilterQuery} objects to pass to Solr.
    attr_accessor :fq

    # [Array] Array of {SolrLite::FacetField} objects to pass to Solr.
    attr_accessor :facets

    # [Integer] Page number to request from Solr.
    attr_accessor :page

    # [Integer] Number of documents per page to request from Solr.
    attr_accessor :page_size

    # [Array] List of fields names to request from Solr.
    attr_accessor :fl

    # [String] Sort string to pass to Solr.
    attr_accessor :sort

    # [Integer] Number of facet values to request from Solr.
    attr_accessor :facet_limit

    # [Bool] True to request Solr to use spellchecking (defaults to false).
    attr_accessor :spellcheck

    # [Bool] Set to true to request hit highlighting information from Solr.
    attr_accessor :hl

    # [String] Sets the highlight fields (hl.fl) to request from Solr.
    attr_accessor :hl_fl

    # [Integer] Sets the number of hit highlights to request from Solr.
    attr_accessor :hl_snippets

    # [String] The name of the value in the response to hold the number of groups found
    # in a grouped request. Defaults to "group_count", set to nil to omit.
    attr_accessor :group_count

    DEFAULT_PAGE_SIZE = 20

    # Creates an instance of the SearchParams class.
    #
    # @param q [String] The q value to use.
    # @param fq [Array] An array of {SolrLite::FilterQuery} objects to pass to Solr.
    # @param facets [Array] An array of {SolrLite::FacetField} objects to pass to Solr.
    #
    def initialize(q = "", fq = [], facets = [])
      @q = q
      @fq = fq          # array of FilterQuery
      @facets = facets  # array of FacetField
      @page = 1
      @page_size = DEFAULT_PAGE_SIZE
      @fl = nil
      @sort = ""
      @facet_limit = nil
      @spellcheck = false
      # Solr's hit highlighting parameters
      @hl = false
      @hl_fl = nil
      @hl_snippets = 1
      @group_count = "group_count"
    end

    # Returns facet information about a given field.
    #
    # @param field [String] Name of the field.
    # @return [SolrLite::FacetField] An object with the facet information.
    #
    def facet_for_field(field)
      @facets.find {|f| f.name == field}
    end

    # Sets the `remove_url` value for the given facet and value.
    #
    # @param field [String] Name of facet field.
    # @param value [String] Value of the facet field.
    # @param url [String] URL to set.
    #
    def set_facet_remove_url(field, value, url)
      facet = facet_for_field(field)
      if facet != nil
        facet.set_remove_url_for(value, url)
      end
    end

    # Calculates the starting row number.
    #
    # @return [Integer] The starting row number for the current page and page_size.
    #
    def start_row()
      (@page - 1) * @page_size
    end

    # Sets the starting row number and recalculates the current page based on the current page_size.
    def star_row=(start)
      # recalculate the page
      if @page_size == 0
        @page = 0
      else
        @page = (start / @page_size) + 1
      end
      nil
    end

    # Calculates the query string that we need render on the browser to execute
    # a search with the current parameters.
    #
    # @param facet_to_ignore [SolrLite::FilterQuery] Object with a specific facet to ignore when
    #     creating the query string. This is used to create the "remove this facet from the search"
    #     links that are shown to the user.
    # @param q_override [String] The q value to use if we want to use a different value
    #     from the current one.
    #
    # @return [String] The string calculated.
    #
    def to_user_query_string(facet_to_ignore = nil, q_override = nil)
      qs = ""
      q_value = q_override != nil ? q_override : @q
      if q_value != "" && @q != "*"
        qs += "&q=#{@q}"
      end
      @fq.each do |filter|
        if facet_to_ignore != nil && filter.solr_value == facet_to_ignore.solr_value
          # don't add this to the query string
        else
          qs += "&fq=#{filter.qs_value}"
        end
      end
      qs += "&rows=#{@page_size}" if @page_size != DEFAULT_PAGE_SIZE
      qs += "&page=#{@page}" if @page != 1
      # Don't surface this to the UI for now
      # (since we don't let the user change the sorting)
      # qs += "&sort=#{@sort}" if sort != ""
      qs
    end

    # Calculates the query string that we need render on the browser to execute
    # a search with the current parameters and NO q parameter.
    #
    # @return [String] The string calculated.
    #
    def to_user_query_string_no_q()
      to_user_query_string(nil, '')
    end

    # Calculates the query string that needs to be passed to Solr to issue a search
    # with the current search parameters.
    #
    # @param extra_fqs [Array] Array of {SolrLite::FilterQuery} objects to use.
    # @return [String] Query string to pass to Solr for the current parameters.
    #
    def to_solr_query_string(extra_fqs = [])
      qs = ""
      if @q != ""
        qs += "&q=#{@q}"
      end

      # Filter query
      @fq.each do |filter|
        qs += "&fq=#{filter.solr_value}"
      end

      extra_fqs.each do |filter|
        qs += "&fq=#{filter.solr_value}"
      end

      qs += "&rows=#{@page_size}"
      qs += "&start=#{start_row()}"
      if sort != ""
        qs += "&sort=#{CGI.escape(@sort)}"
      end

      if @spellcheck
        qs += "&spellcheck=on"
      end

      # Hit highlighting parameters
      if @hl
        qs += "&hl=true"
        if @hl_fl != nil
          qs += "&hl.fl=" + CGI.escape(@hl_fl)
        end
        if @hl_snippets > 1
          qs += "&hl.snippets=#{@hl_snippets}"
        end
      end

      # Facets
      if @facets.count > 0
        qs += "&facet=on"

        facet_ranges = @facets.select {|f| f.range == true }.map { |f| f.name }
        facet_ranges.each do |field_name|
          qs += "&facet.range=#{field_name}"
        end

        @facets.each do |f|
          qs += "&facet.field=#{f.name}"
          qs += "&f.#{f.name}.facet.mincount=1"

          if f.limit != nil
            qs += "&f.#{f.name}.facet.limit=#{f.limit}"
          elsif @facet_limit != nil
            qs += "&f.#{f.name}.facet.limit=#{@facet_limit}"
          end

          if f.range
            qs += "&f.#{f.name}.facet.range.start=#{f.range_start}"
            qs += "&f.#{f.name}.facet.range.end=#{f.range_end}"
            qs += "&f.#{f.name}.facet.range.gap=#{f.range_gap}"
          end
        end
      end

      qs
    end

    # Returns an array of values that can be added to an HTML form to represent the current
    # search parameters. Notice that we do NOT include the `q` parameter because there is
    # typically an explicit HTML form value for it on the form.
    #
    # @return [Array] An array of Hash objects with the values for the current search.
    #
    def to_form_values()
      values = []

      # We create an individual fq_n HTML form value for each
      # fq value because Rails does not like the same value on the form.
      @fq.each_with_index do |filter, i|
        values << {name: "fq_#{i}", value: filter.form_value}
      end

      values << {name: "rows", value: @page_size} if @page_size != DEFAULT_PAGE_SIZE
      values << {name: "page", value: @page} if @page != 1
      # Don't surface this to the UI for now
      # (since we don't let the user change the sorting)
      # values << {name: "sort", value: @sort} if sort != ""
      values
    end

    # Returns a friendly string version of this object.
    #
    # @return [String] With information about the current search parameters.
    #
    def to_s()
      "q=#{@q}\nfq=#{@fq}"
    end

    # Creates a SearchParams object with the values in a query string.
    # This is the inverse of `to_user_query_string()`.
    #
    # @param qs [String] A query string with the search parameters to use.
    # @param facet_fields [Array] An array of {SolrLite::FacetField} to set in the returned object.
    # @return [SolrLite::SearchParams] An object prepopulated with the values indicated in the query string.
    #
    def self.from_query_string(qs, facet_fields = [])
      params = SearchParams.new
      params.facets = facet_fields
      tokens = qs.split("&")
      tokens.each do |token|
        values = token.split("=")
        name = values[0]
        value = values[1]
        fq = nil
        next if value == nil || value.empty?
        case
        when name == "q"
          params.q = url_trim(value)
        when name == "rows"
          params.page_size = value.to_i
        when name == "page"
          params.page = value.to_i
        when name == "fq" || name.start_with?("fq_")
          # Query string contains fq when _we_ build the query string, for
          # example as the user clicks on different facets on the UI.
          # A query string can have multiple fq values.
          #
          # Query string contains fq_n when _Rails_ pushes HTML FORM values to
          # the query string. Rails does not like duplicate values in forms
          # and therefore we force them to be different by appending a number
          # to them (fq_1, f1_2, ...)
          fq = FilterQuery.from_query_string(value)
          if fq != nil
            params.fq << fq
          end
        end
      end
      params
    end

    # Trims leading and trailing spaces from a URL escaped
    # string and returns the string escaped.
    def self.url_trim(value)
      return "" if value == nil
      trimmed = CGI.unescape(value).strip
      CGI.escape(trimmed)
    end
  end
end
