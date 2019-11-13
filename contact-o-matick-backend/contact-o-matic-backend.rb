require 'sinatra'
require 'bcrypt'
require 'jwt'
require 'byebug'
MY_SECRET_SIGNING_KEY = "secret"

class ContactOMaticBackend < Sinatra::Base
 
  def initialize
    super
    @db = SQLite3::Database.new('db/contacts.db')
    @db.results_as_hash = true
  end

  helpers do
    def base_url
      @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}" #short-circuit logic
    end

    def authenticated?
      bearer = env.fetch('HTTP_AUTHORIZATION', '').slice(7..-1)
     
      return false unless bearer
      begin
        @token = JWT.decode(bearer, MY_SECRET_SIGNING_KEY, false)
        @user = @db.execute("SELECT * FROM users WHERE id = ?", @token.first['id']).first
        @user_id = @user["id"]
        return !!@user
      rescue JWT::DecodeError => ex
        return false
      end
    end
  end

  configure do
    enable :cross_origin
  end
  
  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
    content_type :json
  end
  
  #Preflight request
  options "*" do
    response.headers["Access-Control-Allow-Methods"] = "GET, PUT, POST, PATCH, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Location, Accept, X-User-Email, X-Auth-Token"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Expose-Headers"] = "Location, Link"
    200
  end
  
  #special
  get '/api/v1/reset/?' do
    Seeder.seed!
    @db.execute('SELECT * FROM contacts').to_json
  end

  #index
  get '/api/v1/contacts/?' do
    if authenticated?
      contacts = @db.execute('SELECT * from contacts').map{ |contact| [contact['id'], contact]}.to_h.to_json
      [200, contacts]
    else 
      [401, "Error: not authenticated"]
    end 

  end

  #show
  get '/api/v1/contacts/:id/?' do
    if authenticated?
      contact_id = params["id"].to_i
      contact = @db.execute("SELECT user_id FROM contacts WHERE id = ?", contact_id).first
      if @user_id == contact["user_id"].to_i
        contact = @db.execute('SELECT * from contacts WHERE id = ?', [params['id']]).first.to_json
        [200, contact]
      else
        [401, "You are not the owner".to_json] 
      end
    else 
      [401, "Error: not authenticated"]
    end 
  end

  #update
  patch '/api/v1/contacts/:id/?' do
    if authenticated?
      db_contact = @db.execute('SELECT * from contacts WHERE id = ? LIMIT 1', params['id']).first
      if @user["id"] == db_contact["user_id"].to_i
        incoming_changes = JSON.parse(request.body.read)

        updated_contact = db_contact.merge(incoming_changes)
        pp updated_contact        
        result = @db.execute("UPDATE contacts SET company = ?, first_name = ?, last_name = ?, phone = ?, email = ? WHERE id = ?",  
        [ 
          updated_contact["company"],
          updated_contact["first_name"],
          updated_contact["last_name"],
          updated_contact["phone"],
          updated_contact["email"],
          updated_contact["id"] 
        ])
        pp result
        [200, "Successfully Updated the contact "]
      else
        [401, "You are not the owner"]
      end
    else 
      [401, "Error not authenticated"]  
    end               
  end

  #create
  post '/api/v1/contacts/?' do
    if authenticated?
      contact = JSON.parse(request.body.read)
      result = @db.execute('INSERT into contacts (company, first_name, last_name, phone, email, user_id) 
                          VALUES (?,?,?,?,?,?)',
                            [contact['company'], 
                            contact['first_name'],
                            contact['last_name'],
                            contact["phone"],
                            contact["email"],
                            @user["id"]])
      [200, "User was successfully created"]                          
    else 
      [401, "Authentication error"]
    end
  end

  delete '/api/v1/contacts/:id' do
    if authenticated?
      contact_id = params["id"].to_i
      contact = @db.execute("SELECT user_id FROM contacts WHERE id = ?", contact_id).first
      if @user["id"] == contact["user_id"]
        deletedContact = @db.execute("DELETE FROM contacts WHERE id = ?", contact_id)
        deletedNotes = @db.execute("DELETE FROM notes WHERE user_id = ?", contact_id)
        [200, "Sucessfully deleted contact"]
      else 
        [401, "Failed to Delete contact"]
      end
    else
      [401, "Authentication Failed"]
    end
  end


  get '/api/v1/notes/?' do 
    if authenticated?
      result = @db.execute('SELECT * from notes').to_json
    end
  end

  get '/api/v1/contacts/:id/notes' do
    if authenticated?
      contact_id = params["id"].to_i
      contact = @db.execute("SELECT user_id FROM contacts WHERE id = ?", contact_id).first
      if @user_id == contact["user_id"].to_i
        result = @db.execute("SELECT * from notes where user_id = ?", contact_id).to_json
        [200, result]
      else
        [401, "You are not the owner"]
      end
    else 
      [401, "Error: not authenticated"]
    end
  end
  
  get '/api/v1/notes/:id/?' do
    if authenticated?
      notes = @db.execute('SELECT * from notes WHERE id = ?', [params['id']]).to_json
      [200, notes]
    else 
      [401, "Error: not authenticated"]
    end
  end
  
  delete '/api/v1/notes/:id/?' do
    if authenticated?
      @db.execute('DELETE FROM notes WHERE id = ?', [params['id']])
      [200, "Succesfully deleted note #{params['id']}"]
    else 
      [401, "Error: not authenticated"]
    end
  end

  patch '/api/v1/notes/:id/?' do
    require 'pp'
    if authenticated? 
      incoming_changes = JSON.parse(request.body.read)
      pp incoming_changes
      note = @db.execute('SELECT * from notes WHERE id = ? LIMIT 1', params['id']).first
      pp note
      updated_note = note.merge(incoming_changes)
      result = @db.execute('UPDATE notes SET company_id = ?, user_id = ?, text = ? WHERE id = ?', 
      [
        updated_note['company_id'], 
        updated_note['user_id'], 
        updated_note['text'], 
        updated_note['id']
      ])
      [200, result]
    else
      [401, "Error: not authenticated"]
    end                        
  end
  
  post '/api/v1/notes/:contactId' do 
    if authenticated? 
      contact_id = params["contactId"].to_i
      contact = @db.execute("SELECT user_id FROM contacts WHERE id = ?", contact_id).first
      if @user["id"] == contact["user_id"]
        incoming_changes = JSON.parse(request.body.read)
        result = @db.execute('INSERT INTO notes (company_id, user_id, text) VALUES (?,?,?)', 
        [
          incoming_changes['company_id'], 
          contact_id, 
          incoming_changes['text']
        ])
        [200, result]
      else
        [401, "You are not the owner..."]
      end
    else
      [401, "Error: not authenticated"]
    end
  end

  get '/api/v1/users/token' do
    if authenticated?
      user_wop = @user.dup
      user_wop.delete('password_hash')
      [200, user_wop.to_json]
    else
      [401, "Error: not authenticated."] 
    end
  end

  get '/api/v1/users/:userId/contacts' do
    if authenticated?
      result = @db.execute('SELECT * from contacts WHERE user_id = ?', [params["userId"].to_i]).to_json
      [200, result]
    else
      [401, "Error: not authenticated."] 
    end
  end



  #login
  post '/api/v1/users/login' do
    user_form = JSON.parse(request.body.read)

    user = @db.execute('SELECT * FROM users WHERE username = ?', user_form['username']).first
    unless user && BCrypt::Password.new(user['password_hash']) == user_form['password']
      [401, ""]
    else

      response = {
        token: JWT.encode({id: user['id']}, MY_SECRET_SIGNING_KEY)
      }

      [200, response.to_json]
    end
  end

end