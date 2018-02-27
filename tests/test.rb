require "solr_lite"

# TODO:
#   Document how to upload the sample data used in these tests
#   found in books.json
#
#   Consider changing this to use minitest.
#

solr_url = "http://localhost:8983/solr/bibdata"
logger = nil # SolrLite::Logger
solr = SolrLite::Solr.new(solr_url, logger)


# Test: Get by ID
doc = solr.get("00000002")
if doc == nil
  abort "Did not find document by ID"
end

if doc["id"] != "00000002"
  abort "ID mismatch"
end

doc = solr.get("xx00000002")
if doc != nil
  abort "Found non existing document"
end


# Test: Simple search
response = solr.search_text("title:'Songs of the Lakes and other poems'")
if response.num_found == 0
  abort "Document was not found"
elsif response.num_found > 1
  abort "More than one document found"
end


# Test: Complex search
fq1 = SolrLite::FilterQuery.new("subjects", ["school hygiene"])
params = SolrLite::SearchParams.new("*:*", [fq1])
response = solr.search(params, [], nil, nil, true)
if response.num_found == 0
  abort "No documents found with subject 'school hygiene'"
end
response.solr_docs.each do |doc|
  if doc["subjects"].find {|x| x.downcase == "school hygiene"} == nil
    abort "Document does not contain the subject 'school hygiene'"
  end
end


# Test: Spellcheck
response = solr.search_text("washingtn")
puts response.spellcheck.suggestions()
puts response.spellcheck.collations()
puts response.spellcheck.top_collation_query()
puts "done"
