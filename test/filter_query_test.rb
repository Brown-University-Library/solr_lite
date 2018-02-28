require "minitest/autorun"
require "solr_lite"
class FilterQueryTest < Minitest::Test
  def test_single_fq
    fq = SolrLite::FilterQuery.new("F1",["V1"])

    assert_equal "F1", fq.field
    assert_equal "V1", fq.value
    assert_equal "%28F1%3A%22V1%22%29", fq.solr_value
    assert_equal "F1|V1", fq.qs_value
    assert_equal "F1|V1", fq.form_value
  end

  def test_multiple_fq
    fq = SolrLite::FilterQuery.new("F1", ["V1", "V2"])
    assert_equal "F1", fq.field
    assert_equal "V1|V2", fq.value
    assert_equal "%28F1%3A%22V1%22%29+OR+%28F1%3A%22V2%22%29", fq.solr_value
    assert_equal "F1|V1|V2", fq.qs_value
    assert_equal "F1|V1|V2", fq.form_value
  end

  def test_encodings
    fq = SolrLite::FilterQuery.from_query_string('F1|V1 b&w')
    assert_equal "F1", fq.field
    assert_equal "V1 b&w", fq.value
    assert_equal "%28F1%3A%22V1+b%26w%22%29", fq.solr_value
    assert_equal "F1|V1+b%26w", fq.qs_value
    assert_equal "F1|V1 b&w", fq.form_value
  end
end
