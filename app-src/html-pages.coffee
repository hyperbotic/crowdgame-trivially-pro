# ==================================================================================================================
class HtmlUtils

  @screenHeight = 768
  @screenWidth = 1024

  gInstance = null

  gDebugElementName = "debug"

  kImageLoadTimeout = 10 * 1000

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    gInstance = this
    @debugElement = null
    @debugFlag = false
    @fn_allPageImagesLoaded = null
    @fn_timeout = null
    @timer = null

    @imgSpecs = []

    this

  # ----------------------------------------------------------------------------------------------------------------
  cssURL: (url)-> "url(\"#{url}\")"

  # ----------------------------------------------------------------------------------------------------------------
  replaceIllegalChars: (text)->

    illegalCharsSpec = [ {c: "<", replacement: "&#60;"} ]

    for charSpec in illegalCharsSpec
      r = new RegExp(charSpec.c)
      text = text.replace(r, charSpec.replacement, "g")

    return text

  # ----------------------------------------------------------------------------------------------------------------
  _findImageSpec: (url)->

    for e in @imgSpecs
      if e.url is url
        return e

    return null

  # ----------------------------------------------------------------------------------------------------------------
  _addImageSpec: (url, imageURL)->
    @imgSpecs.push {url: url, imageURL: imageURL}
    this

  # ----------------------------------------------------------------------------------------------------------------
  _checkAllImagesLoaded: ()->

    if @fn_allPageImagesLoaded?
      if @numImagesLoaded is @numImagesQueued
#        this.debug(@imageDebug)
        if @timer?
          clearTimeout(@timer)
          @timer = null
        @fn_allPageImagesLoaded()

    this

  # ----------------------------------------------------------------------------------------------------------------
  _startImageLoadTimer: ()->

    if not @timer?
      @timer = setTimeout((()=>this._imageLoadTimeout()), kImageLoadTimeout)

    this

  # ----------------------------------------------------------------------------------------------------------------
  _imageLoadTimeout: ()->

     @fn_timeout?("loaded=#{@numImagesLoaded}/queued=#{@numImagesQueued}")
     @timer = null
     this

  # ----------------------------------------------------------------------------------------------------------------
  initImageLoadForPage: (@fn_timeout = null)->

    @numImagesLoaded = 0
    @numImagesQueued = 0
    @fn_allPageImagesLoaded = null

    @imageDebug = ""

    @timer = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  finishImageLoadForPage: (@fn_allPageImagesLoaded)->

    this._checkAllImagesLoaded()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # http://www.webdeveloper.com/forum/showthread.php?193643-Can-u-check-if-background-image-has-loaded
  #
  asyncImageLoad: (styleName, element, url, tag)->

    fn_setImage = (styleName, element, url)=>
      element.style[styleName] = this.cssURL(url)
      element.style.display = "block"
      null

    fn_loaded = (element, url, img, tag)=>
      @numImagesLoaded++
      @imageDebug += " / (#{@numImagesLoaded}/#{@numImagesQueued}) loaded: #{tag}"
      fn_setImage(styleName, element, img.src)
      this._addImageSpec(url, img.src)
      this._checkAllImagesLoaded()
      null

    if url is "none"
      element.style.backgroundImage = "none"
    else
      if (i = this._findImageSpec(url))?
        fn_setImage(styleName, element, i.imageURL)
        @imageDebug += " / Found in image cache: #{tag}"
      else
        this._startImageLoadTimer()
        @numImagesQueued++
        img = new Image()
        img.onload = ()=>fn_loaded(element, url, img, tag)
        img.src = url

    this

  # ----------------------------------------------------------------------------------------------------------------
  waitForElementLoad: (element)->

    r = 
      element: element
      index: e.index, 
      src: if this.hasRetinaDisplay() and e.src2x? then e.src2x else e.src,
      loading: false,
      loaded: false

    @delayedElements.push r

    this    

  # ----------------------------------------------------------------------------------------------------------------
  loadedElement: (elementIndex)->

    for e in @delayedElements
      if e.index is elementIndex
        e.loaded = true
        e.loading = false
        e.element.style.display = "block"
        break

    this.loadDelayedElement()

    this

  # ----------------------------------------------------------------------------------------------------------------
  #  onload="javascript:htmlPageUtility.loadedDelayedElement(1)"
  #
  loadDelayedElement: ()->
    for e in @delayedElements
      if not e.loading and not e.loaded
        e.element.src = e.src
        e.loading = true

        return this

    this.loadedComplete()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getScreenHeight: ()-> HtmlUtils.screenHeight

  # ----------------------------------------------------------------------------------------------------------------
  getScreenWidth: ()-> HtmlUtils.screenWidth

  # ----------------------------------------------------------------------------------------------------------------
  #
  hasRetinaDisplay: ()->

    window.devicePixelRatio? and (window.devicePixelRatio > 1)

  # ----------------------------------------------------------------------------------------------------------------
  getDebugElement: ()->

    if not @debugElement?
      @debugElement = this.getElement(gDebugElementName)

    @debugElement

  # ----------------------------------------------------------------------------------------------------------------
  setDebug: (@debugFlag = true)->

    if @debugFlag
      this.getDebugElement()?.style.display = if flag then "block" else "none"

    this

  # ----------------------------------------------------------------------------------------------------------------
  debug: (text)->

    if @debugFlag and (element = this.getDebugElement())?

      # Depending on when this function is called, page may not be loaded and the lookup
      # might not find anything

      element.style.display = if @debugFlag then "block" else "none"
      element.innerHTML = text

    this

  # ----------------------------------------------------------------------------------------------------------------
  error: (text)->

    this.debug(text)
    alert text
    this

  # ----------------------------------------------------------------------------------------------------------------
  getElement: (name)->
    document.getElementById(name)

  # ----------------------------------------------------------------------------------------------------------------
  initElements: (page, elementNames)->

    for name in elementNames
      if not (page["_#{name}"] = this.getElement(name))?
        alert "Could not find #{page.getName()}.#{name}"

    this

