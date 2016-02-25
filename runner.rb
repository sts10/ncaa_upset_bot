require 'nokogiri'
require 'open-uri'
require 'twitter'
require 'pry'
require_relative 'secrets.rb'

class ScoreScraper
  def initialize(url)
    @doc = Nokogiri::HTML(open(url))
    @all_games = []
  end

  def scrape_scores
    games = @doc.css("section.game") # .map{|e| e.css("div.score-row") } # div.mod-content
    # binding.pry
    @all_games = []

    games.each do |game_noko|
      this_game = Game.new(game_noko)
      if this_game.active? 
        this_game.get_game_info
        @all_games << this_game
      end
    end
  end

  def announce_upsets
    @all_games.each do |this_game|
      if this_game.upset? 
        this_game.announce
      end
    end
  end
end

class Game
  def initialize(game_noko)
    @game_noko = game_noko
    @game_status = game_noko.css("div.game-status").text
  end

  def active?
    half_text = "Half"
    @game_status.include?(half_text)
  end

  def get_game_info
    if @game_status.downcase.strip == "halftime"
      @half = "Halftime"
    else
      @half = @game_status[0]
      @time_left_in_half = @game_noko.css("div.game-status").text[-5..-1]
    end

    @team1_name = @game_noko.css("a")[0].text 
    @team2_name = @game_noko.css("a")[1].text 

    if @game_noko.css("div.rank")[0] # .text
      @team1_rank = @game_noko.css("div.rank")[0].text 
    else 
      @team1_rank = "100"
    end

    if @game_noko.css("div.rank")[1] # .text
      @team2_rank = @game_noko.css("div.rank")[1].text 
    else
      @team2_rank = "100"
    end

    @team1_points = @game_noko.css("table.linescore td.final")[0].text
    @team2_points = @game_noko.css("table.linescore td.final")[1].text
    @live_url = "http://www.ncaa.com/scoreboard/basketball-men/d1" # @game_noko.css('div.gamecenter-links a.watch-live').attribute('href')
  end

  def second_half?
    @half.to_i != 1
  end

  def less_than_minutes(num)
    if @time_left_in_half
      minutes = @time_left_in_half[0..-4]
      if minutes.to_i < num
        return true
      else
        return false
      end
    end
  end

  def upset? 
    if @team1_rank.to_i > @team2_rank.to_i && @team1_points.to_i > @team2_points.to_i && self.second_half? && self.less_than_minutes(8)
      return true
    elsif @team2_rank.to_i > @team1_rank.to_i && @team2_points.to_i > @team1_points.to_i && self.second_half? && self.less_than_minutes(8)
      return true
    else
      return false
    end
  end

  def announce
    text_to_tweet = "Potential upset:\n#{@team1_rank} #{@team1_name}: #{@team1_points}\n#{@team2_rank} #{@team2_name}: #{@team2_points}\nHalf: #{@half}#{", " + @time_left_in_half + " left" if @half != "Halftime"}\nMore: #{@live_url}"
    puts "Tweeting: #{text_to_tweet}"
    TWITTER_REST.update(text_to_tweet)
  end 
end 

puts "Watching for potential upsets."

while (1 < 2)
  this_scrape = ScoreScraper.new("http://www.ncaa.com/scoreboard/basketball-men/d1")
  this_scrape.scrape_scores
  this_scrape.announce_upsets
  sleep 120 
end


