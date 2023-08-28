# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

rails new relay -T --api
cd relay/
echo "relay" > .ruby-gemset
echo "2.5.3" > .ruby-version
cd ..
cd relay/
gem install bundler:2.1.4
bundle install
rails generate rspec:install
git init
git add .
git commit -m "new project setup"
git remote add origin git@github.com:amazing-jay/relay.git
git push -u origin main
rails db:setup
bin/rails db:migrate
rails g model User
rails g model Hits user:references:index endpoint:text
bin/rails db:migrate
bundle add devise
rails generate devise:install
rails generate devise user
rails db:migrate
bundle add sidekiq
rails db:migrate
bundle add whenever
rails generate migration AddTimeZoneToUsers
rails db:migrate