# ==================================================================================================================
class HtmlPageManager

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    @isLoaded = false
    @lastEventCounter = null

    @pageSpecs = []
    @htmlUtils = null
    @activePageSpec = null

    this.utils().setDebug(true)

    this.addEventListener("_PageEventIn", (event)=>this.eventReceived(event))

    this

  # ----------------------------------------------------------------------------------------------------------------
  getActivePageSpec: ()-> @activePageSpec

  # ----------------------------------------------------------------------------------------------------------------
  setActivePage: (pageName = null, data = null, fn_ready = null)->

    ready = true

    fn_startPage = (data)=>
      # Activate the page - set the appropriate section to "display: block", etc,
      # before trying to start rendering its parts
      @activePageSpec.page.setVisibility(true)

      @activePageSpec.page.startPage(data, fn_ready)
      null

    nextPageSpec =  this.findPageSpecByName(pageName)

    # Do nothing if requested page is already active
    if (aps = this.getActivePageSpec())? and nextPageSpec? and (aps is nextPageSpec)
      fn_startPage(data)
      return this    

    this.stopActivePage()

    if pageName?
      if not nextPageSpec? and not (nextPageSpec = this.addPage(pageName))?
        this.utils().error("can\'t find/create #{pageName} to setActive")

      if nextPageSpec?
        # initialize page
        @activePageSpec = nextPageSpec

        ready = false
        fn_startPage(data)

    if ready
      fn_ready()

    this     

  # ----------------------------------------------------------------------------------------------------------------
  stopActivePage: ()->

    if (aps = this.getActivePageSpec())?
      aps.page.setVisibility(false)
      aps.page.stop()

    @activePageSpec = null
    this

  # ----------------------------------------------------------------------------------------------------------------
  activePageOpacity: (data)->

    v = switch data.opacity
      when 0
        false
      when 1
        true
      else
        null

    if v?
      this.getActivePageSpec()?.page.setVisibility(v)

    this

  # ----------------------------------------------------------------------------------------------------------------
  utils: ()->

    if not @htmlUtils
      @htmlUtils = new HtmlUtils()

    @htmlUtils

  # ----------------------------------------------------------------------------------------------------------------
  addPage: (pageName)->

    if not (pageSpec = this.findPageSpecByName(pageName))?
      @pageSpecs.push pageSpec = {name: pageName, page: HtmlAppPage.create(pageName, this)}

    pageSpec

  # ----------------------------------------------------------------------------------------------------------------
  findPageSpecByName: (pageName = null)->
    if pageName?
      for p in @pageSpecs
        if p.name is pageName
          return p
    null

  # ----------------------------------------------------------------------------------------------------------------
  # Called by page when it's loaded
  loaded: ()-> 

    @isLoaded = true

    this.fireEvent("_pageEventOut", {kind: "pageLoaded"})

    this

  # ----------------------------------------------------------------------------------------------------------------
  addEventListener: (kind, fnEvent)->

    if Ti?
      Ti.App.addEventListener(kind, (event)=>fnEvent(event))

    this

  # ----------------------------------------------------------------------------------------------------------------
  fireEvent: (kind, data)->

#    this.utils().debug("Firing event: #{data.kind}")

    if Ti?
      Ti.App.fireEvent(kind, data)
    this

  # ----------------------------------------------------------------------------------------------------------------
  eventReceived: (event)->

#    this.utils().debug("Event received: #{event.kind}")

    if @lastEventCounter? and (event._counter is @lastEventCounter)
      # ignore it
      this.utils().debug("Ignoring duplicate event ##{event._counter}")
    else
      this.eventAction(event)
      @lastEventCounter = event._counter

    this

  # ----------------------------------------------------------------------------------------------------------------
  eventAction: (event)->

    switch event.kind
      when "initializeWebViewForPage"
        this.setActivePage(event.pageName, event.data, ()=>this.eventActionResponse(event))
      when "activePageOpacity"
        this.activePageOpacity(event.data)
      else
        if (page = this.getActivePageSpec().page)?
          method = "event_#{event.kind}"
#          this.utils().debug("eventAction: #{page}.#{method}")
          if (fn = page[method])?
            if event._responseRequired
              page[method](event.data, ()=>this.eventActionResponse(event))
            else
              page[method](event.data)
        else
          alert "Unknown event: #{event.kind}"
    this

  # ----------------------------------------------------------------------------------------------------------------
  eventActionResponse: (event)->

    if event._responseRequired

      # App is expecting a reply
      event._responseCompleted = true

    this.fireEvent("_pageEventOut", event)
    this


