#
# message = <connection><data>
#
# <connection> = <core_connection> [<bonjour_connection> | <http_connection>]
#  <core_connection> = tag:
#  <bonjour_connection> = dest:value + ??
#
# Supports these external methods
#
#   "stop"        {}
#   "pause"       {}
#   "resumed"     {}
#   "sendsingle"  {connectionIndex, op, data}
#   "sendall"     {op, data}
#
# Calls these supplied functions passed in via @handlerSpecs:
#
#   "fnReady"               {status} (true/false)
#   "fnError"               {error, restartNetwork}
#   "fnMessageReceived"     {playerConnectionIndex, op, data}
#   "fnAddPlayer"           {playerConnectionIndex, playerLabel}
#   "fnRemovePlayer"        {playerConnectionIndex}
#   "fnPlayerStatusChange"  {playerConnectionIndex, status}
#   "fnServiceStatusChange" {serviceStatus}
#

class PlayerNetwork

  gInstance = null

  @kKindFirebase = 1

  @create: (handlerSpecs) ->
    new PlayerNetwork(handlerSpecs)

  # ----------------------------------------------------------------------------------------------------------------
  @_get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @isSingleUserMode: ()-> 
    single = if Hy.Config.PlayerNetwork.kSingleUserModeOverride
      true
    else
      Hy.Customize.map("singleUser", null, false)

    single

  # ----------------------------------------------------------------------------------------------------------------
  @getStatus: ()->
  
    status = null

    status = "uninitialized"
   
    if (playerNetwork = PlayerNetwork._get())?
      status = if playerNetwork.isErrorState()
        "error"
      else
        if playerNetwork.serviceWatchdog.isReady()
          "initialized"
        else
          "initializing"

    status

  # ----------------------------------------------------------------------------------------------------------------
  @getJoinSpec: ()->
  
    joinSpec = null

    if (playerNetwork = Hy.ConsoleApp.get().getPlayerNetwork())?
      if (firebasePlayerService = playerNetwork.findService(PlayerNetwork.kKindFirebase))?
        if (service = firebasePlayerService.service).isReady()

          if (sessionCode = service.getSessionCode())
            joinSpec = 
              displayCode: sessionCode
              sessionCode: sessionCode
              displayURL: PlayerNetwork.getJoinSpecDisplayRendezvousURL()

    joinSpec

  # ----------------------------------------------------------------------------------------------------------------
  @getJoinSpecDisplayRendezvousURL: ()-> Hy.Config.Rendezvous.URLDisplayName

  # ----------------------------------------------------------------------------------------------------------------
  @getJoinHelpPageURL: ()->
    Hy.Config.PlayerNetwork.kHelpPage   

  # ----------------------------------------------------------------------------------------------------------------
  # Methods below are "private" or "protected", used only by this class and friends
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@handlerSpecs)->
 
    gInstance = this

    this.init()

    this

  # ----------------------------------------------------------------------------------------------------------------
  init: ()->
    @errorState = null
    @receivedMessageProcessors = []
    @sentMessageProcessors = []

    this.startServices()

    PlayerConnection.start(this)

    # ActivityMonitor.start(this) # Not needed for Firebase-based system?

    this

  # ----------------------------------------------------------------------------------------------------------------
  isErrorState: ()-> @errorState? and @errorState isnt "warning"

  # ----------------------------------------------------------------------------------------------------------------
  startServices: ()->

    @services = []
    @services.push (s1 = {kind: PlayerNetwork.kKindFirebase})

    @serviceWatchdog = new ServiceStartupWatchdog(this)

    s1.service = (new FirebasePlayerService(this)).start()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # After a "stop", can not restart the same instance. Must start over again with a new instance
  #
  stop: ()->

    for s in @services
      s.service?.stop()

    @serviceWatchdog?.stop()

    ActivityMonitor.stop()

    PlayerConnection.stop()

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    @serviceWatchdog?.pause()

    for s in @services
      s.service?.pause()

    ActivityMonitor.pause()

    PlayerConnection.pause()

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    @serviceWatchdog?.resumed()

    for s in @services
      s.service?.resumed()

    PlayerConnection.resumed()

    ActivityMonitor.resumed()

    this

  # ----------------------------------------------------------------------------------------------------------------

  setServiceReady: (service)->

    @serviceWatchdog?.serviceCheckin(service)

  # ----------------------------------------------------------------------------------------------------------------
  sendSingle: (connectionIndex, op, data)->

    playerConnection = PlayerConnection.findByIndex(connectionIndex)

    # We use an anonymous object, "messageInfo", to group together message-related info, which
    # allows message processors to rewrite the data as necesssary before it's sent off.
    # TODO: consider abstracting messages into a hierarchy of sorts, to keep this a little 
    # more sane.

    message = {op:op, data:data}    
    messageInfo = {playerConnection:playerConnection, message:message, handled:false}
    messageInfo = this.doSentMessageProcessors(messageInfo)

    if messageInfo.playerConnection?
      if (service = messageInfo.playerConnection.getService())?
        if service.isReady()
          service.sendSingle(messageInfo.playerConnection, messageInfo.message.op, messageInfo.message.data)
        else
          Hy.Trace.debug "PlayerNetwork::sendSingle (ERROR SERVICE NOT READY for #{connectionIndex})"
      else
        Hy.Trace.debug "PlayerNetwork::sendSingle (ERROR NO SERVICE for #{connectionIndex})"

    else
      Hy.Trace.debug "PlayerNetwork::sendSingle (ERROR CANT FIND PlayerConnection for #{connectionIndex})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendAll: (op, data)->

    Hy.Trace.debug "PlayerNetwork::sendAll (op=#{op})"

    message = {op:op, data:data}
    messageInfo = {message:message, handled:false}
    messageInfo = this.doSentMessageProcessors(messageInfo)

    for s in @services
      if (service = s.service)?
        if service.isReady()
          service.sendAll(messageInfo.message.op, messageInfo.message.data)
        else
          Hy.Trace.debug "PlayerNetwork::sendAll (ERROR SERVICE NOT READY for #{op})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  doReady: ()->

    Hy.Trace.debug "PlayerNetwork::doReady"

    @handlerSpecs.fnReady?()

  # ----------------------------------------------------------------------------------------------------------------
  #
  # errorState: one of
  #
  #   "warning" - will ignore it or otherwise try to deal with it. No action required from
  #               higher-level code.
  #
  #   "retry" - requires higher-level code to attempt to re-initialize the network service.
  #
  #   "fatal" - app must be restarted
  #
  doError: (error, @errorState="warning")->

    Hy.Trace.debug "PlayerNetwork::doError (ERROR /#{error}/ fatal=#{@errorState})"

    if @errorState isnt "warning"
      @serviceWatchdog.clearTimer()

    @handlerSpecs.fnError?(error, @errorState)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doMessageReceived: (playerConnectionIndex, op, data)->

    Hy.Trace.debug "PlayerNetwork::doMessageReceived (op=#{op} data=#{data})"

    @handlerSpecs.fnMessageReceived?(playerConnectionIndex, op, data)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doAddPlayer: (playerConnectionIndex, playerLabel, majorVersion, minorVersion)->

    Hy.Trace.debug "PlayerNetwork::doAddPlayer (##{playerConnectionIndex}/#{playerLabel})"

    @handlerSpecs.fnAddPlayer?(playerConnectionIndex, playerLabel, majorVersion, minorVersion)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doRemovePlayer: (playerConnectionIndex)->

    Hy.Trace.debug "PlayerNetwork::doRemovePlayer (##{playerConnectionIndex})"

    @handlerSpecs.fnRemovePlayer?(playerConnectionIndex)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doPlayerStatusChange: (playerConnectionIndex, status)->

    Hy.Trace.debug "PlayerNetwork::doPlayerStatusChange (##{playerConnectionIndex})"

    @handlerSpecs.fnPlayerStatusChange?(playerConnectionIndex, status)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doServiceStatusChange: (serviceStatus)->

    Hy.Trace.debug "PlayerNetwork::doServiceStatusChange ()"

    @handlerSpecs.fnServiceStatusChange?(serviceStatus)

    this
  # ----------------------------------------------------------------------------------------------------------------
  getServices: ()->
    @services

  # ----------------------------------------------------------------------------------------------------------------
  findService: (kind)->

    _.detect(@services, (s)=>s.kind is kind)

  # ----------------------------------------------------------------------------------------------------------------
  findServiceByConnection: (connection)->

    this.findService(connection.kind)

  # ----------------------------------------------------------------------------------------------------------------
  addReceivedMessageProcessor: (fn)->

    @receivedMessageProcessors.push fn  

  # ----------------------------------------------------------------------------------------------------------------
  addSentMessageProcessor: (fn)->

    @sentMessageProcessors.push fn  

  # ----------------------------------------------------------------------------------------------------------------
  doMessageProcessors: (list, messageInfo)->

    for fn in list
      messageInfo = fn(this, messageInfo)

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  doReceivedMessageProcessors: (messageInfo)->

    this.doMessageProcessors(@receivedMessageProcessors, messageInfo)

  # ----------------------------------------------------------------------------------------------------------------
  doSentMessageProcessors: (messageInfo)->

    this.doMessageProcessors(@sentMessageProcessors, messageInfo)

  # ----------------------------------------------------------------------------------------------------------------
  messageReceived: (connection, message)->

    playerConnection = PlayerConnection.findByConnection(connection)

