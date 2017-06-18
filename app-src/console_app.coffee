# ==================================================================================================================
#
# IT IS REALLY IMPORTANT THAT App-level event handlers return null.
#   Ti.App.addEventListener("eventName", (event)=>null)
# 
#
class ConsoleApp extends Hy.UI.Application

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (backgroundWindow, tempImage)->

    gInstance = this

    @playerNetwork = null
    @initializingPlayerNetwork = false
    @numPlayerNetworkInitializationAttempts = 0

    super backgroundWindow, tempImage

    this.initSetup()

    # HACK V1.0.2
#    Ti.UI.Clipboard.setText("https://docs.google.com/a/hyperbotic.com/spreadsheet/pub?key=0AvVyfy1LBTe3dFdIa1ItMTN2Q0k4R05qV2VtbWYzbFE&output=html")

    Hy.Pages.StartPage.addObserver this

    this

  # ----------------------------------------------------------------------------------------------------------------
  getContest: ()-> @contest

  # ----------------------------------------------------------------------------------------------------------------
  getPlayerNetwork: ()-> @playerNetwork

  # ----------------------------------------------------------------------------------------------------------------
  initSetup: ()->
    @initFnChain = []

    options = if (newUrl = this.checkURLArg())?
      {page: Hy.Pages.PageState.ContentOptions, fn_completed: ()=>this.doURLArg(newUrl)}
    else
      {page: Hy.Pages.PageState.Start}

    initFnSpecs = [
      {label: "Trace",                    init: ()=>Hy.Trace.init(this)}
      {label: "Analytics",                init: ()=>@analytics = Hy.Analytics.Analytics.init()}
      {label: "Customization",            init: ()=>Hy.Customize.init((c, o)=>this.customizationActivated(c, o))}
#      {label: "CommerceManager",          init: ()=>Hy.Commerce.CommerceManager.init()} #2.7
      {label: "SoundManager",             init: ()=>Hy.Media.SoundManager.init()}
      {label: "Network Service",          init: ()=>this.initNetwork()}
      {label: "DownloadCache",            init: ()=>Hy.Network.DownloadCache.init()}
      {label: "Update Service",           init: ()=>Hy.Update.UpdateService.init()}
      {label: "ContentManager",           init: ()=>Hy.Content.ContentManager.init()}
      {label: "Console Player",           init: ()=>Hy.Player.ConsolePlayer.init()}
#      {label: "CommerceManagerInventory", init: ()=>Hy.Commerce.CommerceManager.inventoryManagedFeatures()} #2.7
      {label: "Page/Video",               init: ()=>this.initPageState()}
      # Should be the last one
      {label: "Customization",            init: ()=>this.applyInitialCustomization(options)}
    ]

    for initFnSpec in initFnSpecs
      this.addInitStep(initFnSpec.label, initFnSpec.init)

    this 

  # ----------------------------------------------------------------------------------------------------------------
  initPageState: ()->
    @pageState = Hy.Pages.PageState.init(this)
    this

  # ----------------------------------------------------------------------------------------------------------------
  doneWithPageState: ()->
    @pageState?.stop()
    @pageState = null
    Hy.Pages.PageState.doneWithPageState()
   
    this
  # ----------------------------------------------------------------------------------------------------------------
  addInitStep: (label, fn)->
    @initFnChain.push({label: label, init: fn})
    this

  # ----------------------------------------------------------------------------------------------------------------
  isInitCompleted: ()-> @initFnChain.length is 0

  # ----------------------------------------------------------------------------------------------------------------
  init: ()->
    super

    Hy.Utils.MemInfo.init()
    Hy.Utils.MemInfo.log "INITIALIZING (init #=#{_.size(@initFnChain)})"

    @timedOperation = new Hy.Utils.TimedOperation("INITIALIZATION")

    fnExecute = ()=>
      while not this.isInitCompleted()
        fnSpec = _.first(@initFnChain)
        fnSpec.init()
        @initFnChain.shift()
        @timedOperation.mark(fnSpec.label)
      null

    fnExecute()

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    Hy.Trace.debug "ConsoleApp::start"

    super

    @analytics?.logApplicationLaunch()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Triggered when the app is backgrounded. Have to work quick here. Do the important stuff first
  pause: (evt)->
    Hy.Trace.debug "ConsoleApp::pause (ENTER)"

    this.getPage()?.pause()
    @playerNetwork?.pause() 
    Hy.Network.NetworkService.get().pause()

    super evt

    Hy.Trace.debug "ConsoleApp::pause (EXIT)"

  # ----------------------------------------------------------------------------------------------------------------
  # Triggered at the start of the process of being foregrounded. Nothing to do here.
  resume: (evt)->
    Hy.Trace.debug "ConsoleApp::resume (ENTER page=#{this.getPage()?.constructor.name})"

    super evt

    Hy.Trace.debug "ConsoleApp::resume (EXIT page=#{this.getPage()?.constructor.name})"

  # ----------------------------------------------------------------------------------------------------------------
  # Triggered when app is fully foregrounded.
  resumed: (evt)->

    Hy.Trace.debug "ConsoleApp::resumed (ENTER page=#{this.getPage()?.constructor.name})"

    super

    this.init()

    Hy.Network.NetworkService.get().resumed()
    Hy.Network.NetworkService.get().setImmediate()

    @playerNetwork?.resumed()

    if (newUrl = this.checkURLArg())?
      this.doURLArg(newUrl)
    else
      this.resumedPage()

    Hy.Trace.debug "ConsoleApp::resumed (EXIT page=#{this.getPage()?.constructor.name})"

  # ----------------------------------------------------------------------------------------------------------------
  #
  # To handle the edge case where we were backgrounded while transitioning to a new page.
  # In the more complex cases, the tactic for handling this is to simply go back to the previous page.
  # This approach seems to be needed when the page is based on a web view and requires images to load
  #
  resumedPage: ()->

    Hy.Trace.debug "ConsoleApp::resumedPage (ENTER (transitioning=#{@pageState.isTransitioning()?})"

    fn = null

    if @pageState.isTransitioning()?
      stopTransitioning = true
      switch (oldPageState = @pageState.getOldPageState())
        when Hy.Pages.PageState.Start, null, Hy.Pages.PageState.Splash
          fn = ()=>this.showStartPage()
        when Hy.Pages.PageState.Any, Hy.Pages.PageState.None
          new Hy.Utils.ErrorMessage("fatal", "Console App", "Unexpected state \"#{oldPageState}\" in resumedPage") #will display popup dialog
          fn = ()=>this.showStartPage()
        else # About, ContentOptions, Join, Question, Answer, Scoreboard, Completed, Options
          stopTransitioning = false
          null

      if stopTransitioning
        @pageState.stopTransitioning()
 
    else
      if not this.getPage()?
        fn = ()=>this.showStartPage()

    Hy.Trace.debug "ConsoleApp::resumedPage (EXIT: \"#{fn?}\")"

    if fn?
      fn()
    else
      @pageState.resumed()
      remotePage = this.remotePlayerMapPage()
      @playerNetwork?.sendAll(remotePage.op, remotePage.data)


    this

  # ----------------------------------------------------------------------------------------------------------------
  showPage: (newPageState, fn_newPageInit, postFunctions = [])->

    Hy.Trace.debug "ConsoleApp::showPage (ENTER #{newPageState} #{@pageState?.display()})"

    fn_showPage = ()=>
      Hy.Trace.debug "ConsoleApp::showPage (FIRING #{newPageState} #{@pageState.display()})"
      @pageState?.showPage(newPageState, fn_newPageInit, postFunctions)

    f = ()=> Hy.Utils.Deferral.create(0, ()=>fn_showPage())

    if (newPageState1 = @pageState.isTransitioning())?
      if newPageState1 isnt newPageState
        @pageState.addPostTransitionAction(f)
    else
      f()

    Hy.Trace.debug "ConsoleApp::showPage (EXIT #{newPageState} #{@pageState.display()})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  showSplashPage: (postFunctions = [])->

    if not @splashShown?
      this.showPage(Hy.Pages.PageState.Splash, ((page)=>page.initialize()), postFunctions)
      @splashShown = true
    null

  # ----------------------------------------------------------------------------------------------------------------
  initNetwork: ()->

    Hy.Network.NetworkService.init().setImmediate()
    Hy.Network.NetworkService.addObserver this

  # ----------------------------------------------------------------------------------------------------------------
  # Called by NetworkService when there's a change in the network scenery (since ConsoleApp is an "observer")
  #
  obs_networkChanged: (evt = null)->

    Hy.Trace.debug "ConsoleApp::obs_networkChanged (online=#{Hy.Network.NetworkService.isOnline()})"

    super

    fn = ()=>
      Hy.Trace.debugM "ConsoleApp::obs_networkChanged (FIRING)"

      this.initPlayerNetwork()

      if not @pageState.isTransitioning()?
        this.getPage()?.obs_networkChanged(evt)
      null

    # If we're in the middle of initialization, postpone this step
    if this.isInitCompleted()
      fn()
    else
      this.addInitStep("obs_networkChanged (ADDED)", ()=>fn())
      Hy.Trace.debugM "ConsoleApp::obs_networkChanged (DEFERRING)"

    this

  # ----------------------------------------------------------------------------------------------------------------
  initPlayerNetwork: ()->

    Hy.Trace.debugM "ConsoleApp::initPlayerNetwork (ENTER)"

    playerNetwork = null

    if @playerNetwork?
      Hy.Trace.debugM "ConsoleApp::initPlayerNetwork (EXIT Already Initialized)"
      return this

    if Hy.Network.PlayerNetwork.isSingleUserMode()
      Hy.Trace.debugM "ConsoleApp::initPlayerNetwork (SINGLE USER MODE)"
      return this

    if @initializingPlayerNetwork
      # Since this function may be called multiple times, in case of a suspend/resume during
      # initialization, or due to a change in the network status
      Hy.Trace.debugM "ConsoleApp::initPlayerNetwork (ALREADY INITIALIZING)"
      return this

    if not Hy.Network.NetworkService.isOnline()
      # Postpone initializing PlayerNetwork subsystem - we don't want to hold up the UI waiting for the device to go online
      return

    @initializingPlayerNetwork = true

    if ++@numPlayerNetworkInitializationAttempts > Hy.Config.PlayerNetwork.kMaxNumInitializationAttempts
      m = "Could not initialize after #{@numPlayerNetworkInitializationAttempts-1} attempts."
      m += "\nRemote Players may not be able to connect"
      new Hy.Utils.ErrorMessage("warning", "Player Network", m) #will display popup dialog
      return

    handlerSpecs =
      fnError: (error, errorState)=>
        m = "Player Network (#{@numPlayerNetworkInitializationAttempts})"
        new Hy.Utils.ErrorMessage(errorState, m, error) #will display popup dialog
        switch errorState
          when "fatal"
            this.obs_networkChanged() # to update UI.
          when "retry"
            this.stopPlayerNetwork()
            Hy.Utils.Deferral.create(Hy.Config.PlayerNetwork.kTimeBetweenInitializationAttempts, ()=>this.obs_networkChanged()) # to update UI and make another init attempt
          when "warning"
            null
        null
      fnReady: ()=>
        Hy.Trace.debug "ConsoleApp::initPlayerNetwork (fnReady)"
        @initializingPlayerNetwork = false
        @numPlayerNetworkInitializationAttempts = 0
        @playerNetwork = playerNetwork
        this.playerNetworkReadyForUser()
        null
      fnMessageReceived: (connection, op, data)=>this.remotePlayerMessage(connection, op, data)
      fnAddPlayer: (connection, label, majorVersion, minorVersion)=>this.remotePlayerAdded(connection, label, majorVersion, minorVersion)
      fnRemovePlayer: (connection)=>this.remotePlayerRemoved(connection)
      fnPlayerStatusChange: (connection, status)=>this.remotePlayerStatusChanged(connection, status)
      fnServiceStatusChange: (serviceStatus)=>
        #this.serviceStatusChange(serviceStatus)
        this.obs_networkChanged() # to update UI
        null

    playerNetwork = Hy.Network.PlayerNetwork.create(handlerSpecs)

    Hy.Trace.debugM "ConsoleApp::initPlayerNetwork (EXIT)"
    this

  # ----------------------------------------------------------------------------------------------------------------
  stopPlayerNetwork: ()->
    @initializingPlayerNetwork = false
    @playerNetwork?.stop()
    @playerNetwork = null
    this

  # ----------------------------------------------------------------------------------------------------------------
  playerNetworkReadyForUser: ()-> 
    Hy.Trace.debug "ConsoleApp::playerNetworkReadyForUser"
    @timedOperation.mark("Network Ready")

    fireEvent = true

    if (newPageState = @pageState.isTransitioning())?
      if newPageState is Hy.Pages.PageState.Splash
        this.showStartPage()
    else
      if this.getPage()?
        if this.getPage().getState() is Hy.Pages.PageState.Splash
          this.showStartPage()
          fireEvent = false
        else
          this.getPage().resumed()
          remotePage = this.remotePlayerMapPage()
          @playerNetwork?.sendAll(remotePage.op, remotePage.data)
      else
        this.showStartPage()

    if fireEvent
      this.obs_networkChanged()

    null

  # ----------------------------------------------------------------------------------------------------------------
  playerNetworkReadyForUser2: ()-> 
    Hy.Trace.debug "ConsoleApp::playerNetworkReadyForUser"
    @timedOperation.mark("Network Ready")

    fireEvent = true

    if this.getPage()?
      if this.getPage().getState() is Hy.Pages.PageState.Splash
        this.showStartPage()
        fireEvent = false
      else
        this.getPage().resumed()
        remotePage = this.remotePlayerMapPage()
        @playerNetwork?.sendAll(remotePage.op, remotePage.data)
    else
      if (newPageState = @pageState.isTransitioning())?
        if newPageState is Hy.Pages.PageState.Splash
          this.showStartPage()

    if fireEvent
      this.obs_networkChanged()

    null

  # ----------------------------------------------------------------------------------------------------------------
  serviceStatusChange: (serviceStatus)->

    Hy.Trace.debug "ConsoleApp::serviceStatusChange"

    this

  # ----------------------------------------------------------------------------------------------------------------
  showAboutPage: ()->
    @playerNetwork?.sendAll("aboutPage", {})
    this.showPage(Hy.Pages.PageState.About, (page)=>page.initialize())

  # ----------------------------------------------------------------------------------------------------------------
  showGameOptionsPage: ()->
    @playerNetwork?.sendAll("aboutPage", {})
    this.showPage(Hy.Pages.PageState.GameOptions, (page)=>page.initialize())

  # ----------------------------------------------------------------------------------------------------------------
  showJoinCodeInfoPage: ()->
    @playerNetwork?.sendAll("aboutPage", {})
    this.showPage(Hy.Pages.PageState.JoinCodeInfo, (page)=>page.initialize())

  # ----------------------------------------------------------------------------------------------------------------
  # Show the start page, and then execute the specified functions
  #
  showStartPage: (postFunctions = [])->
    Hy.Trace.debug "ConsoleApp::showStartPage"

    @questionChallengeInProgress = false

    this.showPage(Hy.Pages.PageState.Start, ((page)=>page.initialize()), postFunctions)
    @playerNetwork?.sendAll("prepForContest", {})

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Invoked from "StartPage" when the enabled state of the Start Button changes.
  #
  obs_startPageStartButtonStateChanged: (state, reason)->

    @playerNetwork?.sendAll("prepForContest", {startEnabled: state, reason: reason})

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Invoked from Page "StartPage" when "Start Game" button is touched
  #
  contestStart: ()->

    page = this.getPage()

    Hy.Media.SoundManager.get().playEvent("gameStart")
    page.contentPacksLoadingStart()

    if this.loadQuestions()
      @nQuestions = @contest.contestQuestions.length
      @iQuestion = 0
      @nAnswered = 0 # number of times at least one player responded

      page.contentPacksLoadingCompleted()

      Hy.Player.ConsolePlayer.findConsolePlayer().setHasAnswered(false)

      Hy.Network.NetworkService.get().setSuspended()

      @playerNetwork?.sendAll('startContest', {})

      this.showCurrentQuestion()

      @analytics?.logContestStart()

    else

      page.contentPacksLoadingCompleted()

      page.resetStartButtonClicked()

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  loadQuestions: ()->

    fnEdgeCaseError = (message)=>
      new Hy.Utils.ErrorMessage("fatal", "Console App Options", message) #will display popup dialog
      false

    contentManager = Hy.Content.ContentManager.get()

    this.getPage().contentPacksLoading("Loading topics...")

    @contentLoadTimer = new Hy.Utils.TimedOperation("INITIAL CONTENT LOAD")

    totalNumQuestions = 0
    for contentPack in (contentPacks = _.select(contentManager.getLatestContentPacksOKToDisplay(), (c)=>c.isSelected()))
      # Edge case: content pack isn't actually local...!
      if contentPack.isReadyForPlay()
        contentPack.load()
        totalNumQuestions += contentPack.getNumRecords()
      else
        return fnEdgeCaseError("Topic \"#{contentPack.getDisplayName()}\" not ready for play. Please unselect it")

    numSelectedContentPacks = _.size(contentPacks)

    @contentLoadTimer.mark("done")

    # Edge case: Shouldn't be here if no topics chosen...
    if numSelectedContentPacks is 0
      return fnEdgeCaseError("No topics chosen - Please choose one or more topics and try again")

    # Edge case: corruption in the option
    if not (numQuestionsNeeded = Hy.Options.numQuestions.getValue())? or not Hy.Options.numQuestions.isValidValue(numQuestionsNeeded)
      fnEdgeCaseError("Invalid \"Number of Questions\" option, resetting to 5 (#{numQuestionsNeeded})")
      numQuestionsNeeded = 5
      Hy.Options.numQuestions.setValue(numQuestionsNeeded)
