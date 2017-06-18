# ==================================================================================================================
class Panel extends Hy.UI.ViewProxy
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@page, options = {})->

    defaultOptions = 
      _tag: "Panel: #{this.constructor.name}"

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (evt)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  getPage: ()-> @page

  # ----------------------------------------------------------------------------------------------------------------
  getPath: (path = [])->
    @page.getPath(path)

# ==================================================================================================================
class CountdownPanelBase extends Panel

  kWidth = 86
  kHeight = 86

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {}, @fnPauseClick)->

    defaultOptions = 
      height: kHeight
      width: kWidth
      zIndex: Hy.Pages.Page.kPageContainerZIndex + 1

    super page, Hy.UI.ImageViewProxy.mergeOptions(defaultOptions,options)

    this.addChild(@pauseButton = this.createButton())

    @pauseButton.addEventListener("click", ()=>@fnPauseClick())

    this

  # ----------------------------------------------------------------------------------------------------------------
  createButton: ()->
    null

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateCountdown: (options, value = null, total = null, init = false)->
    this.animateLabel(options, value, total, init)
    this

  # ----------------------------------------------------------------------------------------------------------------
  setLabelTitle: (value)->

    minutes = Math.floor(value / 60)
    seconds = value % 60

    s = ""

    if minutes is 0
      s = "#{seconds}"
      font = Hy.UI.Fonts.specBiggerNormal
    else
      font = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specBiggerNormal, {fontSize: 30})

      s = "#{minutes}:#{if seconds < 10 then "0" else ""}#{seconds}"

    @pauseButton.setUIProperty("title", "")
    @pauseButton.setUIProperty("font", font)
    @pauseButton.setUIProperty("title", s)

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateLabel: (options, value, total, init)->

    if value?
      this.setLabelTitle(value)

    if options._style?
      color = switch options._style
        when "normal"
          Hy.UI.Colors.white

        when "frantic"
          if value? and value <= Hy.Config.Dynamics.panicAnswerTime
            Hy.Customize.map("bordercolor", this.getPath(), Hy.UI.Colors.MrF.Red) # ignore transparency
          else
            Hy.UI.Colors.white

        when "completed"
          Hy.Customize.map("bordercolor", this.getPath(), Hy.UI.Colors.MrF.Red) # ignore transparency
  
        else
          Hy.UI.Colors.white

#      @label.setUIProperty("color", color)
      @pauseButton.setUIProperty("color", color)
    this

# ==================================================================================================================
class CountdownPanelMrF extends CountdownPanelBase

  kWidth = 86
  kHeight = 86

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {}, fnPauseClick)->

    super page, options, fnPauseClick

    buttonRimOptions = 
      image: "assets/icons/countdown-background.png"
      height: kHeight
      width: kWidth

    this.addChild(@pauseButtonRim = new Hy.UI.ImageViewProxy(buttonRimOptions))

    this

  # ----------------------------------------------------------------------------------------------------------------
  createButton: ()->

    buttonOptions = 
      font: Hy.UI.Fonts.specBiggerNormal
#      backgroundImage: "assets/icons/circle-black.png"
#      backgroundSelectedImage: "assets/icons/circle-black-selected.png"
      backgroundColor: Hy.UI.Colors.black
      color: Hy.UI.Colors.white
      textAlign: 'center'
      zIndex: Hy.Pages.Page.kTouchZIndex
      _tag: "Timer"
      height: kWidth - 20
      height: (kWidth - 20)/2
      width: kWidth - 20
      _style: "plain"
      borderWidth: 0 # Override any customization, etc
#      borderColor: Hy.UI.Colors.white

    new Hy.UI.ButtonProxy(buttonOptions)

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    this.initButtonRimAnimation()

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateCountdown: (options, value = null, total = null, init = false)->

    super options, value, total, init

    this.animateButtonRim(options, value, total, init)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initButtonRimAnimation: ()->

    animation = Ti.UI.createAnimation()
    m = Ti.UI.create2DMatrix()

    @buttonRotation = 0
    animation.duration = 0
    animation.transform = m.rotate(0)

    @pauseButtonRim.animate(animation)

  # ----------------------------------------------------------------------------------------------------------------
  animateButtonRim: (options, value, total, init)->

    if options._style? and options._style is "frantic" and not init
      animation = Ti.UI.createAnimation()
      m = Ti.UI.create2DMatrix()

      animation.transform = m.rotate(++@buttonRotation * 90)
      animation.duration = 100

      @pauseButtonRim.animate(animation)

    this

# ==================================================================================================================
class CountdownPanelCustomized extends CountdownPanelBase

  kWidth = 86
  kHeight = 86

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {}, fnPauseClick)->

    super page, options, fnPauseClick

    this

  # ----------------------------------------------------------------------------------------------------------------
  createButton: ()->

    buttonOptions = 
      font: Hy.UI.Fonts.specBiggerNormal
      zIndex: Hy.Pages.Page.kTouchZIndex
      _tag: "Timer"
      _style: "round"
      _size: "medium2"
      _path: this.getPage().getPath()

    new Hy.UI.ButtonProxy(buttonOptions)

# ==================================================================================================================
class QuestionInfoPanelBase extends Panel

  kHeight = kWidth = 86
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {})->

    defaultOptions = 
      height: kHeight
      width:  kWidth
      zIndex: Hy.Pages.Page.kPageContainerZIndex + 1

    super page, (options = Hy.UI.ViewProxy.mergeOptions(defaultOptions,options))

    this.addElements(options)

    this
  # ----------------------------------------------------------------------------------------------------------------
  addElements: (options)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (currentQ, totalQ, color)->

    super

    this

# ==================================================================================================================
class QuestionInfoPanelMrF extends QuestionInfoPanelBase

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {})->

    super page, options

    this

  # ----------------------------------------------------------------------------------------------------------------
  addElements: (options)->

    zIndex = this.getUIProperty("zIndex")

    labelOptions = 
      font: Hy.UI.Fonts.specMediumNormal
      textAlign: 'center'
      height: (options.height * .35)
      width: (options.width * .35)
      _tag: "Question Info"
      zIndex: zIndex + 1

    labelOptions.font.fontSize = 24
    
    this.addChild(@currentQLabel = new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(labelOptions, {color: Hy.UI.Colors.black, bottom: (options.height/2), right: (options.width/2)})))

    fudge = 3
    this.addChild(@totalQLabel =   new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(labelOptions, {color: Hy.UI.Colors.MrF.DarkBlue, top: ((options.height/2)-fudge), left: (options.width/2)})))

    this.addChild(new Hy.UI.ImageViewProxy({image: "assets/icons/question-info-background.png", zIndex: labelOptions.zIndex-1}))

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (currentQ, totalQ, color)->

    super currentQ, totalQ, color

    @currentQLabel.setUIProperty("text", currentQ)

    @totalQLabel.setUIProperty("text", "#{totalQ}")

 this

# ==================================================================================================================
class QuestionInfoPanelCustomized extends QuestionInfoPanelBase

  kHeight = kWidth = 86
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {})->

    super page, options

    buttonOptions = 
      _style: "round"
      _size: "medium2"
      _path: this.getPage().getPath()

    this.addChild(@button = new Hy.UI.ButtonProxy(buttonOptions))

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (currentQ, totalQ, color)->

    super

    @button.setUIProperty("title", "#{currentQ}/#{totalQ}")

    this


# ==================================================================================================================
#
# "critter": a hold-over from the very first version of Trivially, which had cute critters as 
# player avatars
#
class CritterPanel extends Panel

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {})->

    super page, options

    @stages = []

    this.addPlayerStages()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getPath: (path = [])->
    super [].concat("PlayerStage", path)

  # ----------------------------------------------------------------------------------------------------------------
  addPlayerStages: ()->

    options = 
      _orientation:"horizontal"
      bottom: 0
      left:0

    this.addChild(@playerStage = new Hy.UI.PlayerStage(@page, options))

    this.setUIProperty("height", @playerStage.getUIProperty("height"))

    @stages.push @playerStage

    this    

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    @players = []

    for stage in @stages
      stage.initialize()

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super

    for stage in @stages
      stage.start()

    this
  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    for stage in @stages
      stage.stop()

    super

    this
  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    super

    for stage in @stages
      stage.pause()

    this
  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super

    for stage in @stages
      stage.resumed()

    this

  # ----------------------------------------------------------------------------------------------------------------
  findPlayer: (player)->

    _.detect(@players, (p)=>p.playerIndex is player.getIndex())

  # ----------------------------------------------------------------------------------------------------------------
  addPlayer: (player, playerStage)->

    playerStageSpec = playerStage.addPlayer(player)

    playerSpec = {playerIndex:player.getIndex(), playerStageSpec: playerStageSpec}
    @players.push playerSpec

    playerSpec

  # ----------------------------------------------------------------------------------------------------------------
  removePlayer: (player, playerStage = @playerStage)->

    if (playerSpec = this.findPlayer(player))?
      playerStage.removePlayer(playerSpec.playerStageSpec)
      @players = _.without(@players, playerSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  checkPlayer: (player, playerStage = @playerStage)->

    if not (playerSpec = this.findPlayer(player))?
      playerSpec = this.addPlayer(player, playerStage)

    playerSpec

  # ----------------------------------------------------------------------------------------------------------------
  animateCritters: (animation, players, playerOptions = [], options={}, playerStage = @playerStage)->

    playerSpecs = for player in players
      this.checkPlayer(player).playerStageSpec

    playerStage?.animate(animation, playerSpecs, playerOptions, options)

    this

  # player{Created,Deactivated,Reactivated,Destroyed} are called by Hy.Player.Player as observers, registered by 
  # CheckInCritterPanel
  #
  # ----------------------------------------------------------------------------------------------------------------
  obs_playerCreated: (player)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerDeactivated: (player)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerReactivated: (player)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerDestroyed: (player)->

    this.removePlayer(player)

    this

# ==================================================================================================================
class CheckInCritterPanel extends CritterPanel

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {})->

    super page, options

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super

    Hy.Player.Player.addObserver this

    activePlayers = Hy.Player.Player.getActivePlayersSortedByJoinOrder()

    # if there are remote players, don't show the console player
    if _.size(activePlayers) > 1
      activePlayers = _.without(activePlayers, Hy.Player.ConsolePlayer.findConsolePlayer())

    this.animateCritters("created", activePlayers, [], {_stageOrder: "asProvided"})

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    Hy.Player.Player.removeObserver this

    super

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    super

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerCreated: (player)->

    Hy.Trace.debug "CheckInCritterPanel::playerCreated (#{player.dumpStr()})"
 
    super

    # this will attempt to place the player avatar in the same position as when last created
    this.animateCritters("created", [player], [], {_stageOrder: "perPlayer"})

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerDeactivated: (player)->

    Hy.Trace.debug "CheckInCritterPanel::playerDeactivated (#{player.dumpStr()})"

    super

    this.animateCritters("deactivated", [player])

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerReactivated: (player)->

    Hy.Trace.debug "CheckInCritterPanel::playerReactivated (#{player.dumpStr()})"

    super

    # this will attempt to place the player avatar in the same position as when last created
    this.animateCritters("reactivated", [player], [], {_stageOrder: "perPlayer"})

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerDestroyed: (player)->

    Hy.Trace.debug "CheckInCritterPanel::playerDestroyed (#{player.dumpStr()})"

    super

    this