#    Hy.Trace.debug "PlayerNetwork::messageReceived (/#{message.op}/ from #{if playerConnection? then playerConnection.dumpStr() else connection.kind})"

    # We use an anonymous object, "messageInfo", to group together message-related info, which
    # allows message processors to rewrite the data as necesssary before it's sent off.
    # TODO: consider abstracting messages into a hierarchy of sorts, to keep this a little 
    # more sane.

    messageInfo = {connection:connection, playerConnection:playerConnection, message:message, handled:false}

    messageInfo = this.doReceivedMessageProcessors(messageInfo)

    if not messageInfo.handled
      if messageInfo.playerConnection?
        this.doMessageReceived(messageInfo.playerConnection.getIndex(), messageInfo.message.op, messageInfo.message.data)
      else
        this.doError("Unhandled message Received from unknown player (op=#{messageInfo.message.op}")
    
    this

# ==================================================================================================================
class ServiceStartupWatchdog

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@networkManager)->

    this.initState()

    this.setTimer()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initState: ()->
    @paused = false
    @ready = false
    @failed = false

    this.initServiceStatus()

    this.clearTimer()

    this

  # ----------------------------------------------------------------------------------------------------------------
  isReady: ()-> @ready

  # ----------------------------------------------------------------------------------------------------------------
  clearTimer: ()->
    if @timer?
      @timer.clear()
      @timer = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  initServiceStatus: ()->

    for s in @networkManager.getServices()
      s.initialized = false

    this

  # ----------------------------------------------------------------------------------------------------------------
  setTimer: ()->

    this.clearTimer()    
    @timer = Hy.Utils.Deferral.create(Hy.Config.PlayerNetwork.kServiceStartupTimeout, ()=>this.timerExpired())

    this

  # ----------------------------------------------------------------------------------------------------------------
  timerExpired: ()->

    snr = this.servicesNotReady()

    if _.size(snr) is 0
      @ready = true  # Should never get here
    else
      @failed = true

      failedServices = ""
      diagnostics = ""
      blankNeeded = false
      for s in snr
        failedServices += "#{s.kind} "
        if (d = s.service.getDiagnostic())?
          diagnostics += "#{(if blankNeeded then " " else "")}#{d}"
          blankNeeded = true

      @networkManager.doError("Player network did not start: #{failedServices} (#{diagnostics})", "fatal")

    this

  # ----------------------------------------------------------------------------------------------------------------
  servicesNotReady: ()->
     _.select(@networkManager.getServices(), (s)=>not s.initialized)
  
  # ----------------------------------------------------------------------------------------------------------------
  serviceCheckin: (service)->

    if (s = @networkManager.findService(service.getKind()))?
      s.initialized = true

    snr = this.servicesNotReady()

    Hy.Trace.debug "ServiceStartupWatchdog::serviceCheckin (service=#{service.getKind()} # not ready = #{_.size(snr)})"

    if _.size(snr) is 0
      @ready = true
      this.clearTimer()

      @networkManager.doReady()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this.clearTimer()

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    this.clearTimer()

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    this.initState()
    this.setTimer()

# ==================================================================================================================
# Abstract superclass representing what we need to keep track of a player's connection to the app. 
#
# PlayerConnection
#     FirebasePlayerConnection

class PlayerConnection

  gInstanceCount = 0
  gInstances = []

  @kStatusActive       = 1
  @kStatusInactive     = 2
  @kStatusDisconnected = 3 # when a remote has disconnected... we allow some time to reconnect

  # ----------------------------------------------------------------------------------------------------------------
  @start: (networkManager)->

    gInstances = []

    gInstanceCount = 0

    networkManager.addReceivedMessageProcessor(PlayerConnection.processReceivedMessage)
    networkManager.addSentMessageProcessor(PlayerConnection.processSentMessage)

  # ----------------------------------------------------------------------------------------------------------------
  @stop: ()->

    for pc in PlayerConnection.getPlayerConnections()
      pc.stop()

    gInstances = []

    null

  # ----------------------------------------------------------------------------------------------------------------
  @pause: ()->

    for pc in PlayerConnection.getPlayerConnections()
      pc.pause()

    null

  # ----------------------------------------------------------------------------------------------------------------
  @resumed: ()->

    for pc in PlayerConnection.getPlayerConnections()
      pc.resumed()

  # ----------------------------------------------------------------------------------------------------------------
  @processReceivedMessage: (networkManager, messageInfo)->

