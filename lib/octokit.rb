require "json"
require "mechanize"
require "octokit"

class Sawyer::Resource
  def to_hash_without_urls
    tmp = self
    tmp = tmp.to_hash.reject{|k,v| k.to_s =~ /_url$/}
    tmp = tmp.map do |key, val|
      val = val.is_a?(self.class) ? val.to_hash_without_urls : val
      [key, val]
    end
    Hash[tmp]
  end
end

module Octokit
  self.auto_paginate = true
  class Query
    def initialize params = {}
      @user  = params["user"]
      @token = params["token"]
      halt 404, { error: "token is required!" }.to_json if @token.blank?
      @params = params
      @client = Octokit::Client.new
      @client.access_token = @token
    end

    def fetch prefix, methods = []
      methods = [methods].flatten(1)
      methods = Hash[methods.map{|method| [method, send("#{prefix}_#{method}")]}]
      graphs_to_int_time(methods)
    end

    def gists_all
      return @gists if @gists
      @gists = @client.gists @user
    end

    def repos_all
      return @repos if @repos
      @repos = @client.repos @user
    end

    def issues_all
      return @issues if @issues
      @issues = repos_all.map do |repo|
        @client.issues(repo.full_name, state: "all").map do |issue|
          issue.repo = repo
          issue.to_hash_without_urls
        end
      end.flatten(1)
    end

    def open_issues_all
      return @open_issues if @open_issues
      repos = repos_all.select{|repo| repo.open_issues_count > 0}
      @open_issues = repos.map do |repo|
        @client.issues(repo.full_name).map do |issue|
          issue.repo = repo
          issue.to_hash_without_urls
        end
      end.flatten(1)
    end

    def contributions_all
      return @contributions if @contributions
      url  = "https://github.com/users/#{@user}/contributions"
      page = fetch_page! url
      contributions = page.search("rect.day").map do |day|
        time = Time.parse(day.attribute("data-date").text)
        push = day.attribute("data-count").text.to_i
        [time, push]
      end
      @contributions = Hash[contributions]
    end

    alias :contributions_daily :contributions_all

    def contributions_on_days
      contributions_daily.select{|t,c| c > 0}.keys
    end

    def contributions_weekly
      contributed = contributions_on_days
      weekly = contributions_daily.group_by{|t,c| t - t.wday.days}
      weekly = Hash[weekly.map{|t,v| [t, v.map(&:last).inject(0,:+)]}]
      weekly.select{|t,c| contributed.include?(t)}
    end

    def contributions_monthly
      contributed = contributions_on_days
      monthly = contributions_daily.group_by{|t,c| t - t.day.days}
      monthly = Hash[monthly.map{|t,v| [t, v.map(&:last).inject(0,:+)]}]
      monthly.select{|t,c| contributed.include?(t)}
    end

    def contributions_last_on
      last = contributions_on_days.last || contributions_daily.last.to_a[0]
      last.to_i * 1000
    end

    def contributions_total
      contributions_daily.values.sum
    end

    def contributions_streak
      contributed = contributions_on_days
      streak = contributed.map.with_index do |day, i|
        s  = 0
        s += 1 while contributed.include?(day + s.days)
        [day, s]
      end.max_by{|pair| pair[1]} if contributed.any?
      streak = [ Time.now, 0 ] unless streak

      { start:  streak[0].to_i * 1000,
        finish: (streak[0] + streak[1].days).to_i*1000,
        streak: streak[1] }
    end

    def gists_all_time
      gists = gists_all.group_by do |gist|
        gist.send(@params.fetch(:group_by, :updated_at))
      end
      Hash[gists.map{|t,d| [t, d.count]}]
    end

    def gists_last_week
      gists_all_time.select{|t,c| t >= 1.week.ago }
    end

    def gists_last_month
      gists_all_time.select{|t,c| t >= 1.month.ago }
    end

    def gists_last_year
      gists_all_time.select{|t,c| t >= 1.year.ago }
    end

    def repos_daily
      repos = repos_all.group_by do |repo|
        time  = repo.send(@params.fetch(:group_by, :pushed_at))
        time -= time.sec + time.min.minutes + time.hour.hours
      end
      repos = repos.map{|time, items| [time, items.count]}
      Hash[repos]
    end

    def repos_weekly
      weekly = repos_daily.group_by{|time, count| time - time.wday.days}
      Hash[weekly.map{|t,d| [t, d.count]}]
    end

    def repos_monthly
      monthly = repos_daily.group_by{|time, count| time - time.day.days}
      Hash[monthly.map{|t,d| [t, d.count]}]
    end

    def repos_yearly
      yearly = repos_daily.group_by do |time, count|
        time - (time.day-1).days - (time.month-1).months
      end
      Hash[yearly.map{|t,d| [t, d.count]}]
    end

    def open_issues_daily
      issues = @issues ? issues_all : open_issues_all
      issues = issues.select{|issue| issue[:state] == "open"}
      issues = issues.group_by do |issue|
        time = issue[@params.fetch(:group_by, :updated_at).to_sym]
        time - time.sec - time.min.minutes - time.hour.hours
      end
      Hash[issues.map{|time,data| [time, data.count]}]
    end

    def open_issues_weekly
      weekly = open_issues_daily.group_by{|time, count| time - time.wday.days}
      Hash[weekly.map{|t,d| [t, d.count]}]
    end

    def open_issues_monthly
      monthly = open_issues_daily.group_by{|time, count| time - time.day.days}
      Hash[monthly.map{|t,d| [t, d.count]}]
    end

    def open_issues_yearly
      yearly = open_issues_daily.group_by do |time, count|
        time - (time.day-1).days - (time.month-1).months
      end
      Hash[yearly.map{|t,d| [t, d.count]}]
    end

    def closed_issues_daily
      issues = issues_all.select{|issue| issue[:state] == "closed"}
      issues = issues.group_by do |issue|
        time = issue[@params.fetch(:group_by, :updated_at).to_sym]
        time - time.sec - time.min.minutes - time.hour.hours
      end
      Hash[issues.map{|time,data| [time, data.count]}]
    end

    def closed_issues_weekly
      weekly = closed_issues_daily.group_by{|time, count| time - time.wday.days}
      Hash[weekly.map{|t,d| [t, d.count]}]
    end

    def closed_issues_monthly
      monthly = closed_issues_daily.group_by{|time, count| time - time.day.days}
      Hash[monthly.map{|t,d| [t, d.count]}]
    end

    def closed_issues_yearly
      yearly = closed_issues_daily.group_by do |time, count|
        time - (time.day-1).days - (time.month-1).months
      end
      Hash[yearly.map{|t,d| [t, d.count]}]
    end

    def repos_list
      sort_by = @params.fetch(:sort_by, :updated_at)
      repos_all.map(&:to_hash_without_urls).sort_by{|repo| repo[sort_by]}
    end

    def gists_list
      sort_by = @params.fetch(:sort_by, :updated_at)
      gists_all.map(&:to_hash_without_urls).sort_by{|gist| gist[sort_by]}
    end

    def open_issues_list
      issues  = @issues ? issues_all : open_issues_all
      sort_by = @params.fetch(:sort_by, :updated_at)
      issues.sort_by{|issue| issue[sort_by]}
    end

    def closed_issues_list
      issues = issues_all.select{|issue| issue[:state] == "closed"}
      sort_by = @params.fetch(:sort_by, :updated_at)
      issues.sort_by{|issue| issue[sort_by]}
    end

    def issues_list
      sort_by = @params.fetch(:sort_by, :updated_at)
      issues_all.sort_by{|issue| issue[sort_by]}
    end

    private

    def agent
      @agent ||= Mechanize.new{|a| a.user_agent_alias = 'Mac Safari'}
    end

    def fetch_page! url, options = {}
      page = fetch_page url, options
      halt 500, { error: "could not request page: #{url}"} if page.blank?
      page
    end

    def fetch_page url, options = {}
      params  = options.fetch :params,  {}
      referer = options.fetch :referer, nil
      headers = options.fetch :headers, {}
      agent.get url, params, referer, headers
    rescue Mechanize::ResponseCodeError
      options[:retry] = options.fetch(:retry, 3) - 1
      retry if options[:retry] > 0
    end

    def graphs_to_int_time graphs
      graphs = graphs.map do |type, graph|
        if graph.is_a?(Hash)
          graph = graph.map do |time, data|
            [time.is_a?(Time) ? time.to_i*1000 : time, data]
          end.sort_by{|data| data[0]}
          graph = Hash[graph]
        end
        [type, graph]
      end
      Hash[graphs]
    end
  end
end
