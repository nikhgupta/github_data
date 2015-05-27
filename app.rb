require 'rubygems'
require 'time'
require 'sinatra'
require 'rdiscount'
require 'active_support/all'

pattern = File.join(File.dirname(__FILE__), "lib", "**", "*.rb")
Dir.glob(pattern).each{ |file| require file }
before { content_type 'application/json' }

helpers do
  def query(resource, type = nil, to_json = true)
    type   ||= request.env['PATH_INFO'].split("/").reject{|a| a.empty?}.first
    @query ||= Octokit::Query.new(@params)

    data = {error: "no such method implemented!"}
    methods  = [send("#{type}_mapping_for", resource)].flatten
    if methods and methods.any?
      data     = @query.fetch(resource, methods)
      data     = data.count > 1 ? data : data[methods.first.to_sym]
    end
    to_json ? data.to_json : data
  end

  def stats_mapping_for(resource)
    hash = { contributions: %w[daily weekly monthly last_on total streak],
             gists: %w[ last_week last_month last_year all_time ],
             repos: %w[ daily weekly monthly yearly ],
             open_issues: %w[ daily weekly monthly yearly ],
             closed_issues: %w[ daily weekly monthly yearly ] }
    hash[resource.to_sym]
  end

  def list_mapping_for(resource)
    available = %w[open_issues closed_issues gists repos]
    available = available & [resource.to_s]
    available.any? ? :list : nil
  end
end

get '/' do
  content_type 'text/html'
  markdown :root, layout: :layout, layout_engine: :erb
end

get '/stats/:stats/list/:list' do
  list = params["list"].split(",")
  stat = params["stats"].split(",")
  data = {stats: {}, lists: {}}
  stat.each{|item| data[:stats][item.to_sym] = query(item, :stats, false) }
  list.each{|item| data[:lists][item.to_sym] = query(item, :list, false) }
  data.to_json
end

get '/stats/issues' do
  { open: query(:open_issues), closed: query(:closed_issues)}
end

get '/stats/:resource' do
  resource = params["resource"].split(",")
  if resource.count > 1
    Hash[resource.map{|r| [r, query(r, :stats, false)]}].to_json
  else
    query resource.first, :stats
  end
end

get '/list/:resource' do
  resource = params["resource"].split(",")
  if resource.count > 1
    Hash[resource.map{|r| [r, query(r, :list, false)]}].to_json
  else
    query resource.first, :list
  end
end
