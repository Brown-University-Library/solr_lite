require "minitest/autorun"
require "solr_lite"
class SolrDataTest < Minitest::Test
  #
  # These tests depend on a running version of Solr with the data
  # found in books.json.
  #   TODO: Document how to upload the sample data.
  #
  def setup()
    solr_url = "http://localhost:8983/solr/bibdata"
    logger = nil # SolrLite::DefaultLogger
    @solr = SolrLite::Solr.new(solr_url, logger)
  end

  def test_get_by_id
    doc = @solr.get("00000002")
    assert doc != nil
    doc = @solr.get("xx00000002")
    assert doc == nil
  end

  def test_simple_search
    response = @solr.search_text("title:'Songs of the Lakes and other poems'")
    assert_equal 1, response.num_found
  end

  def test_complex_search
    fq1 = SolrLite::FilterQuery.new("subjects", ["school hygiene"])
    params = SolrLite::SearchParams.new("*:*", [fq1])
    response = @solr.search(params, [], nil, nil, true)
    assert response.num_found > 0
    response.solr_docs.each do |doc|
      target_subject = doc["subjects"].find {|x| x.downcase == "school hygiene"}
      assert target_subject != nil
    end
  end

  def test_spellcheck
    response = @solr.search_text("washingtn")
    assert_equal "washingtn", response.spellcheck.suggestions()[0]
    assert_equal "washington", response.spellcheck.suggestions()[1]["suggestion"].first
    assert_equal "washington", response.spellcheck.top_collation_query()
  end
end