# ==================================================================================================================
class HtmlAppPage

  # ----------------------------------------------------------------------------------------------------------------
  @create: (pageName, pageManager)->
    kind = switch pageName
      when "QuestionPage"
        HtmlQuestionPage
      when "StartPage"
        HtmlStartPage
      when "ContestCompletedPage"
        HtmlContestCompletedPage
      when "AboutPage"
        HtmlAboutPage
      when "ContentOptionsPage"
        HtmlContentOptionsPage
      when "GameOptionsPage"
        HtmlGameOptionsPage
      when "JoinCodeInfoPage"
        HtmlJoinCodeInfoPage
      else
        null

    page = if kind?
      new kind(pageManager)
    else
      alert "Unknown page kind #{pageName}"
      null

    page

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@pageManager)->

    @singleUser = false

    @pageManager.utils().initElements(this, this.getElementNames())

    this

  # ----------------------------------------------------------------------------------------------------------------
  utils: ()-> @pageManager.utils()

  # ----------------------------------------------------------------------------------------------------------------
  isSingleUser: ()-> @singleUser

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()-> "?"

  # ----------------------------------------------------------------------------------------------------------------
  getElementNames: (elementNames = [])->
    [
      "page_wrapper",
      "background_image",
      "logo1_text",
      "logo1_text_inner",
      "logo1_image",
      "logo2_text",
      "logo2_text_inner",
      "logo2_image"
    ].concat(elementNames)

  # ----------------------------------------------------------------------------------------------------------------
  imageLoadTimeout: (diagnostic = "", fn_ready = null)->
    alert "Timed out while waiting for images to load: #{diagnostic}"
    fn_ready?()
    this

  # ----------------------------------------------------------------------------------------------------------------
  startPage: (data, fn_ready)->

    this.utils().initImageLoadForPage((s)=>this.imageLoadTimeout(s, fn_ready))

    this.start(data)
  
    # Check if page is ready to start
    this.utils().finishImageLoadForPage(fn_ready)

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: (data = {})->

    this.clearGeneral()

    if data.customize? and data.customize.general?
      this.customizeGeneral(data.customize.general)

    this.clearLogos()

    if data.customize? and data.customize.logos?
      this.customizeLogos(data.customize.logos)

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  setVisibility: (visible = true)->

    styleValue = if visible then "block" else "none"

    this._getVisibilityElement()?.style.display = styleValue

    for l in this.logoNames()
      this[this._logoText(l)].style.display = styleValue
      this[this._logoImage(l)].style.display = styleValue

    this
    
  # ----------------------------------------------------------------------------------------------------------------
  _getVisibilityElement: ()-> null

  # ----------------------------------------------------------------------------------------------------------------
  clearGeneral: ()->

    for element in [@_background_image]
      element.removeAttribute("style")

    this

  # ----------------------------------------------------------------------------------------------------------------
  customizeGeneral: (customizations = [])->

    if (c = this.getCustomization(customizations, "#{this.getName()}.singleuser"))?
      @singleUser = c.value

    fn_pathname = (propertyName)=> "#{this.getName()}.#{propertyName}"

    for c in customizations
      switch c.name
        when fn_pathname("borderColor")
          null

        when fn_pathname("background.url")
          this.utils().asyncImageLoad("backgroundImage", @_background_image, c.value, c.name)

        when fn_pathname("background.color")
          @_background_image.style.backgroundImage = "none"
          @_background_image.style.backgroundColor = c.value

    this

  # ----------------------------------------------------------------------------------------------------------------
  logoNames: ()-> ["logo1", "logo2"]

  # ----------------------------------------------------------------------------------------------------------------

  _logo: (logoName)->          "_#{logoName}"
  # -------
  _logoImage: (logoName)->     "#{this._logo(logoName)}_image"
  # -------
  _logoText: (logoName)->      "#{this._logo(logoName)}_text"
  # -------
  _logoTextInner: (logoName)-> "#{this._logo(logoName)}_text_inner"

  # ----------------------------------------------------------------------------------------------------------------
  clearLogos: ()->

    fn_clearLogo = (logoName)=>
      for e in [this._logoImage(logoName), this._logoText(logoName), this._logoTextInner(logoName)]
        this[e].removeAttribute("style")
      this[this._logoTextInner(logoName)].innerHTML = ""
      null

    for logoName in this.logoNames()
      fn_clearLogo(logoName)

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  #
  customizeLogos: (customizations = [])->

    s1 = ""
    s2 = ""

    fn_applyStyle = (logoName, elementKind, styleName, value)=>
      fn = switch elementKind
        when "logo"
          (l)=>this._logo(l)
        when "logoImage"
          (l)=>this._logoImage(l)
        when "logoText"
          (l)=>this._logoText(l)
        when "logoTextInner"
          (l)=>this._logoTextInner(l)
        else
          this.utils().error("Unknown \"#{elementKind}\" in \"customizeLogos.fn_applyStyle\"")

      if fn?
        switch styleName
          when "backgroundImage"
            this.utils().asyncImageLoad("backgroundImage", this[fn(logoName)], value, "#{logoName}.#{elementKind}")
          else
            this[fn(logoName)].style[styleName] = value
        s1 += "/ #{logoName}.#{this.cssName(styleName)} "
      null

    fn_checkLogoSize = (options)=>
      # This should have been checked in Customize.validateSettings. 
      null

    fn_checkLogoPosition = (options)=>
      # This should have been checked in Customize.validateSettings. 
      options

    # Presume previous logo customizations have already been cleared
    # Setup and special-cases
    # Reset existing logos by deleting any applied styles
    # Set up text and image
    
    for logoName in this.logoNames()

      # Set background image, color and border-color on image sub-div
      if (b = this.getCustomization(customizations, "#{this.getName()}.#{logoName}.background.url"))?
        fn_applyStyle(logoName, "logoImage", this.cssName("background.url"), b.value)

      if (b = this.getCustomization(customizations, "#{this.getName()}.#{logoName}.background.color"))?
        fn_applyStyle(logoName, "logoImage", this.cssName("background.color"), b.value)

      if (b = this.getCustomization(customizations, "#{this.getName()}.#{logoName}.bordercolor"))?
        fn_applyStyle(logoName, "logoImage", this.cssName("bordercolor"), b.value)

      # Set text on text sub-sub-div
      if (tc = this.getCustomization(customizations, "#{this.getName()}.#{logoName}.text"))?
        this[this._logoTextInner(logoName)].innerHTML = this.utils().replaceIllegalChars(tc.value)

      # Check alignment
      if (tc = this.getCustomization(customizations, "#{this.getName()}.#{logoName}.align"))?
        fn_applyStyle(logoName, "logoTextInner", "text-align", tc.value)

      # Size and position
      if (spc = this.getCustomization(customizations, "#{this.getName()}.#{logoName}._sizeandposition"))?
        fn_checkLogoSize(spc.value)
        fn_checkLogoPosition(spc.value)

        for n, v of spc.value
          if v?             
            fn_applyStyle(logoName, "logoImage", n, v)
            fn_applyStyle(logoName, "logoText", n, v)

        # center horizontally if no left/right set
        # http://stackoverflow.com/questions/114543/how-to-center-a-div-in-a-div-horizontally

        if not (spc.value.right? or spc.value.left?)
          for e in ["logoImage", "logoText"]
            fn_applyStyle(logoName, e, "-webkit-transform", "translateX(-50%)")
            fn_applyStyle(logoName, e, "left", "50%")

    # Apply general customizations
    for c in customizations

      logoName = this.getCustomizationPathname(c.name, 1, 1) # "page.logo1.background.url"
      styleName = propertyName = this.getCustomizationPathname(c.name, 2)

      s2 += "#{logoName}.#{propertyName}=#{c.value} "

      styleValue = null # switch propertyName # nothing to do here

      if styleValue?
        fn_applyStyle(logoName, "logoText", this.cssName(styleName), styleValue)

      styleValue = switch propertyName
        when "font.color"
          c.value
        when "font.name"
          c.value
        when "font.style", "font.weight" # v1.3.0
          c.value
        when "font.size"  # v1.3.0
          "#{c.value}px"
        else
          null

      if styleValue?
        fn_applyStyle(logoName, "logoTextInner", this.cssName(styleName), styleValue)

