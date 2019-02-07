require "minitest/autorun"
require "solr_lite"
class SolrDataTest < Minitest::Test
  #
  # These tests depend on a running version of Solr with the data
  # found in books.json. With Solr 7.x you can upload the data via:
  #
  #   $ path-to-solr/bin/post -c bibdata books.json
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
    response = @solr.search_text('title_txt_en:"Songs of the Lakes and other poems"')
    assert_equal 1, response.num_found
  end

  def test_complex_search
    fq1 = SolrLite::FilterQuery.new("subjects_txts_en", ["school hygiene"])
    params = SolrLite::SearchParams.new("*:*", [fq1])
    response = @solr.search(params, [], nil, nil, true)
    assert response.num_found > 0
    response.solr_docs.each do |doc|
      target_subject = doc["subjects_txts_en"].find {|x| x.downcase == "school hygiene"}
      assert target_subject != nil
    end
  end

  def test_highlighting
    params = SolrLite::SearchParams.new("title_txt_en:washington", [])
    params.hl = true
    params.hl_fl = "title_txt_en"
    response = @solr.search(params, [], nil, nil, true)
    highlights = response.highlights()
    first_id = response.solr_docs[0]["id"]
    assert highlights != nil
    assert highlights.for(first_id) != nil
  end


  # The default configuration in solrconfig.xml for the spellchecker uses the _text_
  # field but we don't have this field defined in our schema.
  #
  # TODO: define the field in the schema or update the solrconfig.xml so that the
  #       spell checker can be tested without manual intervention.
  #
  # def test_spellcheck
  #   params = SolrLite::SearchParams.new("title:washingtn", [])
  #   params.spellcheck = true
  #   response = @solr.search(params, [], nil, nil, true)
  #   assert_equal "washingtn", response.spellcheck.suggestions()[0]
  #   assert_equal "washington", response.spellcheck.suggestions()[1]["suggestion"].first
  #   assert_equal "washington", response.spellcheck.top_collation_query()
  # end
end
