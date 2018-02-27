module SolrLite
  class Spellcheck
    def initialize(solr_reponse_hash)
      @spellcheck = solr_reponse_hash.fetch("spellcheck", {})
    end

    def suggestions()
      @suggestions ||= @spellcheck.fetch("suggestions",[])
    end

    def collations()
      @collations ||= begin
        collations = @spellcheck.fetch("collations",nil)
        if collations != nil
          if collations.kind_of?(Array)
            # We must be in Solr6, use the collation information as-is
          else
            # uh-oh...
            []
          end
        else
          # We must be on Solr4, mimic the structure of the Solr6 results
          # which is an array in the form:
          #
          #   ["collation", {"collationQuery": "wordA"}, "collation", {"collationQuery": "wordB"}, ...]
          #
          # As a reference, the structure in Solr4 is slightly different in that
          # the collationQuery information is in an array within an array:
          #
          #   ["collation", ["collationQuery", "wordA"], "collation"["collationQuery", "wordB"], ...]
          #
          collations = []
          suggestions = suggestions()
          suggestions.each_with_index do |x, i|
            if x == "collation"
              collationQuery = suggestions[i+1]
              word = collationQuery[1]
              collations << "collation"
              collations << {"collationQuery" => word}
            end
          end
        end
        collations
      end
    end

    # def spellcheck_correctly_spelled()
    #   @spellcheck.fetch("correctlySpelled", true)
    # end

    def top_collation_query()
      colls = collations()
      return nil if colls.length < 2
      top_collation = colls[1] || {}
      top_collation.fetch("collationQuery", nil)
    end
  end
end
