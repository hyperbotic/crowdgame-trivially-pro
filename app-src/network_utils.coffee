# ==================================================================================================================
NetworkServiceEventState = 

  NotSent           : 0
  Enqueued          : 1
  Skipped           : 2
  Sent              : 3
  SendError         : 4
  CompletedSuccess  : 5
  CompletedError    : 6
  TimedOut          : 7

# ==================================================================================================================
class NetworkServiceEventStats

  gInstance = null

  names = [
   "NotSent"
   "Enqueued"
   "Skipped"
   "Sent"
   "SendError"
   "CompletedSuccess"
   "CompletedError" 
   "Timedout" ]

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()->
    if not gInstance?
      gInstance = new NetworkServiceEventStats()

    return gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    @stats = []

  # ----------------------------------------------------------------------------------------------------------------
  incrementStat: (state)->

    stat = this.getStat(state)

    stat++

    @stats[state] = stat

    return @stats[state]    

  # ----------------------------------------------------------------------------------------------------------------
  getStat: (state)->

    if not @stats[state]?
      @stats[state] = 0

    return @stats[state]
  
  # ----------------------------------------------------------------------------------------------------------------
  getStateName: (state)->
    name = "??"

    if state?
      name = names[state]

    return name    

  # ----------------------------------------------------------------------------------------------------------------
  dump: ()->
    out = "NetworkServiceEventStats::dump ("

    for i in [0..names.length-1]
      out += "#{names[i]}=#{this.getStat(i)} "

    out += ")"
    
    Hy.Trace.debug out

    return

# ==================================================================================================================
class NetworkEvent

  gInstanceCount = 0

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    ++gInstanceCount

    @instanceCount = gInstanceCount

    @enqueueTime = null
    @sentTime = null

    @recurringDelay = 0
    @initialDelay = 0
    @sendLimit = 1
    @sendCount = 0
    @timeout = null

    @errorInfo = ""

    @fnPre = null
    @fnPost = null

    @state = NetworkServiceEventState.NotSent

    @readyToBeDequeued = false

    @immediate = false

    this.setTimeout()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getErrorInfo: ()-> @errorInfo

  # ----------------------------------------------------------------------------------------------------------------
  setErrorInfo: (@errorInfo)->

  # ----------------------------------------------------------------------------------------------------------------
  setFnPre: (pre)->
    @fnPre = pre

  # ----------------------------------------------------------------------------------------------------------------
  setFnPost: (post)->
    @fnPost = post

  # ----------------------------------------------------------------------------------------------------------------
  enqueueSetup: ()->
    this.setState(NetworkServiceEventState.Enqueued)
    this.setEnqueueTime()
    this.clearImmediate()

  # ----------------------------------------------------------------------------------------------------------------
  enqueue: ()->
    this.enqueueSetup()
    return Hy.Network.NetworkService.get().enqueueEvent(this)

  # ----------------------------------------------------------------------------------------------------------------
  enqueue_: ()->
    this.enqueueSetup()
    return Hy.Network.NetworkService.get().enqueueEvent_(this)

  # ----------------------------------------------------------------------------------------------------------------
  dequeue: ()->

    @readyToBeDequeued = true

  # ----------------------------------------------------------------------------------------------------------------
  isReadyToBeDequeued: ()-> @readyToBeDequeued

  # ----------------------------------------------------------------------------------------------------------------
  doFnPre: ()->

    this.doCallback("PRE", @fnPre, true, false)

  # ----------------------------------------------------------------------------------------------------------------
  doFnPost: ()->

    this.doCallback("POST", @fnPost, (@state is NetworkServiceEventState.CompletedSuccess), true)

  # ----------------------------------------------------------------------------------------------------------------
  doCallback: (display, fn, status, defer)->
    Hy.Trace.debug "NetworkEvent::doCallback (#{display} type=#{this.constructor.name} status=#{status} function=#{fn?})"

    f = (event, func, display, status)=>
#      Hy.Trace.debug "NetworkEvent::doCallback (ENTER type=#{event.constructor.name}/#{display} status=#{status})"
      result = func(event, status)