#      this.utils().debug(s1)

    this
  # ----------------------------------------------------------------------------------------------------------------
  #
  # Various helper functions
  #
  # ----------------------------------------------------------------------------------------------------------------
  # ------------

  getCustomization: (customizations, name)->
    result = null
    for c in customizations
      if c.name is name
        result = c
    result

  # ------------
  cssName: (customizationName)->
    name = switch customizationName
      when "background.url"
        "backgroundImage"
      when "background.color"
        "backgroundColor"
      when "bordercolor"
        "borderColor"
      when "font.name"
        "fontFamily"
      when "font.style"
        "fontStyle"
      when "font.weight"
        "fontWeight"
      when "font.size"
        "fontSize"
      when "font.color"
        "color"
      else
        customizationName
    name

  # ------------
  # Given a pathname like "page.logo1.background.url",
  # Return the subpath from <start> to <end> (zero-based), like so:
  # if start = 1 and end is unspecified, then "logo1.background.url".
  #
  getCustomizationPathname: (pathname, start = null, end = null)->
    name = ""
    sp = pathname.split(".")
    len = sp.length

    if not start? or (start < 0) or (start >= len)
      start = 0

    if not end? or (end < 0) or (end >= len)
      end = len-1

    for i in [start..end]
      name = if name is ""
        sp[i]
      else
        "#{name}.#{sp[i]}"
    name

# ==================================================================================================================