#    Hy.Trace.debug "PlayerConnection::processReceivedMessage (#{messageInfo.message.op})"

    switch messageInfo.message.op 
      when "join"
        messageInfo.handled = true
        messageInfo = PlayerConnection.join(networkManager, messageInfo)

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  @processSentMessage: (networkManager, messageInfo)->

    Hy.Trace.debug "PlayerConnection::processSentMessage (#{messageInfo.message.op})"

    switch messageInfo.message.op
      when "welcome"
        messageInfo.handled = true
        messageInfo.message.data.remoteSessionID = messageInfo.playerConnection.getTag()

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  @join: (networkManager, messageInfo)->

    tag = null

    if not messageInfo.playerConnection?
      # Is this a request from a player we've already seen? Check the tag

      if (tag = messageInfo.message.tag)?
        messageInfo.playerConnection = PlayerConnection.findByTag(tag)

    if messageInfo.playerConnection?
      PlayerConnection.swap(messageInfo.playerConnection, messageInfo.connection)
    else
      messageInfo.playerConnection = PlayerConnection.create(networkManager, messageInfo.connection, messageInfo.message.data)

    # We always send a "welcome" when we receive a join
    if messageInfo.playerConnection?
      networkManager.doAddPlayer(messageInfo.playerConnection.getIndex(), messageInfo.playerConnection.getLabel(), messageInfo.playerConnection.getMajorVersion(), messageInfo.playerConnection.getMinorVersion())

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  # If an existing player connects over a new connection. We want to keep the higher-level player state while swapping
  # out the specifics of the connection. 
  #
  @swap: (playerConnection, newConnection)->

    Hy.Trace.debug "PlayerConnection::swap (OLD: #{playerConnection.dumpStr()} NEW: #{newConnection.tag}/#{newConnection.tag}/#{newConnection.remoteID})"

    # An existing player may be rejoining in a new page?
    isSame = playerConnection.compare(newConnection)

    if not isSame
      # Tell the current remote to go away
      (service = playerConnection.getService()).sendSingle(playerConnection, "ejected", {reason:"You connected in another browser window"}, false)

      # Stop listening to the original connection
      service.doneWithPlayerConnection(playerConnection)

      # Start watching the new connection
      service.watchPlayerConnection(playerConnection)   

    # Swap in our new connection info, the higher-level app code won't know the difference
    playerConnection.resetConnection(newConnection)

    # Will result in the console app doing a reactivate, and then sending a welcome. A little wierd.
    playerConnection.activate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  @create: (networkManager, connection, data)->

    playerConnection = null

    t = null
    switch connection.kind
      when PlayerNetwork.kKindFirebase
        t = FirebasePlayerConnection

    if t?
      playerConnection = t.create(networkManager, connection, data)

    playerConnection

  # ----------------------------------------------------------------------------------------------------------------
  @getPlayerConnections: ()-> 
    gInstances

  # ----------------------------------------------------------------------------------------------------------------
  @numPlayerConnections: ()->

    _.size(gInstances)

  # ----------------------------------------------------------------------------------------------------------------
  @find: (fn_predicate)->
    _.detect(PlayerConnection.getPlayerConnections(), (pc)=>fn_predicate(pc))

  # ----------------------------------------------------------------------------------------------------------------
  @findByConnection: (connection)->

    PlayerConnection.find((pc)=>pc.compare(connection))

#    _.detect(PlayerConnection.getPlayerConnections(), (pc)=>pc.compare(connection))

  # ----------------------------------------------------------------------------------------------------------------
  @findByIndex: (index)->

    PlayerConnection.find((pc)=>pc.getIndex() is index)

#    _.detect(PlayerConnection.getPlayerConnections(), (pc)=>pc.getIndex() is index)

  # ----------------------------------------------------------------------------------------------------------------
  @findByTag: (tag)->

    PlayerConnection.find((pc)=>pc.getTag() is tag)
    
    _.detect(PlayerConnection.getPlayerConnections(), (pc)=>pc.getTag() is tag)

  # ----------------------------------------------------------------------------------------------------------------
  @getActivePlayerConnections: ()->

    _.select(PlayerConnection.getPlayerConnections(), (pc)->pc.isActive())

  # ----------------------------------------------------------------------------------------------------------------
  @getPlayersByServiceKind: (kind)->

    _.select(PlayerConnection.getPlayerConnections(), (pc)->(pc.getKind() is kind))

  # ----------------------------------------------------------------------------------------------------------------
  @getActivePlayersByServiceKind: (kind)->

    _.select(PlayerConnection.getPlayerConnections(), (pc)->(pc.isActive()) and (pc.getKind() is kind))

  # ----------------------------------------------------------------------------------------------------------------  
  # Does some basic checks before we allow a new remote player to join
  #
  @preAddPlayer: (networkManager, connection, data)->

    status = true

    # Check version
    status = status and PlayerConnection.checkPlayerVersion(networkManager, connection, data)

    # Are we at player limit?
    status = status and PlayerConnection.makeRoomForPlayer(networkManager, connection, data)

    status

  # ----------------------------------------------------------------------------------------------------------------  
  @makeRoomForPlayer: (networkManager, connection, data)->

    status = true

    if PlayerConnection.numPlayerConnections() >= Hy.Config.kMaxRemotePlayers
      Hy.Trace.debug "PlayerConnection::makeRoomForPlayer (count=#{PlayerConnection.numPlayerConnections()} limit=#{Hy.Config.kMaxRemotePlayers})"

      toRemove = []
      for p in PlayerConnection.getPlayerConnections()
        if !p.isActive()
          toRemove.push p

      for p in toRemove
        Hy.Trace.debug "PlayerConnection::makeRoomForPlayer (Removing player: #{p.dumpStr()}, count=#{PlayerConnection.numPlayerConnections()})"
        p.remove("You appear to be inactive,<br>so we are making room for another player")

      if PlayerConnection.numPlayerConnections() >= Hy.Config.kMaxRemotePlayers
        Hy.Trace.debug "PlayerConnection::makeRoomForPlayer (TOO MANY PLAYERS #{connection} Count=#{PlayerConnection.numPlayerConnections()})"
        s = networkManager.findServiceByConnection(connection)
        if s?
          reason = "Too many remote players!<br>(Maximum is #{Hy.Config.kMaxRemotePlayers})"
          s.service.sendSingle_(connection, "joinDenied", {reason: reason}, PlayerConnection.getLabelFromMessage(data), false)
        status = false

    return status

  # ----------------------------------------------------------------------------------------------------------------  
  @checkPlayerVersion: (networkManager, connection, data)->

    majorVersion = data.majorVersion
    minorVersion = data.minorVersion

    status = true

    if !majorVersion? or (majorVersion < Hy.Config.Version.Remote.kMinRemoteMajorVersion)
      Hy.Trace.debug "PlayerConnection::checkPlayerVersion (WRONG VERSION #{connection} Looking for #{Hy.Config.Version.Remote.kMinRemoteMajorVersion} Remote is version #{majorVersion}.#{minorVersion})"
      s = networkManager.findServiceByConnection(connection)
      if s?
        s.service.sendSingle_(connection,"joinDenied", {reason: 'Update Required! Please visit the AppStore to update this app!'}, PlayerConnection.getLabelFromMessage(data))
      status = false

    return status

  # ----------------------------------------------------------------------------------------------------------------
  @getLabelFromMessage: (data)->
    unescape(data.label)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@networkManager, connection, data, @requiresActivityMonitor)->

    gInstances.push this

    @majorVersion = data.majorVersion
    @minorVersion = data.minorVersion

    @label = PlayerConnection.getLabelFromMessage(data)

    @index = ++gInstanceCount

    this.setConnection(connection)

    Hy.Trace.debug "PlayerConnection::constructor (##{@index} label=/#{@label}/ tag=/#{@tag}/ count=#{_.size(gInstances)})"

    if @requiresActivityMonitor
      ActivityMonitor.addPlayerConnection(this)      

    this.activate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getIndex: ()-> @index

  # ----------------------------------------------------------------------------------------------------------------
  getNetworkManager: ()-> @networkManager

  # ----------------------------------------------------------------------------------------------------------------
  getMajorVersion: ()-> @majorVersion

  # ----------------------------------------------------------------------------------------------------------------
  getMinorVersion: ()-> @minorVersion

  # ----------------------------------------------------------------------------------------------------------------
  checkVersion: (majorVersion, minorVersion=null)->

    status = false
    if @majorVersion >= majorVersion
      if minorVersion?
        if @minorVersion >= minorVersion
          status = true
      else
        status = true

    status

  # ----------------------------------------------------------------------------------------------------------------
  setConnection: (connection)->

    @tag = Hy.Utils.UUID.generate()

    Hy.Trace.debug "PlayerConnection::setConnection (tag=#{@tag})"

    this
  # ----------------------------------------------------------------------------------------------------------------
  resetConnection: (connection)->


  # ----------------------------------------------------------------------------------------------------------------
  getConnection: ()->
    {kind:this.getKind(), tag:@tag}

  # ----------------------------------------------------------------------------------------------------------------
  getTag: (tag)-> @tag

  # ----------------------------------------------------------------------------------------------------------------
  getLabel: ()-> @label

  # ----------------------------------------------------------------------------------------------------------------
  compare: (connection)->

    (this.getKind() is connection.kind) and (this.getTag() is connection.tag)

  # ----------------------------------------------------------------------------------------------------------------
  getService: ()->

    service = null
    s = this.getNetworkManager().findService(this.getKind())
    if s?
      service = s.service

    service

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> null

  # ----------------------------------------------------------------------------------------------------------------
  isKind: (kind)-> this.getKind() is kind

  # ----------------------------------------------------------------------------------------------------------------
  getStatus: ()-> @status

  # ----------------------------------------------------------------------------------------------------------------
  getStatusString: ()->

    s = switch this.getStatus()
      when PlayerConnection.kStatusActive
        "active"
      when PlayerConnection.kStatusInactive
        "inactive"
      when PlayerConnection.kStatusDisconnected
        "disconnected"
      else
        "???"

    s
  # ----------------------------------------------------------------------------------------------------------------
  setStatus: (newStatus)->

    Hy.Trace.debug "PlayerConnection::setStatus (#{newStatus})"

    @status = newStatus

    s = switch @status
      when PlayerConnection.kStatusActive
        true
      when PlayerConnection.kStatusInactive, PlayerConnection.kStatusDisconnected
        false
      else
        false
    
    this.getNetworkManager().doPlayerStatusChange(this.getIndex(), s)

    @status

  # ----------------------------------------------------------------------------------------------------------------
  isActive: ()->
  
    @status is PlayerConnection.kStatusActive

  # ----------------------------------------------------------------------------------------------------------------
  activate: ()->

    this.setStatus(PlayerConnection.kStatusActive)

  # ----------------------------------------------------------------------------------------------------------------
  reactivate: ()->

    this.activate()

  # ----------------------------------------------------------------------------------------------------------------
  # If "disconnected", means that the socket as closed or something similar
  #
  deactivate: (disconnected = false)->

    this.setStatus(if disconnected then PlayerConnection.kStatusDisconnected else PlayerConnection.kStatusInactive)

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this.deactivate()

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

  # ----------------------------------------------------------------------------------------------------------------
  remove: (warn=null)->

    Hy.Trace.debug "PlayerConnection::remove (Removing #{this.dumpStr()} warn=#{warn})"

    if @requiresActivityMonitor
      ActivityMonitor.removePlayerConnection(this)

    if warn?
      service = this.getService()
      if service?
        service.sendSingle(this, "ejected", {reason:warn}, false)

    gInstances = _.without(gInstances, this)

    this.getService().doneWithPlayerConnection(this)

    this.getNetworkManager().doRemovePlayer(this.getIndex())

    null

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->

    "#{this.constructor.name}: ##{this.getIndex()} tag:#{this.getTag()} #{this.getLabel()} #{this.getStatusString()}"