#      Hy.Trace.debug "NetworkEvent::doCallback (EXIT result=#{result})"
      return result

    result = true

    if fn?
      if defer
        # We want to clear the stack, but we also want to ensure that the callback sees the event object
        # in its current state (before the next pass through processQueue may change it)
        Hy.Utils.PersistentDeferral.create(0, ()=>f(this, fn, display, status))  
      else
        result = f(this, fn, display, status)

    return result

  # ----------------------------------------------------------------------------------------------------------------
  getStateName: ()->
    NetworkServiceEventStats.get().getStateName(@state)

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    "###{@instanceCount}/#{gInstanceCount} #{this.constructor.name} state=#{this.getStateName()} sendCount=#{@sendCount} Delay=#{@initialDelay}/#{@recurringDelay} enqueueAge=#{this.getEnqueueAge()} readyToBeSent=#{this.isReadyToBeSent()} timeSinceSent=#{this.getTimeSinceSent()} immediate=#{this.getImmediate()}"

  # ----------------------------------------------------------------------------------------------------------------
  dumpStrShort: ()->
    "###{@instanceCount}/#{gInstanceCount} #{this.constructor.name} state=#{this.getStateName()} age=#{this.getEnqueueAge()/1000}"

  # ----------------------------------------------------------------------------------------------------------------
  setImmediate: ()->
    @immediate = true
    this

  # ----------------------------------------------------------------------------------------------------------------
  clearImmediate: ()->
    @immediate = false
    this

  # ----------------------------------------------------------------------------------------------------------------
  getImmediate: ()-> @immediate

  # ----------------------------------------------------------------------------------------------------------------
  setInitialDelay: (initialDelay)->
    @initialDelay = initialDelay
    this

  # ----------------------------------------------------------------------------------------------------------------
  getInitialDelay: ()-> @initialDelay

  # ----------------------------------------------------------------------------------------------------------------
  # Specifies a minimum number of milliseconds between creation/send events
  setRecurringDelay: (recurringDelay)->
    @recurringDelay = recurringDelay
    this

  # ----------------------------------------------------------------------------------------------------------------
  getRecurringDelay: ()-> @recurringDelay

  # ----------------------------------------------------------------------------------------------------------------
  # Specifies the maximum number of times this event can be sent. Default is 1, unlimited is -1
  setSendLimit: (sendLimit)->
    @sendLimit = sendLimit

  # ----------------------------------------------------------------------------------------------------------------
  getSendLimit: ()-> @sendLimit

  # ----------------------------------------------------------------------------------------------------------------
  incrementSendCount: ()->

    @sendCount++

  # ----------------------------------------------------------------------------------------------------------------
  getSendCount: ()-> @sendCount

  # ----------------------------------------------------------------------------------------------------------------
  atSendLimit: ()->

    atLimit = false

    if @sendLimit isnt -1
      atLimit = @sendCount >= @sendLimit

    return atLimit

  # ----------------------------------------------------------------------------------------------------------------
  setEnqueueTime: ()->
    @enqueueTime = (new Date()).getTime()
    return @enqueueTime

  # ----------------------------------------------------------------------------------------------------------------
  setEnqueueTime: ()->
    @enqueueTime = (new Date()).getTime()
    return @enqueueTime

  # ----------------------------------------------------------------------------------------------------------------
  getEnqueueAge: ()->
    age = 0

    if @enqueueTime?
      age = ((new Date()).getTime()) - @enqueueTime

    return age

  # ----------------------------------------------------------------------------------------------------------------
  clearEnqueueAge: ()->
    @enqueueTime = null

  # ----------------------------------------------------------------------------------------------------------------
  isReadyToBeSent: ()->

    ready = false

    if this.getState() is NetworkServiceEventState.Enqueued 
      if not this.atSendLimit()
        if this.getImmediate() 
          ready = true
        else
          delay = 0

          if @sendCount is 0
            delay = this.getInitialDelay()
          else
            delay = this.getRecurringDelay()

          if (this.getEnqueueAge() - delay) >= 0
            ready = true

    return ready

  # ----------------------------------------------------------------------------------------------------------------
  getState: ()->
    @state

  # ----------------------------------------------------------------------------------------------------------------
  setState: (state)->

