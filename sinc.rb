#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"
require "haml"
require "yaml"
require "dropbox_sdk"
require "sinatra"
require "pp"

enable :sessions

token_file = "token.yaml"

if File.exists?(token_file)
  token = YAML.load_file("token.yaml")
end

get '/auth' do
  if params[:oauth_token] 
    dropbox_session = DropboxSession.deserialize(session[:dropbox_session])
    access_token = dropbox_session.get_access_token
    access_hash = { :key => access_token.key, :secret => access_token.secret }
    fh = File.new(token_file,"w")
    fh.puts access_hash.to_yaml
    fh.close
    session[:dropbox_session] = dropbox_session.serialize # re-serialize the authenticated session
    redirect '/'
  else
    dropbox_session = DropboxSession.new('pmdl9ie7lltknnb','8qf70i3xust7m6l')
    session[:dropbox_session] = dropbox_session.serialize
    if token and dropbox_session.set_access_token(token[:key], token[:secret])
      session[:dropbox_session] = dropbox_session.serialize
      redirect '/'
    else
      redirect dropbox_session.get_authorize_url(callback=request.url)
    end
  end
end

get '/' do 
  redirect '/index'
end

get '/:name' do
  if session[:dropbox_session] 
    dropbox_session = DropboxSession.deserialize(session[:dropbox_session])
    @client = DropboxClient.new(dropbox_session, :app_folder)
    # client.account_info().inspect
    # dropbox_session.access_token.key
    begin
      @file = @client.get_file(params[:name] + ".txt")
    rescue Exception => e
      halt unless params[:name] == 'index'
    end
    
    @files = @client.search("/",".txt")
    haml :template
  else
    redirect '/auth'
  end
end

get "/logout" do
  session = {}
  # redirect "/"
end
