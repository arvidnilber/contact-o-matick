require 'sinatra'
require 'bcrypt'
require 'jwt'

MY_SECRET_SIGNING_KEY = "secret"

class TodoBackend < Sinatra::Base
 
  def initialize
    super
    @db = SQLite3::Database.new('db/todos.db')
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
    @db.execute('SELECT * FROM todos').to_json
  end

  #index
  get '/api/v1/todos/?' do
      halt 401 unless authenticated?
      @db.execute('SELECT * FROM todos').map{ |todo| [todo['id'], todo] }.to_h.to_json
  end

  #show
  get '/api/v1/todos/:id/?' do
      @db.execute('SELECT * FROM todos WHERE id = ? LIMIT 1', params['id']).first.to_json
  end

  #update
  patch '/api/v1/todos/:id/?' do
      incoming_changes = JSON.parse(request.body.read)
      db_todo = @db.execute('SELECT * from todos WHERE id = ? LIMIT 1', params['id']).first
      incoming_changes['isCompleted'] = incoming_changes['isCompleted'] == 0 ? 1 : 0
      updated_todo = db_todo.merge(incoming_changes)
      result = @db.execute('UPDATE todos 
                            SET title=?, description=?, isCompleted=?
                            WHERE id = ?',
                            updated_todo['title'], updated_todo['description'], updated_todo['isCompleted'], updated_todo['id'])
      halt 200                        
  end

  #create
  post '/api/v1/todos/?' do
      content_type :json
      todo = JSON.parse(request.body.read)
      @db.execute('INSERT into todos (title, description, isCompleted) 
                            VALUES (?,?,?); SELECT last_insert_rowid()',
                            todo['title'], todo['description'], todo['isCompleted'] == true ? 1 : 0)
      id = @db.execute('SELECT last_insert_rowid();').first[0] # use a connectionpool to garantuee thread-safety
      response.headers['Location'] = "#{base_url}/api/v1/todos/#{id}"
      [201, "{\"location\": \"#{base_url}/api/v1/todos/#{id}\"}"] # because cors s@*#$s
  end

  #destroy 
  delete '/api/v1/todos/:id/?' do
      content_type :json
      result = @db.execute('DELETE FROM todos WHERE id = ?', params['id'])
      halt 200
  end

  get '/api/v1/users/token' do
    if authenticated?
      user_wop = @user.dup
      user_wop.delete('encrypted_password')
      [200, user_wop.to_json]
    else
      [401, "Error: not authenticated."] 
    end
  end

  post '/api/v1/users/login' do
    content_type :json

    user_form = JSON.parse(request.body.read)

    user = @db.execute('SELECT * FROM users WHERE username = ?', user_form['username']).first
    unless user && BCrypt::Password.new(user['encrypted_password']) == user_form['password']
      [401, ""]
    else

      response = {
        token: JWT.encode({id: user['id']}, MY_SECRET_SIGNING_KEY)
      }

      [200, response.to_json]
    end
  end

end