#    Hy.Trace.debug "NetworkEvent::setState (old=#{NetworkServiceEventStats.get().getStateName(@state)} new=#{NetworkServiceEventStats.get().getStateName(state)})"
    @state = state

    NetworkServiceEventStats.get().incrementStat(state)

    return @state

  # ----------------------------------------------------------------------------------------------------------------
  isErrorState: ()->

    f = (@state is NetworkServiceEventState.SendError) or 
        (@state is NetworkServiceEventState.CompletedError)

    f
  # ----------------------------------------------------------------------------------------------------------------
  wasSent: ()->
    f = (@state is NetworkServiceEventState.Sent) or 
        (@state is NetworkServiceEventState.SendError) or 
        (@state is NetworkServiceEventState.CompletedSuccess) or 
        (@state is NetworkServiceEventState.CompletedError) or

    f

  # ----------------------------------------------------------------------------------------------------------------
  wasSkipped: ()->
    @state is NetworkServiceEventState.Skipped

  # ----------------------------------------------------------------------------------------------------------------
  setSentTime: ()->
    @sentTime = (new Date()).getTime()
    @sentTime

  # ----------------------------------------------------------------------------------------------------------------
  getSentTime: ()-> @sentTime

  # ----------------------------------------------------------------------------------------------------------------
  getTimeSinceSent: ()->
    timeSinceSent = 0

    if this.wasSent() 
      timeSinceSent = ((new Date()).getTime()) - this.getSentTime()

    return timeSinceSent

  # ----------------------------------------------------------------------------------------------------------------
  getTimeout: ()-> @timeout

  # ----------------------------------------------------------------------------------------------------------------
  setTimeout: (timeout=Hy.Config.NetworkService.kDefaultEventTimeout)->
    @timeout = timeout

  # ----------------------------------------------------------------------------------------------------------------
  hasTimeout: ()-> @timeout?

  # ----------------------------------------------------------------------------------------------------------------
  checkTimedOut: ()->
    timedOut = false

    if this.hasTimeout() and this.wasSent()
      age = this.getTimeSinceSent()

      if age >= @timeout
        Hy.Trace.debug "NetworkEvent::checkTimedOut (type=#{this.constructor.name} state=#{this.getStateName()} timeout=#{@timeout} age=#{age})"

        timedOut = true

    return timedOut
  
  # ----------------------------------------------------------------------------------------------------------------
  hasTimedOut: ()->
    @state is NetworkServiceEventState.TimedOut

  # ----------------------------------------------------------------------------------------------------------------
  hasResponse: ()->
    f = (@state is NetworkServiceEventState.CompletedSuccess || @state is NetworkServiceEventState.CompletedError)
    f

  # ----------------------------------------------------------------------------------------------------------------
  skip: ()->

    this.setState(NetworkServiceEventState.Skipped)

    this.incrementSendCount()
    this.clearEnqueueAge()

    this

  # ----------------------------------------------------------------------------------------------------------------
  send: ()->

    Hy.Trace.debug "NetworkEvent::send (type=#{this.constructor.name} state=#{this.getStateName()})"

    this.setSentTime()
    this.incrementSendCount()
    this.clearEnqueueAge()

    this

  # ----------------------------------------------------------------------------------------------------------------
  response: ()->

    Hy.Trace.debug "NetworkEvent::response (type=#{this.constructor.name} state=#{this.getStateName()})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  timedout: ()->

    Hy.Trace.debug "NetworkEvent::timeout (type=#{this.constructor.name} state=#{this.getStateName()})"

    this.setState(NetworkServiceEventState.TimedOut)

    this.doFnPost()

    this

# ==================================================================================================================
class HTTPEvent extends NetworkEvent

  gHTTPClient = null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    super

    @url = null
    @uas = ""

    @responseText = null
    @responseData = null
    @responseStatus = null

    @httpTimeout = Hy.Config.NetworkService.kDefaultEventTimeout
    @httpAutoRedirect = true

    @locationURL = null

#    Hy.Trace.debug "HTTPEvent::constructor (type=#{this.constructor.name} instance=#{@instanceCount})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->

    s = super

    s += " #{this.getURL()}"

  # ----------------------------------------------------------------------------------------------------------------
  @getHTTPClient: ()->
