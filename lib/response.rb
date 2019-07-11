require "facet_field.rb"
require "explainer.rb"
require "spellcheck.rb"
require "highlights.rb"
module SolrLite
  class Response
    attr_accessor :items, :solr_response

    def initialize(solr_response, params)
      @solr_response = solr_response
      @params = params
      @explainer = nil
      @highlights = nil

      set_facet_values()

      # This value can be set by the client if we want to use a custom
      # representation of solr_docs while preserving the entire Response
      # object.
      @items = []
    end

    def ok?
      return true if status == 0
      return true if status >= 200 && status <= 299
      false
    end

    def status
      return -1 if @solr_response["responseHeader"] == nil
      @solr_response["responseHeader"]["status"]
    end

    def error_msg
      return "" if @solr_response["error"] == nil
      return "" if @solr_response["error"]["msg"] == nil
      @solr_response["error"]["msg"]
    end

    # Total number documents found in solr
    # usually larger than solr_docs.count
    def num_found

      if @solr_response["response"] != nil
        # Normal Solr query
        return @solr_response["response"]["numFound"]
      end

      if @solr_response["grouped"] != nil
        # Grouped Solr query.
        total = 0
        @solr_response["grouped"].keys.each do |key|
          total += @solr_response["grouped"][key]["matches"]
        end
        return total
      end

      return 0
    rescue
      0
    end

    # Total number of groups found in Solr
    # for a grouped request.
    def groups_found
      if @solr_response["grouped"] != nil && @params.group_count != nil
        return @solr_response["facets"][@params.group_count] || 0
      end
      return 0
    rescue
      0
    end

    # Total number documents found in Solr
    # for a given group field/value/
    def num_found_for_group(group_field, group_value)
      group = @solr_response["grouped"][group_field]["groups"]
      docs_for_value = group.find {|x| x["groupValue"] == group_value }
      return 0 if docs_for_value == nil
      docs_for_value["doclist"]["numFound"]
    rescue
      0
    end

    def num_pages
      return 0 if page_size == 0
      pages = (num_found / page_size).to_i
      pages += 1 if (num_found % page_size) != 0
      pages
    end

    def page_size
      @solr_response["responseHeader"]["params"]["rows"].to_i
    rescue
      0
    end

    # Start position for retrieval (used for pagination)
    def start
      if @solr_response["response"] != nil
        @solr_response["response"]["start"].to_i
      else
        # For grouped responses
        # (I believe we could use this value for grouped and not-grouped
        # responses, but for backwards compatibility and since I have not
        # tested it for non-grouped responses, for now we only use it for
        # grouped responses.)
        @solr_response["responseHeader"]["params"]["start"].to_i
      end
    rescue
      0
    end

    def end
      [start + page_size, num_found].min
    end

    def page
      return 1 if page_size == 0 # fail safe
      (start / page_size) + 1
    end

    # Raw solr_docs
    def solr_docs
      @solr_response["response"]["docs"]
    end

    # Groups in the solr_docs (see Solr.search_group())
    def solr_groups(group_field)
      return [] if @solr_response["grouped"] == nil
      @solr_response["grouped"][group_field]["groups"].map {|x| x["groupValue"]}
    end

    # Documents for a given group field and value (see Solr.search_group())
    def solr_docs_for_group(group_field, group_value)
      group = @solr_response["grouped"][group_field]["groups"]
      docs_for_value = group.find {|x| x["groupValue"] == group_value }
      return [] if docs_for_value == nil
      docs = docs_for_value["doclist"]["docs"]
      docs
    end

    def facets
      @params.facets
    end

    def set_facet_values()
      return if @solr_response["facet_counts"] == nil
      solr_ranges = @solr_response["facet_counts"]["facet_ranges"] || {}
      solr_facets = @solr_response["facet_counts"]["facet_fields"]
      solr_facets.each do |solr_facet|
        # solr_facet is an array with two elements, e.g.
        # ["record_type", ["PEOPLE", 32, "ORGANIZATION", 4]]
        #
        # the first element has the field for the facet (record_type)
        # the second element is an array with of value/count pairs (PEOPLE/32, ORG/4)
        field_name = solr_facet[0]
        facet_field = @params.facet_for_field(field_name)

        if facet_field == nil
          # Solr returned facets for a field that we did not ask for. Ignore it.
          next
        end

        if facet_field.range
          # Use the range values as the facet values.
          #
          # Notice that we are overloading the "values" field and therefore
          # we lose (i.e. don't store) the actual facet values and their counts.
          # We might want to rethink this and keep them both.
          values = solr_ranges[facet_field.name]["counts"] || []
          pairs_count = values.count/2
          for pair in (1..pairs_count)
            index = (pair-1) * 2
            start_range = values[index].to_i
            end_range = start_range + facet_field.range_gap - 1
            count = values[index+1]
            facet_field.add_range(start_range, end_range, count)
          end
        else
          # Regular facet values
          values = solr_facet[1]
          pairs = values.count/2
          for pair in (1..pairs)
            index = (pair-1) * 2
            text = values[index]
            count = values[index+1]
            facet_field.add_value(text, count)
          end
        end
      end
    end

    def explainer()
      @explainer ||= SolrLite::Explainer.new(@solr_response)
    end

    def spellcheck()
      @spellcheck ||= SolrLite::Spellcheck.new(@solr_response)
    end

    def highlights()
      @highlights ||= SolrLite::Highlights.new(@solr_response)
    end
  end # class
end # module