# ==================================================================================================================
class FirebasePlayerConnection extends PlayerConnection

  # ----------------------------------------------------------------------------------------------------------------
  @findByRemoteID: (remoteID)->

    PlayerConnection.find((pc)=>pc.getRemoteID() is remoteID)

  # ----------------------------------------------------------------------------------------------------------------
  @create: (networkManager, connection, data)->

    if PlayerConnection.preAddPlayer(networkManager, connection, data)
      new FirebasePlayerConnection(networkManager, connection, data)
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (networkManager, connection, data)->

    Hy.Trace.debug "FirebasePlayerConnection::constructor (ENTER)"

    super networkManager, connection, data, false

    this.getNetworkManager().findService(PlayerNetwork.kKindFirebase)?.service.watchPlayerConnection(this)    

    Hy.Trace.debug "FirebasePlayerConnection::constructor (EXIT)"

    this

  # ----------------------------------------------------------------------------------------------------------------
  setConnection: (connection)->

    super

    @remoteID = connection.remoteID

    this

  # ----------------------------------------------------------------------------------------------------------------
  resetConnection: (connection)->

    super

    @remoteID = connection.remoteID

    this

  # ----------------------------------------------------------------------------------------------------------------
  getConnection: ()-> 
    connection = super
    connection.remoteID = @remoteID
    connection

  # ----------------------------------------------------------------------------------------------------------------
  getRemoteID: ()-> @remoteID

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> PlayerNetwork.kKindFirebase

  # ----------------------------------------------------------------------------------------------------------------
  compare: (connection)->

    result = super and (@remoteID is connection.remoteID)

    result

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    super + " remoteID=#{@remoteID}"

# ==================================================================================================================
class ActivityMonitor

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @start: (networkManager)->

    gInstance?.stop()

    new ActivityMonitor(networkManager)

  # ----------------------------------------------------------------------------------------------------------------
  @stop: ()->

    gInstance?.stop()

    gInstance = null

    null

  # ----------------------------------------------------------------------------------------------------------------
  @pause: ()->

    gInstance?.pause()

    null

  # ----------------------------------------------------------------------------------------------------------------
  @resumed: ()->

    gInstance?.resumed()

    null

  # ----------------------------------------------------------------------------------------------------------------
  @getTime: ()->
    (new Date()).getTime()

  # ----------------------------------------------------------------------------------------------------------------
  @processReceivedMessage: (networkManager, messageInfo)->

    if gInstance?
      messageInfo = gInstance.processReceivedMessage(networkManager, messageInfo)

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  @addPlayerConnection: (pc)->

    gInstance?.addPlayerConnection(pc)

    null

  # ----------------------------------------------------------------------------------------------------------------
  @removePlayerConnection: (pc)->

    gInstance?.removePlayerConnection(pc)

    null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@networkManager)->
#    Hy.Trace.debug "ActivityMonitor::constructor"

    gInstance = this

    @playerConnections = []

    @networkManager.addReceivedMessageProcessor(ActivityMonitor.processReceivedMessage)

    this.startTimer()

    this

  # ----------------------------------------------------------------------------------------------------------------
  startTimer: ()->

    fnTick = ()=>this.tick()

    @interval = setInterval(fnTick, Hy.Config.PlayerNetwork.ActivityMonitor.kCheckInterval)

  # ----------------------------------------------------------------------------------------------------------------
  clearTimer: ()->

    if @interval?
      clearInterval(@interval) 
      @interval = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    Hy.Trace.debug "ActivityMonitor::stop"
    this.clearTimer()
    @playerConnections = []

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    Hy.Trace.debug "ActivityMonitor::pause"

    this.clearTimer()

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    Hy.Trace.debug "ActivityMonitor::resumed"

    this.startTimer()

  # ----------------------------------------------------------------------------------------------------------------

  processReceivedMessage: (networkManager, messageInfo)->

