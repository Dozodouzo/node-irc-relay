_ = require('../utils')
RegexUrlMatcher = require("#{__dirname}/base/regex_url_matcher")

param_string = _({
  request: 'anime',
  client: 'justatest',
  clientver: '1',
  protover: '1'
}).stringify()

class Anidb extends RegexUrlMatcher
  constructor: ({@emitter}) ->
    super
    @commands = {a: @command}
    @command._help = "search anidb for the anime that matches the terms. !a <name> lists all the matches, or the show if there is only one match. !a x <name> gives you the xth match."
#  regexes: [
#    /http:\/\/anidb\.net\/perl-bin\/animedb.pl\?(?:.*)aid=(\d+)(?:.*)/,
#    /http:\/\/anidb\.net\/a(\d+)(?:.*)/
#    ]

#  on_match: (from, match) =>
#    @get_info match[1], ({titles: [{title: t_list}], description}) =>
#      english_title = @get_english_title(t_list)
#      title_string = _(t_list).find(({type}) => type is 'main')['#']
#      title_string += " (\x0309#{english_title})" if english_title
#      @emitter "\x0302That anidb link is: #{title_string}. \x0305#{description}"

  get_english_title: (t_list, extract) =>
    match = (lang_name, type_name) =>
      _(t_list).find ({lang, type}) => lang is lang_name and type is type_name
    english_node = match("en", "official") or
      match("en", "synonym") or
      match("x-jat", "synonym")
    english_node?['#']

  get_english_title_anidb: (t_list) =>
    get_english_title _(t_list).map ({"xml:lang": lang, type}) => {lang: lang, type: type}

  get_info: (aid, cb) =>
    url = "http://api.anidb.net:9001/httpapi?#{param_string}&aid=#{aid}"
    _.requestXmlAsJson {uri: url, cache: aid}, (err, {anime}) ->
      cb(anime) unless err or !anime

  command: (from, tokens, cb) =>
    @parse_query tokens, (error, number, search_tokens) =>
      return cb("!a <anime name>") if error
      query_fn = if @is_inexact_query(search_tokens) then @inexact else @exact
      query_fn search_tokens, (animes) =>
        animes = [animes] unless _(animes).isArray()
        return cb("No Results") if @no_data_in_range(animes, number)
        if animes.length is 1
          @display_info animes[0], cb
        else if number
          @display_info animes[number-1], cb
        else
          @display_options search_tokens, animes, cb

  is_inexact_query: (search_tokens) =>
    search_tokens[0] is '~' and search_tokens.length > 1

  no_data_in_range: ({length}, number) =>
    length is 0 or (number and number > length)

  parse_query: (tokens, cb) =>
    [number, search_tokens] = @split_query(tokens)
    if _(search_tokens).isEmpty()
      cb(true)
    else
      cb(null, number, search_tokens)

  split_query: (tokens) =>
    if /^\d+$/.test(_(tokens).head())
      [_(tokens).head(), _(tokens).tail()]
    else
      [null, tokens]

  url: (search_for) =>
    param_search = _({task: "search", query: search_for}).stringify()
    "http://anisearch.outrance.pl/?#{param_search}"

  ani_search: (search_for, cb) =>
    _.requestXmlAsJson {uri: @url(search_for)}, (error, data) =>
      if error
        console.error "anidb search error #{error}"
      else
        cb data

  inexact: (tokens, cb) =>
    tokens = tokens[1..] if tokens[0] is '~'
    {true: long_tokens, false: short_tokens} =
      _(tokens).groupBy ({length}) => length >= 4
    search_for = _(_(long_tokens).map (t) -> "+#{t}").
      concat(_(short_tokens).map (t) -> "%#{t}%").join(" ")
    @ani_search search_for, ({animetitles: {anime}}) =>
      cb anime if anime

  exact: (tokens, cb) =>
    @ani_search "\\#{tokens.join(" ")}", ({animetitles: {anime}}) =>
      if anime
        cb anime
      else
        @inexact tokens, cb

  display_info: ({title: t_list, aid}, cb) =>
    name = _(t_list).find(({type}) => type is 'main')['#']
    exact_name = _(t_list).find(({exact}) => exact)?['#'] or name
    english_name = @get_english_title(t_list) or name
    msg = name + (if name is exact_name then "" else " also known as #{exact_name}")
    @get_info aid, (result) =>
      r_score = result.ratings?[0].permanent[0]['#'] ? "\u0002\u000304N/A\u000f"
      r_votes = result.ratings?[0].permanent[0]['count'] ?  "\u0002\u000304N/A\u000f"
      r_array = "#{r_score} / Votes: #{r_votes}"
      c_array = result.tags?[0].tag ? ""
      if c_array == "" then "\u0002\u000304N/A\u000f" else c_array = _.chain(c_array).filter((x) -> x.infobox).sortBy('weight').reverse().pluck('name').flatten().value()
      c_array = if c_array == "" then "\u0002\u000304N/A\u000f" else JSON.stringify(c_array).replace(/[\[\]\"]/g, "").split(',', 6).join(', ')
      c_desc = if result.description? then "#{result.description}" else ""
      c_desc = if c_desc == "" then c_desc else c_desc.replace(/https?:\/\/[a-z][\/ \w.]*/g, "").replace(/[\[\]]/g, "").replace(/Source:.*\n?.*/g, "").replace(/\r?\n|\r/g, " ")
      c_desc = if c_desc == "" then "" else c_desc = if c_desc.length > 435 then c_desc.substring(0,435) + "\[...\]" else c_desc = if c_desc.length < 435 then c_desc else c_desc
      t = result.type
      s = result.startdate[0] or "\u0002\u000304TBD\u000f"
      s = if s == "\u0002\u000304TBD\u000f" then s else if s == "1970-01-01" then "\u0002\u000304TBD\u000f" else s
      e = result.enddate[0] or "\u0002\u000304TBD\u000f"
      e = if e == "\u0002\u000304TBD\u000f" then e else if e == "1970-01-01" then "\u0002\u000304TBD\u000f" else e
      c = if not result.episodecount? then "\u0002\u000304TBD\u000f" else if result.episodecount == "0" then "\u0002\u000304TBD\u000f" else result.episodecount
      cb "\[Anime: #{msg}\] - \[#{t}\] - \[Episodes: #{c}\] - \[Airdates: #{s} / #{e}\] - \[Tags: #{c_array}\] - \[Rating: #{r_array}\] - \[Link: http://anidb.net/a#{aid} \]\n#{c_desc}"
      
  display_options: (search_tokens, animes, cb) =>
    list_str = _(animes).chain().
      first(7).
      numbered().
      map(([i, {title: t_list}]) => "#{i}. #{_(t_list).find(({exact}) => exact)['#']}").
      sentence().
      value()
    cb "#{search_tokens.join(' ')} could be #{list_str} #{if animes.length > 7 then 'or others.' else '.'}"

module.exports = Anidb
