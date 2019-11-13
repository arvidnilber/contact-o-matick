require 'sqlite3'
require 'faker'
require 'bcrypt'
class Seeder

  def self.seed! 
    db = SQLite3::Database.new 'db/contacts.db'
    


    db.execute 'DROP TABLE IF EXISTS users'
    db.execute 'CREATE TABLE users (
                "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                "username" VARCHAR(255) UNIQUE NOT NULL,
                "password_hash" VARCHAR(255) NOT NULL)'

    hashed_password = BCrypt::Password.create("123")
    db.execute('INSERT INTO users (username, password_hash) VALUES (?, ?)', "linus", hashed_password)
    hashed_password = BCrypt::Password.create("321")
    db.execute('INSERT INTO users (username, password_hash) VALUES (?, ?)', "sunil", hashed_password)


    db.execute 'DROP TABLE IF EXISTS contacts'
    db.execute 'CREATE TABLE contacts (
                  "id"	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                  "company" VARCHAR(255) NOT NULL,
                  "first_name" TEXT,
                  "last_name" TEXT,
                  "phone" TEXT,
                  "email" TEXT,
                  "user_id" INTEGER)'

    20.times do 
      company = "#{Faker::Company.name} #{Faker::Company.suffix}"
      first_name = Faker::Name.first_name
      last_name = Faker::Name.last_name
      phone = Faker::PhoneNumber.phone_number
      user_id = rand(1..2)
      email = "#{first_name}.#{last_name}@#{company}.#{Faker::Internet.domain_suffix}"
      db.execute('INSERT INTO contacts (company, first_name, last_name, phone, email, user_id) VALUES (?,?,?,?,?,?)', 
        company, first_name, last_name, phone, email, user_id)
    end
  
    db.execute 'DROP TABLE IF EXISTS notes'
    db.execute 'CREATE TABLE notes (
                  "id"  INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                  "company_id" INTEGER NOT NULL,
                  "user_id"  INTEGER NOT NULL,
                  "text" TEXT)'

    60.times do 
      company_id = rand(1..20)
      user_id = rand(1..2)
      text = Faker::Lorem.sentence(word_count: 3, random_words_to_add: 7)
      db.execute('INSERT INTO notes (company_id, user_id, text) VALUES (?,?,?)', company_id, user_id, text)
    end

  end
end