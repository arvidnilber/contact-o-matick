require 'bundler'
Bundler.require

require_relative 'contact-o-matic-backend'
require_relative 'db/seeder'

run(ContactOMaticBackend)