#    Hy.Trace.debug "ActivityMonitor::processReceivedMessage (#{messageInfo.op})"

    if messageInfo.playerConnection?
      p = this.updatePlayerConnection(messageInfo.playerConnection)
    
      switch messageInfo.message.op
        when "ping"
          p.lastPing = messageInfo.message.data.pingCount

          if (service = messageInfo.playerConnection.getService())?
            service.sendSingle(messageInfo.playerConnection, "ack", {pingCount:messageInfo.message.data.pingCount}, false)
          messageInfo.handled = true

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  addPlayerConnection: (pc)->

    if not this.updatePlayerConnection(pc)?
      @playerConnections.push {playerConnection: pc, pingTimestamp:ActivityMonitor.getTime(), lastPing:null}
      Hy.Trace.debug "ActivityMonitor::addPlayerConnection (size=#{_.size(@playerConnections)} Added:#{pc.dumpStr()})"

    pc

  # ----------------------------------------------------------------------------------------------------------------
  updatePlayerConnection: (pc)->

    p = _.detect(@playerConnections, (c)=>c.playerConnection is pc)

    if p?
      timeNow = ActivityMonitor.getTime()
      Hy.Trace.debug "ActivityMonitor::updatePlayerConnection (Updated #{pc.dumpStr()} last heard from=#{timeNow-p.pingTimestamp} lastPing=#{p.lastPing})"
      p.pingTimestamp = timeNow
      pc.reactivate()

    p

  # ----------------------------------------------------------------------------------------------------------------
  removePlayerConnection: (pc)->

    # Why the following, Michael?
    # @pingTimestamp = @pingTimestamp - 5*1000

    @playerConnections = _.reject(@playerConnections, (p)=>p.playerConnection is pc)

  # ----------------------------------------------------------------------------------------------------------------
  tick: ()->
    Hy.Trace.debug "ActivityMonitor::tick (#connections=#{_.size(@playerConnections)})"

    for pc in @playerConnections
      this.checkActivity(pc.playerConnection, pc.pingTimestamp, pc.lastPing)
    null

  # ----------------------------------------------------------------------------------------------------------------
  checkActivity: (pc, pingTimestamp, lastPing)->

    # this mechanism appears to be needed mostly for iPod 1Gs or perhaps anything else not running iOS 4+, and which 
    # don't send a "suspend" to the console when the button is pushed

    fnTestActive = (pc, timeNow, pingTimestamp)->
      ((timeNow - pingTimestamp) <= Hy.Config.PlayerNetwork.ActivityMonitor.kThresholdActive)

    fnTestAlive  = (pc, timeNow, pingTimestamp)->
      ((timeNow - pingTimestamp) <= Hy.Config.PlayerNetwork.ActivityMonitor.kThresholdAlive)

    timeNow = ActivityMonitor.getTime()

    debugString = "#{pc.dumpStr()} last heard from=#{timeNow-pingTimestamp} lastPing=#{lastPing}"

    if fnTestAlive(pc, timeNow, pingTimestamp)
      switch pc.getStatus()
        when PlayerConnection.kStatusActive
          if not fnTestActive(pc, timeNow, pingTimestamp)
            Hy.Trace.debug "PlayerConnection::checkActivity (Deactivating formerly active player #{debugString})"
            pc.deactivate()
        when PlayerConnection.kStatusInactive
          if fnTestActive(pc, timeNow, pingTimestamp)
            Hy.Trace.debug "PlayerConnection::checkActivity (Reactivating formerly inactive player #{debugString})"
            pc.reactivate()
        when PlayerConnection.Disconnected
          # We do nothing here. If the player manages to reconnect, the join code will handle that
          null
    else
      Hy.Trace.debug "ActivityMonitor::checkActivity (Removing #{debugString})"
      pc.remove("You appear to be inactive")

#    if !fnTestAlive(pc, timeNow, pingTimestamp)
#      Hy.Trace.debug "ActivityMonitor::checkActivity (Removing #{pc.dumpStr()} #{timeNow-pingTimestamp})"
#      pc.remove("You appear to be inactive")
#    else if pc.isActive() and !fnTestActive(pc, timeNow, pingTimestamp)
#      Hy.Trace.debug "PlayerConnection::checkActivity (Deactivating player #{pc.dumpStr()} #{timeNow-pingTimestamp})"
#      pc.deactivate()
#        else if !player.isActive() and fnTestActive(player)
#          this.playerReactivate player 

    this

# ==================================================================================================================
# Abstract superclass for all player network types
# Each instance of a subtype of this type is managed by PlayerNetwork
#
# PlayerNetworkService
#      FirebasePlayerService
#
class PlayerNetworkService

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@networkManager)->

    username = Ti.Platform.username

    @diagnostic = null
    @ready = false

    # to allow two simulators to run on the same network
    if username is "iPad Simulator"
      username = "#{username}-#{Hy.Utils.Math.random(10000)}"

    @tag = escape username

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    Hy.Trace.debug "PlayerNetworkService::start"
    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    Hy.Trace.debug "PlayerNetworkService::stop"
    @ready = false
    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    Hy.Trace.debug "PlayerNetworkService::pause"
    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    Hy.Trace.debug "PlayerNetworkService::resumed"
    this

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> null

  # ----------------------------------------------------------------------------------------------------------------
  setReady: ()->
    Hy.Trace.debug "PlayerNetworkService::setReady (service=#{this.getKind()})"

    @ready = true
    @networkManager.setServiceReady(this)

  # ----------------------------------------------------------------------------------------------------------------
  isReady: ()-> @ready

  # ----------------------------------------------------------------------------------------------------------------
  getPlayers: ()->
    PlayerConnection.getPlayersByServiceKind(this.getKind())

  # ----------------------------------------------------------------------------------------------------------------
  getActivePlayers: ()->
    PlayerConnection.getActivePlayersByServiceKind(this.getKind())

  # ----------------------------------------------------------------------------------------------------------------
  sendSingle_: (connection, op, data, label, requireAck=true)->
    Hy.Trace.debug "PlayerNetworkService::sendSingle (#{this.constructor.name} op=#{op} label=#{label})"

  # ----------------------------------------------------------------------------------------------------------------
  sendSingle: (playerConnection, op, data, requireAck=true)->

    this.sendSingle_(playerConnection.getConnection(), op, data, playerConnection.getLabel(), requireAck)

  # ----------------------------------------------------------------------------------------------------------------
  sendAll: (op, data, requireAck=true)->
    Hy.Trace.debug "PlayerNetworkService::sendAll (#{this.constructor.name} op=#{op})"

  # ----------------------------------------------------------------------------------------------------------------
  doneWithAllPlayerConnections: ()->

  # ----------------------------------------------------------------------------------------------------------------
  doneWithPlayerConnection: (playerConnection)->

  # ----------------------------------------------------------------------------------------------------------------
  setDiagnostic: (@diagnostic)->

  # ----------------------------------------------------------------------------------------------------------------
  getDiagnostic: ()-> @diagnostic

