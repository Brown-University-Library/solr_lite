Gem::Specification.new do |s|
  s.name = "solr_lite"
  s.version = "0.0.10"
  s.date = "2019-01-25"
  s.summary = "A lightweight gem to connect to Solr and run queries"
  s.description = "A lightweight gem to connect to Solr and run queries. Requires no extra dependencies."
  s.authors = ["Hector Correa"]
  s.email = "hector_correa@brown.edu"
  s.files = ["lib/solr_lite.rb", "lib/solr.rb",
    "lib/explain_entry.rb", "lib/explainer.rb",
    "lib/facet_field.rb", "lib/filter_query.rb",
    "lib/highlights.rb", "lib/search_params.rb",
    "lib/response.rb", "lib/spellcheck.rb"]
  s.homepage = "https://github.com/Brown-University-Library/solr_lite"
  s.license = "MIT"
end