#      this.getPage().panelNumberOfQuestions.syncCurrentChoiceWithAppOption() # No longer on this page

    # Special Case: numQuestions is -1, means "Play as many questions as possible, up to some limit"
    if numQuestionsNeeded is -1
      # Enforce max number
      numQuestionsNeeded = Math.min(totalNumQuestions, Hy.Config.Dynamics.maxNumQuestions)

    # Edge case: Shouldn't really be in this situation, either: not enough questions!
    # We should be able to set numQuestionsNeeded to a lower value to make it work, since
    # we know that the min number of questions in any contest is 5.
    if (shortfall = (numQuestionsNeeded - totalNumQuestions)) > 0
      for choice in Hy.Options.numQuestions.getChoices().slice(0).reverse()
        if choice isnt -1
          if (shortfall = (choice-totalNumQuestions)) <= 0
            numQuestionsNeeded = choice
            Hy.Options.numQuestions.setValue(numQuestionsNeeded)
#            this.getPage().panelNumberOfQuestions.syncCurrentChoiceWithAppOption() # No longer on this page
            this.getPage().contentPacksLoading("Number of questions reduced to accomodate selected topics...")
            break

      # Something's wrong: apparently have a contest with fewer than 5 questions
      if shortfall > 0
        return fnEdgeCaseError("Not enough questions - Please choose more topics and try again (requested=#{numQuestionsNeeded} shortfall=#{shortfall})")

    this.getPage().contentPacksLoading("Selecting questions...")

    # Edge case: if number of selected content packs > number of requested questions...
    numQuestionsPerPack = Math.max(1, Math.floor(numQuestionsNeeded / numSelectedContentPacks))

    @contest = new Hy.Contest.Contest()

    # This loop should always terminate because we know there are more than enough questions
    contentPacks = Hy.Utils.Array.shuffle(contentPacks)
    index = -1
    numQuestionsFound = 0
    while numQuestionsFound < numQuestionsNeeded

      if index < (numSelectedContentPacks - 1)
        index++
      else
        index = 0
        numQuestionsPerPack = 1 # To fill in the remainder

      contentPack = contentPacks[index]

      numQuestionsFound += (numQuestionsAdded = @contest.addQuestions(contentPack, numQuestionsPerPack))

      if numQuestionsAdded < numQuestionsPerPack
        Hy.Trace.debug "ConsoleApp::loadQuestions (NOT ENOUGH QUESTIONS FOUND pack=#{contentPack.getProductID()} #requested=#{numQuestionsPerPack} #found=#{numQuestionsAdded})"