class HtmlQuestionPage extends HtmlAppPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (pageManager)->

    super pageManager

    this.initAnswerElements()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()-> "questionpage"

  # ----------------------------------------------------------------------------------------------------------------
  getElementNames: (elementNames = [])->

    e = [
      "question_page",
      "question",
      "question_container",
      "question_sizing_container"]

    for l in this.getAnswerLetters()
      for k in ["", "_container", "_sizing_container"]
        e.push "answer_#{l}#{k}"    

    super e.concat(elementNames)

  # ----------------------------------------------------------------------------------------------------------------
  _getVisibilityElement: ()-> @_question_page

  # ----------------------------------------------------------------------------------------------------------------
  start: (data)->

    if data?
      if data.customize? and data.customize.questionpage?
        # customize Q & A appearance
        data.sizes = this.customizeContent(data.customize.questionpage)

      if data.content? and data.content.questionpage?
        this.initPageContent(data.content.questionpage)

    this.resetEmphasis()

    super data

    this

  # ----------------------------------------------------------------------------------------------------------------
  event_showConsoleSelection: (data)->
    @answers[data.indexSelectedAnswer].setAttribute("emphasis", "selected")

  # ----------------------------------------------------------------------------------------------------------------
  event_revealAnswer: (data)->

    for i in [0..3]
      @answers[i].setAttribute("emphasis", if i is data.indexCorrectAnswer then "correct" else "incorrect")

    this

  # ----------------------------------------------------------------------------------------------------------------
  resetEmphasis: ()->

    for i in [0..3]
      @answers[i].setAttribute("emphasis", "none")
      @answers[i].setAttribute("background-color", "none") #HACK

  # ----------------------------------------------------------------------------------------------------------------
  getAnswerLetters: ()-> ["A", "B", "C", "D"]

  # ----------------------------------------------------------------------------------------------------------------
  initAnswerElements: ()->

    @answers = (this["_answer_#{letter}"] for letter in this.getAnswerLetters())

  # ----------------------------------------------------------------------------------------------------------------
  testData: (data)->

    data.question = {}
    data.question.text = "Which Bavarian castle did Walt Disney sculpt Cinderella's after?"

    data.answers = []
    for i in [0..3]
      data.answers[i] = {}

    data.answers[0].text = "Neuschwanstein Castle"
#    data.answers[1].text = "Mad King Ludwig's"
    data.answers[1].text = "1984"
    data.answers[2].text = "The Home of the Studious Megakao"
    data.answers[3].text = "Neuschwanstein Castle"

    data

  # ----------------------------------------------------------------------------------------------------------------
  customizeContent: (customizations)->

    rectInfo = {}

    # For both questions and answers
    kPadding = 10     # .answerSizingContainer
    kBorderWidth = 3  # .answerSizingContainer

    #
    # Questions
    #
    kQuestionContainerWidth = 944
 
    # .questionSizingContainer, may change at runtime
    kQuestionSizingContainerHeight = 195
    kQuestionSizingContainerWidth = 848

    # The amount that we nudge the questions over by, to make room for the pause button, etc
    kQuestionSizingContainerRightMargin = 70

    @questionPanelInfo = 
      height: kQuestionSizingContainerHeight
      width:  kQuestionSizingContainerWidth
      _hOffset: 0
      _vOffset: 0
      _padding: kPadding
      _borderWidth: kBorderWidth

    #
    # Answers
    #

    # "inside" dimensions, before padding, border
    kAnswerSizingContainerHeight = 180 
    kAnswerSizingContainerWidth = 434

    # If using smaller boxes, this is the amount to reduce by
    kSmallAnswerContainerHAdjust = 70

    @answerPanelInfo = 
      height:  kAnswerSizingContainerHeight    # .answerSizingContainer
      width:   kAnswerSizingContainerWidth     # May reduce this if using "A".. graphics
      _hOffset: 0
      _vOffset: 0
      _padding: kPadding
      _borderWidth: kBorderWidth

    answerBackgroundSpecified = null
    useAnswerBackgroundDefault = true

    questionBackgroundSpecified = null
    useQuestionBackgroundDefault = true

    # ------------
    fn_question = ()=>                "_question"
    # ------------
    fn_questionContainer = ()=>       "_question_container"
    # ------------
    fn_questionSizingContainer = ()=> "_question_sizing_container"
    # ------------
    fn_answer = (l)=>                 "_answer_#{l}"
    # ------------
    fn_answerContainer = (l)=>        "_answer_#{l}_container"
    # ------------
    fn_answerSizingContainer = (l)=>  "_answer_#{l}_sizing_container"

    # ------------
    fn_applyStyle = (elementKind, styleName, value, arg1 = null)=>

      fn = switch elementKind
        when "question"
          fn_question
        when "questionContainer"
          fn_questionContainer
        when "questionSizingContainer"
          fn_questionSizingContainer
        when "answer"
          fn_answer
        when "answerContainer"
          fn_answerContainer
        when "answerSizingContainer"
          fn_answerSizingContainer
        else
          this.utils().error("Unknown \"#{elementKind}\" in \"customizeContent.fn_applyStyle\"")
          null

      if fn?
        elementNames = if (elementKind.indexOf("answer") is -1)
          [fn()]
        else
          (for answerLetter in (if arg1? then arg1 else this.getAnswerLetters())
            fn(answerLetter))

        for e in elementNames
          switch styleName
            when "backgroundImage"
              this.utils().asyncImageLoad("backgroundImage", this[e], value, elementKind)
            else
              this[e].style[styleName] = value
              # Using setAttribute to set style is a no-no

        # Extra semantics
        if (elementKind.indexOf("question") isnt -1) and styleName is "borderColor"
          useQuestionBackgroundDefault = false      

        if (elementKind.indexOf("question") isnt -1) and styleName is "backgroundImage"
          useQuestionBackgroundDefault = false      

        if (elementKind.indexOf("question") isnt -1) and styleName is "backgroundColor"
          useQuestionBackgroundDefault = false      

        if (elementKind.indexOf("answer") isnt -1) and styleName is "borderColor"
          useAnswerBackgroundDefault = false      

        if (elementKind.indexOf("answer") isnt -1) and styleName is "backgroundImage"
          useAnswerBackgroundDefault = false      

        if (elementKind.indexOf("answer") isnt -1) and styleName is "backgroundColor"
          useAnswerBackgroundDefault = false      

      null

    # ------------
    fn_dumpQuestionAdjustments = (customization)=>
      s = ""
      for n, v of customization.value
        s += "#{n}=#{v} "

      alert s
      null

    # ------------
    fn_applyQuestionAdjustments = (customization)=>

      for f in ["height", "width", "_hOffset", "_vOffset"]
        if (v = customization.value[f])?
          @questionPanelInfo[f] = v
          useQuestionBackgroundDefault = false

      for e in ["questionSizingContainer"]
        fn_applyStyle(e, "height", @questionPanelInfo.height)
        fn_applyStyle(e, "width", @questionPanelInfo.width)

      # Apply customization-driven offsets

      # By default, the question panel is justified against the left side (margin-left:0)
      # However, If the customized size is smaller than the default size by more than  
      # twice the right margin offset (due to the "pause" button, etc), 
      # then we center on the page...
      # Otherwise we stick to the left proportionately.

      outsideQuestionSizingContainerWidth = @questionPanelInfo.width + 2*@questionPanelInfo._padding + 2*@questionPanelInfo._borderWidth

      diff = kQuestionContainerWidth - outsideQuestionSizingContainerWidth

