# ==================================================================================================================
class MessageMarquee

  kDisplayDurationNormal =   4*1000
  kDisplayDurationShort  = 1.5*1000
  kDisplayLineLimit = 60

  kDisplayTransition = 250

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@page, @container)->

    gInstance = this

    @history = []
    @deferral = null

    @currentMessageIndex = 0
    @currentUpdate = null

    @messageDisplayed = false

    @displayDuration = kDisplayDurationNormal

    @adHocSessions = []

    @action = null

    options = this.initOptions()
    options.text = ""
    options.borderWidth = 1
    options.borderColor = Hy.UI.Colors.white

    @container.addChild(@label = new Hy.UI.LabelProxy(options))

    @label.addBorder()

    this

  # ----------------------------------------------------------------------------------------------------------------
  clearDeferral: ()->
    @deferral?.clear()
    @deferral = null
    null

  # ----------------------------------------------------------------------------------------------------------------
  setDeferral: (duration, func)->
    @deferral = Hy.Utils.Deferral.create(duration, func)
    null

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    this.stop()

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    this.start()

  # ----------------------------------------------------------------------------------------------------------------
  inAdHocSession: ()-> _.size(@adHocSessions) > 0

  # ----------------------------------------------------------------------------------------------------------------
  getAdHocSession: ()-> 
    if this.inAdHocSession()
      _.last(@adHocSessions)
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  startAdHocSession: (label)->

    @adHocSessions.push({label: label, text: ""})

    this

  # ----------------------------------------------------------------------------------------------------------------
  endAdHocSession: ()->

    if this.inAdHocSession()
      @adHocSessions = _.initial(@adHocSessions)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addAdHoc: (text)->

    if (session = this.getAdHocSession())?
      session.text = text
      this.start()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getAdHocText: ()->

    if (session = this.getAdHocSession())?
      "#{session.label}: #{session.text}"
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

#    Hy.Trace.debug "MessageMarquee::stop"

    if @messageDisplayed
      this.clearClickHandlers()
      @label.setUIProperty("opacity", 0)
      @messageDisplayed = false
      this.clearDeferral()

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    animate = false

#    @label.setTraceAll()

    @messageDisplayed = true

    @label.setUIProperty("opacity", 0)

    f_0 = ()=>
      this.clearDeferral()
      this.getNextMessage()        
      if animate
        @label.animate {opacity: 1.0, duration: kDisplayTransition}, f_1
      else
        @label.setUIProperty("opacity", 1.0)
        this.setDeferral(kDisplayTransition, f_1)
      null

    f_1 = ()=>
      this.clearDeferral()
      if @messageDisplayed
        this.setDeferral(@displayDuration, f_2)
      null

    f_2 = ()=>
      this.clearDeferral()
      if @messageDisplayed
        @label.setUIProperty("opacity", 0)
        @label.setUIProperty("text", "")
        this.setDeferral(kDisplayTransition, f_0)
      null

    f_0()

    Hy.Trace.debug "MessageMarquee::show (EXIT)"

    this

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()->gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @startContentUpdates: ()->
    if MessageMarquee.get()?
      Hy.Content.ContentManager.get()?.updateManifests()
    null

  # ----------------------------------------------------------------------------------------------------------------
  @doConsoleAppUpdateURL: ()->
    Hy.Trace.debug "MessageMarquee::doConsoleAppUpdateURL (ENTER)"

    if MessageMarquee.get()?
      MessageMarquee.get().doURL()

    if Hy.ConsoleApp.get().analytics?
      Hy.ConsoleApp.get().analytics.logConsoleAppUpdate()

    null

  # ----------------------------------------------------------------------------------------------------------------
  # PRIVATE INTERFACES  
  # ----------------------------------------------------------------------------------------------------------------
  initOptions: ()->
    options = 
      height: 60
      width:'auto'
      color: Hy.UI.Colors.black
      font: Hy.UI.Fonts.specMediumNormal
      textAlign: 'center'
      top: 605
      zIndex: 110
      touchEnabled: true

    options.font.fontSize = 24
   
    options

  # ----------------------------------------------------------------------------------------------------------------
  # This message focuses on 1-player vs party mode
  #
  getDefaultMessage1: ()->

    content = ""

    numPlayers = _.size(Hy.Player.Player.getActivePlayers())
    numTopicsSelected = _.size(Hy.Options.contentPacks.getList())

    if numTopicsSelected is 0
      content += "Select topics and press "
    else
      content += "Press "

    content += "\"Start Game\" to begin"

    if  Hy.Network.NetworkService.isOnline()
      if (joinSpec = Hy.Network.PlayerNetwork.getJoinSpec())?
        content += "\nAdditional players? Visit #{joinSpec.displayURL} and enter \"#{joinSpec.displayCode}\""
    else
      content += "\nConnect to the Web so your friends can play too!"

    content

  # ----------------------------------------------------------------------------------------------------------------
  getDefaultMessage2: ()->

