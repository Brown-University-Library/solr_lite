require "minitest/autorun"
require "solr_lite"
class SearchParamsTest < Minitest::Test

  def default_facets
    facet_A = SolrLite::FacetField.new("fieldA", "Field A")
    facet_B = SolrLite::FacetField.new("fieldB", "Field B")
    [facet_A, facet_B]
  end

  def test_from_query_string
    # Make sure leading and trailing spaces are removed
    params = SolrLite::SearchParams.from_query_string("q=  &x=1")
    assert params.q == ""

    params = SolrLite::SearchParams.from_query_string("q=hello world&x=1")
    assert params.q == "hello+world"

    params = SolrLite::SearchParams.from_query_string("q=  hello world &x=1")
    assert params.q == "hello+world"
  end

  def test_to_user_query_string
    # Search param defaults
    q = "hello"
    fq = [SolrLite::FilterQuery.from_query_string('F1|V1 b&w')]
    params = SolrLite::SearchParams.new(q, fq, default_facets())
    assert params.q == "hello"

    assert params.fq.count == 1
    assert params.fq[0].field == "F1"
    assert params.fq[0].value == "V1 b&w"

    assert params.page == 1
    assert params.page_size == 20
    assert params.facet_for_field("fieldA") != nil
    assert params.facet_for_field("fieldB") != nil

    # From params to query string
    qs = params.to_user_query_string
    assert qs.include?("q=hello")
    assert qs.include?("fq=F1|V1+b%26w")

    # From query string to params
    params2 = SolrLite::SearchParams.from_query_string(qs, default_facets())
    assert params2.q == "hello"
    assert params2.page == 1
    assert params2.page_size == 20
    assert params2.facet_for_field("fieldA") != nil
    assert params2.facet_for_field("fieldB") != nil

    # With different page size and page numbers
    params2.page = 2
    params2.page_size = 3
    qs = params2.to_user_query_string
    assert qs.include?("q=hello")
    assert qs.include?("rows=3")
    assert qs.include?("page=2")
  end

  def test_to_solr_query_string
    q = "hello"
    fq = [SolrLite::FilterQuery.from_query_string('F1|V1')]
    params = SolrLite::SearchParams.new(q, fq, default_facets())
    qs = params.to_solr_query_string()
    assert qs.include?("&q=hello")
    assert qs.include?("&rows=20")
    assert qs.include?("&start=0")

    # Expect this value to be URL encoded. This is important because
    # non encoded works OK on the Mac but not on Linux.
    assert qs.include?('&fq=%28F1%3A%22V1%22%29')

    # Make sure the facets are included
    assert qs.include?("&facet.field=fieldA")
    assert qs.include?("&facet.field=fieldB")
  end

  def test_to_solr_query_string_q_vs_fq
    q = "hello"
    fq = [SolrLite::FilterQuery.from_query_string('F1|V1')]

    # q and fq
    params = SolrLite::SearchParams.new(q, fq)
    qs = params.to_solr_query_string
    assert qs.include?("&q=hello")
    assert qs.include?('&fq=%28F1%3A%22V1%22%29')

    # no q
    params = SolrLite::SearchParams.new("", fq)
    qs = params.to_solr_query_string
    assert !qs.include?("&q=")
    assert qs.include?('&fq=%28F1%3A%22V1%22%29')

    # no fq
    params = SolrLite::SearchParams.new(q)
    qs = params.to_solr_query_string
    assert qs.include?("&q=hello")
    assert !qs.include?("&fq=")

    # neither q not fq
    params = SolrLite::SearchParams.new()
    qs = params.to_solr_query_string
    assert !qs.include?("&q=")
    assert !qs.include?("&fq=")
  end

  def test_to_solr_query_string_encoding
    # use `q` and `fq` values that must be encoded before sending to Solr
    q = CGI.escape("B & W")
    journal_name = "Signs: Journal of Women's in Culture & Society"
    qs = "published_in|" + CGI.escape(journal_name)
    fq = [SolrLite::FilterQuery.from_query_string(qs)]

    params = SolrLite::SearchParams.new(q, fq)
    solr_qs = params.to_solr_query_string
    assert solr_qs.include?('q=B+%26+W')
    assert solr_qs.include?('fq=%28published_in%3A%22Signs%3A+Journal+of+Women%27s+in+Culture+%26+Society%22%29')
  end

  def test_to_solr_facet_ranges
    # Default facets with no ranges
    q = "*"
    fq = []
    params = SolrLite::SearchParams.new(q, fq, default_facets())
    qs = params.to_solr_query_string
    assert qs.include?("&facet.field=fieldA")
    assert qs.include?("&facet.field=fieldB")
    assert !qs.include?("&facet.range")

    # Add two facets with ranges
    facets = default_facets()
    range1 = SolrLite::FacetField.new("fieldR1", "Field R1")
    range1.range = true
    range1.range_start=10
    range1.range_end=100
    range1.range_gap=5
    facets << range1
    range2 = SolrLite::FacetField.new("fieldR2", "Field R2")
    range2.range = true
    range2.range_start=3
    range2.range_end=9
    range2.range_gap=1
    facets << range2
    params = SolrLite::SearchParams.new(q, fq, facets)
    qs = params.to_solr_query_string
    assert qs.include?("&facet.field=fieldA")
    assert qs.include?("&facet.field=fieldB")
    assert qs.include?("&facet.range=fieldR1&facet.range=fieldR2")
    assert qs.include?("&f.fieldR1.facet.range.start=10")
    assert qs.include?("&f.fieldR1.facet.range.end=100")
    assert qs.include?("&f.fieldR1.facet.range.gap=5")
    assert qs.include?("&f.fieldR2.facet.range.start=3")
    assert qs.include?("&f.fieldR2.facet.range.end=9")
    assert qs.include?("&f.fieldR2.facet.range.gap=1")
  end

  def test_to_solr_facet_limit
    q = "hello"
    fq = []
    params = SolrLite::SearchParams.new(q, fq, default_facets())
    params.facets[1].limit = 8
    qs = params.to_solr_query_string()
    # Make sure facet limit for the second facet is honored
    assert !qs.include?("&f.fieldA.facet.limit")
    assert qs.include?("&f.fieldB.facet.limit=8")
  end
end
