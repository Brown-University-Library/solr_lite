SolrLite is a lightweight class to execute commands against Solr from Ruby.

## Samples of usage
```
require 'solr_lite'
solr = SolrLite::Solr.new("http://localhost:8983/solr/bibdata")

# get by ID
doc = solr.get("00000002")
puts doc

# simple search
response = solr.search_text("title:'Songs of the Lakes and other poems'")
puts response.num_found
response.solr_docs.each do |doc|
  puts doc
end

# complex search
fq = SolrLite::FilterQuery.new("subjects", ["school hygiene"])
params = SolrLite::SearchParams.new("*:*", [fq])
response = solr.search(params)
puts response.num_found
response.solr_docs.each do |doc|
  puts doc
end
```

## Source code
The code is under the `lib` folder. The main files are:
* `solr.rb` defines the main `SolrLite::Solr` class.
* `search_params.rb` defines query search parameters used by Solr class. See also `facet_field` and `filter_query.rb`
* `response` defines the response returned by Solr.


## Tests
Rudimentary "unit tests" are under the `tests` folder. Run `ruby tests/test.rb` to execute them. These tests assume that you have a Solr core created and populated with the data on the `tests/books.json` file.


## Building the gem
To build the gem run `gem build solr_lite.gemspec`. If you make changes to the code be sure to update the version specified in `solr_lite.gemspec` so that you get a new versioned gem.

For testing while developing I run the following commands
```
gem uninstall solr_lite
gem build solr_lite.gemspec
gem install solr_lite-0.0.3.gem
ruby tests/test.rb
```
