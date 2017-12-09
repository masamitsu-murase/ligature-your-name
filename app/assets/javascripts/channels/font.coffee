
log = (obj) ->
  console.log(obj)

@handleError = (id) ->
  log("Disconnected")

@setDownloadLink = (blob) ->
  document.querySelector("#font_file_link").href = URL.createObjectURL(blob)

@updateProgressBar = (type, value) ->
  if type == "create"
    base = 0
    max = 30
  else
    base = 30
    max = 70
  value = base + Math.min(value, 1.0) * max
  document.querySelector("#font_progress_bar").value = value

@downloadFont = (id, url) ->
  log("downloadFont: #{id}")
  xhr = new XMLHttpRequest()
  xhr.open("GET", url, true)
  xhr.responseType = "blob"
  xhr.onload = (e) ->
    log("load completes.")
    blob = xhr.response
    updateProgressBar("download", 1.0)
    setDownloadLink(blob)
  xhr.onerror = ->
    handleError(id)
  xhr.onabort = ->
    handleError(id)
  xhr.ontimeout = ->
    handleError(id)
  xhr.onprogress = (e) ->
    log("onprogress")
    if e.lengthComputable
      updateProgressBar("download", e.loaded / e.total)
  xhr.send()

@updateProgressState = (id, count) ->
  log("updateProgressState: #{id}:#{count}")
  updateProgressBar("create", count/10)

@connectFontCreator = (id, url) ->
  status = "initial"
  timer_id = null
  creating_count = 0
  App.cable.subscriptions.create { channel: "FontChannel", id: id },
    connected: ->
      # Called when the subscription is ready for use on the server
      status = "connected"
      creating_count = 0
      @check()
      timer_id = setInterval =>
        @check()
      , 1500

    disconnected: ->
      if status != "end"
        status = "end"
        handleError(id)
      if timer_id != null
        clearInterval(timer_id)
        timer_id = null

    received: (data) ->
      # Called when there's incoming data on the websocket for this channel
      switch data.event
        when "created"
          status = "end"
          App.cable.disconnect()
          downloadFont(id, url)
        when "creating"
          creating_count += 1
          updateProgressState(id, creating_count)
        when "error"
          status = "end"
          handleError(id)
          App.cable.disconnect()
        else
          console.error("Unknown event")
          console.error(data)

    check: ->
      @perform 'check'
