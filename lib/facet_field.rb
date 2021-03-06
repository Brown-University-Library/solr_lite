module SolrLite
  class FacetField

    class FacetValue
      attr_accessor :text, :count, :remove_url, :add_url, :range_start, :range_end
      def initialize(text = "", count = 0, remove_url = nil)
        @text = text
        @count = count
        @remove_url = remove_url
        @add_url = nil
        @range_start = nil
        @range_end = nil
      end
    end

    attr_accessor :name, :title, :values,
      :range, :range_start, :range_end, :range_gap,
      :limit

    def initialize(name, display_value)
      @name = name # field name in Solr
      @title = display_value
      @values = []
      @ranges = []
      @range = false
      @range_start = nil
      @range_end = nil
      @range_gap = nil
      @limit = nil
    end

    def to_qs(text)
      "#{@name}|#{CGI.escape(text)}"
    end

    def to_qs_range(range_start, range_end)
      "#{@name}^#{range_start},#{range_end}"
    end

    def add_value(text, count)
      @values << FacetValue.new(text, count)
    end

    def add_range(range_start, range_end, count)
      text = "#{range_start} - #{range_end}"
      value = FacetValue.new(text, count)
      value.range_start = range_start
      value.range_end = range_end
      @values << value
    end

    def value_count(text)
      v = @values.find {|v| v.text == text}
      return 0 if v == nil
      v.count
    end

    def set_remove_url_for(value, url)
      @values.each do |v|
        if v.text == value
          v.remove_url = url
        end
      end
    end

    def set_add_url_for(value, url)
      @values.each do |v|
        if v.text == value
          v.add_url = url
        end
      end
    end

    def set_urls_for(value, add_url, remove_url)
      @values.each do |v|
        if v.text == value
          v.add_url = add_url
          v.remove_url = remove_url
        end
      end
    end
  end
end