# ==================================================================================================================
class FirebasePlayerService extends PlayerNetworkService

  gCounter = 0

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (networkManager)->

    @counter = ++gCounter

    Hy.Trace.debug "FirebasePlayerService::constructor"

    super networkManager

    this.initState()

    @firebaseModule = null
    this.initModule()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initState: ()->

    # Represents the current current app session. Globally unique. Generated via Firebase "push".
    # Created anew each time the app is started from scratch. Not shown to humans.
    @consoleID = null 

    @timer = null

    @starting = false

    # External human-friendly code that can be mapped to the consoleID. Globally unique. Generated via 
    # "joincgpro" service. 
    @sessionCode = null 

    @regServiceID = null

    this.setDiagnostic("Init")

    this

  # ----------------------------------------------------------------------------------------------------------------
  initModule: ()->
    @firebaseModule = new Hy.Network.Firebase(this, ((e)=>this.eventHandler_observeEventTypeWithBlockWithCancelBlock(e)), ((e)=>this.eventHandler_setValueWithCompletionBlock(e)))

    if not @firebaseModule.initModule()
      @networkManager.doError("Could not load FireBase Module", "fatal")

    this 

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> PlayerNetwork.kKindFirebase

  # ----------------------------------------------------------------------------------------------------------------
  getConsoleID: ()-> @consoleID

  # ----------------------------------------------------------------------------------------------------------------
  setConsoleID: (@consoleID)->

  # ----------------------------------------------------------------------------------------------------------------
  getSessionCode: ()-> @sessionCode

  # ----------------------------------------------------------------------------------------------------------------
  setSessionCode: (@sessionCode)->

  # ----------------------------------------------------------------------------------------------------------------
  getRegServiceID: ()-> @regServiceID

  # ----------------------------------------------------------------------------------------------------------------
  setRegServiceID: (@regServiceID)->

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLRoot: ()-> Hy.Config.PlayerNetwork.kFirebaseRootURL

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLAppRoot: ()-> Hy.Config.PlayerNetwork.kFirebaseAppRootURL

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLRegServiceID: ()-> "#{Hy.Config.PlayerNetwork.kFirebaseAppRootURL}/regService/ID"

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLConsoles: ()-> "#{this.getFirebaseURLAppRoot()}/consoles"

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLConsole: ()-> "#{this.getFirebaseURLConsoles()}/#{this.getConsoleID()}"

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLConsoleInfo: ()-> "#{this.getFirebaseURLConsole()}/info"

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLConsoleSessionCode: ()-> "#{this.getFirebaseURLConsole()}/sessionCode"

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLConsoleConnectionStatus: ()-> "#{this.getFirebaseURLAppRoot()}/consoleStatus/#{this.getConsoleID()}/connectionStatus"

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLConsoleBroadcast: ()-> "#{this.getFirebaseURLAppRoot()}/broadcasts/#{this.getConsoleID()}"

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLPlayer: (playerTag)-> "#{this.getFirebaseURLAppRoot()}/players/#{this.getConsoleID()}/#{playerTag}"

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLPlayerInfo: (playerTag)-> "#{this.getFirebaseURLPlayer(playerTag)}/info"

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLPlayerConnectionStatus: (playerTag)-> "#{this.getFirebaseURLPlayerInfo(playerTag)}/connectionStatus"

  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLPlayerMessageFromConsole: (playerTag)-> "#{this.getFirebaseURLPlayer(playerTag)}/fromConsole"
  
  # ----------------------------------------------------------------------------------------------------------------
  getFirebaseURLPlayerMessageToConsole: ()-> "#{this.getFirebaseURLAppRoot()}/toConsole/#{this.getConsoleID()}"

  # ----------------------------------------------------------------------------------------------------------------
  # We expect events due to changes in:
  #   remote connected status:  <root>/players/<consoleID>/<remoteID>/info/connectionStatus (value events - "connected", "notConnected")
  #   console connected status: <root>/.info/connected (value events - true/false)
  #   incoming messages: <root>toConsole/<consoleID> (childAdded events)
  #   reg service ID status: <root>/regService/<regID>/ (value events - <ID>, null)
  #
  # There has to be a better way to do this.
  
  eventHandler_observeEventTypeWithBlockWithCancelBlock: (e)->
    #
    # Firebase module sets these properties on "e":
    #   status = OK, ERROR
    #   url
    #   kind (childAdded, childRemoved, childChanged, value)
    #
    #   if status = OK:
    #     description
    #     name
    #     value
    #

    Hy.Trace.debug "FirebasePlayerService::eventHandler_observeEventTypeWithBlockWithCancelBlock (status=#{e.status} url=#{e.url} description=#{e.description} value=#{e.value})"

    handled = false

    if e.status is "OK"
      switch e.kind
        when "childAdded"
          if handled = (e.url.indexOf("toConsole") isnt -1)
            this.messageReceived(e.value)
        when "value"
          if handled = (e.url.indexOf(".info/connected") isnt -1)
            this.consoleConnectionChanged(if e.value then "connected" else "disconnected")
          else
            if handled = (e.url.indexOf("info/connectionStatus") isnt -1)
              this.playerConnectionChanged(e.description, e.value)
            else
              if handled = (e.url.indexOf("regService/ID") isnt -1)
                this.regServiceStatusChanged(e.value)
              else
                if handled = (e.url.indexOf("sessionCode") isnt -1)
                  this.sessionCodeChanged(e.value)

    if not handled
      @networkManager.doError("Unexpected Event: #{e.kind} (#{e.status} #{e.url}) #{@firebaseModule?}")

      
    null

  # ----------------------------------------------------------------------------------------------------------------
  #
  # We care about this kind of callback only as a signal of authentication expiration
  #
  eventHandler_setValueWithCompletionBlock: (e)->
    #
    # Firebase module sets these properties on "e":
    #   status = OK, FAIL
    #   url
    # Currently only fired in case of error (OK==FAIL)
    #
    if e.status is "OK"
      null
    else
      this.firebaseAuthExpired("setValue", e.url)

    null

  # ----------------------------------------------------------------------------------------------------------------
  firebaseAuthExpired: (context, detail)->
    @networkManager.doError("Permissions Issue (#{detail})", "fatal")
    this

  # ----------------------------------------------------------------------------------------------------------------
  start: (firstInitialization = true)->

    Hy.Trace.debug "FirebasePlayerService::start (firstInitialization=#{firstInitialization})"

    fn_consoleIDChanged = (consoleID)=> (existingConsoleID = this.getConsoleID())? and (existingConsoleID isnt consoleID)

    fn_consoleIDNeedsUpdate = (consoleID)=> fn_consoleIDChanged(consoleID) or not this.getConsoleID()?

    fn_sessionCodeChanged = (sessionCode)=> (existingSessionCode = this.getSessionCode())? and (existingSessionCode isnt sessionCode)

    fn_sessionCodeNeedsUpdate = (sessionCode)=> fn_sessionCodeChanged(sessionCode) or not this.getSessionCode()?

    fn_regServiceIDChanged = ((regServiceID)=> (existingRegServiceID = this.getRegServiceID())? and (existingRegServiceID isnt regServiceID))

    fn_regServiceIDNeedsUpdate = (regServiceID)=> fn_regServiceIDChanged(regServiceID) or not this.getRegServiceID()?

    fn_authenticate = (consoleID, sessionCode, authToken, regServiceID, sessionCodeExpires)=>

      if @firebaseModule?
        # If we have received a new consoleID, then let remotes know about the change, so they
        # can migrate over to the new one.

        if fn_consoleIDChanged(consoleID)
          this.updateRemotesWithSessionInfo(consoleID, sessionCode, sessionCodeExpires)

          # Set our status to disconnected, which the remotes will react to
          this.consoleConnectionChanged("disconnected")

          # Uninstall any handlers currently installed for current consoleID. Otherwise, we will
          # start getting permissions errors when we re-authenticate
          this.firebaseManageHandlersForConsoleID(false)

        if fn_consoleIDChanged(consoleID) or not @firebaseModule.isAuthenticated()
          # Auth token is based on consoleID, so if that changes, then we need to reauthenticate
          this.firebaseAuthenticate(this.getFirebaseURLAppRoot(), authToken, ((e)=>fn_authResult(e, consoleID, sessionCode, regServiceID)), (()=>fn_authCancelled()))
        else
          # If we (only) have received a new sessionID, then let remotes know about the change, so they
          # can offer it to the user next time

          if fn_sessionCodeChanged(sessionCode)
            this.updateRemotesWithSessionInfo(consoleID, sessionCode, sessionCodeExpires)

          # And skip authentication
          fn_firebaseInitialize(consoleID, sessionCode, regServiceID)
      null

    fn_authResult = (e, consoleID, sessionCode, regServiceID)=>
      if e.status
        remaining = e.expires - (new Date()).getTime()
        Hy.Trace.debug "FirebasePlayerService::start (authResult: remaining=#{remaining/(1000*60)}m)"
        fn_firebaseInitialize(consoleID, sessionCode, regServiceID)
      else
        @networkManager.doError("auth check failed", "fatal")
      null

    fn_authCancelled = ()=>
      this.firebaseAuthExpired("Authentication", e.url)
      null

    fn_firebaseInitialize = (consoleID, sessionCode, regServiceID)=>
      Hy.Trace.debug "FirebasePlayerService::start.firebaseInitialize"

      if firstInitialization
        this.firebaseManageGlobalHandlers(true)
        @regServiceStatusChangeIgnoreFirst = true
        @sessionCodeChangeIgnoreFirst = true

      this.setRegServiceID(regServiceID)

      if fn_consoleIDNeedsUpdate(consoleID)
        this.setConsoleID(consoleID)

        # Set our info
        @firebaseModule.setValueObjWithCompletionBlock(this.getFirebaseURLConsoleInfo(), {name: "Name", startDate: new Date().toString()})

        # Set up console-specific handlers
        this.firebaseManageHandlersForConsoleID(true)

      this.setSessionCode(sessionCode)
      @firebaseModule.setValueWithCompletionBlock(this.getFirebaseURLConsoleSessionCode(), this.getSessionCode())

      # Set up connection status, for remotes to notice
      this.setConsoleConnection("connected")

      @starting = false

      if firstInitialization
        this.setReady()
      else
        @networkManager.doServiceStatusChange(null) # Update the UI        
      null

    if @firebaseModule?
      if @starting
        Hy.Trace.debug "FirebasePlayerService::start (ALREADY STARTING)"
      else
        @starting = true
        Hy.Trace.debug "FirebasePlayerService::start (START)"

        @timer = new Hy.Utils.TimedOperation("FirebasePlayerService")

        this.registerSession((consoleID, sessionCode, authToken, regServiceID, sessionCodeExpires)=>fn_authenticate(consoleID, sessionCode, authToken, regServiceID, sessionCodeExpires))

    super

  # ----------------------------------------------------------------------------------------------------------------
  setReady: ()->

    @timer?.mark("setReady")
    @timer = null
    super
    this

  # ----------------------------------------------------------------------------------------------------------------
  firebaseAuthenticate: (url, token, fn_authResult, fn_authCancelled)->
    
    if @firebaseModule?
      @timer?.mark("starting authentication")
      this.setDiagnostic("Auth")
      @firebaseModule.authWithCredential(url, token, ((e)=>fn_authResult(e)), ()=>fn_authCancelled())

    this

  # ----------------------------------------------------------------------------------------------------------------
  registerSession: (fnReady)->

    fn = (e, status)=>
      Hy.Trace.debug("FirebasePlayerService::registerSession (callback status=#{status} #{e.responseText})")
      if status
        r = null
        try
          r = JSON.parse(e.responseText)
        catch e
          @networkManager.doError("registerSession parse error: \"#{encodeURI(e.responseText.substring(30))}\"", "fatal")

        if r? and r.status
          fnReady?(r.console_id, r.session_code, r.auth_token, r.reg_server_id, r.session_code_expires)
        else
          @networkManager.doError("Could not register session: \"#{r.message}\"", "fatal")
      else
        @networkManager.doError("Could not contact register API", "retry")

      null

    @timer?.mark("starting registration")
    this.setDiagnostic("Reg setup")

    @rendezvousEvent = new Hy.Network.HTTPEvent()
    @rendezvousEvent.setFnPost(fn)

    url = Hy.Config.PlayerNetwork.registerAPI
    url += "/consoles?register"
    url += "&display=#{escape(Ti.Platform.username)}"
    if (consoleID = this.getConsoleID())?
      url += "&console_id=#{consoleID}"

    @rendezvousEvent.setURL(url)

    if Hy.Network.NetworkService.isOnline()
      if @rendezvousEvent.enqueue()
        null
      else
        @networkManager.doError("Could not enqueue register call", "retry")
    else
      @networkManager.doError("Not online for register call", "retry")


    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Manage general handlers, that arent based on any specific consoleID, sessionCode, etc
  #
  firebaseManageGlobalHandlers: (install = true)->

    Hy.Trace.debug "FirebasePlayerService::firebaseManageGlobalHandlers (install=#{install})"

    if @firebaseModule?
      @timer?.mark("starting firebaseManageGlobalHandlers")
      this.setDiagnostic("init session 1")

      # Watch for changes in our own status, as reported by FB
      url = "#{this.getFirebaseURLRoot()}/.info/connected"
      if install
        @firebaseModule.observeEventTypeWithBlockWithCancelBlock("value", url)
      else
        @firebaseModule.removeAllObservers(url)

      # Watch for changes in status of the reg server
      url = this.getFirebaseURLRegServiceID()
      if install
        @firebaseModule.observeEventTypeWithBlockWithCancelBlock("value", url)
      else
        @firebaseModule.removeAllObservers(url)
    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Manage all our Firebase handles that are based on <consoleID>. Do this just once for each 
  # <consoleID>
  #

  firebaseManageHandlersForConsoleID: (install = true)->

    Hy.Trace.debug "FirebasePlayerService::firebaseManageHandlersForConsoleID (#{install} #{this.getConsoleID()})"

    if @firebaseModule? and this.getConsoleID()?
      @timer?.mark("starting firebaseManageHandlersForConsoleID")
      this.setDiagnostic("init session 3")

      # Set our status for remotes to see, when we disconnect
      url = this.getFirebaseURLConsoleConnectionStatus()
      if install
        @firebaseModule.onDisconnect(url, "disconnected")
      else
        @firebaseModule.cancelDisconnectOperations(url)

      # Watch for when the Session Code expires
      url = this.getFirebaseURLConsoleSessionCode()
      if install
        @firebaseModule.observeEventTypeWithBlockWithCancelBlock("value", url)
      else
        @firebaseModule.removeAllObservers(url)

      # Where we listen for messages meant for us - event handling specified elsewhere
      url = this.getFirebaseURLPlayerMessageToConsole()
      if install
        @firebaseModule.observeEventTypeWithBlockWithCancelBlock("childAdded", url)
      else
        @firebaseModule.removeAllObservers(url)

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Written by reg service. If non-null, represents the ID of the reg service. 
  # Set to null when the reg service stops operating.
  # Compare with our copy to see if it's different, in which case we'll need to re-register. 
  #
  #
  regServiceStatusChanged: (regServiceID)->

    Hy.Trace.debug "FirebasePlayerService::regServiceStatusChanged (ID=#{regServiceID} #{@regServiceStatusChangeIgnoreFirst})"

    if not @starting

      f = @regServiceStatusChangeIgnoreFirst
      @regServiceStatusChangeIgnoreFirst = false

      switch regServiceID

        when null
           if not f
             # If null, tells us that the reg service disconnected. Nothing to do but wait...
             this.setRegServiceID(null)
             this.setSessionCode(null)
             @networkManager.doServiceStatusChange(null) # Update the UI

        when this.getRegServiceID()
          # No change. Nothing to do here
          null

        else
          # Re-register
          this.start(false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Written by the console, when the sessionCode is initially provided to the console
  # by the reg service. 
  # However, the reg service will also write it - to null - when the sessionCode has expired.
  # Thats our signal to go ask for another one.
  #
  sessionCodeChanged: (sessionCode)->

    Hy.Trace.debug "FirebasePlayerService::sessionCodeChanged (#{sessionCode} #{@sessionCodeChangeIgnoreFirst})"
 
    f = @sessionCodeChangeIgnoreFirst
    @sessionCodeChangeIgnoreFirst = false

    if this.isReady() and not @starting
      if sessionCode? and (sessionCode is this.getSessionCode())
        # No change - Nothing to do here 
        null
      else
        if not f
          if sessionCode?
            # Not sure why this would happen, but...
            @networkManager.doError("Unexpected Session Code Change: #{this.getSessionCode()}->(#{sessionCode} #{@firebaseModule?})")
          this.start(false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setConsoleConnection: (status)->
    if this.isReady()
      @firebaseModule.setValueWithCompletionBlock(this.getFirebaseURLConsoleConnectionStatus(), status)
    this

  # ----------------------------------------------------------------------------------------------------------------
  consoleConnectionChanged: (status)->
    Hy.Trace.debug "FirebasePlayerService::consoleConnectionChanged (status=#{status})"

    this.setConsoleConnection(status)

    this

  # ----------------------------------------------------------------------------------------------------------------
  playerConnectionChanged: (url, status)->
    Hy.Trace.debug "FirebasePlayerService::playerConnectionChanged (url=#{url}, status=#{status})"

    if (remoteID = this.getRemoteIDFromURL(url))?
      if (pc = FirebasePlayerConnection.findByRemoteID(remoteID))?
        switch status
          when "connected"
            null
          when "disconnected"
            # if the user refreshes the browser window, the connection is closed. 
            # Let's try to preserve the user's app state across that refresh
            pc.deactivate(true) 

    else
      Hy.Trace.debug "FirebasePlayerService::playerConnectionChanged (COULD NOT GET TAG #{url})"

    null

  # ----------------------------------------------------------------------------------------------------------------
  doneWithAllPlayerConnections: ()->

    Hy.Trace.debug "FirebasePlayerService::doneWithAllPlayerConnections"

    for p in this.getPlayers()
      this.doneWithPlayerConnection(p)

    super
    this

  # ----------------------------------------------------------------------------------------------------------------
  doneWithPlayerConnection: (playerConnection)->

    if playerConnection.isKind(PlayerNetwork.kKindFirebase) # Sanity Check

      Hy.Trace.debug "FirebasePlayerService::doneWithPlayerConnection (#{this.getFirebaseURLPlayerConnectionStatus(playerConnection.getRemoteID())})"

      @firebaseModule.removeAllObservers(this.getFirebaseURLPlayerConnectionStatus(playerConnection.getRemoteID()))

    super

  # ----------------------------------------------------------------------------------------------------------------
  watchPlayerConnection: (playerConnection)->

    # Watch for connection status changes for this new player
    if playerConnection.isKind(PlayerNetwork.kKindFirebase) # Sanity Check
      if this.isReady()
        @firebaseModule?.observeEventTypeWithBlockWithCancelBlock("value", this.getFirebaseURLPlayerConnectionStatus(playerConnection.getRemoteID()))

    this

  # ----------------------------------------------------------------------------------------------------------------
  getRemoteIDFromURL: (url)->

    #   //<ROOT>/players/<consoleID>/<remoteID>/info/connectionStatus 

    a = url.split("/")
    tag = if a.length >= 3 # due to the leading //
      a[a.length-3]
    else
      null

    tag

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    Hy.Trace.debug "FirebasePlayerService::stop"

    this.consoleConnectionChanged("disconnected")

    this.doneWithAllPlayerConnections()
    this.firebaseManageHandlersForConsoleID(false)
    this.firebaseManageGlobalHandlers(false)

    @firebaseModule?.stop()
    @firebaseModule = null

    super

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    Hy.Trace.debug "FirebasePlayerService::pause"

    this.consoleConnectionChanged("suspended")

    @firebaseModule?.pause()

    super

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    Hy.Trace.debug "FirebasePlayerService::resumed (#active=#{_.size(this.getActivePlayers())})" # TODO

    if @firebaseModule?
      @firebaseModule.resumed()
      this.setReady()

      this.consoleConnectionChanged("connected")

    super

  # ----------------------------------------------------------------------------------------------------------------
  messageReceived: (messageText)->

    try
      message = JSON.parse messageText
    catch e
      @networkManager.doError("Error parsing message /#{messageText}/")
      return null      

    @networkManager.messageReceived({kind:this.getKind(), tag: message.tag, remoteID:message.remoteID}, message)

    null

  # ----------------------------------------------------------------------------------------------------------------
  sendSingle_: (connection, op, data, label, requireAck=true)->

    # requireAck is not implemented
    super connection, op, data, label, requireAck

    if @firebaseModule? and this.isReady()
      try
        message = JSON.stringify(src: @tag, op: op, data: data, time: new Date().toString())
        url = @firebaseModule.childByAutoId(this.getFirebaseURLPlayerMessageFromConsole(connection.remoteID))
        @firebaseModule.setValueWithCompletionBlock(url, message)
      catch e
        @networkManager.doError("Error encoding message (connection=#{connection.tag} op=#{op} tag=#{@tag} data=#{data})")

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendAll: (op, data, requireAck=true)->

    Hy.Trace.debug "FirebasePlayerService::sendAll ()"

    super op, data, requireAck

    if @firebaseModule? and this.isReady()
      if _.size(this.getActivePlayers()) > 0
        # Where we broadcast messages to be received by all remotes
        child = @firebaseModule.childByAutoId(this.getFirebaseURLConsoleBroadcast())

        try
          message = JSON.stringify(src: @tag, op: op, data: data, time: new Date().toString())
          @firebaseModule.setValueWithCompletionBlock(child, message)
        catch e
          @networkManager.doError("Error encoding Firebase message (#{child} op=#{op} tag=#{@tag} data=#{@data})")
      else
        Hy.Trace.debug "FirebasePlayerService::sendAll (NOT SENDING - NO ACTIVE PLAYERS)"
    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # If the console receives a new consoleID, need to tell the remotes about it, too
  # Currently, the only way to do this is to get each remote to simply drop its current connection
  # and ask the user to re-join
  #
  updateRemotesWithSessionInfo: (newConsoleID, newSessionCode, newSessionCodeExpires)->

    Hy.Trace.debug "FirebasePlayerService::updateRemotesWithSessionInfo (#{newConsoleID} #{newSessionCode})"
    # First, while we still have their attention, tell all remotes about the change
    data =
      console_id: newConsoleID
      session_code: newSessionCode
      session_code_expires: newSessionCodeExpires
    this.sendAll("sessionInfoChange", data)

    # Then, if the consoleID changed, stop listening to 'em, so that we don't start getting
    # (permissions) complaints from Firebase
    if this.getConsoleID() isnt newConsoleID
      this.doneWithAllPlayerConnections()
      # The players should reconnect with their existing game state if the remotes refresh, 
      # due to the "remoteSessionID" cookie written by the remotes

    this

# ==================================================================================================================
# assign to global namespace:
if not Hy.Network?
  Hy.Network = {}

Hy.Network.PlayerNetwork = PlayerNetwork