#    return "1234567890 1234567890 1234567890 1234567890 1234567890 1234567890 1234567890 1234567890 1234567890 1234567890 1234567890 1234567890 "

    content = null

    if  Hy.Network.NetworkService.isOnline()
      switch Hy.Network.PlayerNetwork.getStatus()
        when "initializing", "uninitialized"
          content = "#{Hy.Config.DisplayName} is connecting to #{Hy.Network.PlayerNetwork.getJoinSpecDisplayRendezvousURL()}..."

    content

  # ----------------------------------------------------------------------------------------------------------------
  _getNextNews: ()->

    news = Hy.Update.NewsUpdate.getUpdates()

    if news?
      for n in news
        h = _.select @history, (i)=>i.id is n.getID()
        if h.length is 0
          @history.push {id:n.getID()}
          return n

    return null

  # ----------------------------------------------------------------------------------------------------------------
  getNextNews: ()->

    news = this._getNextNews()

    if not news?
      if @history.length > 0
        @history = []
        news = this._getNextNews() # start showing old news

    news

  # ----------------------------------------------------------------------------------------------------------------
  padMessageForClicking: (content)->
    " " + content + "   "

  # ----------------------------------------------------------------------------------------------------------------
  getNextMessage: ()->

    this.removeClick()
    @currentUpdate = null

    addOfflineNote = false 

    content = null

    if this.inAdHocSession()
      # Always show Ad Hoc messages first, if any
      content = this.getAdHocText()

    @displayDuration = if content? then kDisplayDurationShort else kDisplayDurationNormal

    clickable = false

    while not content?

      switch @currentMessageIndex
        when 0
          content = this.getDefaultMessage1() # this will always return something, so we know the loop will terminate

        when 1
          content = this.getDefaultMessage2() # this will always return something, so we know the loop will terminate

        when 2
          if (update = Hy.Content.ContentManifestUpdate.getUpdate())?
            if Hy.Network.NetworkService.isOnline()
              content = update.getDisplay()
              this.addClick MessageMarquee.startContentUpdates
              clickable = true
            else
              addOfflineNote = true

        when 3
          if (update = Hy.Update.ConsoleAppUpdate.getUpdate())?
            if Hy.Network.NetworkService.isOnline()      
#              content = "An App update is available! Touch here to install"
              @currentUpdate = update
              content = @currentUpdate.getDisplay()
              this.addClick MessageMarquee.doConsoleAppUpdateURL
              clickable = true
            else
              addOfflineNote = true

        when 4
          update = this.getNextNews()
          if update?
            # News items may be accompanied by a URL. If so, only display the item if we're online
            if update.hasURL() 
              if Hy.Network.NetworkService.isOnline()
                content = update.getDisplay()
                @currentUpdate = update
                this.addClick MessageMarquee.doMessageURL
                clickable = true
              else
                addOfflineNote = true
            else
              content = update.getDisplay()
        when 4
          if addOfflineNote
            addOfflineNote = false
            content = "App or Trivia updates may be available the next time you connect to the web"

        else
          @currentMessageIndex = -1

      @currentMessageIndex++

    if clickable
      content = this.padMessageForClicking(content)

    @label.setUIProperty("text", content)
    @displayDuration = @displayDuration * (if content.length > kDisplayLineLimit then 2 else 1)

    @label

  # ----------------------------------------------------------------------------------------------------------------
  @doMessageURL: ()->

    Hy.Trace.debug "MessageMarquee::doMessageURL (ENTER)"

    if MessageMarquee.get()?
      MessageMarquee.get().doURL()

    if Hy.ConsoleApp.get().analytics?
      Hy.ConsoleApp.get().analytics.logURLClick()

    null

  # ----------------------------------------------------------------------------------------------------------------
  doURL: ()->
    Hy.Trace.debug "MessageMarquee::doURL (ENTER)"

    if @currentUpdate? and @currentUpdate.hasURL()
        Hy.Utils.Deferral.create 0, ()=>@currentUpdate?.doURL()

  # ----------------------------------------------------------------------------------------------------------------
  doClick_: ()->

#    Hy.Trace.debug "MessageMarquee::doClick_ (@action=#{@action?})"

    action = @action

    this.doClickEmphasis()
    this.clearClickHandlers()

    if action?
      action()

  # ----------------------------------------------------------------------------------------------------------------
  @doClick: (evt)->
#    Hy.Trace.debug "MessageMarquee::doClick (ENTER gInstance=#{MessageMarquee.get()?})"
    if MessageMarquee.get()?
      MessageMarquee.get().doClick_()

  # ----------------------------------------------------------------------------------------------------------------
  addClick: (f)->
#    Hy.Trace.debug "MessageMarquee::addClick (ENTER @action=#{@action?})"

    this.removeClick()

    @action = f

    @label.addEventListener "click", MessageMarquee.doClick

    this.addOutline()

#    Hy.Trace.debug "MessageMarquee::addClick (EXIT @action=#{@action?})"
   
    this

  # ----------------------------------------------------------------------------------------------------------------
  removeClick: ()->
    this.clearClickHandlers()

    this.removeOutline()

    this
    
  # ----------------------------------------------------------------------------------------------------------------
  clearClickHandlers: ()->
#    Hy.Trace.debug "MessageMarquee::clearClickHandlers (@action=#{@action?})"
    if @action?
      @label.removeEventListener "click", MessageMarquee.doClick
      @action = null
    null

  # ----------------------------------------------------------------------------------------------------------------
  addOutline: ()->
    return # Ed doesn't like this :)
    @label.setUIProperty("borderWidth", 3)
    @label.setUIProperty("borderColor", '#333')

  # ----------------------------------------------------------------------------------------------------------------
  removeOutline: ()->
    @label.setUIProperty("borderWidth", 0)
    null

  # ----------------------------------------------------------------------------------------------------------------
  addOutlineEmphasis: ()->
    return # Ed doesn't like this :)
    @label.setUIProperty("borderWidth", 4)
    @label.setUIProperty("borderColor", '#fff')

  # ----------------------------------------------------------------------------------------------------------------
  doClickEmphasis: ()->
#    Hy.Trace.debug "MessageMarquee::doClickEmphasis (@action=#{@action?})"
    this.addOutlineEmphasis()


# ==================================================================================================================
if not Hyperbotic.Panels?
  Hyperbotic.Panels = {}

Hyperbotic.Panels.MessageMarquee = MessageMarquee