#    Hy.Trace.debug "HTTPEvent::getHTTPClient (client=#{gHTTPClient})"

    if NetworkService.isOnline()
      if not gHTTPClient?
        try
          gHTTPClient = Ti.Network.createHTTPClient();
        catch e
          gHTTPClient = null
          new Hy.Utils.ErrorMessage "fatal", "NetworkService::getHTTPClient", "Failed to create HTTP Client"
    else
      Hy.Trace.debug "HTTPEvent::createHTTPClient (NOT ONLINE)"
      gHTTPClient = null

    return gHTTPClient

  # ----------------------------------------------------------------------------------------------------------------
  setURL: (url)->
    @url = url
  # ----------------------------------------------------------------------------------------------------------------
  getURL: ()->
    @url

  # ----------------------------------------------------------------------------------------------------------------
  getUAS: ()->
    @uas

  # ----------------------------------------------------------------------------------------------------------------
  setUAS: (uas)->
    @uas = uas

  # ----------------------------------------------------------------------------------------------------------------
  getLocationURL: ()-> @locationURL

  # ----------------------------------------------------------------------------------------------------------------
  setHTTPTimeout: (@httpTimeout)->

  # ----------------------------------------------------------------------------------------------------------------
  getHTTPTimeout: ()-> @httpTimeout

  # ----------------------------------------------------------------------------------------------------------------
  setHTTPAutoRedirect: (@httpAutoRedirect)->

  # ----------------------------------------------------------------------------------------------------------------
  getHTTPAutoRedirect: ()-> @httpAutoRedirect

  # ----------------------------------------------------------------------------------------------------------------
  send: ()->

    Hy.Trace.debug "HTTPEvent::send (type=#{this.constructor.name})"

    state = NetworkServiceEventState.SendError

    httpClient = HTTPEvent.getHTTPClient()

    if httpClient?
      state = NetworkServiceEventState.Sent

    this.setState state

    super

    if httpClient?
      b = false
      if b
        httpClient.setOndatastream( (o)=> alert o.progress)

      httpClient.onload = (o)=>this.response(true, o.error, httpClient.status, httpClient.responseText, httpClient.responseData, httpClient.getLocation())
      httpClient.onerror = (o)=>this.response(false, o.error, httpClient.status, httpClient.responseText, httpClient.responseData, httpClient.getLocation())

      httpClient.open 'GET', this.getURL() #, false # 1.1.0 https://jira.appcelerator.org/browse/TC-4836
      httpClient.setRequestHeader 'User-Agent', this.getUAS()

      httpClient.timeout = this.getHTTPTimeout()
      httpClient.autoRedirect = this.getHTTPAutoRedirect()

      httpClient.send()

    Hy.Trace.debug "HTTPEvent::send (type=#{this.constructor.name} state=#{this.getStateName()} EXIT)"

    this
  
  # ----------------------------------------------------------------------------------------------------------------
  response: (success_f, errorString, status, responseText, responseData, locationURL)->

    @responseText = responseText
    @responseData = responseData
    @responseStatus = status
    @locationURL = locationURL

    this.setErrorInfo(errorString)

    state = NetworkServiceEventState.CompletedSuccess

    if not success_f
      state = NetworkServiceEventState.CompletedError
    
    if @responseStatus isnt 200
      state = NetworkServiceEventState.CompletedError

    this.setState(state)

    super

    Hy.Trace.debug "HTTPEvent::response (SUCCESS=#{success_f} #{this.getErrorInfo()} #{@responseStatus}/#{if @responseText? then @responseText.length else "?"} chars responseData=#{@responseData?} #{this.dumpStr()}"

    this.doFnPost()

    this


