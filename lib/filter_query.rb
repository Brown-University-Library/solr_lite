require "cgi"

module SolrLite
  # Represents an "fq" in Solr. Field is the field to filter by
  # and value the value to filter by. In a Solr query are represented
  # as "fq=field:value"
  class FilterQuery
    attr_accessor :field, :value, :solr_value, :qs_value, :form_value
    attr_accessor :title, :remove_url

    def initialize(field, values, is_range = false)
      if is_range
        init_from_range(field, values.first)
      else
        init_from_values(field, values)
      end
    end

    def range_from()
      tokens = (value || "").split(" - ")
      return nil if tokens.count != 2
      tokens[0].gsub("*","")
    end

    def range_to()
      tokens = (value || "").split(" - ")
      return nil if tokens.count != 2
      tokens[1].gsub("*","")
    end

    # qs is assumed to be the value taken from the query string
    # in the form `field|value` or `field|value1|valueN`.
    #
    # For range values the format is: `field^start,end`
    #
    # Sometimes(*) the string comes URL encoded, for example:
    #     `field|hello`
    #     `field|hello%20world`
    # CGI.unespace handles these cases nicer than URL.decode
    #
    # (*) Values coming from HTML forms submitted via HTTP POST tend
    # to be encoded slighly different than value submitted via
    # HTTP GET requests.
    #
    # TODO: Should I remove support for multi-values
    #     (e.g. `field|value1|valueN`) since we are
    #     not using them? It will make the code here
    #     and in init_from_values() cleaner.
    def self.from_query_string(qs)
      is_range = false
      tokens = CGI.unescape(qs).split("|")
      if tokens.count < 2
        tokens = CGI.unescape(qs).split("^")
        return nil if tokens.count != 2
        is_range = true
      end
      field = ""
      values = []
      tokens.each_with_index do |token, i|
        if i == 0
          field = token
        else
          values << token
        end
      end
      FilterQuery.new(field, values, is_range)
    end

    private
      # Creates a filter query (fq) string as needed by Solr from
      # an array of values. Handles single and multi-value gracefully.
      # For single-value it returns "(field:value)". For multi-value
      # it returns "(field:value1) OR (field:value2)". We use the
      # multi-value in the Advanced Search when we allow the user to
      # select multiple values for a single facet.
      def to_solr_fq_value(field, values)
        solr_value = ""
        values.each_with_index do |v, i|
          solr_value += '(' + field + ':"' + v + '")'
          lastValue = (i == (values.length-1))
          if !lastValue
            solr_value += " OR "
          end
        end
        # Very important to escape the : otherwise URL.parse throws an error in Linux
        CGI.escape(solr_value)
      end

      def to_solr_fq_value_range(field, range_start, range_end)
        if range_start.empty?
          range_start = "*"
        end
        if range_end.empty?
          range_end = "*"
        end
        solr_value = '(' + field + ':[' + range_start + ' TO ' + range_end + '])'
        # Very important to escape the : otherwise URL.parse throws an error in Linux
        CGI.escape(solr_value)
      end

      # range_string is expected in the form "start,end"
      def init_from_range(field, range_string)
        @field = field
        tokens = (range_string || "").split(",")
        return nil if tokens.count != 2
        range_start = tokens[0]
        range_end = tokens[1]
        @value = "#{range_start} - #{range_end}"
        @solr_value = to_solr_fq_value_range(field, range_start, range_end)
        @qs_value = "#{field}^#{range_string}"
        @form_value = "#{field}^#{range_string}"  # HTML Form friendly (no encoding, the form auto-encodes on POST)
        @title = field                            # default to field name
        @remove_url = nil
      end

      def init_from_values(field, values)
        @field = field
        @value = values.join("|")
        @solr_value = to_solr_fq_value(field, values)
        @qs_value = "#{field}"
        values.each do |v|
          @qs_value += "|#{CGI.escape(v)}"        # URL friendly (no : or quotes)
        end
        @form_value = "#{field}|#{@value}"        # HTML Form friendly (no encoding, the form auto-encodes on POST)
        @title = field                            # default to field name
        @remove_url = nil
      end
  end # class
end # module
