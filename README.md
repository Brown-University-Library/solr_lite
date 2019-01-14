SolrLite is a lightweight class to execute commands against Solr from Ruby. Requires no extra dependencies.

Information about to create a gem http://guides.rubygems.org/make-your-own-gem/

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
q = "*:*"
fq = SolrLite::FilterQuery.new("subjects", ["school hygiene"])
params = SolrLite::SearchParams.new(q, [fq])
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
There is a rudimentary set of unit tests are under the `test` folder. You need to have `minitest` installed to run them:

```
gem install minitest
ruby test/run_all.rb
```

but if you have an older version of them gem installed they might pick that one up instead of the code in this folder. To be absolutely sure I am testing the correct version I uninstall/install them gem as shown in the script below.

## Building the gem
To build the gem run `gem build solr_lite.gemspec`. If you make changes to the code be sure to update the version specified in `solr_lite.gemspec` so that you get a new versioned gem.

For testing while developing I run the following commands:
```
gem uninstall solr_lite
gem build solr_lite.gemspec
gem install solr_lite-0.0.6.gem
ruby test/run_all.rb
```

To publish a new version of the gem
```
gem push solr_lite-0.0.6.gem
```