# ==================================================================================================================
class AnswerCritterPanel extends CritterPanel

  # ----------------------------------------------------------------------------------------------------------------
  reportResponses: (players, playerOptions)->

    # will place the player avatar on the stage in order created (answered)
    this.animateCritters("showCorrectness", players, playerOptions, {_stageOrder: "fill"})

    this

  # ----------------------------------------------------------------------------------------------------------------
  playerAnswered: (response)->

    # will place the player avatar on the stage in order created (answered)
    this.animateCritters("answered", [response.getPlayer()], [], {_stageOrder: "fill"})

    this

# ==================================================================================================================
class ScoreboardCritterPanel extends CritterPanel

  # Per Ed's design
  stageLayouts = [
    {low: 1, high:  3, numStages: 1, maxPerStage: 3}
    {low: 4, high:  4, numStages: 2, maxPerStage: 2}
    {low: 5, high:  6, numStages: 2, maxPerStage: 3}
    {low: 7, high:  8, numStages: 2, maxPerStage: 4}
    {low: 9, high: 12, numStages: 3, maxPerStage: 4}
    ]

  # For PRO
  stageLayouts = [
    {low: 1, high:  6, numStages: 1, maxPerStage: 6}
    ]

  # ----------------------------------------------------------------------------------------------------------------
  findLayoutSpec: (numPlayers)->
    for layout in stageLayouts
      if layout.low <= numPlayers <= layout.high
        return layout
    return null

  # ----------------------------------------------------------------------------------------------------------------
  # How many stages will we need to fit numPlayers?
  #
  computeNumStages: (numPlayers)->

    if (layout = this.findLayoutSpec(numPlayers))?
      layout.numStages
    else
      0

  # ----------------------------------------------------------------------------------------------------------------
  # How many avatars should be placed on stage# stageIndex (1-based)?
  #
  computeNumPlayersOnStage: (numPlayers, stageIndex)->

    count = 0
    if (layout = this.findLayoutSpec(numPlayers))?
      if stageIndex < layout.numStages
        count = layout.maxPerStage
      else
        count = numPlayers - ((layout.numStages-1) * layout.maxPerStage)

    count

  # ----------------------------------------------------------------------------------------------------------------
  addPlayerStages: ()->

    numPlayers = _.size(Hy.Player.Player.collection())

    # if console player didn't participate, don't show in the leaderboard
    if not Hy.Player.ConsolePlayer.findConsolePlayer().hasAnswered()
      numPlayers--

    options = 
      _scoreOrientation: "horizontal"
      _avatarBacklighting: true
      borderColor: Hy.UI.Colors.red
      borderRadius: 1

    updateOptions = {}

    switch this.getUIProperty("_orientation")
      when "horizontal"
        options._orientation = "horizontal"
        updateOptions._verticalLayout = "group"
        updateOptions._horizontalLayout = "center"

      when "vertical"
        options._orientation = "vertical"
        updateOptions._verticalLayout = "center"
        updateOptions._horizontalLayout = "group"

    this.setUIProperties(updateOptions)

    @stages = []

    if numPlayers > 0
      for i in [1..this.computeNumStages(numPlayers)]
        options._maxNumPlayers = this.computeNumPlayersOnStage(numPlayers, i)
        @stages.push (stage = new Hy.UI.PlayerStageWithScores(@page, options))

      this.addChildren(@stages)
       
    this

  # ----------------------------------------------------------------------------------------------------------------
  displayScores: ()->

    players = Hy.Player.Player.collection()

    # if console player didn't participate, don't show in the leaderboard
    consolePlayer = Hy.Player.ConsolePlayer.findConsolePlayer()
    if not consolePlayer.hasAnswered()
      players = _.without(players, consolePlayer)

    contest = Hy.ConsoleApp.get().getContest()

    fnSortPlayers = (p1, p2)=>p2.score(contest) - p1.score(contest)
    @leaderboard = players.sort(fnSortPlayers)
    numPlayers = _.size(@leaderboard)

    initialScore = null

    playerNum = 0
    for stage, stageNum in @stages
      playerSpecs = []
      playerOptions = []
      for position in [1..this.computeNumPlayersOnStage(numPlayers, stageNum + 1)]
        player = @leaderboard[playerNum++]
        playerSpecs.push this.checkPlayer(player, stage).playerStageSpec
        playerOptions.push {_score: player.score()}
      stage.animate("showScore", playerSpecs, playerOptions, {})

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Returns an array of objects: {score: <number>, group: <array>}, where "group" is an array of playerIndex representing
  # players with "score". Array is sorted in order of decreasing score.
  #
  # Used to send scores to remotes!
  #
  getLeaderboard: ()->

    standings = []

    if @leaderboard?
      tempObj = _.groupBy(@leaderboard, (p)=>p.score())

      # "temp" is an object. We want a sorted array
      tempArray = []
      for score, group of tempObj
        tempArray.push {score:score, group:_.pluck(group, "index")}

      _.sortBy(tempArray, (o)=>o.score).reverse()
    else
      null

# ==================================================================================================================
class UtilityPanelBase extends Panel
  
  @kPadding = 10

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options)->

    defaultOptions =
      zIndex: Hy.Pages.Page.kPageContainerZIndex + 1

    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # 
  initialize: ()->
    super
    this

# ==================================================================================================================

class UtilityButtonsPanel extends UtilityPanelBase

  kButtonContainerWidth = 180
  kButtonBottom = 70

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {}, buttonSpecs = [])->

    defaultOptions = 
      height: Hy.UI.ButtonProxy.getDimension(buttonSpecs[0].buttonOptions._size) # fail if no buttons!
      zIndex: Hy.Pages.Page.kTouchZIndex

    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    @buttonSpecs = []
    this.addButtons(buttonSpecs)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # 
  initialize: ()->

    super

    this._initButtonState()

    this

  # ----------------------------------------------------------------------------------------------------------------
  addButtons: (buttonSpecs)->

    buttonsContainerOptions = 
      bottom: 0
      left: 0
      width: this.getUIProperty("width")
      height: this.getUIProperty("height")
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: 40
      zIndex: Hy.Pages.Page.kTouchZIndex
#      borderColor: Hy.UI.Colors.yellow
#      borderWidth: 1

    this.addChild(buttonsContainer = new Hy.UI.ViewProxy(buttonsContainerOptions))

    for buttonSpec in buttonSpecs
      if buttonSpec?
        buttonsContainer.addChild(this.createButton(buttonSpec))

    this

  # ----------------------------------------------------------------------------------------------------------------
  # buttonOptions: passed to ButtonProxy: _style, _size, _text, etc
  # text, font: for label
  # fnClicked

  createButton: (buttonSpec)->

    containerOptions = {}

    width = kButtonContainerWidth
    buttonDimension = Hy.UI.ButtonProxy.getDimension(buttonSpec.buttonOptions._size)
    padding = 10

    defaultContainerOptions =
      width: width
      height: buttonDimension
      bottom: kButtonBottom
      zIndex: Hy.Pages.Page.kTouchZIndex
      _tag: "Button Container: #{buttonSpec.name}"
#      borderColor: Hy.UI.Colors.white
#      borderWidth: 1

    container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(defaultContainerOptions, containerOptions))

    defaultButtonOptions = 
      left: 0
      bottom: 0
      _path: this.getPath()
      _tag: "Button: #{buttonSpec.name}"
      zIndex: Hy.Pages.Page.kTouchZIndex
#      borderColor: Hy.UI.Colors.white
#      borderWidth: 1

    container.addChild(button = new Hy.UI.ButtonProxy(Hy.UI.ViewProxy.mergeOptions(defaultButtonOptions, buttonSpec.buttonOptions)))

    defaultLabelOptions = 
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specMediumNormal, {fontSize: 18})
      color: Hy.UI.Colors.black
      left: buttonDimension + padding
      zIndex: Hy.Pages.Page.kTouchZIndex