# ==================================================================================================================
class NetworkService

  _.extend NetworkService, Hy.Utils.Observable

  gInstance = null

  ServiceLevelImmediate = 1
  ServiceLevelBackground = 2
  ServiceLevelSuspended = 3

  # ----------------------------------------------------------------------------------------------------------------
  @getIP: ()->

    ip = null

    if NetworkService.isOnline()
      ip = Ti.Platform.address

    ip

  # ----------------------------------------------------------------------------------------------------------------
  @isOnline: ()->
    online = Ti.Network.online

  # ---------------------------------------------------------------------------------------------------------------- 
  @init: ()->
    if not gInstance?
      gInstance = new NetworkService()

    gInstance

  # ---------------------------------------------------------------------------------------------------------------- 
  @setIsActive: ()->

    NetworkService.get()?.setIsActive()

  # ---------------------------------------------------------------------------------------------------------------- 
  @getIPURL: ()->

    url = if (s = NetworkService.get())?
      s.getIPURL()
    else
      null

    url

  # ---------------------------------------------------------------------------------------------------------------- 
  @get: ()-> gInstance

  # ---------------------------------------------------------------------------------------------------------------- 
  constructor: (serviceLevel = ServiceLevelBackground)->
    @queue = []
    @timeoutQueue = []
    @busy = false

    @interval = null

    this.setServiceLevel(serviceLevel)

    Ti.Network.addEventListener 'change', (evt)=>this.networkChangedEvent(evt)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Called by app-level code to indicate activity
  #
  setIsActive: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  networkChangedEvent: (evt)->

    Hy.Trace.info "NetworkService::networkChanged (networkType=#{evt.networkType} networkTypeName=#{evt.networkTypeName} online=#{evt.online} source=#{evt.source} type=#{evt.type})"

    this.setNetworkChanged(evt)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setNetworkChanged: (evt = null)->

    if evt?
      Hy.Trace.info "NetworkService::setNetworkChanged (networkType=#{evt.networkType} networkTypeName=#{evt.networkTypeName} online=#{evt.online} source=#{evt.source} type=#{evt.type})"
    else
      Hy.Trace.info "NetworkService::setNetworkChanged (NULL)"

    NetworkService.notifyObservers (observer)=>observer.obs_networkChanged?(evt)

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    Hy.Trace.debug "NetworkService::pause"
    this.clearInterval()

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    Hy.Trace.debug "NetworkService::resumed"
    this.setServiceLevel @serviceLevel

  # ----------------------------------------------------------------------------------------------------------------
  setSuspended: ()->
    this.setServiceLevel ServiceLevelSuspended

  # ----------------------------------------------------------------------------------------------------------------
  setBackgrounded: ()->
    this.setServiceLevel ServiceLevelBackground

  # ----------------------------------------------------------------------------------------------------------------
  setImmediate: ()->
    this.setServiceLevel ServiceLevelImmediate
    this

  # ----------------------------------------------------------------------------------------------------------------
  getServiceLevel: ()-> @serviceLevel

  # ----------------------------------------------------------------------------------------------------------------
  setServiceLevel: (serviceLevel)->

    Hy.Trace.debug "NetworkService::setServiceLevel (#{@serviceLevel}->#{serviceLevel})"

    @serviceLevel = serviceLevel

    switch @serviceLevel
      when ServiceLevelImmediate
        duration = Hy.Config.NetworkService.kQueueImmediateInterval
      when ServiceLevelBackground
        duration = Hy.Config.NetworkService.kQueueBackgroundInterval
      when ServiceLevelSuspended
        duration = -1
      else
        Hy.Trace.debug "NetworkService::setServiceLeve (ERROR UNKNOWN SERVICE LEVEL #{level})"
        duration = Hy.Config.NetworkService.kQueueBackgroundInterval

    this.clearInterval()

    this.setInterval duration

    @servicelevel

  # ----------------------------------------------------------------------------------------------------------------
  clearInterval: ()->
    if @interval?
      clearInterval @interval

  # ----------------------------------------------------------------------------------------------------------------
  setInterval: (duration)->
    f = ()=>this.processQueue()

    if duration > -1
      @interval = setInterval f, duration

    this
    
  # ---------------------------------------------------------------------------------------------------------------- 
  enqueueEvent: (event)->
    Hy.Trace.debug "NetworkService::enqueueEvent (event=#{event.dumpStr()})"

    result = true

    if @busy
      Hy.Trace.debug "NetworkService::enqueueEvent (BUSY)"
      result = false
    else
      @busy = true
      this.enqueueEvent_(event)
      @busy = false   
   
    return result
  # ---------------------------------------------------------------------------------------------------------------- 

  enqueueEvent_: (event)->

    @queue.push event

    return true

  # ---------------------------------------------------------------------------------------------------------------- 
  dump: ()->
    for e in @queue
      Hy.Trace.debug "NetworkService::dump (event=#{e.dumpStr()})"

    NetworkServiceEventStats.get().dump()

  # ---------------------------------------------------------------------------------------------------------------- 
  processQueue: ()->
#    Hy.Trace.debug "NetworkService::processQueue (ENTER queue=#{_.size(@queue)} timeoutQueue=#{_.size(@timeoutQueue)} serviceLevel=#{@serviceLevel})"
#    this.dump()

    if @busy
      Hy.Trace.debug "NetworkService::processQueue (BUSY)"
      return

    @busy = true

    this.processQueueCheckForTimeouts()
    this.processQueueCheckForSpentEvents()

    if NetworkService.isOnline()

      f = (event)=>
        okToSend = event.doFnPre()

        if okToSend
