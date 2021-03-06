displayAbove = (hash) ->
  return if window.topMarker.lock
  window.topMarker.lock = true
  topData window.topMarker, 200, (rows, newTopMarker) ->
    window.topMarker = newTopMarker
    window.logTemplate.tmpl(Logs: rows).prependTo "#content"
    if hash
      setTimeout (->
        window.location.hash = "#1"
        window.location.hash = "#" + hash
        window.topMarker.lock = `undefined`
      ), 100
    else
      window.topMarker.lock = `undefined`

displayBelow = (hash) ->
  return  if window.bottomMarker.lock
  window.bottomMarker.lock = true
  bottomData window.bottomMarker, 200, (rows, newBottomMarker) ->
    window.bottomMarker = newBottomMarker
    window.logTemplate.tmpl(Logs: rows).appendTo "#content"
    window.bottomMarker.lock = `undefined`
    if hash
      setTimeout (->
        window.location.hash = "#1"
        window.location.hash = "#" + hash
      ), 100

bottomData = (marker, number, cb, rows) ->
  if number is 0
    cb rows, marker
    return
  getLog marker.date, (logs) ->
    unless logs
      marker.location is "end"
      bottomData marker, 0, cb, rows or []
    else
      rlogs = logs.slice(marker.location + 1, marker.location + number + 1)
      if rlogs.length < number
        marker.date = _(_(marker.date).createGmtDate().add(d: 1)).gmtDate()
        marker.location = -1
      bottomData marker, number - rlogs.length, cb, _(rows or []).concat(rlogs)

topData = (marker, number, cb, rows) ->
  if number is 0
    cb rows, marker
    return
  getLog marker.date, (logs) ->
    unless logs
      marker.location is "end"
      topData marker, 0, cb, rows or []
    else
      count = number
      marker.location = logs.length  unless marker.location
      n = marker.location - number
      if n < 0
        n = 0
        count = marker.location
      rlogs = logs.slice(n, marker.location)
      marker.location = n
      if n is 0
        marker.date = _(_(marker.date).createGmtDate().subtract(d: 1)).gmtDate()
        marker.location = `undefined`
      topData marker, number - count, cb, _(rlogs).concat(rows or [])

getLog = (dateString, cb) ->
  if dateString of logs
    cb logs[dateString]
  else
    $.get("/logs/" + dateString + ".log", (data) ->
      logs[dateString] = _(data.split("\n")).chain().reject((l) ->
        l is ""
      ).map((l) ->
        t = l.indexOf(",")
        timestamp = Number(l.slice(1, t))
        timestamp: timestamp
        date: _.date(timestamp).format("dddd, MMMM Do YYYY, hh:mm:ss")
        msg: l.slice(t + 2, -2)
      ).value()
      cb logs[dateString]
    ).error ->
      console.log arguments
      cb `undefined`

window.logTemplate = undefined

$ ->
  window.logTemplate = $("#logTemplate")
  url = document.location.toString()
  match = /.*#(.*)/.exec(url)
  timestamp = (if match then Number(match[1]) else new Date().getTime())
  date = _(timestamp).chain().date().gmtDate().value()
  getLog date, (data) ->
    location = _(data).sortedIndex {timestamp: timestamp}, (log) -> log.timestamp
    location = data.length - 1  if location >= data.length
    window.topMarker = {date: date, location: location}
    window.bottomMarker = { date: date, location: location}
    window.logTemplate.tmpl(Logs: [data[location]]).appendTo "#content"
    displayAbove()
    displayBelow data[location].timestamp


_.mixin
  gmtDate: (date) ->
    date = date.date if date.date
    yyyy = date.getUTCFullYear().toString()
    mm = date.getUTCMonth().toString()
    mm = "0#{mm}" if mm.length is 1
    dd = date.getUTCDate().toString()
    dd = "00#{dd}" if dd.length is 1
    "#{yyyy}_#{mm}_#{dd}"

  createGmtDate: (str) ->
    dtm = /(.*)_(.*)_(.*)/.exec(str)
    d = new Date()
    d.setUTCFullYear dtm[1]
    d.setUTCMonth dtm[2]
    d.setUTCDate dtm[3]
    _.date d

window.topMarker = {}
window.bottomMarker = {}
logs = {}
$(window).scroll (e) ->
  #scroll position
  #wait for 500 milliseconds to confirm the user scroll action
  displayBelow()  if $(document).height() - $(window).scrollTop() - $(window).height() < 500
  if $(window).scrollTop() < 500
    oldHash = $("#content a").attr("name")
    #wait for 500 milliseconds to confirm the user scroll action
    displayAbove oldHash