#      alert diff + " " + outsideQuestionSizingContainerWidth

      hOffset = if diff >= (2 * kQuestionSizingContainerRightMargin)
        # Center on the page
        diff/2
      else
        # Center on the space to the left of the pause button
        (kQuestionSizingContainerWidth - @questionPanelInfo.width)/2

      # Apply customized hortizontal offset, if any
      hOffset += @questionPanelInfo._hOffset

      fn_applyStyle("questionSizingContainer", "marginLeft", hOffset)

      # Center vertically
      # http://stackoverflow.com/questions/396145/whats-the-best-way-of-centering-a-div-vertically-with-cs
      #
      topCenteringAdjustment = -(@questionPanelInfo.height + (2*@questionPanelInfo._padding) + 2*(@questionPanelInfo._borderWidth))/2

      # Apply vertical offset
      topCenteringAdjustment += @questionPanelInfo._vOffset

      fn_applyStyle("questionSizingContainer", "marginTop", topCenteringAdjustment)

      rectInfo.question = this[fn_questionSizingContainer()].getBoundingClientRect()

      null

    # ------------
    fn_dumpAnswerPositionAdjustments = ()=>
      s = ""
      s += "height: #{@answerPanelInfo.height} "
      s += "width: #{@answerPanelInfo.width} "
      s += "hOffset: #{@answerPanelInfo._hOffset} "
      s += "padding: #{@answerPanelInfo._padding} "
      s += "borderWidth: #{@answerPanelInfo._borderWidth} "
      alert s
      null

    # ------------
    fn_applyAnswerAdjustments = (customization)=>

      for f in ["height", "width", "_hOffset", "_vOffset"]
        if (v = customization.value[f])?
          @answerPanelInfo[f] = v
          useAnswerBackgroundDefault = false

      # Do we need to make room for the "A", "B", etc answer letter graphics?
      # We've already processed: size, offset, border
      # Check the other criteria.

      if useAnswerBackgroundDefault and not this.isSingleUser()
        @answerPanelInfo.width -= kSmallAnswerContainerHAdjust

      for e in ["answerSizingContainer"]
        fn_applyStyle(e, "height", @answerPanelInfo.height)
        fn_applyStyle(e, "width", @answerPanelInfo.width)