#          Hy.Trace.debug "NetworkService::processQueue (sending #{event.dumpStrShort()})"
          this.send(event)
          if event.hasTimeout()
            @timeoutQueue.push event

        return okToSend

      this.processQueueFindNextToSend(f)

    else
      Hy.Trace.debug "NetworkService::processQueue (NOT ONLINE)"

    @busy = false

#    Hy.Trace.debug "NetworkService::processQueue (EXIT queue=#{@queue.length} serviceLevel=#{@serviceLevel})"

    this            

  # ---------------------------------------------------------------------------------------------------------------- 
  processQueueCheckForTimeouts: ()->
#    Hy.Trace.debug "NetworkService::processQueueCheckForTimeouts (ENTER #{_.size(@timeoutQueue)})"

    # Check for events that were sent but have not received a response within their specified timeout period
    newTimeoutQueue = []
    for e in @timeoutQueue
      if not e.hasResponse()
        if e.checkTimedOut()
          Hy.Trace.debug "NetworkService::processQueue (event timed out #{e.dumpStrShort()} #{e.getTimeSinceSent()})"
          this.timedout(e)
        else
          Hy.Trace.debug "NetworkService::processQueueCheckForTimeouts (no response yet, adding #{e.dumpStrShort()} #{e.getStateName()} #{e.getTimeSinceSent()})"
          newTimeoutQueue.push e
      else
        Hy.Trace.debug "NetworkService::processQueueCheckForTimeouts (had response, removing #{e.dumpStrShort()} #{e.getStateName()} #{e.getTimeSinceSent()})"

    @timeoutQueue = newTimeoutQueue

#    Hy.Trace.debug "NetworkService::processQueueCheckForTimeouts (EXIT #{_.size(@timeoutQueue)})"

    this

  # ---------------------------------------------------------------------------------------------------------------- 
  processQueueCheckForSpentEvents: ()->
#    Hy.Trace.debug "NetworkService::processQueueCheckForSpentEvents"

    # Remove events that were:
    # - sent and a response received for, or 
    # - which were skipped, or 
    # - which have timedout, or
    # - which are marked to be dequeued
    #
    # Remove into "spentQueue"

    newQueue = []
    spentQueue = []
    for e in @queue
      if e.hasResponse() or e.wasSkipped() or e.hasTimedOut()
        spentQueue.push e
      else
        if not e.isReadyToBeDequeued()
          newQueue.push e

    @queue = newQueue

    # For all of these spent events: If an event is at its send limit, then drop it. Otherwise, requeue it up.
    for e in spentQueue
      if e.atSendLimit()
        Hy.Trace.debug "NetworkService::processQueueCheckForSpentEvents (at send limit #{e.dumpStrShort()} #{e.sendCount}/#{e.sendLimit})"
      else
        Hy.Trace.debug "NetworkService::processQueueCheckForSpentEvents (re-enqueueing #{e.dumpStrShort()})"
        e.enqueue_()

    this

  # ---------------------------------------------------------------------------------------------------------------- 
  processQueueFindNextToSend: (fnSend)->

#    Hy.Trace.debug "NetworkService::processQueueFindNextToSend"

    # Find the next event to send. We start at the front of the queue
    q = @queue
    sent = false

    while (not sent) and (_.size(q)>0)
      first = _.first(q)
      rest = _.rest(q)

      if first.isReadyToBeSent()
        sent = fnSend(first) 
        if not sent
          this.skip(first)
#          Hy.Trace.debug "NetworkService::processQueue (Skipping #{first.dumpStrShort()})"

      if not sent
        q = rest

    return sent

  # ---------------------------------------------------------------------------------------------------------------- 
  send: (event)->

    startTime = (new Date().getTime())

    Hy.Trace.debug "NetworkService::sending (#{event.dumpStrShort()})"

    event.send()

    elapsed = (new Date().getTime()) - startTime

    Hy.Trace.debug "NetworkService::sent (Elapsed=#{elapsed} #{event.dumpStrShort()})"

    true

  # ---------------------------------------------------------------------------------------------------------------- 
  skip: (event)->
    event.skip()

  # ---------------------------------------------------------------------------------------------------------------- 
  timedout: (event)->
    event.timedout()

# ==================================================================================================================

# assign to global namespace:

if not Hy.Network?
  Hy.Network = {}

Hy.Network.HTTPEvent                = HTTPEvent
Hy.Network.NetworkEvent             = NetworkEvent
Hy.Network.NetworkService           = NetworkService
Hy.Network.NetworkServiceEventState = NetworkServiceEventState


