# ==================================================================================================================
class Player
  _.extend Player, Hy.Utils.Observable
  _.extend Player, Hy.Utils.Iterable

  @kStatusActive = 1
  @kStatusInactive = 2

  @kKindConsole = 1
  @kKindRemote  = 2

  gPlayers = []
  gPlayerIndex = -1
  
  # ----------------------------------------------------------------------------------------------------------------
  # Constructor:
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@kind, @label)->
#    Hy.Trace.debug "Player::constructor(label => #{@label})"

    gPlayers.push this

    @status = Player.kStatusActive
    @index = ++gPlayerIndex

    @name = @defaultName = null
    this.setDefaultName()

    player = this
    Player.notifyObservers (observer)=>observer.obs_playerCreated?(player)

    this

  # ----------------------------------------------------------------------------------------------------------------
  _setDefaultName: (n)->

    this.setName(@defaultName = n, true)

    this


  # ----------------------------------------------------------------------------------------------------------------
  setDefaultName: ()->

    # Assign generated name, can be customized by player
    this._setDefaultName("Player " + @index)

    this

  # ----------------------------------------------------------------------------------------------------------------
  @destroy: (player)->
#    Hy.Trace.debug "Player::@destroy(tag => #{player.tag})"
    Player.removePlayer(player)
    Player.notifyObservers (observer)=>observer.obs_playerDestroyed?(player)

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    "#{this.constructor.name}: index=#{@index} #{@name} label=#{@label} status=#{if @status==Player.kStatusActive then "Active" else "Inactive"}"

  # ----------------------------------------------------------------------------------------------------------------
  dump: ()->
    Hy.Trace.debug(this.dumpStr())

  # ----------------------------------------------------------------------------------------------------------------
  @collection: ()->gPlayers

  # ----------------------------------------------------------------------------------------------------------------
  # true if only the consolePlayer is playing
  #
  @isConsolePlayerOnly: ()->
    Player.collectionByKind(Player.kKindRemote).length is 0

  # ----------------------------------------------------------------------------------------------------------------
  @collectionByKind: (kind)->
     _.select(Hy.Player.Player.collection(), (player)->player.kind is kind)

  # ----------------------------------------------------------------------------------------------------------------
  @removePlayer: (player)->
    gPlayers = _.reject(gPlayers, (p)->p is player)

  # ----------------------------------------------------------------------------------------------------------------
  @count: ()->_.size(gPlayers)

  # ----------------------------------------------------------------------------------------------------------------
  @findByClosure: (fn)->

    _.detect(gPlayers, (p)->fn(p))

  # ----------------------------------------------------------------------------------------------------------------
  @findByProperty: (property, value)->

    Player.findByClosure((p)=>p[property] is value)

  # ----------------------------------------------------------------------------------------------------------------
  @findByName: (name)->this.findByProperty('name', name)

  # ----------------------------------------------------------------------------------------------------------------
  @findByNameCaseInsensitive: (name)->Player.findByClosure((p)=>(p.getName().toUpperCase() is name.toUpperCase()))

  # ----------------------------------------------------------------------------------------------------------------
  @findByIndex: (index)->this.findByProperty('index', index)
    
  # ----------------------------------------------------------------------------------------------------------------
  @getActivePlayersSortedByJoinOrder: ()->
    _.sortBy(Player.getActivePlayers(), (p)=>p.getIndex())

  # ----------------------------------------------------------------------------------------------------------------
  @getActivePlayers: ()->
    _.select(Hy.Player.Player.collection(), (player)->player.isActive())

  # ----------------------------------------------------------------------------------------------------------------
  @getActivePlayersByKind: (kind)->
    _.select(Hy.Player.Player.collection(), (player)->player.isActive() and player.kind is kind)

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()-> @name

  # ----------------------------------------------------------------------------------------------------------------
  getDefaultName: ()-> @defaultName

  # ----------------------------------------------------------------------------------------------------------------
  isReservedName: (n)->
    n.match(/player/gi)? or n.match(/console/gi)?

  # ----------------------------------------------------------------------------------------------------------------
  # Do some checking / validation of the requested "requestedName", returning an object hash containing the 
  #  "givenName" if successful (but which may vary slightly from the requested "requestedName", 
  #   or a non-null "errorMessage". 
  #  
  # We check for empty or null strings, and will trim length to fit, and also remove illegal characters
  setName: (requestedName, systemAssigned = false) ->

    errorMessage = null

    # Check for null or empty name
    fnNull = (n)=>
      if (not n?) or (n? and (n is ""))
        errorMessage = "No name specified"
        null
      else
        n

    # Trim names that are too long
    fnShorten = (n)=>
      n?.slice(0, Hy.Config.kMaxPlayerNameLength)

    # Trim spaces from both ends
    fnTrim = (n)=>
      n?.trim()

    # Don't allow injection
    fnCatchInjection = (n)=>
      n?.replace(/</g, "")

    # Check for reserved names
    fnReserved = (n)=>
      if systemAssigned
        n
      else
        if this.isReservedName(n)
          if n.toUpperCase() is this.getDefaultName().toUpperCase()
            this.getDefaultName()
          else
            errorMessage = "Don\'t use \"player\" or \"console\""
            null
        else
          n

    # Check for uniqueness
    fnUnique = (n)=>
      if (p = Player.findByNameCaseInsensitive(n))? and (p isnt this)
        errorMessage = "Someone is already named \"#{n}\"!"
        null
      else
        n

    givenName = requestedName

    if not systemAssigned
      # Now run all checks
      checks = [fnCatchInjection, fnTrim, fnShorten, fnTrim, fnNull, fnReserved, fnUnique]

      for f in checks
        if (n = f(givenName))?
          givenName = n
        else
          if not errorMessage?
            errorMessage = "Sorry, that name is not allowed."
          break

    if not errorMessage?
      @name = givenName
      player = this
      Player.notifyObservers (observer)=>observer.obs_playerNameChanged?(player)
      null

    {givenName: givenName, errorMessage: errorMessage}

  # ----------------------------------------------------------------------------------------------------------------
  buildResponse: (contestQuestion, answerIndex, startTime, answerTime)->
    response = new Hy.Contest.ContestResponse(this, contestQuestion, answerIndex, startTime, answerTime)
    response
  
  # ----------------------------------------------------------------------------------------------------------------
  score: ()->

    responses = Hy.Contest.ContestResponse.selectByPlayer(this)

    responses.map((r)->Number(r.getScore())).sum()

  # ----------------------------------------------------------------------------------------------------------------
  isKind: (kind)->

    @kind is kind

  # ----------------------------------------------------------------------------------------------------------------
  isActive: ()->
    @status is Player.kStatusActive

  # ----------------------------------------------------------------------------------------------------------------
  getIndex: ()-> @index

