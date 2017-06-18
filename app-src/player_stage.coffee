# ==================================================================================================================
class PlayerView extends Hy.UI.LabelProxy

  kHeight = 20
  gCachedViews = []

  # ----------------------------------------------------------------------------------------------------------------
  @findUnusedView: ()->
    _.find(gCachedViews, (vs)=>not vs.inUse)

  # ----------------------------------------------------------------------------------------------------------------
  @create: (player, options = {})->

    vs = PlayerView.findUnusedView()

    if not vs?
      gCachedViews.push (vs = {view: new PlayerView(player, options), inUse: false})
      vs

    vs.inUse = true
    vs.view.initialize(player, options)
    vs.view   

  # ----------------------------------------------------------------------------------------------------------------
  @doneWithView: (v)->
    if (vs = _.find(gCachedViews, (vs)=>vs.view is v))
      vs.inUse = false
    null

  # ----------------------------------------------------------------------------------------------------------------
  @getHeight: ()-> kHeight

  # ----------------------------------------------------------------------------------------------------------------
  @getWidth: ()-> Hy.Config.kMaxPlayerNameLength * 10

  # ----------------------------------------------------------------------------------------------------------------
  @getPadding: ()-> Hy.Config.PlayerStage.kPadding

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options={})->

    super Hy.UI.ViewProxy.mergeOptions(this.defaultOptions(), options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (@player, options={})->

    this.initializeFromOptions(Hy.UI.ViewProxy.mergeOptions(this.defaultOptions(), options))

    this.setUIProperty("color", Hy.UI.Colors.white)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getPlayer: ()-> @player

  # ----------------------------------------------------------------------------------------------------------------
  defaultOptions: ()->

    height: PlayerView.getHeight()
    width: PlayerView.getWidth()
    left: 0
    bottom: 0
    font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specMinisculeNormal, {fontSize:14})
    textAlign: "center"
    color: Hy.UI.Colors.black
    backgroundColor: Hy.UI.Colors.black
#    backgroundImage: "assets/icons/avatar-name-background.png"
    text: this.getDisplay()
#    borderColor: Hy.UI.Colors.black
#    borderWidth: 0


  # ----------------------------------------------------------------------------------------------------------------
  getDisplay: (score = null)->

    t = ""

    if (p = this.getPlayer())?
      t += p.getName()

    if score? and score > 0
      t += " #{score}"

    t
  # ----------------------------------------------------------------------------------------------------------------
  update: ()->

    this.setUIProperty("text", this.getDisplay())

    this

  # ----------------------------------------------------------------------------------------------------------------
  showCorrectness: (correctness, score)->

   options = 
     borderColor: if correctness then Hy.UI.Colors.green else Hy.UI.Colors.red
#     borderWidth: 1
     text: this.getDisplay(score)

   this.setUIProperties(options)
   this

  # ----------------------------------------------------------------------------------------------------------------
  showScore: (score)->

   options = 
     borderColor: Hy.UI.Colors.black
     borderWidth: 0
     text: this.getDisplay(score)

   this.setUIProperties(options)
   this

# ==================================================================================================================
class PlayerSpec
  
  constructor: (@player)->
    @visible = false
    @stagePosition = null
    @playerView = null
    @position = null
    this

  getPlayer: ()-> @player

  getVisible: ()-> @visible
  setVisible: (@visible)-> this

  getStagePosition: ()-> @stagePosition
  setStagePosition: (@stagePosition)-> this

  getPlayerView: ()->
    if @playerView? then @playerView else (@playerView = PlayerView.create(this.getPlayer()))

  setPlayerView: (@playerView)-> this

  getPosition: ()-> @position
  setPosition: (@position)-> this

  getDumpStr: ()-> "#{this.getPlayer()?.dumpStr()} stagePosition:#{@stagePosition} visible:#{@visible} playerView:#{@playerView?}"
  