#      fn_dumpAnswerPositionAdjustments()

      adjustments = []

      # Apply customization-driven offsets
      #      
      hOffset = 0

      if @answerPanelInfo._hOffset isnt 0

        hOffset += ((kAnswerSizingContainerWidth - @answerPanelInfo.width)/2) + @answerPanelInfo._hOffset

      if useAnswerBackgroundDefault and not this.isSingleUser()
        hOffset += kSmallAnswerContainerHAdjust

      if hOffset isnt 0
        adjustments.push { name: "A", style: "marginLeft",   value: hOffset }
        adjustments.push { name: "C", style: "marginLeft",   value: hOffset }
        adjustments.push { name: "B", style: "marginRight",  value: hOffset }
        adjustments.push { name: "D", style: "marginRight",  value: hOffset }

      # Center vertically
      # http://stackoverflow.com/questions/396145/whats-the-best-way-of-centering-a-div-vertically-with-cs
      #
      tca = -(@answerPanelInfo.height + (2*@answerPanelInfo._padding) + 2*(@answerPanelInfo._borderWidth))/2

      adjustments.push { name: "A", style: "marginTop",  value: tca + @answerPanelInfo._vOffset }
      adjustments.push { name: "B", style: "marginTop",  value: tca + @answerPanelInfo._vOffset}
      adjustments.push { name: "C", style: "marginTop",  value: tca - @answerPanelInfo._vOffset}
      adjustments.push { name: "D", style: "marginTop",  value: tca - @answerPanelInfo._vOffset}

      for a in adjustments
        fn_applyStyle("answerSizingContainer", a.style, a.value, [a.name])

      rectInfo.answers = []
      index = 0
      for answer in this.getAnswerLetters()
        rectInfo.answers.push {index: index, rect: this[fn_answerSizingContainer(answer)].getBoundingClientRect()}
        index++

      null

    # ------------
    fn_setQuestionBackground = ()=>
      if questionBackgroundSpecified?
        fn_applyStyle("questionSizingContainer", "backgroundImage", questionBackgroundSpecified)

      bi = if useQuestionBackgroundDefault
         "assets/icons/question-background.png"
      else
        "none"

      fn_applyStyle("questionContainer", "backgroundImage", bi)

      null

    # ------------
    fn_setAnswerBackground = ()=>
      if answerBackgroundSpecified?
        fn_applyStyle("answerSizingContainer", "backgroundImage", answerBackgroundSpecified)
      else
        if useAnswerBackgroundDefault
          for answer in this.getAnswerLetters()
            url = if this.isSingleUser()
              "answer-#{answer}-no-letter"
            else
              "answer-#{answer}"

            fn_applyStyle("answerContainer", "backgroundImage", "assets/icons/#{url}.png", [answer])

      null

    # ------------
    fn_clearAnswerStyles = ()=>
      for l in this.getAnswerLetters()
        for e in [fn_answer(l), fn_answerContainer(l), fn_answerSizingContainer(l)]
          this[e].removeAttribute("style")
      null

    # ------------
    fn_clearQuestionStyles = ()=>
      for e in [fn_question(), fn_questionSizingContainer(), fn_questionContainer()]
        this[e].removeAttribute("style")
      null

    # ------------

    # First, clear any styles that were applied last time
    if customizations.length > 0
      fn_clearQuestionStyles()
      fn_clearAnswerStyles()

    # Then, deal with some global customizations
    if (customization = this.getCustomization(customizations, "questionpage.question.bordercolor"))?
      # has side effects
      fn_applyStyle("questionSizingContainer", "borderColor", customization.value)

    if (customization = this.getCustomization(customizations, "questionpage.answers.bordercolor"))?
      # has side effects
      fn_applyStyle("answerSizingContainer", "borderColor", customization.value)

    #
    # Now process the remaining directives, which don't affect size/color/offset, but
    # which might (also) affect background
    #

    for customization in customizations
      switch customization.name

        when "questionpage.question.background.url"
          questionBackgroundSpecified = customization.value
        when "questionpage.answers.background.url"
          answerBackgroundSpecified = customization.value

        when "questionpage.question.background.color"
          fn_applyStyle("questionSizingContainer", "backgroundColor", customization.value)
        when "questionpage.answers.background.color"
          fn_applyStyle("answerSizingContainer", "backgroundColor", customization.value)

        when "questionpage.question.font.color"
          fn_applyStyle("question", "color", customization.value)
        when "questionpage.answers.font.color"
          fn_applyStyle("answer", "color", customization.value)

        when "questionpage.question.font.name"
          fn_applyStyle("question", "fontFamily", customization.value)
        when "questionpage.answers.font.name"
          fn_applyStyle("answer", "fontFamily", customization.value)

        when "questionpage.question.font.style"
          fn_applyStyle("question", "fontStyle", customization.value)
        when "questionpage.answers.font.style"
          fn_applyStyle("answer", "fontStyle", customization.value) # v1.3.0

        when "questionpage.question.font.weight" #v1.3.0 Why doesnt this use cssName()?
          fn_applyStyle("question", "fontWeight", customization.value)
        when "questionpage.answers.font.weight"  #v1.3.0
          fn_applyStyle("answer", "fontWeight", customization.value) # v1.3.0

        when "questionpage.question.align"
          fn_applyStyle("question", "text-align", customization.value)

    if answerBackgroundSpecified?
      useAnswerBackgroundDefault = false
 
    if questionBackgroundSpecified?
      useQuestionBackgroundDefault = false

    # Set Question size and offset
    if (customization = this.getCustomization(customizations, "questionpage.question._sizeandoffset"))?
      fn_applyQuestionAdjustments(customization)

    # Set Answer size and offset. Relies on knowing which background to use
    if (customization = this.getCustomization(customizations, "questionpage.answers._sizeandoffset"))?
      fn_applyAnswerAdjustments(customization)

    # Finally, fix up backgrounds
    fn_setQuestionBackground()
    fn_setAnswerBackground()

#    alert rectInfo.question.top

    rectInfo

  # ----------------------------------------------------------------------------------------------------------------
  initPageContent: (content)->

    s = ""
    questionSizeSpec = {max: 78, min: 15, failsafe: 10}
    answerSizeSpec =   {max: 66, min: 15, failsafe: 10}

#    this.testData(data)

    @_question.innerHTML = this.utils().replaceIllegalChars(content.question.text)
    questionFontSize = this.findBestFontSize("question", @_question, @questionPanelInfo, questionSizeSpec)

    @_question.style.fontSize = "#{questionFontSize}px"
    s += "Question: #{questionFontSize} "

    answerFontSize = answerSizeSpec.max

    for i in [0..3]
      @answers[i].innerHTML = this.utils().replaceIllegalChars(content.answers[i].text)

      f = this.findBestFontSize("answer ##{i}", @answers[i], @answerPanelInfo, answerSizeSpec)
      answerFontSize = Math.min(f, answerFontSize)

    s += "Answer: #{answerFontSize}"

    for i in [0..3]
      @answers[i].style.fontSize = "#{answerFontSize}px"

