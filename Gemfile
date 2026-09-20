source "https://rubygems.org"
gemspec
gem "sqlite3", "~> 2.1"
gem "pg", "~> 1.5" if ENV["DATABASE_URL"]&.start_with?("postgres")