# ==================================================================================================================
#
# Players are added via "addPlayer", and can be removed via "removePlayer". 
# A Player can exist on the stage without being visible.
#
class PlayerStage extends Hy.UI.ViewProxy

  @kPanelWidthDefault = Hy.UI.iPad.screenWidth
  @kPanelHeightDefault = 100

  @kPanelWidthMax = Hy.UI.iPad.screenWidth
  @kPanelHeightMax = 200 # A Guess

  @kPanelSizeMin = 10 # A Guess

  # ----------------------------------------------------------------------------------------------------------------
  @validateCustomization: ()->
    null

  # ----------------------------------------------------------------------------------------------------------------
  @validateResponsesSize: (sizeSpec)->

    constraint = 
      min: 
        height: PlayerStage.kPanelSizeMin
        width:  PlayerStage.kPanelSizeMin
      max:
        height: PlayerStage.kPanelHeightMax + 1
        width:  PlayerStage.kPanelWidthMax + 1

    (new Hy.UI.SizeEx(sizeSpec)).isValid(constraint)
  
  # ------------
  @validateResponsesOffset: (positionSpec)->

    widthConstraint =  (PlayerStage.kPanelWidthMax -  PlayerStage.kPanelSizeMin)/2
    heightConstraint = (PlayerStage.kPanelHeightMax - PlayerStage.kPanelSizeMin)

    constraint = 
      min: 
        left:   -widthConstraint
        right:  -widthConstraint
        top:    -heightConstraint
        bottom: 0
      max:
        left:   widthConstraint + 1
        right:  widthConstraint + 1
        top:    0
        bottom: heightConstraint + 1

    (new Hy.UI.PositionEx(positionSpec)).isValid(constraint)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@page, options = {})->

    # The players on this stage
    @playerSpecs = []

    if not (@maxNumPlayers = options._maxNumPlayers)?
      @maxNumPlayers = Hy.Config.PlayerStage.kMaxNumPlayers

    # Special view used only when we have a single player, the ConsolePlayer, and we want to 
    # provide a more customized experience
    @stageletSizeOptions = 
      height: Hy.UI.iPad.screenHeight
      width: Hy.UI.iPad.screenWidth

    otherStageletOptions = 
      bottom: 0
      left: 0

    defaultOptions =
      _orientation: "horizontal"
#      borderWidth: 5
#      borderColor: Hy.UI.Colors.yellow

    defaultOptions = this.getSize(Hy.Config.PlayerNetwork.kSingleUserModeOverride, defaultOptions)

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this.addChild(@consolePlayerOnlyStagelet = new ConsolePlayerOnlyStagelet(@page, Hy.UI.ViewProxy.mergeOptions(@stageletSizeOptions, otherStageletOptions)))

    Hy.Player.Player.addObserver this

    this

 # ----------------------------------------------------------------------------------------------------------------
  getSize: (isSingleUser, options = {})->

    if isSingleUser
      o = @stageletSizeOptions
    else
      o = 
        _orientation: "horizontal"
        borderWidth: 0
        borderColor: Hy.UI.Colors.red

      n = this.getNumPlayersPerRow()

      if this.getOrientation() is "horizontal"
        o.height = this.getPlayerViewHeight() * this.getNumRows()
        o.width = (n * this.getPlayerViewWidth()) + ((n - 1) * this.getPlayerViewPadding())
        o.width = Hy.UI.iPad.screenWidth # HACK 1.0.2 TODO
      else
        o.width = this.getPlayerViewWidth() * this.getNumRows()
        o.height = (n * this.getPlayerViewHeight()) + ((n - 1) * this.getPlayerViewPadding())

    Hy.UI.ViewProxy.mergeOptions(options, o)

 # ----------------------------------------------------------------------------------------------------------------
  # "EXTERNAL" methods
  # ----------------------------------------------------------------------------------------------------------------
 # ----------------------------------------------------------------------------------------------------------------
  #
  # playerOptions:
  #   
  #  _showCorrectness: true or false, according to whether the avatar's player answered correctly
  #
  #  _score:           avatar's player's score
  #
  # options:
  #  _stageOrder:      for requests involving more than one avatar. Overrides "_stagePosition" to impose
  #                    the order in which the supplied avatars are animation. Valid values:
  #
  #                       "asProvided": avatars arranged in the order in which they appear in the
  #                                     supplied array of playerSpecs. Used for Scoreboard, etc.
  #
  #                       "perPlayer" : use avatar._stagePosition if possible.
  #               
  #                       "fill"   :    Default. Places the avatar in the first available position or hole. Used
  #                                     for question/answer page.
  #
  #                       In all cases, if a requested position is null or already in use, reverts to "fill".
  #
  animate: (pose, playerSpecs, playerOptions = [], options={})->

    currentStagePosition = -1    
    sequence = null

    if playerSpecs.length > 0
      for i in [0..playerSpecs.length-1]
        playerSpec = playerSpecs[i]
        playerOption = if playerOptions? then playerOptions[i] else null

        useConsolePlayerStage = Hy.Network.PlayerNetwork.isSingleUserMode() or Hy.Player.Player.isConsolePlayerOnly()

        this.setUIProperties(this.getSize(useConsolePlayerStage))

        if useConsolePlayerStage
          this.applyPoseToPlayerViewConsolePlayerOnly(pose, playerSpec, playerOption, options, ++currentStagePosition)
        else
          this.applyPoseToPlayerView(pose, playerSpec, playerOption, options, ++currentStagePosition)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addPlayer: (player)->

    if not (playerSpec = this.findPlayerSpecByPlayer(player))?    
      this.getPlayerSpecs().push (playerSpec = new PlayerSpec(player))

    Hy.Trace.debug("PlayerStage::addPlayer (#{playerSpec.getDumpStr()})")

    playerSpec