#      bottom: 0
      width: width - (buttonDimension + padding)
      _tag: "Button Label: #{buttonSpec.name}"
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1

    Hy.Customize.mapOptions(["font"], this.getPath(), defaultLabelOptions)

    labelOptions = {text: buttonSpec.text, font: buttonSpec.font}

    container.addChild(label = new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultLabelOptions, labelOptions)))

    # We create a new & different "buttonSpec" for use at runtime, separate from the
    # buttonSpec we're initializing from right now
    bs = this._addButtonSpec(buttonSpec.name, button, buttonSpec.fnClick, label)

    fn = (e, v, bs)=>
      if not this._getButtonClicked(bs)
        this._setButtonClicked(bs, true)
        bs.fnClick?(e, v)
      null
  
    button.addEventListener("click", (e, v)=>fn(e, v, bs))

    container

  # ----------------------------------------------------------------------------------------------------------------
  _addButtonSpec: (name, button, fnClick, label)->
    @buttonSpecs.push bs = {name: name, button: button, clicked: false, fnClick: fnClick, label: label}
    this._setButtonEnabled(bs, true)
    bs

  # ----------------------------------------------------------------------------------------------------------------
  setEnabled: (enabled)->
    for buttonSpec in @buttonSpecs
      this._setButtonEnabled(buttonSpec, enabled)
      buttonSpec.clicked = false
    this

  # ----------------------------------------------------------------------------------------------------------------
  getButtonByName: (name)->
    this._getButtonSpecPropByName(name, "button")

  # ----------------------------------------------------------------------------------------------------------------
  getButtonLabelByName: (name)->
    this._getButtonSpecPropByName(name, "label")

  # ----------------------------------------------------------------------------------------------------------------
  _getButtonSpecPropByName: (buttonName, buttonSpecPropName)->
    prop = if (bs = this._findButtonSpecByName(buttonName))?
      bs[buttonSpecPropName]
    else
      null

    prop

  # ----------------------------------------------------------------------------------------------------------------
  _setButtonEnabled: (buttonSpec, enabled)->
    buttonSpec.button?.setEnabled(enabled)
    this
    
  # ----------------------------------------------------------------------------------------------------------------
  _findButtonSpecByName: (name)->
    _.find(@buttonSpecs, (bs)=>bs.name is name)

  # ----------------------------------------------------------------------------------------------------------------
  _getButtonClicked: (buttonSpec)-> buttonSpec.isClcked

  # ----------------------------------------------------------------------------------------------------------------
  _setButtonClicked: (buttonSpec, value)-> 
    buttonSpec.clicked = value
    this._setButtonEnabled(buttonSpec, not value)
    this

  # ----------------------------------------------------------------------------------------------------------------
  _initButtonState: ()->
    for buttonSpec in @buttonSpecs
      this._setButtonClicked(buttonSpec, false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  launchURL: (url)->

    Ti.Platform.openURL(url)

    this

# ==================================================================================================================

class UtilityTextPanel extends UtilityPanelBase

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {}, @fn_getText, @shouldInitOnNetworkChange = false)->

    defaultOptions = 
      width: "auto"
      height: 100

    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    @labelView = null   

    this

  # ----------------------------------------------------------------------------------------------------------------
  # 
  # We re-render everything here since these Panels tend to have dynamic info on 'em
  #
  initialize: ()->

    super

    this.addInfo()

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (evt)->

    super

    if @shouldInitOnNetworkChange
      this.addInfo(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()-> {}

  # ----------------------------------------------------------------------------------------------------------------
  addInfo: (animateFlag = false)->

    duration = 250

    fn = ()=>
      this.removeChildren()

      if (labelSections = @fn_getText?())?
        this.addChildren(this.createLabelItems(labelSections))

      if animateFlag
        this.animate({opacity: 1, duration: duration})

      null

    # Animate out gracefully if there's text already on display
    if animateFlag
      this.animate({opacity: 0, duration: duration}, (e)=>fn(duration))
    else
      fn()

    this

  # ----------------------------------------------------------------------------------------------------------------
  labelViewOptions: ()-> 

    borderWidth: 1
    borderColor: null # Hy.UI.Colors.green @ 1.4.0

  # ----------------------------------------------------------------------------------------------------------------
  labelOptions: ()-> 
    top:    UtilityPanelBase.kPadding
    left:   UtilityPanelBase.kPadding
    right:  UtilityPanelBase.kPadding
    height: 'auto'
    font:   Hy.UI.Fonts.specSmallNormal
    zIndex: this.getUIProperty("zIndex")-1
    color: Hy.UI.Colors.black
    _tag: "UtilityTextPanel"
    borderWidth: 0
#    borderColor: Hy.UI.Colors.yellow

  # ----------------------------------------------------------------------------------------------------------------
  createLabelItems: (labelSpecs)->
    labelItems = (for labelSpec in labelSpecs
      new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(this.labelOptions(), labelSpec.options, {text: labelSpec.text})))

    labelItems

# ==================================================================================================================
OptionPanels = 
  kButtonHeight:      53
  kButtonWidth:       53

  kPadding:            5

  kLabelWidth:       120

  kPanelHeight:       60

  kPanelWidthSmall:  120
  kPanelWidthLarge:  250

  # ----------------------------------------------------------------------------------------------------------------
  createSoundPanel: (page, options = {}, labelOptions = {}, choiceOptions = {})->

    defaultLabelOptions =
      width: 100
      text: "Sound"
      _attach: "left"
      _padding: OptionPanels.kPadding
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth
      color: Hy.UI.Colors.white # Important to specify this here

    _buttons = [
      {_value: "on"}
      {_value: "off"}
    ]

    defaultChoiceOptions = 
      _style: "round"
      _size: "small"
      _buttons: _buttons
      _appOption: Hy.Options.sound
      _state: "toggle"

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250
      _tag: "Sound Toggle Options"

    new Hy.UI.OptionsList(page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), Hy.UI.ViewProxy.mergeOptions(defaultLabelOptions, labelOptions), Hy.UI.ViewProxy.mergeOptions(defaultChoiceOptions, choiceOptions), stackingOptions)

  # ----------------------------------------------------------------------------------------------------------------
  createNumberOfQuestionsPanel: (page, options = {})->

    labelOptions =
      text: "Number Of Questions"
      _attach: "left"
      _padding: OptionPanels.kPadding
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth
      color: Hy.UI.Colors.white # Important to specify this here

    _buttons = [
      {_value: 5},
      {_value: 10},
      {_value: 20},
      {_value: -1, _text: "50"}
    ]

    choiceOptions = 
      _style: "round"
      _size: "small"
      _buttons: _buttons
      _appOption: Hy.Options.numQuestions
      _state: "toggle"

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250 + 15 # Add room for caveat
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1

    panel = new Hy.UI.OptionsList(page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, choiceOptions, stackingOptions)

    # Caveat re: #of questions
    caveatOptions = 
      text: "Max\n#{Hy.Config.Dynamics.maxNumQuestions}"
      right: 0
      top: 0
      height: OptionPanels.kButtonHeight
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyNormal, {fontSize: 14})
      textAlign: "center"
#      borderColor: Hy.UI.Colors.white
#      borderWidth: 1

    panel.addChild(new Hy.UI.LabelProxy(caveatOptions))

    panel

  # ----------------------------------------------------------------------------------------------------------------
  createSecondsPerQuestionPanel: (page, options = {})->

    labelOptions =
      _attach: "left"
      _padding: OptionPanels.kPadding
      text: "Time Per Question"
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth
      color: Hy.UI.Colors.white # Important to specify this here

    # This is sub-optimal
    _buttons = [
      {_value: 10, _text: "10 seconds"}
      {_value: 15, _text: "15 seconds"}
      {_value: 20, _text: "20 seconds"}
      {_value: 30, _text: "30 seconds"}
      {_value: 45, _text: "45 seconds"}
      {_value: 60, _text: "1 minute"}
      {_value: 90, _text: "1 min 30 sec"}
      {_value: 120, _text: "2 minutes"}
      {_value: 150, _text: "2 min 30 sec"}
      {_value: 180, _text: "3 minutes"}
      {_value: 210, _text: "3 min 30 sec"}
      {_value: 240, _text: "4 minutes"}
      {_value: 270, _text: "4 min 30 sec"}
      {_value: 300, _text: "5 minutes"}
      {_value: 360, _text: "6 minutes"}
      {_value: 420, _text: "7 minutes"}
      {_value: 480, _text: "8 minutes"}
      {_value: 540, _text: "9 minutes"}
      {_value: 570, _text: "9 min 30 sec"}
    ]

    choiceOptions = 
      _style: "round"
      _size: "small"
      _buttons: _buttons
      width: OptionPanels.kButtonWidth # NEED THIS FOR NOW - SEEMS REDUNDANT
      height: OptionPanels.kButtonHeight # NEED THIS FOR NOW - SEEMS REDUNDANT
      _appOption: Hy.Options.secondsPerQuestion

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250
      _tag: "Seconds per Question Toggle Options"

    new Hy.UI.OptionsSelector(page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, choiceOptions, stackingOptions)

  # ----------------------------------------------------------------------------------------------------------------
  createFirstCorrectPanel: (page, options = {})->

    labelOptions =
      text: "First Correct Answer Wins"
      _attach: "left"
      _padding: OptionPanels.kPadding
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth
      color: Hy.UI.Colors.white # Important to specify this here

    _buttons = [
      { _value: "yes"}
      { _value: "no"}
    ]

    choiceOptions = 
      _style: "round"
      _size: "small"
      _buttons: _buttons
      _appOption: Hy.Options.firstCorrect
      _state: "toggle"

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250
      _tag: "First Correct Toggle Options"

    new Hy.UI.OptionsList(page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, choiceOptions, stackingOptions)

  # ----------------------------------------------------------------------------------------------------------------
  createUserCreatedContentInfoPanel2: (page, options = {})->

    labelOptions =
      text: "Custom Trivia Packs"
      _attach: "left"
      _padding: OptionPanels.kPadding
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth
      color: Hy.UI.Colors.black

    fnClick = (action)=>
      if page.isPageEnabled()
        page.getApp().userCreatedContentAction(action)
      null

    _buttons = [
      { _value: Hy.Config.Content.kThirdPartyContentNewText,  _fnCallback: (evt, view)=>fnClick("add")},
      { _value: Hy.Config.Content.kThirdPartyContentInfoText, _fnCallback: (evt, view)=>fnClick("info")}      
    ]

    if not Hy.Config.Commerce.kPurchaseTEST_dontShowBuy
      _buttons.push { _value: Hy.Config.Content.kThirdPartyContentBuyText,  _fnCallback: (evt, view)=>fnClick("upsell")}

    choiceOptions = 
      _style: "round"
      _size: "small"
      _buttons: _buttons

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250
      _tag: "createUserCreatedContentInfoPanel2"

    new Hy.UI.OptionsList(page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, choiceOptions, stackingOptions)

# ==================================================================================================================
class ContentView extends Hy.UI.ViewProxy

  @kVerticalPadding =  3
  @kHorizontalPadding = 5

  @kSummaryHeight = @kNameHeightDefault = 60

  @kInfoArrowWidth = 40
  @kInfoArrowHeight = 40

  @kDifficultyWidth = @kIconWidth =  @kIconHeight = 33
  @kDifficultyHeight = 15

  @kBuyWidth = @kBuyHeight = @kSelectedHeight = @kSelectedWidth = @kResetWidth = @kResetHeight = 40

  @kPriceHeight = @kDescriptionHeight = @kUsageHeight = 30

  @kPriceWidth = @kUsageWidth = 70

  @kUCCDetailsHeight = 55
  @kUCCDetailsWidth = 150

  gInstances = []

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@page, options, @contentOptionsPanel, @contentPack)->

    gInstances.push this

    @buyButton = null
    @hasUsage = false
    @usage = null
    @usageInfoView = null

    @selectedIndicatorHandlerIndex = null
    @resetButtonHandlerIndex = null

    defaultOptions =
      borderColor:  @borderColor = null # Hy.UI.Colors.white # 1.4.0
      borderWidth:  @borderWidth = 0

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this.update()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getPage: ()-> @page
  # ----------------------------------------------------------------------------------------------------------------
  @getInstances: (contentPack = null)->

    if contentPack?
      _.select(gInstances, (v)=>v.getContentPack() is contentPack)
    else
      gInstances

  # ----------------------------------------------------------------------------------------------------------------
  # Call this when done with this view, so we can clean up event handlers, etc
  #
  done: ()->

    this.removeSelectedClickHandler()

    gInstances = _.without(gInstances, this)

    null

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->

    options=
      left: 0