# ==================================================================================================================
class ConsolePlayer extends Player

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  setDefaultName: ()->

    # Assign generated name
    this._setDefaultName("Console")

    this

  # ----------------------------------------------------------------------------------------------------------------
  @init: ()->

    if not gInstance?
      gInstance = new ConsolePlayer()
    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @findConsolePlayer: ()->

    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    super Player.kKindConsole, "Console"

    @answered = false

  # ----------------------------------------------------------------------------------------------------------------
  setHasAnswered: (flag)->
    @answered = flag

  # ----------------------------------------------------------------------------------------------------------------
  hasAnswered: ()-> @answered

# ==================================================================================================================
class RemotePlayer extends Player

  # ----------------------------------------------------------------------------------------------------------------
  @create: (connection, label, versionMajor, versionMinor)->

    new RemotePlayer(connection, label, versionMajor, versionMinor)

  # ----------------------------------------------------------------------------------------------------------------
  @findByConnection: (connection)->

    _.detect(this.collectionByKind(Player.kKindRemote), (p)=>p.getConnection() is connection)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@connection, label, @majorVersion, @minorVersion)->

    super Player.kKindRemote, label

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    "#{super} connection=#{this.getConnection()}"

  # ----------------------------------------------------------------------------------------------------------------
  getConnection: ()-> @connection

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
  destroy: ()->
#    Hy.Trace.debug "Player::destroy (#{this.dumpStr()})"
    Player.destroy(this)
    null

  # ----------------------------------------------------------------------------------------------------------------
  deactivate: ()->
    Hy.Trace.debug "Player::deactivate (#{this.dumpStr()})"
    @status = Player.kStatusInactive
    player = this
    Player.notifyObservers (observer)=>observer.obs_playerDeactivated?(player)
    this

  # ----------------------------------------------------------------------------------------------------------------
  reactivate: ()->
#    Hy.Trace.debug "Player::reactivate (#{this.dumpStr()})"
    @status = Player.kStatusActive
    player = this
    Player.notifyObservers (observer)=>observer.obs_playerReactivated?(player)
    this


# ==================================================================================================================
# assign to global namespace:
Hy.Player =
  Player: Player
  ConsolePlayer: ConsolePlayer
  RemotePlayer: RemotePlayer