# ----------------------------------------------------------------------------------------------------------------
  removePlayer: (playerSpec)->
    Hy.Trace.debug("PlayerStage::removePlayer (#{playerSpec.getDumpStr()})")

    this.animate("destroyed", [playerSpec])
    @playerSpecs = _.without(@playerSpecs, playerSpec)

    this

 # ----------------------------------------------------------------------------------------------------------------
  removePlayers: ()->
    Hy.Trace.debug("PlayerStage::removePlayers")

    this.animate("destroyed", this.getPlayerSpecs())
    @playerSpecs = []

    this

 # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    this.stop()

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  stop: ()->
    this.removePlayers()
    this.getConsolePlayerOnlyStagelet().setVisibility(false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()-> 
    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerNameChanged: (player)->
    if (playerSpec = this.findPlayerSpecByPlayer(player))?
      playerSpec.getPlayerView().update()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDumpStr: ()->

    s = ""
    s += " #players=#{_.size(@playerSpecs)}"

    for playerSpec in @playerSpecs
      s += " / " + playerSpec.getDumpStr()

    s

 # ----------------------------------------------------------------------------------------------------------------
  #
  # "INTERNAL" methods
  #
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  getConsolePlayerOnlyStagelet: ()-> @consolePlayerOnlyStagelet

  # ----------------------------------------------------------------------------------------------------------------
  getMaxNumPlayers: ()-> @maxNumPlayers

  # ----------------------------------------------------------------------------------------------------------------
  getNumRows: ()-> 4
  # ----------------------------------------------------------------------------------------------------------------
  getNumPlayersPerRow: ()-> 12 
  # ----------------------------------------------------------------------------------------------------------------
  getOrientation: ()-> this.getUIProperty("_orientation")

  # ----------------------------------------------------------------------------------------------------------------
  # This class handles its own layout
  layoutChildren: ()-> this

  # ----------------------------------------------------------------------------------------------------------------
  getPlayerViewHeight: ()-> PlayerView.getHeight()

  # ----------------------------------------------------------------------------------------------------------------
  getPlayerViewWidth: ()-> PlayerView.getWidth()

  # ----------------------------------------------------------------------------------------------------------------
  getPlayerViewPadding: ()-> PlayerView.getPadding()

  # ----------------------------------------------------------------------------------------------------------------
  getPlayerSpecs: ()-> @playerSpecs

  # ----------------------------------------------------------------------------------------------------------------
  findPlayerSpecByProperty: (property, value)->

    _.detect(this.getPlayerSpecs(), (a)=>a[property] is value)

  # ----------------------------------------------------------------------------------------------------------------
  findPlayerSpecByPlayer: (player)->
    this.findPlayerSpecByProperty("player", player)

  # ----------------------------------------------------------------------------------------------------------------
  computeStagePosition: (playerSpec, pose, options, currentStagePosition)->

    info = ""

    fnSlotTaken = (a)=>_.detect(this.getPlayerSpecs(), (ps)=>ps.getStagePosition() is a)

    # start with requested _stageOrder options "asProvided" and "perPlayer"
    options._stagePosition = switch options._stageOrder
      when "asProvided"
        currentStagePosition
      when "perPlayer"
        playerSpec.getStagePosition() # Might be null
      else
        null
 
    # Is the requested slot already in use by some other avatar?
    if options._stagePosition? and (as = fnSlotTaken(options._stagePosition))? and (as isnt playerSpec)
      options._stagePosition = null

    # Implement "fill" and edge cases
    if not options._stagePosition?

      # First, does it already happen to have a place of its own?
      if playerSpec.getStagePosition()? and (as = fnSlotTaken(playerSpec.getStagePosition()))? and (as is playerSpec)
        options._stagePosition = playerSpec.getStagePosition()
        info += " Re-using own slot"
      else
        # find a nice empty spot
        for i in [0..this.getMaxNumPlayers() - 1]
          if not fnSlotTaken(i)?
            options._stagePosition = i
            info += " Found empty slot"
            break

    # screw'd case
    if not options._stagePosition?
      options._stagePosition = 0
      info += " COULD NOT PLACE"
      Hy.Trace.debug "PlayerStage::computeStagePosition (COULD NOT PLACE #{pose} #{playerSpec.getDumpStr()})"

    # Remember where we put this sucker.
    playerSpec.setStagePosition(options._stagePosition)

    Hy.Trace.debug "PlayerStage::computeStagePosition (\"#{pose}\" #{playerSpec.getDumpStr()} #{info} #{this.getDumpStr()})"

    this
  # ----------------------------------------------------------------------------------------------------------------
  # 0-based indicator of stage position
  # We pass in options to allow more runtime control.
  #
  computePlayerCoordinates: (playerSpec)->

    position = null

    # At the very least, should have been computed when the animation was created
    if not (stagePosition = playerSpec.getStagePosition())?
      stagePosition = 0 # fallback

    row = Math.floor(stagePosition / this.getNumPlayersPerRow())
    positionWithinRow = stagePosition % this.getNumPlayersPerRow()

    heightFactor = this.getPlayerViewPadding() + this.getPlayerViewHeight()
    widthFactor =  this.getPlayerViewPadding() + this.getPlayerViewWidth()

    switch this.getOrientation()
      when "horizontal"
        top = row * heightFactor
        left = positionWithinRow * widthFactor
      when "vertical"
        top = positionWithinRow * widthFactor
        left = row * heightFactor

    new Hy.UI.Position(top, left)

  # ----------------------------------------------------------------------------------------------------------------
  applyPoseToPlayerView: (pose, playerSpec, playerOption, options, stagePosition)->

    playerView = playerSpec.getPlayerView(playerSpec)

    fnStagePosition = ()=> this.computeStagePosition(playerSpec, pose, options, stagePosition)
    fnCoordinates =   ()=> playerView.setPosition(this.computePlayerCoordinates(playerSpec, options))

    fnCorrectness =   ()=> playerView.showCorrectness(playerOption._correctness, playerOption._score)
    fnScore =         ()=> playerView.showScore(playerOption._score)

    fnAddView =       ()=> this.addChild(playerView) if not this.hasChild(playerView)
    fnRemoveView =    ()=> this.removeChild(playerView)
    fnDoneWithView =  ()=> PlayerView.doneWithView(playerView)

    actions = []
    
    switch pose
      when "created", "reactivated"
        actions.push fnStagePosition, fnCoordinates, fnAddView
      when "answered" 
        actions.push fnStagePosition, fnCoordinates, fnAddView
      when "showCorrectness" 
        actions.push fnStagePosition, fnCoordinates, fnAddView, fnCorrectness
      when "showScore"
        actions.push fnStagePosition, fnCoordinates, fnAddView, fnScore
      when "deactivated", "destroyed"
        actions.push fnRemoveView, fnDoneWithView

      else
        Hy.Trace.debug "PlayerStage::animate (ERROR UNKNOWN POSE #{pose})"
        actions.push fnStagePosition, fnAddView        

    _.each(actions, (a)=>a())

    this

  # ----------------------------------------------------------------------------------------------------------------
  applyPoseToPlayerViewConsolePlayerOnly: (pose, playerSpec, playerOption, options, stagePosition)->

    fnSuper =         ()=> this.applyPoseToPlayerView(pose, playerSpec, playerOption, options, stagePosition)
    fnStagelet =      ()=> this.getConsolePlayerOnlyStagelet()

    fnVisible =       ()=> fnStagelet().setVisibility(true)     
    fnInvisible =     ()=> fnStagelet().setVisibility(false)     

    fnAdd =           ()=> fnStagelet().added()
    fnAnswered =      ()=> fnStagelet().answered()
    fnCorrectness =   ()=> fnStagelet().showCorrectness(playerOption._correctness, playerOption._score)
    fnScore =         ()=> fnStagelet().showScore(playerOption._score)

    actions = switch pose
      when "created", "reactivated"
        [fnAdd, fnVisible]
      when "answered" 
        [fnAnswered, fnVisible]
      when "showCorrectness" 
        [fnCorrectness, fnVisible]
      when "showScore"
        [fnScore, fnVisible]
      when "deactivated", "destroyed"
        [fnInvisible]

      else
        Hy.Trace.debug "PlayerStage::animate (ERROR UNKNOWN POSE #{pose})"
        [fnInvisible]

    _.each(actions, (a)=>a())

    this

# ==================================================================================================================
class ConsolePlayerOnlyStagelet extends Hy.UI.ViewProxy


  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@page, options)->

    defaultOptions = 
      bottom: 0
      left: 0
      height: PlayerStage.kPanelHeightMax