#      backgroundImage: Hy.UI.Backgrounds.pixelOverlay      
      borderRadius:16


  # ----------------------------------------------------------------------------------------------------------------            
  update: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  finishUpdate: ()->

    if @usage?
      @hasUsage = true

    this.renderAsAppropriate()

  # ----------------------------------------------------------------------------------------------------------------
  renderAsAppropriate: (contentPack = this.getContentPack()) ->

    for contentView in ContentView.getInstances(contentPack)
      contentView.renderAsAppropriate_()
    this

  # ----------------------------------------------------------------------------------------------------------------
  renderAsAppropriate_: (readyToPlay = [], readyToBuy = [])->

    fnShow = (views)=> view?.show() for view in views
    fnHide = (views)=> view?.hide() for view in views

    if this.getContentPack().isReadyForPlay()

      fnShow(readyToPlay)
      fnHide(readyToBuy)

      @selectedIndicatorView?.setSelected(this.getContentPack().isSelected())

    else

      fnShow(readyToBuy)
      fnHide(readyToPlay)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getContentPack: ()-> @contentPack

  # ----------------------------------------------------------------------------------------------------------------
  createIcon: (options = {})->

    iconView = null

    if (icon = this.getContentPack().getIcon())?

      defaultOptions = 
        height: ContentView.kIconHeight
        width: ContentView.kIconWidth
        image: icon.getPathname()
        borderColor: @borderColor
        borderWidth: @borderWidth

      iconView = new Hy.UI.ImageViewProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

    iconView

  # ----------------------------------------------------------------------------------------------------------------
  createDifficulty: (options = {}, longForm = false)->

    defaultOptions = 
      text: this.getContentPack().getDifficultyDisplay(longForm)
      font: Hy.UI.Fonts.specTinyCode
      color: Hy.UI.Colors.white
      textAlign: 'center'
      height: ContentView.kDifficultyHeight
      width: ContentView.kDifficultyWidth
      borderColor: @borderColor
      borderWidth: @borderWidth

    new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

  # ----------------------------------------------------------------------------------------------------------------
  createName: (options = {})->

    font = if true #this.getContentPack().isThirdParty() 
      Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specSmall, {fontSize: 20})
    else 
      Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specSmallMrF, {fontSize: 21})

    defaultOptions = 
#      text: "12345678901234567890123456789012345678901234567890" #this.getContentPack().getDisplayName()
      text: this.getContentPack().getDisplayName()
      font: font
      color: if this.getContentPack().isThirdParty() then Hy.UI.Colors.white else Hy.UI.Colors.MrF.DarkBlue
#      textAlign: 'left'
      textAlign: 'center'
      height: ContentView.kNameHeightDefault
      borderColor: @borderColor
      borderWidth: @borderWidth

    new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

  # ----------------------------------------------------------------------------------------------------------------
  createDescription: (options={})->

    # Ensure compatibility with pre-1.3 installations
    if not (description = this.getContentPack().getLongDescriptionDisplay())?
      description = this.getContentPack().getDescription()

#    description = "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345"

    defaultOptions = 
      text: description
      font: Hy.UI.Fonts.specTinyNormalNoBold
      color:Hy.UI.Colors.white
      textAlign:'left'
      height: ContentView.kDescriptionHeight
      borderColor: @borderColor
      borderWidth: @borderWidth

    new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

  # ----------------------------------------------------------------------------------------------------------------
  getBuyButton: ()-> @buyButton

  # ----------------------------------------------------------------------------------------------------------------
  createBuy: (options = {})->

    kBuyButtonHeight = 40
    kBuyButtonWidth = 40

    buttonOptions = 
      title: "Buy"
      _style: "round"
      _size: "tiny"
      _tag: "Buy Button for #{this.getContentPack().getDisplayName()}"
      height: kBuyButtonHeight
      width: kBuyButtonWidth

    @buyButton = new Hy.UI.ButtonProxy(buttonOptions)

    fnBuy = (e, view)=>
      if @buyButtonClicked? # 2.5.0
        Hy.Trace.debug "ContentView::createBuy (ignoring - buy already in progress..)"
        null
      else
        @buyButtonClicked = true
        Hy.Trace.debug "ContentView::createBuy (preparing for \"doBuy\"...)"
        @contentOptionsPanel.doBuy(this.getContentPack(), "ContentList")
        @buyButtonClicked = null
      null

    @buyButton.addEventListener("click", fnBuy)

    containerOptions = 
      width: ContentView.kBuyWidth
      height: ContentView.kBuyHeight

    buyContainer = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(containerOptions, options))

    buyContainer.addChild(@buyButton)

    this.enableBuy()

    buyContainer

  # ----------------------------------------------------------------------------------------------------------------
  createPrice: (options= {})->

    kPriceLabelWidth = 70

#    if (price = "1234567")?

    if (price = this.getContentPack().getDisplayPrice())?
      priceOptions = 
        text: price
        font: Hy.UI.Fonts.specTinyCode
        color: Hy.UI.Colors.white
        textAlign:'center'
        height: ContentView.kPriceHeight
        width: kPriceLabelWidth
  
      priceLabel = new Hy.UI.LabelProxy(priceOptions)

      containerOptions = 
        height: ContentView.kPriceHeight
        width: ContentView.kPriceWidth
        borderColor: @borderColor
        borderWidth: @borderWidth

      priceContainer = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(containerOptions, options))
      priceContainer.addChild(priceLabel)

      priceContainer        

    else
      null
    
  # ----------------------------------------------------------------------------------------------------------------
  disableBuy: ()->

    @buy?.setEnabled(false)

  # ----------------------------------------------------------------------------------------------------------------
  enableBuy: ()->

    @buy?.setEnabled(true)

  # ----------------------------------------------------------------------------------------------------------------
  getInfoArrowButton: ()-> @infoArrowButton

  # ----------------------------------------------------------------------------------------------------------------
  createInfoArrow: (options = {})->

    buttonOptions = 
      backgroundImage: "assets/icons/arrow-right-blue.png"
      width: ContentView.kInfoArrowWidth,
      height: ContentView.kInfoArrowHeight
      _tag: "Info Arrow Button for #{this.getContentPack().getDisplayName()}"

    buttonOptions = 
      _symbol: "rightArrow"
      _size: "tiny"
      _style: "round"
      _tag: "Info Arrow Button for #{this.getContentPack().getDisplayName()}"

    defaultContainerOptions = 
      _verticalLayout: "distribute"
      _tag: "Info Arrow Button Container for #{this.getContentPack().getDisplayName()}"
      borderColor: @borderColor
      borderWidth: @borderWidth
      width: ContentView.kInfoArrowWidth
      height: ContentView.kInfoArrowHeight

    container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(defaultContainerOptions, options))
    container.addChild(@infoArrowButton = new Hy.UI.ButtonProxy(buttonOptions))

    fnClick = (e, v)=>
      if @infoArrowClicked?  # 2.5.0
        null
      else
        @infoArrowClicked = true
        @contentOptionsPanel.showContentOptions(this.getContentPack())
        @infoArrowClicked = null
      null

    @infoArrowButton.addEventListener("click", fnClick)

    container

  # ----------------------------------------------------------------------------------------------------------------
  createSelectedIndicator: (options = {})->

    kCheckImageWidth = kCheckImageHeight = 40
    buttonOptions = 
      _symbol: "check"
      _size: "tiny"
      _style: "round"
