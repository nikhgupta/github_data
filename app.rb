require 'rubygems'
require 'time'
require 'sinatra'
require 'rdiscount'
require 'active_support/all'

pattern = File.join(File.dirname(__FILE__), "lib", "**", "*.rb")
Dir.glob(pattern).each{ |file| require file }
before do
  headers 'Access-Control-Allow-Origin' => '*'
  content_type 'application/json'
end

helpers do
  def github_query(resource, type = nil, to_json = true)
    type   ||= request.env['PATH_INFO'].split("/").reject{|a| a.empty?}.first
    @query ||= Octokit::Query.new(@params)

    data = {error: "no such method implemented!"}
    methods  = [send("#{type}_mapping_for", resource)].flatten
    if methods and methods.any?
      data = @query.fetch(resource, methods)
      data = data.count > 1 ? data : data[methods.first.to_sym]
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

  def lists_mapping_for(resource)
    available = %w[open_issues closed_issues gists repos]
    available = available & [resource.to_s]
    available.any? ? :list : nil
  end

  def charts_mapping_for(resource)
    :chart
  end
end

get '/' do
  content_type 'text/html'
  markdown :root, layout: :layout, layout_engine: :erb
end

get '/ip' do
  data    = Hash[request.env.map{|k,v| [k.underscore, v]}]
  regex   = /^(async\.|rack\.|sinatra\.|server_)/
  data    = data.reject{|k,v| k =~ regex || v.blank? }
  as_text = params["format"] =~ /(plain|te?xt|html)/
  content_type 'text/plain' if as_text
  data    = params["keys"].split(",").map{|k| data[k.underscore]} if params["keys"]
  return data.to_json unless as_text
  data.is_a?(Hash) ? data.map{|k,v| "#{k.upcase}: #{v}"}.join("\n") : data.join("\n")
end

get '/github/charts/:charts/stats/:stats/lists/:lists' do
  lists  = params["lists"].split(",")
  stats  = params["stats"].split(",")
  charts = params["charts"].split(",")
  data = {stats: {}, lists: {}, charts: {}}
  stats.each{ |item| data[:stats][item.to_sym]  = github_query(item, :stats, false) }
  lists.each{ |item| data[:lists][item.to_sym]  = github_query(item, :lists, false) }
  charts.each{|item| data[:charts][item.to_sym] = github_query(item, :charts, false) }
  data.to_json
end

get '/github/:type/:resource' do
  resource = params["resource"].split(",")
  type     = params["type"].to_sym
  if resource.count > 1
    Hash[resource.map{|r| [r, github_query(r, type, false)]}].to_json
  else
    github_query resource.first, type
  end
end