#      borderColor: Hy.UI.Colors.black
#      borderWidth: 1
#      backgroundColor: Hy.UI.Colors.white

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    @panelSpecs = []
    @currentPanelSpec = null
    this.initPanels()

    this

  # ----------------------------------------------------------------------------------------------------------------
  setVisibility: (visible)->
    this.setUIProperty("visible", visible)

    if visible
      if @currentPanelSpec?
        this.setPanelVisibility(@currentPanelSpec, true)
    else
      @currentPanelSpec = null
      for panelSpec in this.getPanelSpecs()
        this.setPanelVisibility(panelSpec, false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  findPanelSpecByName: (panelName)-> _.find(this.getPanelSpecs(), (ps)=>ps.panelName is panelName)

  # ----------------------------------------------------------------------------------------------------------------
  getPanelPath: (panelName)-> @page.getPath([panelName])

  # ----------------------------------------------------------------------------------------------------------------
  getPanelSpecs: ()-> @panelSpecs

  # ----------------------------------------------------------------------------------------------------------------
  setPanelVisibility: (panelSpec, visibility)->

    panelSpec.panel.setUIProperty("visible", visibility)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setPanelText: (panelSpec = null, text = null, context = null)->

    fn_replaceValues = (text, context)=>
      if (t = text)? and context?
        for n, v of context
          s = "#" + "{" + n + "}"
          t = t.replace(s, v)
      t

    if panelSpec?
      t = if panelSpec.text?
        fn_replaceValues(panelSpec.text, context)
      else
        text

      panelSpec.panel.setUIProperty("text", t)

    if @currentPanelSpec?
      this.setPanelVisibility(@currentPanelSpec, false)

    @currentPanelSpec = panelSpec

    this

  # ----------------------------------------------------------------------------------------------------------------
  getPanelKinds: ()->
    [
      {panelName: "join"     }
      {panelName: "response" }
      {panelName: "correct"  }
      {panelName: "incorrect"}
      {panelName: "score"    }
    ]

  # ----------------------------------------------------------------------------------------------------------------
  # 
  # questionpage.{responded,correct,incorrect}.{accent,size,position,background.*,font}
  #

  initPanels: ()->

    defaultOptions =
      width: PlayerStage.kPanelWidthDefault
      height: PlayerStage.kPanelHeightDefault
      bottom: 0
      textAlign: "center"
      visible: false
      font: Hy.UI.Fonts.specBigNormal

    center = Hy.UI.PositionEx.createCenteringPoint(["left"])

    for panelSpec in this.getPanelKinds()
      options = {}

      options = Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)
      path = this.getPanelPath(panelSpec.panelName)

      # First, establish size (and misc other stuff)
      Hy.Customize.mapOptions(["size", "font", "background", "text"], path, options)

      # Then establish a default horizontal center
      center.getOptions(options)

      # Now apply offset directives
      Hy.Customize.mapOptions(["offset"], path, options)

      options.borderColor = Hy.UI.Colors.mapTransparent(Hy.Customize.map("bordercolor", path)) # handle transparency
      options.borderWidth = if options.borderColor? then 1 else 0

      @panelSpecs.push ps = {panelName: panelSpec.panelName, text: options.text, panel: (p = new Hy.UI.LabelProxy(options))}

      this.setPanelVisibility(ps, false)
      this.addChild(p)

    this


  # ----------------------------------------------------------------------------------------------------------------
  report: (kind, text, context = null)->

    if (panelSpec = this.findPanelSpecByName(kind))?

      this.setPanelText(panelSpec, text, context)

    this

  # ----------------------------------------------------------------------------------------------------------------
  added: ()->
    this.report("join", "Hello There!")
    this

  # ----------------------------------------------------------------------------------------------------------------
  answered: ()->
    this.report("response", "You Answered...")
    this

  # ----------------------------------------------------------------------------------------------------------------
  showCorrectness: (correctness, score)->

    text = if correctness then "CORRECT!" else "INCORRECT!"

    if correctness
      text += " #{score} Point#{if score is 1 then "" else "s"}"

    this.report( (if correctness then "correct" else "incorrect"), text, {score: score})

    this

  # ----------------------------------------------------------------------------------------------------------------
  showScore: (score)->

   this.report("score", "Your Score: #{score}", {score: score})

   this
  