#    this.utils().debug(s)

    this

  # ----------------------------------------------------------------------------------------------------------------
  findBestFontSize: (tag, element, maxDimensions, sizeSpec)->

    heightNormal = heightBreakWord = "??"

    for size in [sizeSpec.max..sizeSpec.min]
      element.style.fontSize = "#{size}px"

      element.style.wordWrap = "normal"
      heightNormal = element.clientHeight
      widthNormal = element.clientWidth

      element.style.wordWrap = "break-word"
      heightBreakWord = element.clientHeight
      widthBreakWord = element.clientWidth

      if (heightBreakWord is heightNormal) and (heightNormal <= maxDimensions.height) and 
         (widthBreakWord is widthNormal) and (widthNormal <= maxDimensions.width)
#        alert "Text:#{element.innerHTML} width:#{heightBreakWord}/#{heightNormal} #{widthBreakWord}/#{widthNormal} font:#{size}"
        return size

#    alert("Font: Failsafe #{tag} current last heightNormal=#{heightNormal} heightBreakWord=#{heightBreakWord}")

    return sizeSpec.failsafe


# ==================================================================================================================
class HtmlStartPage extends HtmlAppPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (pageManager)->

    super pageManager

    this

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()-> "startpage"

  # ----------------------------------------------------------------------------------------------------------------
  getElementNames: (elementNames = [])->
    e = [
      "start_page"
    ].concat(elementNames)

    super e

  # ----------------------------------------------------------------------------------------------------------------
  _getVisibilityElement: ()-> @_start_page

  # ----------------------------------------------------------------------------------------------------------------
  start: (data)->

    super data

    this

# ==================================================================================================================
class HtmlContestCompletedPage extends HtmlAppPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (pageManager)->

    super pageManager

    this

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()-> "completedpage"

  # ----------------------------------------------------------------------------------------------------------------
  getElementNames: (elementNames = [])->
    e = [
      "contest_completed_page"
    ].concat(elementNames)

    super e

  # ----------------------------------------------------------------------------------------------------------------
  _getVisibilityElement: ()-> @_contest_completed_page

# ==================================================================================================================
class HtmlUtilityPage extends HtmlAppPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (pageManager)->

    super pageManager

    this

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()-> "utilitypage"


# ==================================================================================================================
class HtmlAboutPage extends HtmlUtilityPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (pageManager)->

    super pageManager

    this

  # ----------------------------------------------------------------------------------------------------------------
  getElementNames: (elementNames = [])->
    e = [
      "about_page",
      "about_content",
      "contact2",
      "copyright1",
      "copyright2"
      "version",
      "trivially_logo",
      "crowdgame_logo"
    ].concat(elementNames)

    super e

  # ----------------------------------------------------------------------------------------------------------------
  _getVisibilityElement: ()-> @_about_page

  # ----------------------------------------------------------------------------------------------------------------
  start: (data)->

    if data?
      if data.content? and data.content.aboutpage?
        this.initPageContent(data.content.aboutpage)

    super data

    this

  # ----------------------------------------------------------------------------------------------------------------
  initPageContent: (aboutPageContent)->

    if (v = aboutPageContent.version)?
      @_version.innerHTML = "v#{v.major}.#{v.minor}.#{v.minor2}#{v.moniker}"

    if (c = aboutPageContent.copyright)?
      for i in ["copyright1", "copyright2"]
        this["_#{i}"].innerHTML = c[i]

    if (t = aboutPageContent.contact)?
      @_contact2.innerHTML = t

    for logoName in ["trivially", "crowdgame"]
      if aboutPageContent.logos? and (l = aboutPageContent.logos[logoName])?
        this.utils().asyncImageLoad("backgroundImage", this["_#{logoName}_logo"], l, "#{logoName}_logo")          
    this

# ==================================================================================================================
class HtmlContentOptionsPage extends HtmlUtilityPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (pageManager)->

    super pageManager

    this

  # ----------------------------------------------------------------------------------------------------------------
  getElementNames: (elementNames = [])->
    e = [
      "content_options_page"
    ].concat(elementNames)

    super e

  # ----------------------------------------------------------------------------------------------------------------
  _getVisibilityElement: ()-> @_content_options_page

# ==================================================================================================================
class HtmlGameOptionsPage extends HtmlUtilityPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (pageManager)->

    super pageManager

    this

  # ----------------------------------------------------------------------------------------------------------------
  getElementNames: (elementNames = [])->
    e = [
      "game_options_page"
    ].concat(elementNames)

    super e

  # ----------------------------------------------------------------------------------------------------------------
  _getVisibilityElement: ()-> @_game_options_page

# ==================================================================================================================
class HtmlJoinCodeInfoPage extends HtmlUtilityPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (pageManager)->

    super pageManager

    this

  # ----------------------------------------------------------------------------------------------------------------
  getElementNames: (elementNames = [])->
    e = [
      "join_code_info_page"
    ].concat(elementNames)

    super e

  # ----------------------------------------------------------------------------------------------------------------
  _getVisibilityElement: ()-> @_join_code_info_page

 
# ==================================================================================================================

window.htmlPageManager = new HtmlPageManager()