#      width: kCheckImageWidth,
#      height: kCheckImageHeight

    @selectedIndicatorView = new Hy.UI.ButtonProxyWithState(buttonOptions)

    containerOptions = 
      width: ContentView.kSelectedWidth
      height: ContentView.kSelectedHeight
      borderColor: @borderColor
      borderWidth: @borderWidth

    container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(containerOptions, options))
    container.addChild(@selectedIndicatorView)

    this.addSelectedClickHandler()

    container

  # ----------------------------------------------------------------------------------------------------------------
  addSelectedClickHandler: ()->

    fnHandler = (e, view)=>
      this.toggleSelected()
      null

    this.removeSelectedClickHandler()

    if @selectedIndicatorView?
      @selectedIndicatorHandlerIndex = @selectedIndicatorView.addEventListener("click", fnHandler)
  
    this

  # ----------------------------------------------------------------------------------------------------------------
  removeSelectedClickHandler: ()->

    if @selectedIndicatorHandlerIndex?
      @selectedIndicatorView?.removeEventListenerByIndex(@selectedIndicatorHandlerIndex)
      @selectedIndicatorHandlerIndex = null

    this    

  # ----------------------------------------------------------------------------------------------------------------
  updateUsage: ()->

    if @hasUsage
      if @usage? and (u = this.getUsageText())?
        @usageLabel?.setUIProperty("text", u)
      else
        @fnCreateUsage?()
        @fnAddUsage?()

      this.renderAsAppropriate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getUsageText: ()->

    usage = if (u = @contentPack.getUsage())?
      u = Math.round(u*100)

      "#{u}%\nPlayed"
    else
      null

    usage
  # ----------------------------------------------------------------------------------------------------------------
  createUsage: (options= {})->

    kUsageLabelWidth = ContentView.kUsageWidth

    if (usage = this.getUsageText())

      usageOptions = 
        text: usage
        font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyCode, {fontSize:12})
        color: Hy.UI.Colors.white
        textAlign:'center'
        height: ContentView.kUsageHeight
        width: kUsageLabelWidth
  
      @usageLabel = new Hy.UI.LabelProxy(usageOptions)

      containerOptions = 
        height: ContentView.kUsageHeight
        width: ContentView.kUsageWidth
        borderColor: @borderColor
        borderWidth: @borderWidth

      usageContainer = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(containerOptions, options))
      usageContainer.addChild(@usageLabel)

      usageContainer        

    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  createReset: (options= {})->

    kCheckImageWidth = kCheckImageHeight = 40
    buttonOptions = 
      _style: "plainOnDarkBackground"
      title: "Reset"
      width: kCheckImageWidth,
      height: kCheckImageHeight
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyCode, {fontSize:10})

    buttonOptions = 
      title: "Reset"
      _style: "round"
      _size: "tiny"
      font: Hy.UI.ButtonProxy.mergeDefaultFont({fontSize:10}, "tiny")

    @resetButtonView = new Hy.UI.ButtonProxy(buttonOptions)

    containerOptions = 
      width: ContentView.kResetWidth
      height: ContentView.kResetHeight
      borderColor: @borderColor
      borderWidth: @borderWidth

    container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(containerOptions, options))
    container.addChild(@resetButtonView)

    this.addResetClickHandler()

    container

  # ----------------------------------------------------------------------------------------------------------------
  addResetClickHandler: ()->

    fnHandler = (e, view)=>
      this.getContentPack().resetUsage()
      this.updateUsage()
      null

    this.removeResetClickHandler()

    if @resetButtonView?
      @resetButtonHandlerIndex = @resetButtonView.addEventListener("click", fnHandler)
  
    this

  # ----------------------------------------------------------------------------------------------------------------
  removeResetClickHandler: ()->

    if @resetButtonHandlerIndex?
      @resetButtonView?.removeEventListenerByIndex(@resetButtonHandlerIndex)
      @resetButtonHandlerIndex = null

    this    

  # ----------------------------------------------------------------------------------------------------------------
  # Toggle selected state and update all contentViews
  #
  toggleSelected: ()->

    fn_getSelectedContentPacks = ()=>
      _.select(Hy.Content.ContentManager.get().getLatestContentPacksOKToDisplay(), (c)=>c.isSelected())
    fn_toggleContentPack = (contentPack)=>
      contentPack.toggleSelected()
      this.renderAsAppropriate(contentPack)
      null

    fn_toggleContentPacks = (contentPacks)=>
       for contentPack in contentPacks
         fn_toggleContentPack(contentPack)
       null

    if (contentPack = this.getContentPack()).isReadyForPlay()

      # Either of the following must be true
      #
      # 1: If more than one content pack is selected, none are customized
      # 2: If a customized content pack is selected, it is the only selected content pack
      # 

      nextCustomization = null

      selectedContentPacks = fn_getSelectedContentPacks()

      toBeToggled = []
      toBeToggled.push(contentPack)

      if (not contentPack.isSelected())

        # Here means our content pack needs to be selected
        if (nextCustomization = contentPack.getCustomization())?
          # Unselect all selected
          toBeToggled = toBeToggled.concat(selectedContentPacks)
        else
          # Unselect all selected, customized
          toBeToggled = toBeToggled.concat(_.select(selectedContentPacks, (c)=>c.hasCustomization()))

      fn_toggleContentPacks(toBeToggled)

      Hy.Customize.activate(nextCustomization, {page: Hy.Pages.PageState.ContentOptions})

    this

  # ----------------------------------------------------------------------------------------------------------------
  createUCCDetails: (containerOptions = {}, labelOptions = {})->

    container = null
    defaultLabelHeight = 15

    if (contentPack = this.getContentPack()).isThirdParty()

      defaultContainerOptions = 
        height: ContentView.kUCCDetailsHeight
        width: ContentView.kUCCDetailsWidth
        borderColor: @borderColor
        borderWidth: @borderWidth
        _verticalLayout: "distribute"
        _margin: 0

      container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(defaultContainerOptions, containerOptions))

      font = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyNormalNoBold, {fontSize: 11})
      defaultLabelOptions = 
        font: font
        color: Hy.UI.Colors.white
        textAlign:'center'
        left: 0
        height: defaultLabelHeight
        width: ContentView.kUCCDetailsWidth
        borderColor: @borderColor
        borderWidth: @borderWidth

      labelsOptions = []
      labelsOptions.push {text: "Custom Trivia Pack"}
      labelsOptions.push {text: "# of Questions: #{contentPack.getNumRecords()}"}

      if (t = contentPack.getAuthorVersionInfo())?
        labelsOptions.push {text: "Version: #{t}"}

      for options in labelsOptions
        container.addChild(c = new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultLabelOptions, labelOptions, options)))

    container

# ==================================================================================================================
# 
class ContentViewSummary extends ContentView

  # ----------------------------------------------------------------------------------------------------------------
  @getHeight: ()->

    ContentView.kVerticalPadding + ContentView.kSummaryHeight + ContentView.kVerticalPadding

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options, contentOptionsView, contentPack)->

    defaultOptions = 
      _tag: "ContentViewSummary #{contentPack.getDisplayName()}"
      height: ContentViewSummary.getHeight()

    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), contentOptionsView, contentPack

    this

  # ----------------------------------------------------------------------------------------------------------------
  update: ()->

    super

    this.removeChildren()

    vOptions = 
      top: 0
      left: ContentView.kHorizontalPadding
      height: ContentViewSummary.getHeight()
      width: Math.max(ContentView.kIconWidth, ContentView.kDifficultyWidth)
      borderColor: null # Hy.UI.Colors.white # 1.4.0
      borderWidth: @borderWidth
      _verticalLayout: "distribute"

    this.addChild(v1 = new Hy.UI.ViewProxy(vOptions))
    v1?.addChild(@icon = this.createIcon({left: 0}))
    v1?.addChild(@difficulty = this.createDifficulty({left: 0}))

    this.addChild((arrow = this.createInfoArrow({right: ContentView.kHorizontalPadding})), false, {_verticalLayout: "distribute"})

    buyOrSelectOptions = 
      right: ContentView.kHorizontalPadding + arrow.getUIProperty("width") + ContentView.kHorizontalPadding

    @selectedIndicator = this.createSelectedIndicator(buyOrSelectOptions)
    @buy = this.createBuy(buyOrSelectOptions)

    this.addChild(@selectedIndicator, false, {_verticalLayout: "distribute"})
    this.addChild(@buy, false, {_verticalLayout: "distribute"})
    h = Math.max(@selectedIndicator.getUIProperty("height"), @buy.getUIProperty("height"))

    nameOptions = 
     left: ContentView.kHorizontalPadding + v1.getUIProperty("width") + ContentView.kHorizontalPadding
     right: ContentView.kHorizontalPadding + arrow.getUIProperty("width") + ContentView.kHorizontalPadding + h + ContentView.kHorizontalPadding

    this.addChild((@name = this.createName(nameOptions)), false, {_verticalLayout: "distribute"})

    this.finishUpdate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  renderAsAppropriate_: ()->

    readyToPlay    = [@selectedIndicator]
    readyToBuy     = [@buy]

    super(readyToPlay, readyToBuy)

    this

# ==================================================================================================================
# 
class ContentViewDetailed extends ContentView

  # ----------------------------------------------------------------------------------------------------------------
  @getHeight: ()->

    200

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options, contentOptionsView, contentPack)->

    defaultOptions = 
      _tag: "ContentViewDetailed #{contentPack.getDisplayName()}"
      width: contentOptionsView.getNavGroup().getButtonWidth() # Relies on navGroup already existing, obviously
      height: ContentViewDetailed.getHeight()

    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), contentOptionsView, contentPack

    this

  # ----------------------------------------------------------------------------------------------------------------
  update: ()->

    super

    this.removeChildren()

    c = []

    spacing = 3
    margin = 5
    containerHeight = this.getUIProperty("height")
    containerWidth = this.getUIProperty("width")

    top = margin

    rowZeroHeight = 50
    rowTwoHeight = ContentView.kUCCDetailsHeight
    rowOneHeight = ContentViewDetailed.getHeight() - (rowZeroHeight + rowTwoHeight + (2 * spacing) + (2 * margin))

    # Row 0: "name" centered across entire width
    nameOptions = 
      top: top
      height: rowZeroHeight
      width: containerWidth - (2 * margin)
      left: margin
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specSmall, {fontSize: 19})
      textAlign: 'center'
    c.push @name = this.createName(nameOptions)
    top += rowZeroHeight + spacing

    # Row 1: "description", full-width
    font = Hy.UI.Fonts.cloneFont(Hy.UI.Fonts.specTinyNormal)
    font.fontSize = 15

    descriptionInnerMargin = 5
    descriptionOptions = 
      top: top
      right: margin
      left: margin
      height: rowOneHeight
      font: font
    c.push @description = this.createDescription(descriptionOptions)
    top += rowOneHeight + spacing

    # Row 2: 
    # Icon/Difficulty vertically stacked, horizontally centered across entire width.
    # "uccDetails" hugging the left.
    # "selected" hugging the right
    # "usageinfo" between Icon/Difficulty and "selected"
    #
    rowTwoOptions = 
      top: top
      width: containerWidth
      height: rowTwoHeight
      _verticalLayout: "center"
    c.push rowTwoView = new Hy.UI.ViewProxy(rowTwoOptions)
    top += rowTwoHeight + spacing

    # Starting on the right, add "selected"
    rowTwoView.addChild(@selectedIndicator = this.createSelectedIndicator({right: margin}))

    # In the middle: a stack o' icon and difficulty
    iconDifficultyStackOptions = 
      top: 0
      width: Math.max(ContentView.kIconHeight, ContentView.kDifficultyHeight)
      height: rowTwoHeight
      _verticalLayout: "distribute"
    iconDifficultyStackView = new Hy.UI.ViewProxy(iconDifficultyStackOptions)

    iconDifficultyStackView.addChild(@icon = this.createIcon())
    iconDifficultyStackView.addChild(@difficulty = this.createDifficulty())
    rowTwoView.addChild(iconDifficultyStackView, false, {_horizontalLayout: "center"})

    @usageInfoView = null
    @fnCreateUsage = ()=>this.createUsage({right: spacing})
    @fnAddUsage = ()->if @usage? then @usageInfoView?.addChild(@usage) else null

    # Then add usage info, between it and the "selected" button
    if this.getContentPack().isEntitled() and (@usage = @fnCreateUsage())?

      reset = this.createReset({left: spacing})

      width = @usage.getUIProperty("width") + reset.getUIProperty("width") + (3*spacing)

      r_selectedIndicator = @selectedIndicator.getUIProperty("right")
      w_selectedIndicator = @selectedIndicator.getUIProperty("width")
      right = (((iconDifficultyStackView.getUIProperty("right") - (r_selectedIndicator + w_selectedIndicator)) - width)/2) + r_selectedIndicator + w_selectedIndicator

      usageInfoOptions = 
        top: 0
        height: rowTwoHeight
        right: right
        width: width
        borderColor: @borderColor
        borderWidth: @borderWidth

      rowTwoView.addChild(@usageInfoView = new Hy.UI.ViewProxy(usageInfoOptions))

      @fnAddUsage()
      @usageInfoView.addChild(reset)

    # Finish with "uccInfo", on the far left
    if @contentPack.isThirdParty()
      font2 = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyNormal, {fontSize: 14})

      rowTwoView.addChild(@uccDetails = this.createUCCDetails({left: margin}, {font: font2}))

    this.addChildren(c)

    this.finishUpdate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  update2: ()->

    super

    this.removeChildren()

    c = []

    spacing = 3
    margin = 5
    containerHeight = this.getUIProperty("height")
    containerWidth = this.getUIProperty("width")

    top = margin

    rowZeroHeight = 50
    rowTwoHeight = ContentView.kUCCDetailsHeight
    rowOneHeight = ContentViewDetailed.getHeight() - (rowZeroHeight + rowTwoHeight + (2 * spacing) + (2 * margin))

    # Row 0: "icon"/"difficulty" stacked in a column on the left, and "name" on the right
    rowZeroLeftColumnOptions = 
      top: top
      left: margin
      width: rowZeroLeftColumnWidth = Math.max(ContentView.kIconHeight, ContentView.kDifficultyHeight)
      height: rowZeroHeight
      _verticalLayout: "distribute"
    c.push rowZeroLeftColumnView = new Hy.UI.ViewProxy(rowZeroLeftColumnOptions)

    rowZeroLeftColumnView.addChild(@icon = this.createIcon())
    rowZeroLeftColumnView.addChild(@difficulty = this.createDifficulty())

    nameOptions = 
      top: top
      height: rowZeroHeight
      width: nameWidth = containerWidth - (rowZeroLeftColumnWidth + (2 * margin) + spacing)
      right: margin
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specSmall, {fontSize: 19})
      textAlign: 'center'
    c.push @name = this.createName(nameOptions)
    top += rowZeroHeight + spacing

    # Row 1: "description", full-width
    font = Hy.UI.Fonts.cloneFont(Hy.UI.Fonts.specTinyNormal)
    font.fontSize = 15

    descriptionInnerMargin = 5
    descriptionOptions = 
      top: top
      right: margin
      left: margin
      height: rowOneHeight
      font: font
    c.push @description = this.createDescription(descriptionOptions)
    top += rowOneHeight + spacing

    # Row 2: "usage", "uccDetails", and "selected", vertical centers aligned.
    # "usage" and "selected" hug the sides, "uccDetails" is centered horizontally
    rowTwoOptions = 
      top: top
      width: containerWidth
      height: rowTwoHeight
      _verticalLayout: "center"
    c.push rowTwoView = new Hy.UI.ViewProxy(rowTwoOptions)
    top += rowTwoHeight + spacing

    rowTwoView.addChild(@selectedIndicator = this.createSelectedIndicator({right: margin}))

    if this.getContentPack().isEntitled()
      if (@usage = this.createUsage({left: margin}))?
        rowTwoView.addChild(@usage)

    if @contentPack.isThirdParty()
      font2 = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyNormal, {fontSize: 14})

      rowTwoView.addChild(@uccDetails = this.createUCCDetails({}, {font: font2}), false, {_horizontalLayout: "center"})

    this.addChildren(c)

    this.finishUpdate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  renderAsAppropriate_: ()->

    readyToPlay    = [@selectedIndicator]
    readyToBuy     = []

    super(readyToPlay, readyToBuy)

    this