# ==================================================================================================================
class Score extends Hy.UI.LabelProxy

  kScoreHeight = 40
  kScoreWidth = 70

  # ----------------------------------------------------------------------------------------------------------------
  @getHeight: ()-> kScoreHeight

  # ----------------------------------------------------------------------------------------------------------------
  @getWidth: ()-> kScoreWidth

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options, @scoreText)->

    defaultOptions = 
      top: 0
      height: Score.getHeight()
      width: Score.getWidth()
      color: Hy.UI.Colors.white
      font: Hy.UI.Fonts.specBigNormal
      textAlign: 'center'
      text: @scoreText

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this

# ==================================================================================================================
class PlayerStageWithScores extends PlayerStage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {})->

    defaultOptions = {}

    if not options._scoreOrientation?
      defaultOptions._scoreOrientation = "horizontal"

    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getScoreOrientation: ()->
    this.getUIProperty("_scoreOrientation")

  # ----------------------------------------------------------------------------------------------------------------
  getPlayerViewHeight: ()->

    height = super

    if this.getScoreOrientation() is "vertical"
      height += Score.getHeight()

    height

  # ----------------------------------------------------------------------------------------------------------------
  getPlayerViewWidth: ()->

    width = super
    if this.getScoreOrientation() is "horizontal"
      width += Score.getWidth()

    width

  # ----------------------------------------------------------------------------------------------------------------
  # 0-based indicator of stage position
  computePlayerCoordinates: (playerSpec)->

    if (position = super)?
      top = position.getTop()
      left = position.getLeft()

      switch this.getScoreOrientation()
        when "horizontal"
          null

        when "vertical"
          top += Score.getHeight()

      position = new Hy.UI.Position(top, left)

    position


# ==================================================================================================================
if not Hyperbotic.UI
  Hyperbotic.UI = {}

Hyperbotic.UI.PlayerStage = PlayerStage
Hyperbotic.UI.PlayerStageWithScores = PlayerStageWithScores