#        return false # We should be ok, because we know there are enough questions in total...

    for contestQuestion in @contest.getQuestions()
      question = contestQuestion.getQuestion()
      Hy.Trace.debug "ConsoleApp::contestStart (question ##{question.id} #{question.topic})"

    true
  
  # ----------------------------------------------------------------------------------------------------------------
  contestPaused: (remotePage)->

    @playerNetwork?.sendAll('gamePaused', {page: remotePage})

    this

  # ----------------------------------------------------------------------------------------------------------------
  contestRestart: (completed = true)->
    # set this before showing the Start Page
    Hy.Network.NetworkService.get().setImmediate()

    this.showStartPage()

#    this.logContestEnd(completed, @nQuestions, @nAnswered, @contest)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Player requested that we skip to the final Scoreboard
  #
  contestForceFinish: ()->

    this.contestCompleted()

    this

  # ----------------------------------------------------------------------------------------------------------------
  contestCompleted: ()->

    Hy.Trace.debug("ConsoleApp::contestCompleted")

    fnNotify = ()=>

      if not (Hy.Network.PlayerNetwork.isSingleUserMode() or Hy.Player.Player.isConsolePlayerOnly())
        for o in (leaderboard = this.getPage().getLeaderboard())
          for player in o.group
            Hy.Trace.debug("ConsoleApp::contestCompleted (score: #{o.score} player#: #{player})")

        @playerNetwork?.sendAll('contestCompleted', {leaderboard: leaderboard})

      null

    iQuestion = @iQuestion # By the time the init function below is called, @iQuestion will have been nulled out
    Hy.Network.NetworkService.get().setImmediate()

    this.showPage(Hy.Pages.PageState.Completed, ((page)=>page.initialize()), [()=>fnNotify()])

    Hy.Network.NetworkService.get().setImmediate()
    this.logContestEnd(true, @iQuestion, @nAnswered, @contest)

    @nQuestions = null
    @iQuestion = null
    @cq = null

    Hy.Utils.MemInfo.log "Contest Completed"

    this

  # ----------------------------------------------------------------------------------------------------------------
  showQuestionChallengePage: (startingDelay)->

    someText = @cq.question.question
    someText = someText.substr(0, Math.min(30, someText.length))

    Hy.Trace.debug "ConsoleApp::showQuestionChallengePage (#=#{@iQuestion} question=#{@cq.question.id}/#{someText})"

    @currentPageHadResponses = false #set to true if at least one player responded to current question

    @questionChallengeInProgress = true

    # we copy these here to avoid possible issues with variable bindings, when the callbacks below are invoked
    cq = @cq
    iQuestion = @iQuestion
    nQuestions = @nQuestions

    fnNotify = ()=>@playerNetwork?.sendAll('showQuestion', {questionId: cq.question.id})

    nSeconds = Hy.Options.secondsPerQuestion.choices[Hy.Options.secondsPerQuestion.index]

    if not nSeconds? or not (nSeconds >= 10 and nSeconds <= 570) # this is brittle. HACK
      error = "INVALID nSeconds: #{nSeconds}"
      Hy.Trace.debug "ConsoleApp (#{error})"
      new Hy.Utils.ErrorMessage("fatal", "Console App Options", error) #will display popup dialog
      nSeconds = 10
      Hy.Options.secondsPerQuestion.setIndex(0)
