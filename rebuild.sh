# http://guides.rubygems.org/make-your-own-gem/
gem uninstall solr_lite
gem build solr_lite.gemspec
gem install solr_lite-0.0.14.gem

ruby test/run_all.rb

# gem push solr_lite-0.0.14.gem