# ==================================================================================================================
# 
class ContentPackList extends Hy.UI.ScrollOptions

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@contentOptionsPanel, page, options={}, labelOptions = {}, scrollOptions = {}, childViewOptions = {}, arrowsOptions, fnReInitViewsFired = null)->

    defaultOptions = 
      _tag: "Content Options"
#      borderColor: Hy.UI.Colors.yellow
#      borderWidth: 1

    defaultScrollOptions = 
      _padding: 3
      _orientation: "vertical"
      _rowHeight: this.getContentViewHeight()
      _divider: true
      _fnViews: ()=>this.getContentViews()

    combinedScrollOptions = Hy.UI.ViewProxy.mergeOptions(defaultScrollOptions, scrollOptions)

    # We handle various events here: buy, more info, and select
    # UPDATE: not any more... moved to handlers on the individual buttons

    fnTouchAndHold = (e, view)=>
      this.doTouchAndHold(e, view)

    fnClicked = (e, view)=>
      if view?
        if e.source?
          contentPack = view.contentPack

          fn = switch e.source
            when view.getBuyButton()?.getView()
              if contentPack?
                ()=>@contentOptionsPanel.doBuy(contentPack, "ContentList")
            when view.getInfoArrowButton()?.getView()
              if contentPack?
                ()=>@contentOptionsPanel.showContentOptions(contentPack)
              else
                null
            else
              view.toggleSelected()
              null

          if fn?
            Hy.Utils.Deferral.create(0, fn)

    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, combinedScrollOptions, childViewOptions, arrowsOptions, null, null, fnReInitViewsFired

    this

  # ----------------------------------------------------------------------------------------------------------------
  mapToGlobalCoords: (eventPoint, view)->

    windowView = @page.getWindow().getView()
    scrollView = this.getScrollView().getView()
    viewHeight = view.getUIProperty("height")

    # Regardless of where within the ContentView the user touched, we remap it to the extreme left, and halfway down,
    # the ContentView
    #
    newPoint = if eventPoint.y? and (c1 = view.getView().convertPointToView({x: 0, y: viewHeight/2}, scrollView))? and (c2 = scrollView.convertPointToView(c1, windowView))?
      c2
    else
      x: 0
      y: 0

    fnDumpPoint = (point)=> "(#{point.x},#{point.y})"

#    Hy.Trace.debug "ContentPackList::mapToGlobalCoords (view: #{fnDumpPoint({x: evt.x, y: evt.y})} scrollView: #{fnDumpPoint(c1)} windowView: #{fnDumpPoint(c2)})"

    newPoint

  # ----------------------------------------------------------------------------------------------------------------
  doTouchAndHold: (evt, view)->

    if (contentPack = view.contentPack)? and contentPack.isThirdParty() # HACK UNTIL WE ADD A DEDICATED UI ELEMENT
      @contentOptionsPanel.showContentOptions(contentPack)

    return this

    if (coord = this.mapToGlobalCoords({x: evt.x, y: evt.y}, view))? and (contentPack = view.contentPack)? and contentPack.isThirdParty()
      @page.getApp().userCreatedContentAction("selected", {contentPack: contentPack, coord: coord})

    this

  # ----------------------------------------------------------------------------------------------------------------
  reInitViews: (autoScroll = true)->

    super autoScroll

    if autoScroll
      this.scrollToSelectedContentPack()

    this    

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->

    {}

  # ----------------------------------------------------------------------------------------------------------------
  # We want to group all topics in a category together. We use the "icon" property as a proxy for "category".
  # Within a category, we sort by productId or by the "sort" property, if present.
  # We show custom content first.
  #
  getContentPacks: ()->

    result = []

    contentPacks = Hy.Content.ContentManager.get().getLatestContentPacksOKToDisplay()

    thirdPartyContentPacks = _.select(contentPacks, (c)=>c.isThirdParty())
    thirdPartyContentPacks = _.sortBy(thirdPartyContentPacks, (c)=>c.getDisplayName())
    result = result.concat(thirdPartyContentPacks)

    otherContentPacks = _.select(contentPacks, (c)=>not c.isThirdParty()) # 2.5.0
    otherContentPacks = _.sortBy(otherContentPacks, (c)=>c.getIconSpec())

    groupSpecs = []
    for c in otherContentPacks
      if not (groupSpec = _.detect(groupSpecs, (g)=>g.iconSpec is c.getIconSpec()))?
        groupSpecs.push (groupSpec = {iconSpec: c.getIconSpec(), contentPacks: []})
      groupSpec.contentPacks.push c

    for groupSpec in groupSpecs

      # Use of "sort" field is all or nothing... all packs must have a sort spec, otherwise ignore
      hasSort = not _.detect(groupSpec.contentPacks, (c)=>c.getSort() is -1)?

      for c in _.sortBy(groupSpec.contentPacks, (c)=>if hasSort then c.getSort() else c.getProductID()) # 2.5.0
        if c.isOKToDisplay()
          result.push c

    result

  # ----------------------------------------------------------------------------------------------------------------
  getContentViews: ()->

    contentViews = []

    for c in this.getContentPacks()
      if not this.findContentViewByContentPack(c)?
        contentViews.push new ContentViewSummary(this.getPage(), {}, @contentOptionsPanel, c)

    contentViews

  # ----------------------------------------------------------------------------------------------------------------
  getContentViewHeight: ()->

    ContentViewSummary.getHeight()

  # ----------------------------------------------------------------------------------------------------------------
  findContentViewByContentPack: (contentPack)->

    this.findViewByProperty("contentPack", contentPack)

  # ----------------------------------------------------------------------------------------------------------------
  scrollToSelectedContentPack: ()->

    index = -1
    for contentPack in this.getContentPacks()
      index++
      if contentPack.isSelected()
        this.makeViewVisible(index)
        return

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    this.scrollToSelectedContentPack()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  open: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  close: ()->

#    this.clearEventHandler() # 2.5.0 Where is this defined?

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->
    super

    # Update the %used info for each content pack
    this.applyToViews("updateUsage")

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    super
    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super
    this

# ==================================================================================================================
#
class ContentOptionsPanel extends Panel

  kBaseHeight = 400
  kBaseWidth = 440
  kArrowPadding = 50
  kContainerPadding = 5
  kPaddingHeight = 10 #20
  kPaddingWidth = 15


  @kHeight = kBaseHeight + (2*kArrowPadding)
  @kWidth =  kBaseWidth + (2*kContainerPadding)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, @parent, options)->

    @zIndex = Hy.Pages.Page.kPageContainerZIndex + 1

    @contentPackDetails = null # Set if we've generated a detail page for a content pack

    @navGroup = null
    @navGroupStarted = false
    @navViewWidth = kBaseWidth - (2*kPaddingWidth)
    @navViewHeight = kBaseHeight - (2*kPaddingHeight)

    @helpfulInfo = null

    defaultOptions = 
      height: ContentOptionsPanel.kHeight
      width:  ContentOptionsPanel.kWidth
      _tag: "ContentOptionsPanel"