#      this.getPage().panelSecondsPerQuestion.syncCurrentChoiceWithAppOption() # No longer on this page

    controlInfo =
      fnPause: (isPaused)=>if isPaused then this.contestPaused("showQuestion") else fnNotify()
      fnCompleted: ()=>this.challengeCompleted()
      countdownSeconds: nSeconds
      startingDelay: startingDelay

    questionSpec = 
      contestQuestion: cq
      iQuestion: iQuestion
      nQuestions: nQuestions

    this.showPage(Hy.Pages.PageState.Question, ((page)=>page.initialize("question", controlInfo, questionSpec)), [()=>fnNotify()])

  # ----------------------------------------------------------------------------------------------------------------
  challengeCompleted: (finishedEarly=false)->

    if @questionChallengeInProgress 
      Hy.Media.SoundManager.get().playEvent("challengeCompleted")
      this.getPage().animateCountdownQuestionCompleted()
      this.getPage().stop() #haltCountdown() #adding this here to ensure that countdown stops immediately, avoid overlapping countdowns

      @questionChallengeInProgress = false
      @cq.setUsed()
      @nAnswered++ if @currentPageHadResponses

      this.showQuestionAnswerPage()

  # ----------------------------------------------------------------------------------------------------------------
  showQuestionAnswerPage: ()->
