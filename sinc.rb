#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"
require "haml"
require "yaml"
require "dropbox_sdk"
require "sinatra"
require "RedCloth"
require "pp"

enable :sessions

token_file = "token.yaml"

get '/auth' do
  # if we got redirected from dropbox.com to here we are getting the access token 
  # and saving it for future use
  if params[:oauth_token] 
    dropbox_session = DropboxSession.deserialize(session[:dropbox_session])
    access_token = dropbox_session.get_access_token
    access_hash = { :key => access_token.key, :secret => access_token.secret }
    fh = File.new(token_file,"w")
    fh.puts access_hash.to_yaml
    fh.close
    session[:dropbox_session] = dropbox_session.serialize 
    redirect '/'
  else
    # if we got redirected from another page...
    keys = YAML.load_file("keys.yaml")
    dropbox_session = DropboxSession.new(keys['key'], keys['secret'])
    session[:dropbox_session] = dropbox_session.serialize
    # redirect to dropbox.com to authorize
    redirect dropbox_session.get_authorize_url(callback=request.url)
  end
end

get '/' do 
  redirect '/Index'
end

get "/logout" do
  session = {}
  if File.exists?('token.yaml')
    File.unlink("token.yaml")
  end
  halt "Logged out"
end

get '/:name' do
  pp session
  # If a dropbox session doesn't exist create a new one
  if ! session[:dropbox_session]
    dropbox_session = DropboxSession.new('pmdl9ie7lltknnb','8qf70i3xust7m6l')

    # If a token file exists load it 
    if File.exists?(token_file)
      token = YAML.load_file("token.yaml")
    end

    # If there was something inside the token file try to use it 
    if token
      begin
        dropbox_session.set_access_token(token[:key], token[:secret])
        session[:dropbox_session] = dropbox_session.serialize
      rescue Net::HTTPUnauthorized
        redirect '/auth'
      end
    else
      redirect '/auth'
    end
  end

  dropbox_session = DropboxSession.deserialize(session[:dropbox_session])

  pp dropbox_session.authorized?
  if ! dropbox_session.authorized?
    redirect '/auth'
  end

  @client = DropboxClient.new(dropbox_session, :app_folder)
  begin
    @file = @client.get_file(params[:name] + ".txt")
  rescue DropboxError => e
    pp e.error
    begin
      @client.put_file('/Index.txt', open('template/Index.txt')) if params[:name] == "Index"
      sleep 3
      redirect '/'
    rescue DropboxAuthError => e
      puts e.inspect
      redirect '/auth'
    end
  end

  @files = @client.search("/",".txt")
  haml :template
end