#      borderColor: Hy.UI.Colors.blue
      borderWidth: 0
      zIndex: @zIndex

    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    arrowsOptions = 
      _parent: this
      left: kPaddingWidth + kContainerPadding
      top: 0
      bottom: 0

    @contentPackList = this.createContentPackList({width: @navViewWidth, height: @navViewHeight}, 
                                                  {width: @navViewWidth, height: @navViewHeight}, arrowsOptions)

    # Make sure to call "addNavGroup" once this view has been attached to a parent view
    this

  # ----------------------------------------------------------------------------------------------------------------
  getNumContentPacks: ()->
  
    numContentPacks = if @contentPackList?
      @contentPackList.getScrollView().getNumViews()
    else
      0

    numContentPacks
  
  # ----------------------------------------------------------------------------------------------------------------
  getPath: (path = [])->
    super [].concat("ContentList", path)

  # ----------------------------------------------------------------------------------------------------------------
  manageHelpfulInfo: (showInfo = (this.getNumContentPacks() is 0))->

    if showInfo
      if not @helpfulInfo?
        labelOptions = 
          top: kPaddingHeight
          left: kPaddingWidth
          width: @navViewWidth - (2*kPaddingWidth)
          height: @navViewHeight - (2*kPaddingHeight)
          text: "You have no Content! Tap \"Help\"#{if Hy.Update.SamplesUpdate.getSamplesUpdate()? then ", or to load Sample Contests, tap \"Samples\"" else ""}!"
          textAlign: 'center'
          font: Hy.UI.Fonts.specMediumMrF
          color: Hy.UI.Colors.white
#          zIndex: 10000000000
          _tag: "Helpful Info"
          borderColor: null # Hy.UI.Colors.green # 1.4.0
          borderWidth: 0
        Hy.Customize.mapOptions(["font"], this.getPath(), labelOptions)
        @helpfulInfo = new Hy.UI.LabelProxy(labelOptions)

      @contentPackList.addChild(@helpfulInfo)
       
    else
      if @helpfulInfo?
        @contentPackList.removeChild(@helpfulInfo)
      
    this
  
  # ----------------------------------------------------------------------------------------------------------------
  createContentPackList: (options, scrollOptions, arrowsOptions)->

    labelOptions = {}
    childViewOptions = {}

    defaultOptions =
      backgroundColor: Hy.UI.Colors.black

    combinedOptions = Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    defaultScrollOptions = {}

    combinedScrollOptions = Hy.UI.ViewProxy.mergeOptions(defaultScrollOptions, scrollOptions)

    new Hy.Panels.ContentPackList(this, @page, combinedOptions, labelOptions, combinedScrollOptions, childViewOptions, arrowsOptions, ()=>this.manageHelpfulInfo())

  # ----------------------------------------------------------------------------------------------------------------
  update: ()->

    @contentPackList.reInitViews()
    this.updateContentOptions()

    this
  # ----------------------------------------------------------------------------------------------------------------
  getNavGroup: ()-> @navGroup

  # ----------------------------------------------------------------------------------------------------------------
  addNavGroup: ()->

    navSpec = 
      _root: true
      _id: "ContentList"
      _backButton: "_none"
      _view: @contentPackList

    navGroupOptions = 
      top: kArrowPadding + kPaddingHeight
#      left: kPaddingWidth + kContainerPadding
      right: kPaddingWidth + kContainerPadding # 2.5.0
      width: @navViewWidth
      height: @navViewHeight
      borderWidth: 1
      _colorScheme: "black"

    navGroupOptions.borderColor = Hy.Customize.map("bordercolor", this.getPath(), Hy.UI.Colors.MrF.Gray) # ignore transparency
    navGroupOptions.borderWidth = 3

    # NavGroup's coordinate system is at the top-level. It's not added as a child of this view.
    # The below works because we assume that this panel is being added as a direct child of the page
    navGroupOptions.top += this.getUIProperty("top")
    navGroupOptions.right += this.getUIProperty("right")

    # 2.5.0: Titanium 3.1.3 deprecates iPhone.NavigationGroup... 
    # The replacement, iOS.NavigationWindow, is a top-level window