#    Hy.Trace.debug "ConsoleApp::showQuestionAnswerPage(#=#{@iQuestion} question=#{@cq.question.id} Responses=#{@currentPageHadResponses} nAnswered=#{@nAnswered})"

    responseVector = []

    # Tell the remotes if we received their responses in time
    for response in Hy.Contest.ContestResponse.selectByQuestionID(@cq.question.id)
      responseVector.push {player: response.getPlayer().getIndex(), score: response.getScore()}
    
    fnNotify = ()=>@playerNetwork?.sendAll('revealAnswer', {questionId: @cq.question.id, indexCorrectAnswer: @cq.indexCorrectAnswer, responses:responseVector})

    controlInfo =
      fnPause: (isPaused)=>if isPaused then this.contestPaused("revealAnswer") else fnNotify()
      fnCompleted: ()=>this.questionAnswerCompleted()
      countdownSeconds: Hy.Config.Dynamics.revealAnswerTime
      startingDelay: 0

    this.showPage(Hy.Pages.PageState.Answer, ((page)=>page.initialize("answer", controlInfo)), [()=>fnNotify()])

  # ----------------------------------------------------------------------------------------------------------------
  questionAnswerCompleted: ()->

    Hy.Trace.debug "ConsoleApp::questionAnswerCompleted(#=#{@iQuestion} question=#{@cq.question.id})"

    @iQuestion++

    if @iQuestion >= @nQuestions
      this.contestCompleted() 
    else
      this.showCurrentQuestion()

    this


  # ----------------------------------------------------------------------------------------------------------------
  showCurrentQuestion: ()->

    Hy.Trace.debug "ConsoleApp::showCurrentQuestion(#=#{@iQuestion})"

    @cq = @contest.contestQuestions[@iQuestion]

    if @iQuestion >= @nQuestions
      this.contestCompleted()
    else
      this.showQuestionChallengePage(500)

    this

  # ----------------------------------------------------------------------------------------------------------------  
  remotePlayerAdded: (connection, label, majorVersion, minorVersion)->

    Hy.Trace.debug "ConsoleApp::remotePlayerAdded (##{connection}/#{label})"
    s = "?"

    player = Hy.Player.RemotePlayer.findByConnection(connection)

    if player?
      player.reactivate()
      s = "EXISTING"
    else
      player = Hy.Player.RemotePlayer.create(connection, label, majorVersion, minorVersion)
      @analytics?.logNewPlayer(Hy.Player.Player.count() - 1 ) # Don't count the console player
      s = "NEW"

    Hy.Media.SoundManager.get().playEvent("remotePlayerJoined")

    remotePage = this.remotePlayerMapPage()

    currentResponse = null
    if @cq?
      currentResponse = Hy.Contest.ContestResponse.selectByQuestionIDAndPlayer @cq.question.id, player

    Hy.Trace.debug "ConsoleApp::remotePlayerAdded (#{s} #{player.dumpStr()} page=#{remotePage.op} currentAnswerIndex=#{if currentResponse? then currentResponse.answerIndex else -1})"

    op = "welcome"
    data = {}
    data.index = player.index
    data.page = remotePage
    data.questionId = (if @cq? then @cq.question.id else -1)
    data.answerIndex = (if currentResponse? then currentResponse.answerIndex else -1)
    data.score = player.score()

    data.playerName = player.getName()

    @playerNetwork?.sendSingle(player.getConnection(), op, data)

    player

  # ----------------------------------------------------------------------------------------------------------------  
  remotePlayerRemoved: (connection)->

    Hy.Trace.debug "ConsoleApp::remotePlayerRemoved (#{connection})"

    player = Hy.Player.RemotePlayer.findByConnection(connection)

    if player?

      Hy.Trace.debug "ConsoleApp::remotePlayerRemoved (#{player.dumpStr()})"
      player.destroy()

    this

  # ----------------------------------------------------------------------------------------------------------------
  remotePlayerStatusChanged: (connection, status)->

    player = Hy.Player.RemotePlayer.findByConnection(connection)

    if player?
      Hy.Trace.debug "ConsoleApp::remotePlayerStatusChanged (status=#{status} #{player.dumpStr()})"
      if status
        player.reactivate()
      else
        player.deactivate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  remotePlayerMessage: (connection, op, data)->

    player = Hy.Player.RemotePlayer.findByConnection(connection)

    if player?
      if op is "playerNameChangeRequest"
        this.doPlayerNameChangeRequest(player, data)
      else
        if @pageState.isTransitioning()
          Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (IGNORING, in Page Transition)"
        else
          if not this.doGameOp(player, op, data)
            Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (UNKNOWN OP #{op} #{connection})"
    else
      Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (UNKNOWN PLAYER #{connection})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  doPlayerNameChangeRequest: (player, data)->

    result = player.setName(data.name)

    if result.errorMessage?
      data.errorMessage = result.errorMessage
    else
      data.givenName = result.givenName

    @playerNetwork?.sendSingle(player.getConnection(), "playerNameChangeRequestResponse", data)

    true
  # ----------------------------------------------------------------------------------------------------------------
  doGameOp: (player, op, data)->

    handled = true

    switch op
      when "answer"  
        Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (Answered: question=#{data.questionId} answer=#{data.answerIndex} player=#{player.dumpStr()})"
        this.playerAnswered(player, data.questionId, data.answerIndex)
      when "pauseRequested"
        Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (pauseRequested: player=#{player.dumpStr()})"
        if this.getPage()?
          switch this.getPage().getState()
            when Hy.Pages.PageState.Question, Hy.Pages.PageState.Answer
              if not this.getPage().isPaused()
                this.getPage().fnPauseClick()
      when "continueRequested"
        Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (continueRequested: player=#{player.dumpStr()})"
        if this.getPage()?
          switch this.getPage().getState()
            when Hy.Pages.PageState.Question, Hy.Pages.PageState.Answer
              if this.getPage().isPaused()
                this.getPage().fnClickContinueGame()
      when "newGameRequested"
        Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (newGameRequested: player=#{player.dumpStr()})"
        if this.getPage()?
          switch this.getPage().getState()
            when Hy.Pages.PageState.Start
              this.getPage().fnClickStartGame()
            when Hy.Pages.PageState.Completed
              this.getPage().fnClickPlayAgain()
            when Hy.Pages.PageState.Question, Hy.Pages.PageState.Answer
              if this.getPage().isPaused()
                this.getPage().fnClickNewGame()
      else 
        handled = false

    handled

  # ----------------------------------------------------------------------------------------------------------------
  remotePlayerMapPage: ()->

    page = this.getPage()

    remotePage = if page?
      switch page.constructor.name
        when "SplashPage"
          {op: "introPage"}
        when "StartPage"
          [state, reason] = page.getStartEnabled()
          {op: "prepForContest", data: {startEnabled:state, reason: reason}}
        when "AboutPage", "ContentOptionsPage", "JoinCodeInfoPage", "GameOptionsPage"
          {op: "aboutPage"}
        when "QuestionPage"
          if page.isPaused()
            {op: "gamePaused"}
          else 
            if @questionChallengeInProgress && page.getCountdownValue() > 5
              {op: "showQuestion", data: {questionId: (if @cq? then @cq.question.id else -1)}}
            else
              {op: "waitingForQuestion"}
        when "ContestCompletedPage"
          {op: "contestCompleted"}
        else
          {op: "prepForContest"}
    else
      {op: "prepForContest"}
 
    remotePage

  # ----------------------------------------------------------------------------------------------------------------
  consolePlayerAnswered: (answerIndex)->

    Hy.Player.ConsolePlayer.findConsolePlayer().setHasAnswered(true)
    this.playerAnswered(Hy.Player.ConsolePlayer.findConsolePlayer(), @cq.question.id, answerIndex)

    this

  # ----------------------------------------------------------------------------------------------------------------
  playerAnswered: (player, questionId, answerIndex)->

    if not this.answeringAllowed(questionId)
      return

    isConsole = player.isKind(Hy.Player.Player.kKindConsole)

    responses = Hy.Contest.ContestResponse.selectByQuestionID(questionId)

    if (r = this.playerAlreadyAnswered(player, responses))?
#      Hy.Trace.debug "ConsoleApp::playerAnswered(Player already answered! questionId=#{questionId}, answerIndex (last time)=#{r.answerIndex} answerIndex (this time)=#{answerIndex} player => #{player.index})"
      return

    cq = Hy.Contest.ContestQuestion.findByQuestionID(@contest.contestQuestions, questionId)

    isCorrectAnswer = cq.indexCorrectAnswer is answerIndex

#    Hy.Trace.debug "ConsoleApp::playerAnswered(#=#{@iQuestion} questionId=#{questionId} answerIndex=#{answerIndex} correct=#{cq.indexCorrectAnswer} #{if isCorrectAnswer then "CORRECT" else "INCORRECT"} player=#{player.index}/#{player.label})"

    response = player.buildResponse(cq, answerIndex, this.getPage().getCountdownStartValue(), this.getPage().getCountdownValue())
    this.getPage().playerAnswered(response)

    @currentPageHadResponses = true

    firstCorrectMode = Hy.Options.firstCorrect.getValue() is "yes"

    # if all remote players have answered OR if the console player answers, end this challenge
    done = if isConsole
      true
    else
      if firstCorrectMode and isCorrectAnswer
        true
      else
        activeRemotePlayers = Hy.Player.Player.getActivePlayersByKind(Hy.Player.Player.kKindRemote)

        if (activeRemotePlayers.length is responses.length+1)
          true
        else
          false

    if done
      this.challengeCompleted(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  playerAlreadyAnswered: (player, responses)->

    return _.detect(responses, (r)=>r.player.index is player.index)

  # ----------------------------------------------------------------------------------------------------------------
  answeringAllowed: (questionId)->

    (@questionChallengeInProgress is true) && (questionId is @cq.question.id)

  # ----------------------------------------------------------------------------------------------------------------
  logContestEnd: (completed, nQuestions, nAnswered, contest)->

    numUserCreatedQuestions = 0

    topics = []
    for contestQuestion in contest.getQuestions()
      if contestQuestion.wasUsed()
        # Find the contentPack via the topic, which is really a ProductID
        if (contentPack = Hy.Content.ContentPack.findLatestVersion(topic = contestQuestion.getQuestion().topic))?
          if contentPack.isThirdParty()
            numUserCreatedQuestions++
          else
            topics.push(topic)

    @analytics?.logContestEnd(completed, nQuestions, nAnswered, topics, numUserCreatedQuestions)

    this

  # ----------------------------------------------------------------------------------------------------------------
  userCreatedContentAction: (action, context = null, fn_showPage = null, url = null)->

    contentManager = Hy.Content.ContentManager.get()

    if fn_showPage?
      fn_showPage([(page)=>this.userCreatedContentAction(action, context, null, url)])
    else
      switch action
        when "refresh"
          contentManager.userCreatedContentRefreshRequested(context)
        when "delete"
          contentManager.userCreatedContentDeleteRequested(context)
        when "upsell"
          contentManager.userCreatedContentUpsell()
        when "buy"
          contentManager.userCreatedContentBuyFeature()
        when "add"
          contentManager.userCreatedContentAddRequested(url)
        when "samples"
          contentManager.userCreatedContentLoadSamples()
        when "info"
          this.showContentOptionsPage()
    this

  # ----------------------------------------------------------------------------------------------------------------
  showContentOptionsPage: (postFunctions = [])->
    @playerNetwork?.sendAll("aboutPage", {})
    this.showPage(Hy.Pages.PageState.ContentOptions, ((page)=>page.initialize()), postFunctions)

  # ----------------------------------------------------------------------------------------------------------------
  restoreAction: ()->

    this.showStartPage([(page)=>Hy.Content.ContentManager.get().restore()])

    this

  # ----------------------------------------------------------------------------------------------------------------
  applyInitialCustomization: (options = {page: Hy.Pages.PageState.Start})->    

    if (c = Hy.Content.ContentManager.getCurrentCustomization())?
      Hy.Customize.activate(c, options)
    else
      this.customizationActivated(null, options) 
    this

  # ----------------------------------------------------------------------------------------------------------------
  # 
  # options.page = page to restart onto
  #
  # options.fn_completed = function to call when done
  # options.page = page to transition to when done
  #
  customizationActivated: (customization = null, options = null)->

    Hy.Trace.debug "ConsoleApp::customizationActivated (ENTER #{customization?})"

    #
    # Approach:
    #
    # Transition to black screen
    # Clear all existing page instances cached via PageState
    # Restart on the ContentOptions Page
    #

    fn_pageState = ()=>
      this.doneWithPageState()
      this.initPageState()
      null

    fn_showPage = ()=>
      switch options.page
        when Hy.Pages.PageState.Start
          this.showStartPage([fn_completed])
        when Hy.Pages.PageState.ContentOptions
          this.showContentOptionsPage([fn_completed])
      null

    fn_playerNetwork = ()=>
      if Hy.Network.PlayerNetwork.isSingleUserMode()
        this.stopPlayerNetwork()
      else
        this.initPlayerNetwork()
      null

    fn_completed = ()=>
      fn_playerNetwork()
      options.fn_completed?()
      null

    fns = [fn_pageState, fn_showPage]
    
    Hy.Utils.Deferral.create(0, ()=>f?() for f in fns)
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # We're here because the app was launched, or resumed, because the user is trying to 
  # open a url of the form: 
  #
  # triviapro://args
  #
  # where "triviallypro" is specified in info.plist/CFBundleURLSchemes
  #
  # Let's support this form:
  #
  # triviapro://contest=url
  #
  doURLArg: (url)->

    if url.match(/^triviapro:\/\/customcontest=/)?
      if (i = url.indexOf("=")) isnt -1
        contestURL = url.substr(i+1)
        this.userCreatedContentAction("add", null, ((actions)=>this.showContentOptionsPage(actions)), contestURL)

  this

# ==================================================================================================================
# assign to global namespace:
Hy.ConsoleApp = ConsoleApp

