module SolrLite
  class Highlights

    # solr_response_hash a Solr HTTP response parsed via JSON.parse()
    def initialize(solr_reponse_hash)
      @highlighting = solr_reponse_hash.fetch("highlighting", {})
    end

    # solr_response (string) is the Solr HTTP response from a query
    def self.from_response(solr_response)
      hash = JSON.parse(solr_response)
      Highlights.new(hash)
    end

    # Returns the highlight information for the given document ID.
    def for(id)
      return nil if @highlighting[id] == nil
      @highlighting[id]
    end
  end
end