#    this.addChild(@navGroup = new Hy.UI.NavGroup(Hy.UI.ViewProxy.mergeOptions(defaultNavGroupOptions, options), navSpec)) 

    @navGroup = new Hy.UI.NavGroup(navGroupOptions, navSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  animate: (options)->

    @navGroup.animate(options)
    super options
    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    super

    Hy.Content.ContentManager.addObserver this
    Hy.Content.ContentManagerActivity.addObserver this

    if @navGroupStarted # 2.5.0
      if not @hackUpdate?
        @contentPackList.animate({opacity: 1, duration: 200})
        @hackUpdate = true
    else
      @navGroup.start()
      @navGroupStarted = true

    @contentPackList.start()

    this.manageHelpfulInfo()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this.manageHelpfulInfo(false)

    Hy.Content.ContentManager.removeObserver this
    Hy.Content.ContentManagerActivity.removeObserver this

#    @contentPackList.stop() # 2.5.0 Function doesn't do anything

    this.getNavGroup().dismiss(true, "_root")

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  open: ()->

    @navGroup.open() # 2.5.0
    @contentPackList.open()

    this

  # ----------------------------------------------------------------------------------------------------------------
  close: (options)-> # 2.5.0 added options

#    @contentPackList.close(options) # 2.5.0 Function doesn't do anything
    @navGroup.close(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    @contentPackList.initialize()

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    @contentPackList.pause()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super

    @contentPackList.resumed()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Note that contentPacks may have been updated, so we may be holding on to old versions...
  #
  obs_contentUpdateSessionCompleted: (report, changes)->

    if changes
      @contentPackList.reInitViews()
      this.updateContentOptions()

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryCompleted: (status, message)->

    if status
      @contentPackList.reInitViews()
      this.updateContentOptions()

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_purchaseInitiated: (label, report)->

#    @contentPackList.applyToViews("disableBuy")

  # ----------------------------------------------------------------------------------------------------------------
  obs_purchaseCompleted: (report)->

    @contentPackList.applyToViews("enableBuy")
    this.updateContentOptions()    

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_restoreInitiated: (report)->

    @contentPackList.applyToViews("disableBuy")

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_restoreCompleted: (report, changes = false)->

    Hy.Trace.debug "ContentOptionsPanel::obs_restoreCompleted (report=#{report}, changes=#{changes})"

    @contentPackList.applyToViews("enableBuy")

    if changes
      @contentPackList.reInitViews()
      this.updateContentOptions()

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_userCreatedContentSessionCompleted: (report = null, changes = false)->

    if changes
      @contentPackList.reInitViews(true) # Was "false" - why?
      this.updateContentOptions()

    null

  # --------------------------------------------------------------------------------------------------------------
  contentOptionsNavSpec: (contentPack)->

    fnMakeContext = (fnDone)=>
      context = 
        contentPack: contentPack
        navGroup: this.getNavGroup()
        fnDone: fnDone
        _dismiss: "ContentOptions"
      context

    fnUserCreatedContentAction = (action, fnDone)=>
      @page.getApp().userCreatedContentAction(action, fnMakeContext(fnDone))
      null

    fnDone = (context, status, navSpec, changes, target)=>
      if navSpec?
        navSpec._backButton = target
        context.navGroup.pushNavSpec(navSpec)   
      null

    fnDone1 = (context, status, navSpec, changes)=>
      fnDone(context, status, navSpec, changes, "ContentOptions")

    fnDone2 = (context, status, navSpec, changes)=>
      fnDone(context, status, navSpec, changes, "ContentList")

    fnBuy = (fnDone)=>
      if @buyButtonClicked? # 2.5.0
        Hy.Trace.debug "ContentOptionsPanel::contentOptionsNavSpec (ignoring - buy already in progress..)"
        null
      else
        @buyButtonClicked = true
        Hy.Trace.debug "ContentOptionsPanel::contentOptionsNavSpec (preparing for \"doBuy\"...)"
        this.doBuy(contentPack, "ContentOptions")
        @buyButtonClicked = null
      null

    buttonSpecs = []
    if contentPack.isThirdParty()
      if contentPack.isSelected()
        buttonSpecs.push {
          _value: "remove this Trivia Pack (unselect it first)", 
          _destructive: true, 
        }
      else
        buttonSpecs.push {
          _value: "remove this Trivia Pack", 
          _destructive: true, 
          _navSpec: 
            _title: "" #contentPack.getDisplayName() 
            _backButton: "_previous"
            _explain: "#{contentPack.getDisplayName()}\n\nAre you sure you want to remove this Trivia Pack?"
            _buttonSpecs: [
              {_value: "yes, remove it", _destructive: true, _navSpecFnCallback: (event, view, navGroup)=>fnUserCreatedContentAction("delete", fnDone2)}
              {_value: "cancel", _dismiss: "_previous", _cancel: true}
            ]
        }

      buttonSpecs.push {
        _value: "check for update", 
        _navSpecFnCallback: (event, view, navGroup)=>fnUserCreatedContentAction("refresh", fnDone1)}
    else if contentPack.showPurchaseOption()
      price = contentPack.getDisplayPrice() # May not have been inventoried yet. Stall.
      buttonSpecs.push {
        _value: "buy this Trivia Pack#{if price? then " for " + price else ""}", 
        _navSpecFnCallback: (event, view, navGroup)=>fnBuy(fnDone1)}

    contentInfoOptions = 
      borderColor: Hy.UI.Colors.MrF.Gray
      borderWidth: 1
      top: 5 # 0 # 2.5.0

    navSpec = 
      _id: "ContentOptions"
      _backButton: "ContentList"
      _title: "" #"1234567890123456789012345678901234567890" #contentPack.getDisplayName() # 2.5.0
      _view: (@contentPackDetails = new ContentViewDetailed(this.getPage(), contentInfoOptions, this, contentPack))
      _buttonSpecs: buttonSpecs
      _verticalLayout: "manual"

    navSpec

  # ----------------------------------------------------------------------------------------------------------------
  showContentOptions: (contentPack)->

    @contentPackList.setArrowsEnabled(false)

    this.getNavGroup().pushFnGuard(this,"viewDismiss", ()=>@contentPackList.setArrowsEnabled(true))
    this.getNavGroup().pushFnGuard(this,"viewDismiss", ()=>this.clearContentPackDetails())
    this.getNavGroup().pushFnGuard(this,"viewDismiss", ()=>this.manageHelpfulInfo())

    this.getNavGroup().pushNavSpec(this.contentOptionsNavSpec(contentPack))

    null

  # ----------------------------------------------------------------------------------------------------------------
  clearContentPackDetails: ()->

    @contentPackDetails?.done() # Removes event handler, etc
    @contentPackDetails = null

  # ----------------------------------------------------------------------------------------------------------------
  updateContentOptions: ()->

    if @contentPackDetails?

      contentPack = @contentPackDetails.getContentPack()

      this.clearContentPackDetails()

      # Make sure we have the latest version of the content pack in hand
      if (contentPack = Hy.Content.ContentPack.findLatestVersionOKToDisplay(contentPack.getProductID()))
        this.getNavGroup().replaceNavView(this.contentOptionsNavSpec(contentPack))

    null

  # ----------------------------------------------------------------------------------------------------------------
  doBuy: (contentPack, returnTarget)->

    contentView = @contentPackList.findContentViewByContentPack(contentPack)

    fnDoneBuy = (context, status, navSpec, changes)=>
      if navSpec?
        navSpec._backButton = returnTarget
        context.navGroup.pushNavSpec(navSpec)   

      contentView.enableBuy()
      contentView.renderAsAppropriate()

      if status
        contentView.toggleSelected()

      null

    contentView.disableBuy()

    @contentPackList.setArrowsEnabled(false)
    this.getNavGroup().pushFnGuard(this,"viewDismiss", ()=>@contentPackList.setArrowsEnabled(true))

    context = 
      contentPack: contentPack
      navGroup: this.getNavGroup()
      fnDone: fnDoneBuy

    status = Hy.Content.ContentManager.get().buyContentPack(context)
   
    status

# ==================================================================================================================
class WebViewPanel extends Panel

  gListeners = []
  gEventCount = 0
  gOutstandingEvents = []


  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options, @htmlOptions)->

    defaultOptions = 
       zIndex: Hy.Pages.Page.kWebViewZIndex
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 10

    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    @webView = null
    @webViewLoaded = false
    @fnLoaded = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  addWebView: ()->

    @webView = null
    @webViewLoaded = false

    this.initEventHandler()

    this.addChild(@webView = new Hy.UI.WebViewProxy(@htmlOptions))

    # Now we wait for pageLoaded event from the page

    this

  # ----------------------------------------------------------------------------------------------------------------
  event_pageLoaded: ()->

    Hy.Trace.debug "WebViewPanel::event_pageLoaded webViewLoaded=#{@webViewLoaded}"

    @webViewLoaded = true

    @fnLoaded?()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (@fnLoaded)->

    if not @webView?
      this.addWebView()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  @staticHandler: (instance, event)->
    Hy.Trace.debug "WebViewPanel::staticHandler #{event.kind}"
    instance.pageEventHandler(event)
    null

  # ----------------------------------------------------------------------------------------------------------------
  initEventHandler: ()->

#    Ti.App.addEventListener("_pageEventOut", (event)=>null) # Works
#    Ti.App.addEventListener("_pageEventOut", (event)=>this.pageEventHandler(event)) # not work
    instance = this
    Ti.App.addEventListener("_pageEventOut", (event)=>WebViewPanel.staticHandler(instance, event))
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  clearEventHandler: ()->

    # Not implemented

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Handler for outbound events (those coming from the html page)
  #
  pageEventHandler: (event)->

    Hy.Trace.debug "WebViewPanel::pageEventHandler (webView=#{@webView?} #{event._counter} #{event.kind} responseRequired=#{event._responseRequired})"

    if @webView?
      if event._responseRequired? and event._responseRequired
        if (pendingEvent = _.detect(gOutstandingEvents, (e)=>e.event._counter is event._counter))?
          Hy.Trace.debug "WebViewPanel::pageEventHandler (detected)"
          gOutstandingEvents = _.without(gOutstandingEvents, pendingEvent)
          pendingEvent.fnCompleted(event)
      else
        method = "event_#{event.kind}"
        if(fn = this[method])? and (typeof(fn) is "function")
          this[method](event.data)

    this

  # ----------------------------------------------------------------------------------------------------------------
  fireEvent: (event, fnCompleted = null)->
    event._counter = ++gEventCount

    if (event._responseRequired = (fnCompleted?))
      gOutstandingEvents.push {event: event, fnCompleted: fnCompleted}

    Hy.Trace.debug "WebViewPanel::fireEvent (FIRING #{event._counter} #{event.kind} responseRequired=#{event._responseRequired})"

    Ti.App.fireEvent("_PageEventIn", event)

    this

# ==================================================================================================================
class LabeledButtonPanel extends Panel

  kWidth = 150
  kHeight = 100
  kTextHeightRatio = 0.5
  kButtonImageWidth = 53

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {}, @buttonOptions = {}, @fnClicked = null, @topTextOptions = {}, @bottomTextOptions = {}) ->

    @defaultBorderWidth = 0

    defaultOptions =
      width: kWidth
      height: kHeight
      _tag: "LabeledButtonPanel"
      borderColor: Hy.UI.Colors.yellow
      borderWidth: @defaultBorderWidth

    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions,options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addInfo: (animatedFlag = false, enabled = true)->

    duration = 250

    fn = ()=>
      this.removeChildren()

      this.addTopText(@topTextOptions)
          .addButton(@buttonOptions, @fnClicked)
          .addBottomText(@bottomTextOptions)

      this.setEnabled(enabled)

      null

    if animatedFlag
      this.animate({opacity: 0, duration: duration}, (e)=>fn()) # Callback may not be fired if view isn't onscreen...!
    else
      fn()
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  # Presume that initialized state == enabled. Subclasses can change as necessary
  #
  initialize: (animatedFlag = false, enabled = true)->

    super

    this.addInfo(animatedFlag, enabled)

    this

  # ----------------------------------------------------------------------------------------------------------------
  createTextLabel: (options)->

    defaultTextOptions = 
      width: this.getUIProperty("width")
      height: this.getUIProperty("height")  * (1 - kTextHeightRatio) * .5
      font: Hy.UI.Fonts.specMinisculeNormal
      textAlign: 'center'
      borderColor: Hy.UI.Colors.white
      borderWidth: @defaultBorderWidth
      text: ""

    this.addChild(new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultTextOptions, options)))

    this 

  # ----------------------------------------------------------------------------------------------------------------
  addTopText: (options)->

    defaultOptions = 
      top: 0
      _tag: "Top Text"

    this.createTextLabel(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  addBottomText: (options)->

    defaultOptions = 
      bottom: 0
      _tag: "Bottom Text"

    this.createTextLabel(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  addButton: (options, fnClicked = null)->

    defaultOptions = 
      width: kButtonImageWidth
      height: this.getUIProperty("height") * kTextHeightRatio
      backgroundImage: "assets/icons/circle-black.png"
      backgroundSelectedImage: "assets/icons/circle-black-selected.png"
      borderColor: Hy.UI.Colors.white
      borderWidth: @defaultBorderWidth
      _tag: "Button"
      title: "?"
      font: Hy.UI.Fonts.specMinisculeNormal

    defaultOptions = 
      _style: "round"
      _size: "small"
      _tag: "Button"
      title: "?"

    this.addChild(@button = new Hy.UI.ButtonProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)))

    @button.addEventListener("click", ()=>fnClicked?()) 

    this

  # ----------------------------------------------------------------------------------------------------------------
  setEnabled: (enabled)->

    @button?.setEnabled(enabled)

    super enabled

    this

# ==================================================================================================================
class CodePanel extends LabeledButtonPanel

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options = {}, fnClicked = null)->

    defaultOptions = {}

#    url = Hy.Network.PlayerNetwork.getJoinSpecDisplayRendezvousURL() # HACK
    url = "joinCGPro.\nheroku.com"
    super page, Hy.UI.ViewProxy.mergeOptions(defaultOptions,options), {}, fnClicked, {text: url}, {text: "Tap for Info"}

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (evt)->

    super

    this.initialize(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addButton: (buttonOptions, fnClicked)->

    text = if Hy.Network.NetworkService.isOnline()
      joinSpec = Hy.Network.PlayerNetwork.getJoinSpec()
      switch Hy.Network.PlayerNetwork.getStatus()
        when "uninitialized", "initializing"
          "..."
        when "initialized"
          if joinSpec?
            joinSpec.displayCode
          else
            "?"
        else
          if joinSpec?
            joinSpec.displayCode
          else
            "?"
    else
      "no web"

    # Only display up to 7 characters
    if text.length > 7
      text = "!!!"

    # We want to take the default values from the font spec, and then change the font size a bit.
    # So we make a copy of the font spec first.
    defaultButtonOptions = 
      font: Hy.UI.Fonts.cloneFont(Hy.UI.Fonts.specMinisculeNormal)
      title: text

    defaultButtonOptions.font.fontSize = switch text.length
      when 1
        24
      when 2
        23
      when 3
        19
      when 4
        16
      when 5
        13
      when 6
        12
      else
        10

    super Hy.UI.ViewProxy.mergeOptions(defaultButtonOptions, buttonOptions), fnClicked

    this

# ==================================================================================================================
if not Hyperbotic.Panels?
  Hyperbotic.Panels = {}

Hyperbotic.Panels.Panel = Panel
Hyperbotic.Panels.QuestionInfoPanelMrF = QuestionInfoPanelMrF
Hyperbotic.Panels.QuestionInfoPanelCustomized = QuestionInfoPanelCustomized
Hyperbotic.Panels.CheckInCritterPanel = CheckInCritterPanel
Hyperbotic.Panels.AnswerCritterPanel = AnswerCritterPanel
Hyperbotic.Panels.ScoreboardCritterPanel = ScoreboardCritterPanel
Hyperbotic.Panels.ContentPackList = ContentPackList
Hyperbotic.Panels.ContentView = ContentView
Hyperbotic.Panels.ContentOptionsPanel = ContentOptionsPanel

Hyperbotic.Panels.UtilityButtonsPanel = UtilityButtonsPanel
Hyperbotic.Panels.UtilityTextPanel = UtilityTextPanel

Hyperbotic.Panels.OptionPanels = OptionPanels
Hyperbotic.Panels.CountdownPanelCustomized = CountdownPanelCustomized
Hyperbotic.Panels.CountdownPanelMrF = CountdownPanelMrF
Hyperbotic.Panels.WebViewPanel = WebViewPanel

Hyperbotic.Panels.LabeledButtonPanel = LabeledButtonPanel
Hyperbotic.Panels.CodePanel = CodePanel

