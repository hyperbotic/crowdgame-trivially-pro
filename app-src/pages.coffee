# ==================================================================================================================
#
#
# zIndex scheme:
#  windows: 1-10
#  page-owned stuff: 50-100
#  overlays, buttons, other clickbale stuff: 101+
#
# Lifecycle of a Page:
#   created
#   initialize
#   open
#   start
#    ...
#   close
#   stop
#
#   also:
#     pause
#     resumed
# 
class Page
  gInstanceCount = 0

  gPages = []

  @kWebViewZIndex = 50
  @kPageContainerZIndex = 100
  @kTouchZIndex = 1000
  @kOverlayZIndex = 900
  
  # ----------------------------------------------------------------------------------------------------------------
  @findPage: (pageClass)->
    for page in gPages
      if page.constructor.name is pageClass.name
        return page
    null
  # ----------------------------------------------------------------------------------------------------------------
  @getPage: (pageMap)->

    p = (Page.findPage(pageMap.pageClass)) || new pageMap.pageClass(pageMap.state, Hy.ConsoleApp.get())

    p

  # ----------------------------------------------------------------------------------------------------------------
  # NOT IMPLEMENTED
  @doneWithPage: (pageMap)->

    if (p = Page.findPage(pageMap.pageClass))
      gPages = gPages.reject(p)
      p.doneWithPage()

    null

  # ----------------------------------------------------------------------------------------------------------------
  @doneWithPages: ()->
    gPages = []
    null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@state, @app)->
    @instance = ++gInstanceCount

    @windowOpen = false

    gPages.push this

    options = 
      fullscreen: true
      zIndex: 2
      orientationModes: [Ti.UI.LANDSCAPE_LEFT, Ti.UI.LANDSCAPE_RIGHT]
      opacity: 0
      _tag: "Main Window"

    @window = new Hy.UI.WindowProxy(options)

    @window.addChild(@container = new Hy.UI.ViewProxy(this.containerOptions()))

#    @window.setTrace("opacity")

    @pageEnabled = true

    this

  # ----------------------------------------------------------------------------------------------------------------
  isWebContentPage: ()-> false

  # ----------------------------------------------------------------------------------------------------------------
  isPageEnabled: ()-> @pageEnabled

  # ----------------------------------------------------------------------------------------------------------------
  setPageEnabled: (enabled)-> 

    @pageEnabled = enabled

    this

  # ----------------------------------------------------------------------------------------------------------------
  getContainer: ()-> @container

  # ----------------------------------------------------------------------------------------------------------------
  addChild: (child, isTopLevel = false, addChildOptions = null)-> 
    this.getContainer().addChild(child, isTopLevel, addChildOptions)
    this

  # ----------------------------------------------------------------------------------------------------------------
  hasChild: (child)->
    this.getContainer().hasChild(child)

  # ----------------------------------------------------------------------------------------------------------------
  removeChild: (child)->
    this.getContainer().removeChild(child)
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    @allowEvents = false

    true

  # ----------------------------------------------------------------------------------------------------------------
  getPath: (searchPath = [], kind = null)->

    Hy.Customize.path(this, searchPath, kind)

  # ----------------------------------------------------------------------------------------------------------------
  getAllowEvents: ()-> @allowEvents

  # ----------------------------------------------------------------------------------------------------------------
  getState: ()-> @state

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()->
    name = if (state = this.getState())?
      PageState.getPageName(state)
    else
      null

    name

  # ----------------------------------------------------------------------------------------------------------------
  getCustomizeName: ()->
    this.getDisplayName()

  # ----------------------------------------------------------------------------------------------------------------
  getDisplayName: ()->
    name = if (state = this.getState())?
      PageState.getPageDisplayName(state)
    else
      null

    name

  # ----------------------------------------------------------------------------------------------------------------
  setState: (state)-> @state = state

  # ----------------------------------------------------------------------------------------------------------------
  getWindow: ()->@window

  # ----------------------------------------------------------------------------------------------------------------
  getApp: ()-> @app

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (evt)->

    this

  # ----------------------------------------------------------------------------------------------------------------  
  openWindow: (options={})->

    if @windowOpen
      # It seems that if the window is already open, then any requested animations
      # won't be executed. So work around that here.
      this.animateWindow(options)
    else
      @windowOpen = true
      @window.open(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  closeWindow: (options={})->

    Hy.Trace.debug("Page::closeWindow")

    @windowOpen = false

    @window.close()

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateWindow: (options)-> # 2.5.0
    @window.animate(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    @allowEvents = true

    Hy.Network.NetworkService.addObserver this

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    @allowEvents = false

    Hy.Network.NetworkService.removeObserver this

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  containerOptions: ()->

    top: 0
    left: 0
    width: Hy.UI.iPad.screenWidth # must set these, else _layout{vertical, horizontal} directives wont work
    height: Hy.UI.iPad.screenHeight
    zIndex: Page.kPageContainerZIndex
    _tag: "Main Container"

# ==================================================================================================================
#
# Adds "Standard Buttons" support
#

class ContentPage extends Page

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->
    super state, app

    @standardButtons = null

    this.addStandardButtons(this.getStandardButtonSpecs())

    this

  # ----------------------------------------------------------------------------------------------------------------
  setPageEnabled: (enabled)-> 

    super

    this.doStandardButtons("setEnabled", enabled)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getStandardButtonsOptions: ()->

    options =
      width: this.getContainer().getUIProperty("width")
      bottom: 50
      left: 0

    options

  # ----------------------------------------------------------------------------------------------------------------
  getStandardButtons: ()-> @standardButtons

  # ----------------------------------------------------------------------------------------------------------------
  getStandardButtonsChildOptions: ()-> {_horizontalLayout: "center"}

  # ----------------------------------------------------------------------------------------------------------------
  addToStandardButtonContainer: (standardButtons)->

    this.addChild(standardButtons, false, this.getStandardButtonsChildOptions())

  # ----------------------------------------------------------------------------------------------------------------
  addStandardButtons: (standardButtonSpecs)->

    if standardButtonSpecs? and not @standardButtons?
      this.addToStandardButtonContainer(@standardButtons = new Hy.Panels.UtilityButtonsPanel(this, this.getStandardButtonsOptions(), standardButtonSpecs))

    this

  # ----------------------------------------------------------------------------------------------------------------
  getStandardButtonSpecs: ()-> null

  # ----------------------------------------------------------------------------------------------------------------
  doStandardButtons: (action, options = {})->
    if @standardButtons? and @standardButtons[action]?
      @standardButtons[action](options)
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    this.doStandardButtons("initialize")

    true

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (evt)->

    super evt

    this.doStandardButtons("obs_networkChanged", evt)

    this

  # ----------------------------------------------------------------------------------------------------------------  
  openWindow: (options={})->

    super options

    this.doStandardButtons("open", options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  closeWindow: (options={})->

    super options

    this.doStandardButtons("close", options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    super

    this.doStandardButtons("start")

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this.doStandardButtons("stop")

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    this.doStandardButtons("pause")

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    this.doStandardButtons("resumed")

    this

# ==================================================================================================================
#
# Adds WebView-based page support, with support for customizable background, and optional
# CrowdGame logo
#

class WebContentPage extends ContentPage

  # Instances of this class share a single WebView panel
  # So it's important to be careful about any page-local state... (i.e., there shouldn't be any)
  gWebView = null
  gWebViewLoaded = false

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    @currentCustomization = null
    @currentSingleUserMode = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  isWebContentPage: ()-> true

  # ----------------------------------------------------------------------------------------------------------------
  webViewOptions: ()->

    options = this.containerOptions()

    webViewOptions =
      url:              "app-pages.html"
      top:              options.top
      left:             options.left
      width:            options.width
      height:           options.height
      _tag:             "Web View #{this.getDisplayName()}"
      scalesPageToFit:  false
      backgroundColor:  'transparent' 
      # http://developer.appcelerator.com/question/45491/can-i-change-the-white-background-that-shows-when-a-web-view-is-loading

    webViewOptions

  # ----------------------------------------------------------------------------------------------------------------
  addWebView: (fnLoaded = null)->

    if not gWebView?
      options = this.containerOptions()
      options._tag = "WebViewPanel"
      Hy.Trace.debug("WebContentPage::addWebView (creating web view)")
      gWebView = new Hy.Panels.WebViewPanel(this, options, this.webViewOptions())

    Hy.Trace.debug("WebContentPage::addWebView (adding web view #{this.hasChild(gWebView)})")

    # Trivially Pro v1.1.0: Apparently, something changed with Titanium, and now just adding
    # a pre-existing web view as a child view causes a page loaded event.
    #
    if this.hasChild(gWebView)
      fnLoaded?()
    else
      this.addChild(gWebView)
      gWebView.initialize(()=>this.webViewLoaded(fnLoaded))

    this

  # ----------------------------------------------------------------------------------------------------------------
  closeWindow: (options = {})->

    if gWebView?
      Hy.Trace.debug("WebContentPage::closeWindow (removing web view)")
      this.removeChild(gWebView)
    super options
    this

  # ----------------------------------------------------------------------------------------------------------------
  animateWindow: (options)-> # 2.5.0

    if (o = options.opacity)?
      if o isnt 1  # Test optimization
        this.pokeWebView("activePageOpacity", {opacity: options.opacity})
   
    @window.animate(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewIsLoaded: ()-> gWebViewLoaded

  # ----------------------------------------------------------------------------------------------------------------
  # Returns true if the current customization is the same as was used the last time the page was
  # initialized.
  #
  isSameCustomization: ()->

    @currentCustomization? and (@currentCustomization is Hy.Customize.getCurrentCustomization())

  # ----------------------------------------------------------------------------------------------------------------
  isSameSingleUserMode: ()-> 

    @currentSingleUserMode? and (@currentSingleUserMode is Hy.Network.PlayerNetwork.isSingleUserMode)

  # ----------------------------------------------------------------------------------------------------------------
  # 1. If web view hasn't been created, fire that event and wait for it to return
  # 2. If this specific page needs the web view to be further initialized, fire that
  #    event and wait for it to return
  # 3. When all is done, resume page initialization
  #
  initialize: ()->

    fn_ready = ()=> 
      Hy.Trace.debug "WebContentPage::initialize.fn_ready"
      this.initializeResume()
      null

    fn_initForCurrentPage = (iwv)=>
      Hy.Trace.debug "WebContentPage::initialize.fn_initForCurrentPage (iwv=#{iwv})"

      if iwv
        this.initializeWebViewForCurrentPage(()=>fn_ready()) # will call fn_ready when ready
        @currentCustomization = Hy.Customize.getCurrentCustomization()
      null

    super

    # If set, need to wait for the web view to be created
    waitForWebViewCreate = not this.webViewIsLoaded()

    # If set, need to wait for the web view to initialize
    initializeWebView = this.shouldInitializeWebViewForCurrentPage()

    Hy.Trace.debug "WebContentPage::initialize (waitForWebViewCreate=#{waitForWebViewCreate} initializeWebView=#{initializeWebView})"

    this.addWebView(()=>fn_initForCurrentPage(initializeWebView))

    # return false if we need to wait for the webview
    not (waitForWebViewCreate or initializeWebView)

  # ----------------------------------------------------------------------------------------------------------------
  # Page is now ready... let the show continue
  #
  # NOTE: There's the possibility for a subtle timing bug here. It could happen that the web view
  #       returns very quickly, before, in fact, the PageState loop has moved into the wait state
  #       (i.e., the page.initialize function call hasn't yet returned "false"), and if that 
  #       happens, something wierd will happen with the "resumed" call below)
  #
  initializeResume: ()->

    Hy.Trace.debug "WebContentPage::initializeResume"

    Hy.Utils.Deferral.create(0, ()=>PageState.get().resumed())
    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewLoaded: (fn_loaded = null)->

    gWebView.show() # Is this needed?

    gWebViewLoaded = true

    fn_loaded?()

    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewReady: (event = null)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Returns true if the webView should be initialized
  #
  shouldInitializeWebViewForCurrentPage: ()-> true

  # ----------------------------------------------------------------------------------------------------------------
  # Tell WebView to set the html page up for the current page
  #
  initializeWebViewForCurrentPage: (fnReady)->

    _fnReady = (e)=>
      this.webViewReady(e)    
      fnReady()
      null

    Hy.Trace.debug "WebContentPage::initializeWebViewForCurrentPage"

    if (data = this.webViewOptionsForCurrentPage())?
      this.pokeWebView("initializeWebViewForPage", data, (e)=>_fnReady(e))
      null
    else
      _fnReady()

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  #
  webViewOptionsForCurrentPage: (data = null)->

    this.addDataSection(data, "customize", "general", this.customizeGeneral())

    data

  # ----------------------------------------------------------------------------------------------------------------
  pokeWebView: (kind, data = {}, fn_callback = null)->

    Hy.Trace.debug "WebContentPage::pokeWebView #{kind}"

    gWebView.fireEvent({kind: kind, pageName: this.getName(), data: data}, if fn_callback? then ((e)=>fn_callback(e)) else null)
    this

  # ----------------------------------------------------------------------------------------------------------------
  addDataSection: (data = null, sectionKind, sectionName, sectionData = null)->

    if sectionData?
      if not data?
        data = {}

      if not data[sectionKind]?
        data[sectionKind] = {}

      section = data[sectionKind]

      section[sectionName] = sectionData

    data

  # ----------------------------------------------------------------------------------------------------------------
  addCustomizationValue: (customization, path = null, value)->

    fn_pathname = (customization, path)=>
      cssPropPath = ""
      if path.pageName?
        cssPropPath = "#{cssPropPath}#{path.pageName}."

      for e in path.intermediate
        cssPropPath = "#{cssPropPath}#{e}."

      cssPropPath = "#{cssPropPath}#{customization}".toLowerCase()

      cssPropPath

    if value
      {name: fn_pathname(customization, path), value: value}
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  addCustomization: (customization, path = null, defaultValue = null, fn_pack = null)->

    c = if (c = Hy.Customize.map(customization, path, defaultValue))?
      this.addCustomizationValue(customization, path, if fn_pack? then fn_pack(c) else c)
    else
      null

    c

  # ----------------------------------------------------------------------------------------------------------------  
  customizeGeneral: ()->

    customizations = null

    fn_push = (customization = null)=>
      if customization?
        customizations.push customization
      null

    customizations = []
    path = this.getPath()

    fn_push this.addCustomizationValue("singleuser", this.getPath(), (@currentSingleUserMode = Hy.Network.PlayerNetwork.isSingleUserMode()))

    fn_push this.addCustomization("bordercolor", path)

    # If a background image is specified, it overrides a background color, if specified.
    if (value = Hy.Customize.map("background.url", path))?
      fn_push this.addCustomizationValue("background.url", path, value)
    else
      if (value = Hy.Customize.map("background.color", path))?
        fn_push this.addCustomizationValue("background.color", path, value)
      else
        fn_push this.addCustomizationValue("background.url", path, "assets/bkgnds/stage-no-curtain.png")

    customizations

# ==================================================================================================================
#
# Adds customizable Logo support
#

class WebContentExPage extends WebContentPage

  kDefaultLogoWidth = 400  # .logoImageClass
  kDefaultLogoHeight = 100
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewOptionsForCurrentPage: (data = {})->

    this.addDataSection(data, "customize", "logos", this.customizeLogos())

    super data

    data

  # ----------------------------------------------------------------------------------------------------------------
  getLogoPath: (logoName)->

    # A little funky... "logo1" as a "kind" and as a specific instance
    this.getPath([logoName], logoName)

  # ----------------------------------------------------------------------------------------------------------------
  # Logos are shared by all of the pages in the WebView. So we always send customization over
  #
  customizeLogos: ()->

    customizations = []

    for logoName in ["logo1", "logo2"]
      if (options = this.getLogoOptions(logoName))?
        customizations = customizations.concat this.customizeLogo(logoName, options)

    customizations

  # ----------------------------------------------------------------------------------------------------------------
  # true if the customization triggers the need to actually show a logo
  # currently: only if text or background.url are specified
  #
  requiresCustomLogo: (logoName)->
   
    Hy.Customize.required(logoName, this.getLogoPath(logoName))

  # ----------------------------------------------------------------------------------------------------------------
  # true if the customization specifies changes to a logo, such as borderColor.
  # This is not the same as triggering the actual appearance of a log (see above)
  #
  # Note that we don't trigger by "font.*" here, since our default logos are images
  #
  hasLogoCustomization: (logoName, additionalProps = [])->

    props = ["bordercolor", "background.color", "background.url", "align", "size", "position"].concat(additionalProps)
    Hy.Customize.has(props, this.getLogoPath(logoName))

  # ----------------------------------------------------------------------------------------------------------------
  getDefaultLogoOptions: (logoName)->

    # need to make sure that we set width and height, if anything
    defaultOptions = 
      width:  kDefaultLogoWidth
      height: kDefaultLogoHeight

    switch logoName
      when "logo1"
        defaultOptions.top = 20

      when "logo2"
        defaultOptions.bottom = 20
    
    defaultOptions

  # ----------------------------------------------------------------------------------------------------------------
  getLogoOptions: (logoName)->

    defaultOptions = this.getDefaultLogoOptions(logoName)
    requiresCustLogo = this.requiresCustomLogo(logoName)
    hasLogoCust = this.hasLogoCustomization(logoName)

    options = switch logoName
      when "logo1" # Assume that all pages have a default logo unless otherwise specified

        # If there's been any customization, don't show the default logo.
        if not requiresCustLogo and not hasLogoCust
          defaultOptions.url = "assets/icons/label-TriviallyPro.png" 
          defaultOptions.width = 315
          defaultOptions.height = 100

        defaultOptions

      when "logo2" # Only show a logo if one provided via customization
        if requiresCustLogo
          defaultOptions
        else
          null

    options

  # ----------------------------------------------------------------------------------------------------------------
  customizeLogo: (logoName, options)->

    customizations = []

    fn_push = (customization = null)=>
      if customization?
        customizations.push customization
      null

    path = this.getLogoPath(logoName)

    # Size 
    sizeAndPosition = _.pick(options, "width", "height")
    Hy.Customize.mapOptions(["size"], path, sizeAndPosition)

    # Position
    position = Hy.Customize.map("position", path)

    dimensions = if position? and (position.isDirective("left", "center") or position.isDirective("right", "center"))
        # code on the html page will center it horizontally by default, so just process vertical 
        ["top", "bottom"]
    else
      ["top", "bottom", "left", "right"]

    for d in dimensions
      sizeAndPosition[d] = if (v = options[d])? then v else null

    Hy.Customize.mapOptions(["position"], path, sizeAndPosition)

    fn_push this.addCustomizationValue("_sizeAndPosition", path, sizeAndPosition)

    # background.{URL, color}
    fn_push this.addCustomization("background.url", path, options.url)
    backgroundColor = Hy.UI.Colors.mapTransparent(Hy.Customize.map("background.color", path)) # handle transparency
    fn_push this.addCustomizationValue("background.color", path, backgroundColor)

    # text
    fn_push this.addCustomization("text", path, options.text)

    # alignment
    fn_push this.addCustomization("align", path)

    if (borderColor = Hy.Customize.map("bordercolor", path))? 
      borderColor = Hy.UI.Colors.mapTransparent(borderColor) # handle transparency
      fn_push this.addCustomizationValue("bordercolor", path, borderColor)

    # font
    fn_push this.addCustomization("font.color",  path)
    fn_push this.addCustomization("font.name",   path)
    fn_push this.addCustomization("font.style",  path)
    fn_push this.addCustomization("font.weight", path)
    fn_push this.addCustomization("font.size",   path, options.fontSize)

    customizations

# ==================================================================================================================

  # ----------------------------------------------------------------------------------------------------------------
  # Bummed. Steve Jobs just died. 2011 Oct 5.
  # ----------------------------------------------------------------------------------------------------------------

# ==================================================================================================================
#
# Support for panels
#
class UtilityPage extends WebContentExPage

  UtilityPage.kBackgroundWidth = 700
  UtilityPage.kBackgroundHeight = 400
  UtilityPage.kBackgroundTop = 130
  UtilityPage.kBackgroundLeft = UtilityPage.kBackgroundRight = (Hy.UI.iPad.screenWidth - UtilityPage.kBackgroundWidth)/2
  UtilityPage.kBackgroundBottom = Hy.UI.iPad.screenHeight - (UtilityPage.kBackgroundHeight + UtilityPage.kBackgroundTop)
  UtilityPage.kPadding = 5

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    @subpanels = []

    super state, app

    this.addBackgroundPanel()
        .addSubpanel(this.createTitle())

    this

  # ----------------------------------------------------------------------------------------------------------------
  # "UtilityPage" is how customizations refer to all subclasses of this class
  #
  getCustomizeName: ()->
    "UtilityPage"

  # ----------------------------------------------------------------------------------------------------------------
  getLogoOptions: (logoName)->

    # Only show the default Trivially logo if there's no customization

    options = if this.hasLogoCustomization(logoName)
      null
    else
      super logoName

    options

  # ----------------------------------------------------------------------------------------------------------------
  getBackgroundPanelOptions: ()->

    options = 
      top: UtilityPage.kBackgroundTop
      height: UtilityPage.kBackgroundHeight
      width: UtilityPage.kBackgroundWidth
      left: UtilityPage.kBackgroundLeft
      borderRadius: 16
      zIndex: Page.kPageContainerZIndex + 1
      _tag: "UtilityPageBackgroundPanel"
      borderColor: (bc = Hy.UI.Colors.mapTransparent(Hy.Customize.map("bordercolor", this.getPath(), Hy.UI.Colors.black))) # handle transparency
      borderWidth: if bc then 3 else 0
      backgroundColor: Hy.UI.Colors.black

    options

  # ----------------------------------------------------------------------------------------------------------------
  addBackgroundPanel: ()->

    if (options = this.getBackgroundPanelOptions())?
      this.addChild(new Hy.UI.ViewProxy(options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  createTitle: (options = {}, text = null)->

    panel = null

    if text?
      fn = ()=>
        spec = 
          text: text
          options:
            textAlign: "center"
            color: Hy.UI.Colors.MrF.DarkBlue
            font: Hy.UI.Fonts.specBigNormal

        Hy.Customize.mapOptions(["font"], this.getPath(), spec.options)
        spec

      panel = new Hy.Panels.UtilityTextPanel(this, options, (()=>[fn()]), false)

    panel

  # ----------------------------------------------------------------------------------------------------------------
  addSubpanel: (subpanel=null, options = {})->

    if subpanel?
      this.addChild(subpanel, null, {_horizontalLayout: "center"})

      subpanel.setUIProperty("zIndex", Page.kPageContainerZIndex + 1)

      top = UtilityPage.kBackgroundTop

      for s in @subpanels
        top += UtilityPage.kPadding + s.panel.getUIProperty("height")
      top += UtilityPage.kPadding

      subpanel.setUIProperty("top", top)

      # options:
      #   options.exclude = [array of method names to NOT invoke in a "doPanels" call]
      #
      @subpanels.push {panel: subpanel, options: options}

    this

  # ----------------------------------------------------------------------------------------------------------------
  doPanels: (action, options = null)->

    for panel in @subpanels

      execute = if (exclude = panel.options.exclude)?
        exclude.indexOf(action) is -1
      else
        true
 
      if execute
        panel.panel[action]?(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getStandardButtonSpecs: ()->

    backButtonSpec = 
      name: "Back"
      buttonOptions:
        _style: "round"
        _size: "medium"
        _text: "Back"
      text: "Return To\nStart Page"
      fnClick: ()=> this.getApp().showStartPage()

    helpButtonSpec = 
      name: "Help"
      buttonOptions: 
        _style: "round"
        _size: "medium"
        _text: "Help"
#        _font: Hy.UI.ButtonProxy.mergeDefaultFont({fontSize: 36}, "medium")
      text: "Get Help\nOn The Web"
      fnClick: ()=> this.launchURL(this.getHelpButtonURL())

    [backButtonSpec, helpButtonSpec]

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    f = super

    this.doPanels("initialize")

    f

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super
    this.doPanels("start")

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    super
    this.doPanels("stop")

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    super
    this.doPanels("pause")
    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super
    this.doPanels("resumed")
    this

  # ----------------------------------------------------------------------------------------------------------------
  openWindow: (options={})->

    super options

    this.doPanels("open", options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  closeWindow: (options={})->

    this.doPanels("close", options)

    super options

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (evt)->

    super

    this.doPanels("obs_networkChanged", evt)

    this

  # ----------------------------------------------------------------------------------------------------------------
  launchURL: (url)->

    Ti.Platform.openURL(url)

    this.setPageEnabled(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getHelpButtonURL: ()-> Hy.Config.kHelpPage

# ==================================================================================================================
class ContentOptionsPage extends UtilityPage

  _.extend ContentOptionsPage, Hy.Utils.Observable 

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    @contentOptionsPanel = null
    @contentOptionsPanelStartState = "not initialized"

    this

  # ----------------------------------------------------------------------------------------------------------------
  getBackgroundPanelOptions: ()->

    options = super

    options.height = Hy.Panels.ContentOptionsPanel.kHeight + (2 * UtilityPage.kPadding)

    options

  # ----------------------------------------------------------------------------------------------------------------
  createTitle: ()->

    super null, null # No title

  # ----------------------------------------------------------------------------------------------------------------
  getStandardButtonSpecs: ()->

    _size = "medium"
    buttonFont = Hy.UI.ButtonProxy.mergeDefaultFontSize(17, _size)

    fn_userCreatedContentAction = (action)=>
      # If we're looking at detail for a content pack, pop back a bit first
      @contentOptionsPanel?.getNavGroup().dismiss(true, "_root")
      this.getApp().userCreatedContentAction(action)
      null

    backButtonSpec = 
      name: "Back"
      buttonOptions:
        _style: "round"
        _size: _size
        _text: "Back"
        font: buttonFont
      text: "Return To\nStart Page"
      fnClick: ()=>this.getApp().showStartPage()

    addButtonSpec = 
      name: "Add"
      buttonOptions: 
        _style: "round"
        _size: _size
        _text: "Add"
        font: buttonFont
      text: "Add Content"
      fnClick: ()=>fn_userCreatedContentAction("add")

    buyButtonSpec = 
      name: "Buy"
      buttonOptions: 
        _style: "round"
        _size: _size
        _text: "Buy"
        font: buttonFont
      text: "Buy Now"
      fnClick: ()=>fn_userCreatedContentAction("buy")

    browseSamplesButtonSpec = 
      name: "Samples"
      buttonOptions: 
        _style: "round"
        _size: _size
        _text: "Samples"
        font: buttonFont
      text: "Load Sample\nContests"
      fnClick: ()=>fn_userCreatedContentAction("samples")

    helpButtonSpec = 
      name: "Help"
      buttonOptions: 
        _style: "round"
        _size: _size
        _text: "Help"
        font: buttonFont
      text: "Get Help\nOn The Web"
      fnClick: ()=> this.launchURL(this.getHelpButtonURL())

    buttons = []
    buttons.push backButtonSpec

    buttons.push addButtonSpec # TODO - check if purchases?

    if not Hy.Config.Commerce.kPurchaseTEST_dontShowBuy
      buttons.push buyButtonSpec

    if Hy.Update.SamplesUpdate.getSamplesUpdate()?
      buttons.push browseSamplesButtonSpec

    buttons.push helpButtonSpec

    buttons

  # ----------------------------------------------------------------------------------------------------------------
  getHelpButtonURL: ()-> Hy.Config.Content.kHelpPage

  # ----------------------------------------------------------------------------------------------------------------
  addContentOptions: ()->

    options = {}

    # so that we can create it, initialize it, and start it asynchronously in "initialize"
    # Ordinarily, "initialize" and "start" would be called by superclass UtilityPage automatically
    subpanelOptions = {exclude: ["initialize", "start"]} 
    
    this.addSubpanel(@contentOptionsPanel = new Hy.Panels.ContentOptionsPanel(this, options), subpanelOptions)

    # Setup the navGroup on the ContentOptionsPanel, now that "top" has been set
    @contentOptionsPanel.addNavGroup()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    f = super

    if @contentOptionsPanel?
      @contentOptionsPanel.initialize()
      @contentOptionsPanelStartState = "ready for start"

    f

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    fn_createContentOptionsPanel = ()=>
      this.addContentOptions()

      @contentOptionsPanel.initialize()
      @contentOptionsPanelStartState = "starting"
      @contentOptionsPanel.start()
      @contentOptionsPanelStartState = "started"
      null

    super

    if @contentOptionsPanel?
      if @contentOptionsPanelStartState is "ready for start"
        @contentOptionsPanel.start()
        @contentOptionsPanelStartState = "started"
    else
      Hy.Utils.Deferral.create(100, ()=>fn_createContentOptionsPanel())


    # Hy.Options.contentPacks.addEventListener 'change', @fnContentPacksChanged # No longer needed?

    Hy.Content.ContentManager.addObserver this # Tracking inventory changes
    Hy.Content.ContentManagerActivity.addObserver this # ContentPack updates

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    super

    # Hy.Options.contentPacks.removeEventListener 'change', @fnContentPacksChanged # No longer needed?

    Hy.Content.ContentManager.removeObserver this
    Hy.Content.ContentManagerActivity.removeObserver this

    Hy.Update.Update.removeObserver this

    this

  # ----------------------------------------------------------------------------------------------------------------
  setPageEnabled: (enabled)-> 

    super enabled

    if enabled
      this.updateContentOptions()
    else
      # disable contentOptionsPanel?
      # May not have to worry about this, since the PopOver is sited directly over it...
      null

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # TODO
  #
  updateContentOptions: ()->

#    if this.isPageEnabled()
#      isPurchased = Hy.Content.ContentManager.get().getUCCPurchaseItem().isPurchased()
#      buyButton?.setEnabled(not isPurchased)
#      addButton?.setEnabled(isPurchased)
#      infoButton?.setEnabled(true)
#    else
#      buyButton?.setEnabled(false)
#      addButton?.setEnabled(false)
#      infoButton?.setEnabled(false)

    @contentOptionsPanel?.update()

    this
      
    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_contentUpdateSessionStarted: (label, report)->

    this.setPageEnabled(false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_userCreatedContentSessionStarted: (label, report = null)->

    this.setPageEnabled(false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_userCreatedContentSessionProgressReport: (report = null)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_userCreatedContentSessionCompleted: (report = null, changes = false)->

    this.setPageEnabled(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_contentUpdateSessionProgressReport: (report, percentDone = -1)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_contentUpdateSessionCompleted: (report, changes)->

    this.setPageEnabled(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryInitiated: ()->

    this
  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryUpdate: (status, message)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryCompleted: (status, message)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_purchaseInitiated: (label, report)->

    this.setPageEnabled(false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_purchaseProgressReport: (report)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_purchaseCompleted: (report)->

    this.setPageEnabled(true)

    this

# =================================================================================================================
class JoinCodeInfoPage extends UtilityPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    this.addSubpanel(this.createJoinAdvicePanel())

    this.addSubpanel(this.createJoinCodePanel())
    this.addSubpanel(this.createJoinURLPanel())
#    this.addSubpanel(this.createPlayerStage())

    this

  # ----------------------------------------------------------------------------------------------------------------
  getHelpButtonURL: ()-> Hy.Config.PlayerNetwork.kHelpPage

  # ----------------------------------------------------------------------------------------------------------------
  getJoinInfo: ()->

    color = Hy.UI.Colors.black
    code = ""
    advice = ""

    if Hy.Network.NetworkService.isOnline()
      joinSpec = Hy.Network.PlayerNetwork.getJoinSpec()
      switch Hy.Network.PlayerNetwork.getStatus()
        when "uninitialized", "initializing"
          color = Hy.UI.Colors.MrF.Red
          code = "?"
          advice = "#{Hy.Config.DisplayName} is connecting to #{Hy.Network.PlayerNetwork.getJoinSpecDisplayRendezvousURL()}..."
        when "initialized"
          if joinSpec?
            code = joinSpec.displayCode
            advice = "Each player should visit #{joinSpec.displayURL} and enter code:"
          else
            color = Hy.UI.Colors.MrF.Red
            code = "?"
            advice = "#{Hy.Config.DisplayName} is reconnecting to #{Hy.Network.PlayerNetwork.getJoinSpecDisplayRendezvousURL()}..."
        else
          color = Hy.UI.Colors.MrF.Red
          joinCode = if joinSpec?
            joinSpec.displayCode
          else
            "?"
          advice = "Please connect this iPad to the Web and restart Trivially Pro"
    else
      color = Hy.UI.Colors.MrF.Red
      advice = "This iPad must also be connected to the Web (it isn\'t currently)"
      code = "?"

    {
      URL: {text: "#{Hy.Network.PlayerNetwork.getJoinSpecDisplayRendezvousURL()}", options: {textAlign: "center", color: color}}
      code: {text: code, options: {textAlign: "center", color: color, font: Hy.UI.Fonts.specMediumCode}}
      advice: {text: advice, options: {textAlign: "center", color: color}}
    }

  # ----------------------------------------------------------------------------------------------------------------
  createJoinCodePanel: ()->

    options =
      borderWidth: 1
      borderColor: Hy.UI.Colors.red

    new Hy.Panels.UtilityTextPanel(this, options, (()=>[this.getJoinInfo().code]), true)

  # ----------------------------------------------------------------------------------------------------------------
  createJoinURLPanel: ()->

    options =
      borderWidth: 1
      borderColor: Hy.UI.Colors.red

    new Hy.Panels.UtilityTextPanel(this, options, (()=>[this.getJoinInfo().URL]), true)

  # ----------------------------------------------------------------------------------------------------------------
  createJoinAdvicePanel: ()->

    options =
      borderWidth: 1
      borderColor: Hy.UI.Colors.red

    new Hy.Panels.UtilityTextPanel(this, options, (()=>[this.getJoinInfo().advice]), true)

  # ----------------------------------------------------------------------------------------------------------------
  createPlayerStage: ()->

    options = 
      left: 0
      bottom: 0

    new Hy.Panels.CheckInCritterPanel(this, options)

# ==================================================================================================================
class GameOptionsPage extends UtilityPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    @gameOptionPanelsContainer = null
    @gameOptionsPanelContainerStartState = "not initialized"
    this

  # ----------------------------------------------------------------------------------------------------------------
  getHelpButtonURL: ()-> Hy.Config.kHelpPage

  # ----------------------------------------------------------------------------------------------------------------
  createTitle: ()->

    super {}, "Game Options"

  # ----------------------------------------------------------------------------------------------------------------
  syncOptions: ()->
    if @panelSound?
      @panelSound.syncCurrentChoiceWithAppOption()
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    f = super

    if @gameOptionPanelsContainer?
      @gameOptionPanelsContainer.initialize()
      @gameOptionsPanelContainerStartState = "ready for start"
      this.syncOptions()

    f

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    fn_createGameOptionPanels = ()=>
      this.addGameOptionPanels()
      @gameOptionPanelsContainer.initialize()
      @gameOptionsPanelContainerStartState = "starting"
      @gameOptionPanelsContainer.start()
      @gameOptionsPanelContainerStartState = "started"
      this.syncOptions()
      null

    super

    if @gameOptionPanelsContainer?
      if @gameOptionsPanelContainerStartState is "ready for start"
        @gameOptionPanelsContainer.start()
        @gameOptionsPanelContainerStartState = "started"
    else
      Hy.Utils.Deferral.create(10, ()=>fn_createGameOptionPanels())

    this

  # ----------------------------------------------------------------------------------------------------------------
  addGameOptionPanels: ()->

    left = 0
    padding = 60

    panelSpecs = [
      {varName: "panelSound",              fnName: "createSoundPanel",                   options: {left: left}},
      {varName: "panelNumberOfQuestions",  fnName: "createNumberOfQuestionsPanel",       options: {left: left}},
      {varName: "panelSecondsPerQuestion", fnName: "createSecondsPerQuestionPanel",      options: {left: left}}
      ]

    if not Hy.Config.PlayerNetwork.kSingleUserModeOverride
      panelSpecs.push {varName: "panelFirstCorrect", fnName: "createFirstCorrectPanel", options: {left: left}}

    panelsContainerOptions = 
      zIndex: Page.kPageContainerZIndex + 1
      
    @gameOptionPanelsContainer = new Hy.UI.ViewProxy(panelsContainerOptions)

    # Really shouldn't have to do this. Why doesn't "conformToChildren" work?
    panelsMaxWidth = 0
    top = 0

    for panelSpec in panelSpecs
      panel = this[panelSpec.varName] = Hy.Panels.OptionPanels[panelSpec.fnName](this, Hy.UI.ViewProxy.mergeOptions(panelSpec.options, {top: top}))

      panelsMaxWidth = Math.max(panelsMaxWidth, panel.getUIProperty("width"))
      @gameOptionPanelsContainer.addChild(panel)

      top += padding

    morePanelContainerOptions = 
      left: (this.getContainer().getUIProperty("width")-panelsMaxWidth)/2
      height: top
      width: panelsMaxWidth

    @gameOptionPanelsContainer.setUIProperties(morePanelContainerOptions)

    this.addSubpanel(@gameOptionPanelsContainer, {exclude: ["initialize", "start"]})

    this

# ==================================================================================================================
class StartPage extends WebContentExPage

  _.extend StartPage, Hy.Utils.Observable # For changes to the state of the Start button

  kDefaultStartButtonPadding = 10

  kDefaultStartButtonSize = 110
  kDefaultStartButtonCustomizedSize = "jumbo"

  # Code assumes that this text is always wider than the button
  kDefaultStartButtonTextWidth = 220
  kDefaultStartButtonTextHeight = 50

  kDefaultStartButtonContainerTop = 190
  kDefaultStartButtonContainerLeft = 140

  kDefaultStartButtonContentOptionsInfoWidth = 70

  kStandardButtonPanelWidthForStartPage = 700

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    @startEnabled = {state: false, reason: null}

    # Just creates the container, so that the standard buttons have somewhere to go
    # Need to do this before the standard buttons are added

    this.prepStartButtonGroup()

    super state, app

    this.initStartButtonGroup((evt)=>this.startClicked())

    this.addJoinCodeInfo()
        .adjustJoinCodeInfo()

  #    @message = new Hy.Panels.MessageMarquee(this, this.getContainer()) # TODO

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDefaultLogoOptions: (logoName)->

    defaultOptions = super logoName

    switch logoName
      when "logo1"
        # "What, the curtains?!"
        defaultOptions.top = 80

    defaultOptions

  # ----------------------------------------------------------------------------------------------------------------
  setPageEnabled: (enabled)-> 

    super enabled
   
    StartPage.notifyObservers (observer)=>observer.obs_startPagePageEnabledStateChange?(this.isPageEnabled)

    this    

  # ----------------------------------------------------------------------------------------------------------------
  getStandardButtonsOptions: ()->

    options =
      width: kStandardButtonPanelWidthForStartPage
      zIndex: Page.kTouchZIndex
      bottom: 50
      left: 0
      top: 0
      borderColor: Hy.UI.Colors.red
      borderWidth: 1

    Hy.UI.ViewProxy.mergeOptions(super, options)

  # ----------------------------------------------------------------------------------------------------------------
  getStandardButtonSpecs: ()->

#    _size = "small"
    _size = "medium"

    buttonFont = Hy.UI.ButtonProxy.mergeDefaultFontSize(12, _size)
    labelFont = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specMediumNormal, {fontSize: 14})

    contentOptionsButtonSpec = 
      name: "Content"
      buttonOptions: 
        _style: "round"
        _size: _size
        _text: Hy.Localization.T("content", "Content")
        font: buttonFont
      text: Hy.Localization.T("add-select-trivia", "add & select trivia packs")
      font: labelFont
      fnClick: ()=> this.getApp().userCreatedContentAction("info")

    gameOptionsButtonSpec = 
      name: "Options"
      buttonOptions: 
        _style: "round"
        _size: _size
        _text: Hy.Localization.T("options", "Options")
        font: buttonFont
      text: Hy.Localization.T("change-game-settings", "change game settings")
      font: labelFont
      fnClick: ()=> this.getApp().showGameOptionsPage()

    helpButtonSpec = 
      name: "Help"
      buttonOptions:
        _style: "round"
        _size: _size
        _text: Hy.Localization.T("help", "Help")
        font: buttonFont
      text: ""
      font: labelFont
      fnClick: ()=> this.getApp().showAboutPage()

    [contentOptionsButtonSpec, gameOptionsButtonSpec, helpButtonSpec]

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    super

    Hy.Content.ContentManager.addObserver this # Tracking inventory changes
    Hy.Update.Update.addObserver this # as updates become available: "obs_updateAvailable"

    @message?.start()

    # Check for required or strongly-urged content or app updates, which appear to the user
    # as a popover, which either allows dismissal, with frequent reminders, or which can't be dismissed, in 
    # the case of required updates.
    # First, make sure we're online and not otherwise busy
    if not Hy.Pages.PageState.get().hasPostFunctions() and Hy.Network.NetworkService.isOnline() 
      if not Hy.Content.ContentManager.get().doUpdateChecks() # Do update checks first
        if not Hy.Update.ConsoleAppUpdate.getUpdate()?.doRequiredUpdateCheck() # Then app updates
          Hy.Update.RateAppReminder.getUpdate()?.doRateAppReminderCheck() # Then rate app requests

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    Hy.Content.ContentManager.removeObserver this
    Hy.Update.Update.removeObserver this

    @message?.stop()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    @message?.pause()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    super

    @message?.resumed()

    # If our state shows that the Start Button was clicked, and we're being resumed, then
    # it's likely that we were backgrounded while preparing a contest. So just reset state and let
    # the user tap the button again if so inclined
    if this.startButtonIsClicked()
      this.resetStartButtonClicked()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    f = super

    this.updateStartButtonEnabledState()

    this.resetStartButtonClicked()


    f

  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryInitiated: ()->

    @message?.startAdHocSession("Syncing with Apple App Store")

    @message?.addAdHoc("Contacting Store")

    this
  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryUpdate: (status, message)->

    if message?
      @message?.addAdHoc(message)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryCompleted: (status, message)->
    if message?
      @message?.addAdHoc(message)

    @message?.endAdHocSession()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # TODO
  # This should just be one of the standard buttons?
  #
  adjustJoinCodeInfo: ()->

    # Hang JoinCode under the Standard Buttons
    if (stdButt = this.getStandardButtons())? and @joinCodeInfoPanel?

      stdButtOptions = stdButt.getUIPropertiesAsOptions(["top", "height", "left", "width"])
      jcOptions = @joinCodeInfoPanel.getUIPropertiesAsOptions(["width"])

      top = stdButtOptions.top + stdButtOptions.height + kDefaultStartButtonPadding
      left = stdButtOptions.left + (stdButtOptions.width - jcOptions.width)/2

      @joinCodeInfoPanel.setUIProperties({top: top, left: left})

    this

  # ----------------------------------------------------------------------------------------------------------------
  prepStartButtonGroup: ()->

#      top: 150    # For default "trivially" button
#      left: 600

    defaultOptions = 
      height: 1 * kDefaultStartButtonPadding # Starting point
      width:  2 * kDefaultStartButtonPadding # Starting point
      zIndex: Page.kTouchZIndex
      _tag: "Start Button Container"
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1

    @startButtonGroup = new Hy.UI.ViewProxy(defaultOptions)

    this
  # ----------------------------------------------------------------------------------------------------------------
  # Presumes that "prepStartButtonGroup" has already been called  
  #
  # This group contains the start button, helper text, the standard buttons, and maybe
  # some other stuff

  initStartButtonGroup: (fn_clicked)->

    # We presume that the Standard Button panel is already in the container, and
    # that it's wider than anything else we'll add in.

    # Add the start button. Center it.
    @startButtonGroup.addChild(this.createStartButton(fn_clicked), false, {_horizontalLayout: "center"})

    # Add helpful text to the left
    @startButtonGroup.addChild(this.createContentOptionsInfo())

    # Add "Start Game" just below the Button
    @startButtonGroup.addChild(this.createStartButtonText())

    # Just to set a default, center the container first
    childOptions = {_verticalLayout: "center", _horizontalLayout: "center"}
    this.addChild(@startButtonGroup, false, childOptions)

    this.positionStartButtonGroup()

    this

  # ----------------------------------------------------------------------------------------------------------------
  addToStartButtonGroupSize: (additive = null, maxative = null)->

    sbgSize = @startButtonGroup.getUIPropertiesAsOptions(["width", "height"])

    if additive?
      for p, v of additive
        sbgSize[p] += v + kDefaultStartButtonPadding

    if maxative?
      for p, v of maxative
        sbgSize[p] = Math.max(sbgSize[p], v)

    @startButtonGroup.setUIProperties(sbgSize)

    this

  # ----------------------------------------------------------------------------------------------------------------
  positionStartButtonGroup: ()->

    # Apply customizations, if any
    o = @startButtonGroup.getUIPropertiesAsOptions(["width", "height"])
    Hy.Customize.mapOptions(["position"], this.getPath(["startbutton"]), o)

    # Special case: if customization specified "center" for x or y, compute on the basis
    # of the position of the actual start button, not the container.
    # So we interpret position options on the basis of the size of the button, not the container
    # The start button is already positioned in the center, horizontally, so the only adjustment
    # to make here is in the vertical dimension.
    # Note that the default is "center" as well.

    sbgSizeOptions = @startButtonGroup.getUIPropertiesAsOptions(["height"])
    sbOptions = @startButton.getUIPropertiesAsOptions(["top","height"])

    position = Hy.Customize.map("position", this.getPath(["startbutton"]))

    if not position? or position.isDirective("top", "center") or position.isDirective("bottom", "center")
      # Will be < 0 if center of startButton is to the right of container centerline (horizontal)
      centerVDiff = (sbgSizeOptions.height/2) - (sbOptions.top + (sbOptions.height/2))

      o.top += centerVDiff

    # Reposition accordingly
    @startButtonGroup.setUIProperties(o)

    this
  # ----------------------------------------------------------------------------------------------------------------
  createStartButton: (fn_clicked)->

    defaultOptions = 
      top: kDefaultStartButtonPadding
      _tag: "Start Button"
      _path: this.getPath(["startbutton"], "buttons")
      zIndex: Page.kTouchZIndex
#      borderColor: Hy.UI.Colors.red
#      borderWidth: 1

    specificOptions = if Hy.Customize.required("button", this.getPath(["startbutton"]))
      _style: "round"
      _size: kDefaultStartButtonCustomizedSize
      _text: Hy.Localization.T("Play", "Play")
    else
      height: kDefaultStartButtonSize
      width: kDefaultStartButtonSize
      backgroundImage: "assets/icons/button-play.png"
      backgroundSelectedImage: "assets/icons/button-play-selected.png"

    @startButton = new Hy.UI.ButtonProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, specificOptions))
    height = @startButton.getUIProperty("top") + @startButton.getUIProperty("height")
    width = @startButton.getUIProperty("width")

    this.addToStartButtonGroupSize({height: height}, {width: width})

    this.resetStartButtonClicked()

    @fnClickStartGame = (evt)=>
      if @startEnabled.state
        if not this.startButtonIsClicked()
          this.setStartButtonClicked()
          fn_clicked()
      null

    @startButton.addEventListener('click', (evt)=>@fnClickStartGame(evt))

    @startButton

  # ----------------------------------------------------------------------------------------------------------------
  @validatePlayButtonCustomization: (positionSpec)->

    # We want to ensure that the "Play" button itself is on the screen
    kCustomizedHeight = 294
    kCustomizedWidth = kStandardButtonPanelWidthForStartPage

    kDefaultHeight = 264
    kDefaultWidth = kStandardButtonPanelWidthForStartPage

    height = Math.max(kCustomizedHeight, kDefaultHeight)
    width = Math.max(kCustomizedWidth, kDefaultWidth)

    sh = Hy.UI.iPad.screenHeight
    sw = Hy.UI.iPad.screenWidth

    constraint =
      min: 
        left:   0
        right:  0
        top:    0 
        bottom: 0
      max:
        left:   (sw - width) + 1
        right:  (sw - width) + 1
        top:    (sh - height) + 1
        bottom: (sh - height) + 1

    (new Hy.UI.PositionEx(positionSpec)).isValid(constraint)

  # ----------------------------------------------------------------------------------------------------------------
  getStandardButtonsOptions: ()->

    options =
      width: 520 # Just a guess. Need to get this right to make it appear centered under the Start Button
#      borderColor: Hy.UI.Colors.red
#      borderWidth: 1
      bottom: 0
      left: 0

    options

  # ----------------------------------------------------------------------------------------------------------------
  addToStandardButtonContainer: (standardButtons)->

    @startButtonGroup?.addChild(standardButtons, false, this.getStandardButtonsChildOptions())

    # Adjust size of the container
    sbOptions = standardButtons.getUIPropertiesAsOptions(["width", "height"])
    this.addToStartButtonGroupSize({height: sbOptions.height}, {width: sbOptions.width})

    this

  # ----------------------------------------------------------------------------------------------------------------
  startButtonIsClicked: ()-> @startButtonClicked

  # ----------------------------------------------------------------------------------------------------------------
  setStartButtonClicked: ()-> @startButtonClicked = true

  # ----------------------------------------------------------------------------------------------------------------
  resetStartButtonClicked: ()->
    @startButtonClicked = false

  # ----------------------------------------------------------------------------------------------------------------
  getStartEnabled: ()-> [@startEnabled.state, @startEnabled.reason]

  # ----------------------------------------------------------------------------------------------------------------
  setStartEnabled: (state, reason)->

    @startEnabled.state = state
    @startEnabled.reason = reason

    @startButton.setEnabled(state)

    this.setContentOptionsInfo(state, reason)

    StartPage.notifyObservers (observer)=>observer.obs_startPageStartButtonStateChanged?(state, reason)
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  # "1 topic selected", etc
  #
  createContentOptionsInfo: ()->

    # Position this just to the left of the start button
    options =
      top: kDefaultStartButtonPadding
      left: @startButton.getUIProperty("left") - (kDefaultStartButtonPadding + kDefaultStartButtonContentOptionsInfoWidth)
      width: kDefaultStartButtonContentOptionsInfoWidth
      height:  @startButton.getUIProperty("height")
      font: Hy.UI.Fonts.specMinisculeNormal
      color: Hy.UI.Colors.black
      textAlign: 'center'
      _tag: "Content Options Info"
#      borderColor: Hy.UI.Colors.white
#      borderWidth: 1

    @contentOptionsPanelInfoView = new Hy.UI.LabelProxy(options)

    @contentOptionsPanelInfoView
  # ----------------------------------------------------------------------------------------------------------------
  setContentOptionsInfo: (state, info = null)->

    color = if state
      Hy.Customize.map("font.color", this.getPath(), Hy.UI.Colors.black)
    else
      Hy.UI.Colors.MrF.Red

    @contentOptionsPanelInfoView.setUIProperty("color", color)
    @contentOptionsPanelInfoView.setUIProperty("text", info)

    this

  # ----------------------------------------------------------------------------------------------------------------
  createStartButtonText: ()->

    view = null

    # Position just under the start button, and centered with it
    if not Hy.Customize.required("button", this.getPath(["startbutton"]))

      sbOptions = @startButton.getUIPropertiesAsOptions(["top", "left", "width", "height"])

      options = 
        top: sbOptions.top + sbOptions.height + kDefaultStartButtonPadding
        left: sbOptions.left + ((sbOptions.width - kDefaultStartButtonTextWidth)/2)
        width: kDefaultStartButtonTextWidth
        height: kDefaultStartButtonTextHeight
        text: "Start Game"
        font: Hy.UI.Fonts.specMediumMrF
        textAlign: 'center'
        _tag: "Start Game Label"
#        borderColor: Hy.UI.Colors.yellow
#        borderWidth: 1

      view = new Hy.UI.LabelProxy(options)

      # Determine new height. Assume text is not wide enough to matter
      this.addToStartButtonGroupSize({height: view.getUIProperty("height")})

    view

  # ----------------------------------------------------------------------------------------------------------------
  addJoinCodeInfo: ()->

    fnClick = ()=>
      if @joinCodeInfoPanel?.isEnabled()
        this.getApp().showJoinCodeInfoPage()
      null

    options =
      bottom: 268
      left: 120
      borderColor: Hy.UI.Colors.red
      borderWidth: 0

    if not Hy.Network.PlayerNetwork.isSingleUserMode()
      this.addChild(@joinCodeInfoPanel = new Hy.Panels.CodePanel(this, options, fnClick))

    this

  # ----------------------------------------------------------------------------------------------------------------
  createCheckInCritterPanel: ()->

    options = 
      left: 0
      bottom: 0

    this.addChild(@checkInCritterPanel = new Hy.Panels.CheckInCritterPanel(this, options))
    this

  # ----------------------------------------------------------------------------------------------------------------
  startClicked: ()->
    
    Hy.Utils.Deferral.create 0, ()=>this.getApp().contestStart() # must use deferral to trigger startContest outside of event handler
   
    this

  # ----------------------------------------------------------------------------------------------------------------
  updateStartButtonEnabledState: ()->
    Hy.Trace.debug "StartPage::updateStartButtonEnabledState"

    reason = null
    state = false

    numTopics = _.size(_.select(Hy.Content.ContentManager.get().getLatestContentPacksOKToDisplay(), (c)=>c.isSelected()))

    if numTopics <= 0
      reason = Hy.Localization.T("no-topics-selected", "No topics selected!")
      state = false
    else
      state = true
      reason = if numTopics is 1
        "#{numTopics} #{Hy.Localization.T("topic-selected", "topic selected")}"
      else
        "#{numTopics} #{Hy.Localization.T("topics-selected", "topics selected")}"

    if (r = Hy.Content.ContentManager.isBusy())?
      reason = "Please wait: #{r}"
      state = false

    this.setStartEnabled(state, reason)

    this

  # ----------------------------------------------------------------------------------------------------------------
  contentPacksLoadingStart: ()->
    @message?.startAdHocSession("Preparing Contest")

  # ----------------------------------------------------------------------------------------------------------------
  contentPacksLoadingCompleted: ()->
    @message?.endAdHocSession()

  # ----------------------------------------------------------------------------------------------------------------
  contentPacksLoading: (report)->
    @message?.addAdHoc(report)

# ==================================================================================================================
# adds support for pause button and countdown

class CountdownPage extends WebContentExPage

  kCountdownStateUndefined = 0
  kCountdownStateRunning   = 1
  kCountdownStatePaused    = 2

  @kWidth = 164

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    @controlInfo =
      fnPause: null
      fnCompleted: null
      countdownSeconds: null
      startingDelay: null

    @pauseClicked = false
    @overlayClicked = false
    @overlayShowing = false

    @currentCountdownValue = null
    @countdownDeferral = null

    @fnPauseClick = (evt)=>
      if not @pauseClicked
        @pauseClicked = true
        this.click()
      null

    @fnClickContinueGame = ()=>
      this.continue_()
      @overlayClicked = false
      @pauseClicked = false
      null

    @fnClickNewGame = ()=>
      @overlayClicked = false
      @pauseClicked = false
      this.getApp().contestRestart(false)
      null

    @fnClickForceFinish = ()=>
      @overlayClicked = false
      @pauseClicked = false
      this.getApp().contestForceFinish()
      null


    @countdownPanel = if Hy.Customize.required("button", this.getPath())
      new Hy.Panels.CountdownPanelCustomized(this, this.countdownPanelOptions(), @fnPauseClick)
    else
      new Hy.Panels.CountdownPanelMrF(this, this.countdownPanelOptions(), @fnPauseClick)

    this.addChild(@countdownPanel)

    this.addChild(this.createPauseButton(this.pauseButtonOptions()))
    this.addChild(this.createPauseButtonText(this.pauseButtonTextOptions()))

    this

  # ----------------------------------------------------------------------------------------------------------------
  countdownPanelOptions: ()->

    {zIndex: Page.kPageContainerZIndex + 1}

  # ----------------------------------------------------------------------------------------------------------------
  pauseButtonOptions: ()->

    {}

  # ----------------------------------------------------------------------------------------------------------------
  pauseButtonTextOptions: ()->

    {}
  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    return if @countdownState is kCountdownStatePaused
    @countdownState = kCountdownStatePaused
    this.disablePause()
    @countdownTicker?.pause()
    this.showOverlay({opacity:1, duration: 200})
#    Hy.Network.NetworkService.get().setImmediate()
    @controlInfo.fnPause?(true)

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super
    this.pause()

    this

  # ----------------------------------------------------------------------------------------------------------------
  continue_: ()->
    return if @countdownState is kCountdownStateRunning
#    Hy.Network.NetworkService.get().setSuspended()
    @countdownState = kCountdownStateRunning

    f = ()=>
      this.enablePause()
      @countdownTicker?.continue_()
      @controlInfo.fnPause?(false)

    this.hideOverlay({opacity:0, duration: 200}, f)

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super

    this.initCountdown()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this.haltCountdown()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  haltCountdown: ()->

    @countdownDeferral.clear() if @countdownDeferral?.enqueued()
    @countdownTicker?.exit()
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (@controlInfo)->

    @countdownState = kCountdownStateUndefined

    @currentCountdownValue = null

    @pauseClicked = false
    @overlayClicked = false

    f = super

    this.hideOverlayImmediate()
    this.enablePause()

    this.getCountdownPanel().initialize().animateCountdown(this.countdownAnimationOptions(@controlInfo.countdownSeconds), @controlInfo.countdownSeconds, null, true)

    f

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (evt)->

    Hy.Trace.debug("QuestionPage::obs_networkChanged (isPaused=#{this.isPaused()})")
    super

    if this.isPaused()
      this.updateConnectionInfo(evt)

    this

  # ----------------------------------------------------------------------------------------------------------------
  createPauseButton: (options)->

    defaultOptions = if Hy.Customize.required("button", this.getPath())
      _style: "round"
      _size: "medium2"
      _text: Hy.Localization.T("pause", "pause")
    else
      backgroundImage: "assets/icons/button-pause-question-page.png"

    defaultOptions._tag = "Pause"
    defaultOptions._path = this.getPath()

    @pauseButton = new Hy.UI.ButtonProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

    f = ()=>
      @fnPauseClick()
      null

    @pauseButton.addEventListener("click", f)

    @pauseButton

  # ----------------------------------------------------------------------------------------------------------------
  createPauseButtonText: (options)->

    @pauseButtonText = null

    if not Hy.Customize.required("button", this.getPath())
      defaultOptions = 
        zIndex: Page.kTouchZIndex
        text: 'Pause'
        font: Hy.UI.Fonts.specTinyMrF
        color: Hy.UI.Colors.MrF.DarkBlue
        height: 'auto'
        textAlign: 'center'
        _tag: "Pause Text"

      @pauseButtonText = new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

    @pauseButtonText

  # ----------------------------------------------------------------------------------------------------------------
  getCountdownPanel: ()->
    @countdownPanel

  # ----------------------------------------------------------------------------------------------------------------
  animateCountdown: (init, value)->

    this.getCountdownPanel().animateCountdown(this.countdownAnimationOptions(value), value, @controlInfo.countdownSeconds, init)

    this

  # ----------------------------------------------------------------------------------------------------------------
  countdownAnimationOptions: (value)->

    _style: "normal"

  # ----------------------------------------------------------------------------------------------------------------
  playCountdownSound: (value)->
    if (event = this.countdownSound(value))?
      Hy.Media.SoundManager.get().playEvent(event)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initCountdown: ()->
    @countdownState = kCountdownStateRunning
    @countdownDeferral = null if @countdownDeferral?.triggered()

    fnInitView = (value)=>
      @currentCountdownValue = value
      this.animateCountdown(true, value)

    fnUpdateView = (value)=>
      @currentCountdownValue = value
      this.animateCountdown(false, value)

    fnCompleted = (evt)=>this.countdownCompleted()
    fnSound = (value)=>this.playCountdownSound(value)
    @countdownTicker = new CountdownTicker(fnInitView, fnUpdateView, fnCompleted, fnSound)

    @countdownTicker.init(@controlInfo.countdownSeconds, @controlInfo.startingDelay)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getCountdownStartValue: ()-> @controlInfo.countdownSeconds

  # ----------------------------------------------------------------------------------------------------------------
  getCountdownValue: ()->
#    @countdownTicker?.getValue()     # This isn't reliable, if console user answers
     @currentCountdownValue

  # ----------------------------------------------------------------------------------------------------------------
  countdownSound: (value)->
    null

  # ----------------------------------------------------------------------------------------------------------------
  countdownCompleted: ()->

    this.disablePause()

    @controlInfo.fnCompleted?()

  # ----------------------------------------------------------------------------------------------------------------
  click: (evt)->
    this.pause() if @countdownState is kCountdownStateRunning

  # ----------------------------------------------------------------------------------------------------------------
  disablePause: ()->
    for view in [@pauseButton, @pauseButtonText]
      view?.animate({duration: 100, opacity: 0})
      view?.hide()

    this

  # ----------------------------------------------------------------------------------------------------------------
  enablePause: ()->
    for view in [@pauseButton, @pauseButtonText]
#      view?.animate({duration: 100, opacity: 1})
      view?.setUIProperty("opacity", 1)
      view?.show()

    this

  # ----------------------------------------------------------------------------------------------------------------
  isPaused: ()->
    @countdownState is kCountdownStatePaused  

  # ----------------------------------------------------------------------------------------------------------------
  createOverlay: ()->
    container = this.overlayContainer()

    overlayBkgndOptions = 
      top: 0
      bottom: 0
      left: 0
      right: 0
      backgroundImage: Hy.UI.Backgrounds.pixelOverlay
      zIndex: Page.kOverlayZIndex
      opacity: 0
      _tag: "Overlay Background"

    container.addChild(@overlayBkgnd = new Hy.UI.ViewProxy(overlayBkgndOptions))

    overlayFrameOptions =  
      top: 100
      bottom: 100
      left: 100
      right: 100
      borderColor: Hy.UI.Colors.mapTransparent(Hy.Customize.map("bordercolor", this.getPath(), Hy.UI.Colors.white)) # handle transparency
      borderRadius: 16
      borderWidth: 4
      zIndex: Page.kOverlayZIndex + 1
#      _alignment: "center"
      opacity: 0
      _tag: "Overlay Frame"
    
    container.addChild(@overlayFrame = new Hy.UI.ViewProxy(overlayFrameOptions))

    elementOptions = 
      width: 400
    
    @overlayFrame.addChild(this.overlayBody(elementOptions))

    this
    
  # ----------------------------------------------------------------------------------------------------------------
  showOverlay: (options, fnDone = null)->

    fn = ()=>
      if fnDone? 
        Hy.Utils.Deferral.create(0, fnDone)
      null

    if not @overlayBkgnd?
      this.createOverlay()

    this.updateConnectionInfo()

    @panelSound?.syncCurrentChoiceWithAppOption()

    for view in [@overlayBkgnd, @overlayFrame]
      view.setUIProperty("opacity", 0)
      view.show()

    @overlayBkgnd.animate(options, ()=>)
    @overlayFrame.animate(options, fn)

    this

  # ----------------------------------------------------------------------------------------------------------------
  hideOverlayImmediate: ()->

    for view in [@overlayBkgnd, @overlayFrame]
      view?.hide()

    this

  # ----------------------------------------------------------------------------------------------------------------
  hideOverlay: (options, fnDone = null)->

    fn = ()=>
      for view in [@overlayBkgnd, @overlayFrame]
        view?.hide()
      if fnDone?
        Hy.Utils.Deferral.create(0, fnDone)
      null

    if @overlayBkgnd?
      @overlayFrame.animate(options, ()=>)
      @overlayBkgnd.animate(options, fn)
    else
      fn()

    this

  # ----------------------------------------------------------------------------------------------------------------
  overlayContainer: ()->
    this.getContainer()

  # ----------------------------------------------------------------------------------------------------------------
  overlayBody: (elementOptions)->

    options = 
      backgroundImage: Hy.UI.Backgrounds.pixelOverlay
      _tag: "Overlay Body"

    body = new Hy.UI.ViewProxy(options)

    body.addChild(this.createGamePausedText())

    top = 170 #200
    verticalPadding = 90 #elementOptions.height + 15 #25
    textOffset = 125

    horizontalPadding = 20

    choiceOptions = {}
#      _style: "plainOnDarkBackground"
#      borderColor: Hy.UI.Colors.red
#      borderWidth: 1

    @panelSound = Hy.Panels.OptionPanels.createSoundPanel(this, Hy.UI.ViewProxy.mergeOptions(elementOptions, {top:top}), {font: Hy.UI.Fonts.specBigNormal, color: Hy.UI.Colors.white, _attach: "right"}, choiceOptions)
    body.addChild(@panelSound)

    continueGameButtonOptions = {left: horizontalPadding}
    continueGameLabelOptions = {left: textOffset}

    hasCustomization = Hy.Customize.required("button", this.getPath())

    if hasCustomization
      continueGameButtonOptions._style = "round"
      continueGameButtonOptions._size = "medium"
      continueGameButtonOptions.title = "Play"
      continueGameLabelOptions.text = "Continue Game"
    else
      continueGameButtonOptions.backgroundImage = "assets/icons/button-play-small-blue.png"
      continueGameLabelOptions.text = "Continue Game"

    continueGame = this.createOverlayButtonPanel(Hy.UI.ViewProxy.mergeOptions(elementOptions, {top: (top += verticalPadding)}), continueGameButtonOptions, continueGameLabelOptions, @fnClickContinueGame)
    body.addChild(continueGame)

    forceFinishGameButtonOptions = {left: horizontalPadding}
    forceFinishGameLabelOptions = {left: textOffset}

    if hasCustomization
      forceFinishGameButtonOptions._style = "round"
      forceFinishGameButtonOptions._size = "medium"
      forceFinishGameButtonOptions.title = "End"
      forceFinishGameLabelOptions.text = "Finish Game"
    else
      forceFinishGameButtonOptions.backgroundImage = "assets/icons/button-cancel.png"
      forceFinishGameLabelOptions.text = "Finish Game"

    forceFinishGame = this.createOverlayButtonPanel(Hy.UI.ViewProxy.mergeOptions(elementOptions, {top: (top += verticalPadding)}), forceFinishGameButtonOptions, forceFinishGameLabelOptions, @fnClickForceFinish)
    body.addChild(forceFinishGame)

    newGameButtonOptions = {left: horizontalPadding}
    newGameLabelOptions = {left: textOffset}

    if hasCustomization
      newGameButtonOptions._style = "round"
      newGameButtonOptions._size = "medium"
      newGameButtonOptions.title = "New"
      newGameLabelOptions.text = "New Game"
    else
      newGameButtonOptions.backgroundImage = "assets/icons/button-restart.png"
      newGameLabelOptions.text = "New Game"

    newGame = this.createOverlayButtonPanel(Hy.UI.ViewProxy.mergeOptions(elementOptions, {top: (top += verticalPadding)}), newGameButtonOptions, newGameLabelOptions, @fnClickNewGame)
    body.addChild(newGame)

#    @connectionInfo = this.createConnectionInfo(Hy.UI.ViewProxy.mergeOptions(elementOptions, {top: (top += verticalPadding)}))
#    this.updateConnectionInfo()
#    body.addChild(@connectionInfo)

    body

  # ----------------------------------------------------------------------------------------------------------------
  updateConnectionInfo: (evt = null)->

    return this # TODO

    text = ""

    if Hy.Network.NetworkService.isOnline() and (joinSpec = Hy.Network.PlayerNetwork.getJoinSpec())?
        text = "Additional players? Visit #{joinSpec.displayURL} and enter: #{joinSpec.displayCode}"

    @connectionInfo?.setUIProperty("text", text)

    this

  # ----------------------------------------------------------------------------------------------------------------
  createConnectionInfo: (commonOptions)->

    options = 
      width: 600
      font: Hy.UI.Fonts.specSmallNormal
      color: Hy.UI.Colors.white
      _tag: "Connection Info"
      height: 'auto'
      textAlign: 'center'
      _tag: "Connection Info"

    new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(commonOptions, options))


  # ----------------------------------------------------------------------------------------------------------------
  createGamePausedText: ()->

    options = 
      text: 'Game Paused'
      font: Hy.UI.Fonts.specGiantMrF
      color: Hy.UI.Colors.white
      top: 50
      height: 'auto'
      textAlign: 'center'
      _tag: "Game Paused"

    if Hy.Customize.has(["font.*"], this.getPath())
      options.font = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specBiggerNormal, {fontSize: 84})
      Hy.Customize.mapOptions(["font"], this.getPath(), options)

    new Hy.UI.LabelProxy(options)

  # ----------------------------------------------------------------------------------------------------------------
  createOverlayButtonPanel: (containerOptions, buttonOptions, labelOptions, fnClick)->

    options = 
      height: 76 #72
      _tag: "Overlay Button Panel"

    container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(options, containerOptions))

    f = ()=>
      if not @overlayClicked
        @overlayClicked = true
        fnClick()
      null

    defaultButtonOptions = 
      height: 72
      width: 72
      left: 0
      _tag: "Overlay Button"
      _path: this.getPath()

    buttonOptions = Hy.UI.ViewProxy.mergeOptions(defaultButtonOptions, buttonOptions)

    button = new Hy.UI.ButtonProxy(buttonOptions)
    button.addEventListener 'click', f
    container.addChild(button)

    defaultLabelOptions = 
      font: Hy.UI.Fonts.specBigNormal
      color: Hy.UI.Colors.white
      _tag: "Overlay Label"

    Hy.Customize.mapOptions(["font"], this.getPath(), defaultLabelOptions)

    container.addChild(new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultLabelOptions, labelOptions)))

    container

# ==================================================================================================================
class QuestionPage extends CountdownPage

  # "exterior" height
  kQuestionBlockHeight = 215 # see CSS for question_container
  kQuestionBlockWidth = 944

  # "interior" height, before padding/border
  kQuestionSizingContainerHeight = 195
  kQuestionSizingContainerWidth = 848
  kQuestionSizingContainerRightOffset = 70

  # Guesses
  kQuestionSizingContainerHeightMin = 50
  kQuestionSizingContainerWidthMin = 300

  kAnswerSizingContainerHeightMin = 50
  kAnswerSizingContainerWidthMin = 100

  # "interior" height, before padding/border
  kAnswerSizingContainerHeight = 180 
  kAnswerSizingContainerWidth = 434

  kQuestionInfoHeight = kQuestionInfoWidth = 86

  kQuestionBlockHorizontalMargin = (Hy.UI.iPad.screenWidth - kQuestionBlockWidth)/2
#  kQuestionBlockVerticalMargin = 30
  kQuestionBlockVerticalMargin = 25

  kQuestionTextMargin = 10
  kQuestionTextWidth = kQuestionBlockWidth - (kQuestionTextMargin + kQuestionInfoWidth)
  kQuestionTextHeight = kQuestionBlockHeight - (2*kQuestionTextMargin)

  kAnswerSectionDefaultTop = kQuestionBlockHeight + kQuestionBlockVerticalMargin

  kAnswerSizingContainerWidthDefault = 460
  kAnswerSizingContainerHeightDefault = 206

  kAnswerBlockHorizontalPadding = 24
  kAnswerBlockVerticalPadding = 7 #15

#  kAnswerContainerVerticalMargin = 20
  kAnswerContainerVerticalMargin = 7
  kAnswerContainerHorizontalMargin = kQuestionBlockHorizontalMargin
  kAnswerContainerWidth = (2*kAnswerSizingContainerWidthDefault) + kAnswerBlockHorizontalPadding
  kAnswerContainerHeight = (2*kAnswerSizingContainerHeightDefault) + kAnswerBlockVerticalPadding

  kCountdownClockHeight = kCountdownClockWidth = 86

  kButtonOffset = 5

  kPauseButtonHeight = kPauseButtonWidth = 86
  kPauseButtonVerticalMargin = kQuestionBlockVerticalMargin + kQuestionBlockHeight - (kPauseButtonHeight - kButtonOffset)
  kPauseButtonHorizontalMargin = kQuestionBlockHorizontalMargin - 20

  kQuestionInfoVerticalMargin = kQuestionBlockVerticalMargin - kButtonOffset
  kQuestionInfoHorizontalMargin = kQuestionBlockHorizontalMargin - 20

  # ----------------------------------------------------------------------------------------------------------------
  @validateQuestionCustomizationSize: (sizeSpec)->

    constraint = 
      min: 
        height: kQuestionSizingContainerHeightMin
        width:  kQuestionSizingContainerWidthMin
      max:
        height: kQuestionSizingContainerHeight + 1
        width:  kQuestionSizingContainerWidth + 1

    (new Hy.UI.SizeEx(sizeSpec)).isValid(constraint)
  
  # ------------
  @validateQuestionCustomizationOffset: (positionSpec)->

    widthConstraint1 = (Hy.UI.iPad.screenWidth - kQuestionSizingContainerWidthMin)/2

    # Take into account the "pause" button, et al
    widthConstraint2 = widthConstraint1 - kQuestionSizingContainerRightOffset

    heightConstraint = (kQuestionBlockHeight - kQuestionSizingContainerHeightMin)/2

    constraint = 
      min: 
        left:   -widthConstraint1
        right:  -widthConstraint2
        top:    -heightConstraint
        bottom: -heightConstraint
      max:
        left:   widthConstraint2 + 1
        right:  widthConstraint1 + 1
        top:    heightConstraint + 1
        bottom: heightConstraint + 1

    (new Hy.UI.PositionEx(positionSpec)).isValid(constraint)

  # ------------
  @validateAnswersCustomizationSize: (sizeSpec)->

    constraint = 
      min: 
        height: kAnswerSizingContainerHeightMin
        width:  kAnswerSizingContainerWidthMin
      max:
        height: kAnswerSizingContainerHeight + 1
        width:  kAnswerSizingContainerWidth + 1

    (new Hy.UI.SizeEx(sizeSpec)).isValid(constraint)

  # ------------
  @validateAnswersCustomizationOffset: (positionSpec)->

    widthConstraint = (kAnswerSizingContainerWidth - kAnswerSizingContainerWidthMin)/2
    heightConstraint = (kAnswerSizingContainerHeight - kQuestionSizingContainerHeightMin)/2

    constraint = 
      min: 
        left:   (-widthConstraint) + 1 # HACK
        right:  -widthConstraint
        top:    -heightConstraint
        bottom: -heightConstraint
      max:
        left:   widthConstraint + 1
        right:  widthConstraint + 1
        top:    heightConstraint + 1
        bottom: heightConstraint + 1

    (new Hy.UI.PositionEx(positionSpec)).isValid(constraint)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    @zIndexPassive = 110
    @zIndexActive = 150

    @showingAnswers = false
    @consoleAnswered = false
    @showingAnswersClicked = false

    @questionSpec = 
      contestQuestion: null
      iQuestion: null
      nQuestions: null

    super state, app

    this.initSound()

    this.addChild(@questionInfoPanel = this.createQuestionInfoPanel())

    this.createAnswerCritterPanel()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initSound: ()->

    @sound = null
    @soundCounter ||= 0
    @soundKeys = ["countDown_0", "countDown_1", "countDown_2", "countDown_3", "countDown_4"]

    @nSounds = @soundKeys.length

    this

  # ----------------------------------------------------------------------------------------------------------------
  createQuestionInfoPanel: ()->

    panel = if Hy.Customize.required("button", this.getPath())
      new Hy.Panels.QuestionInfoPanelCustomized(this, this.questionInfoPanelOptions())
    else
      new Hy.Panels.QuestionInfoPanelMrF(this, this.questionInfoPanelOptions())

    panel

  # ----------------------------------------------------------------------------------------------------------------
  countdownPanelOptions: ()->
    top     : kQuestionBlockVerticalMargin + kQuestionBlockHeight + kAnswerContainerVerticalMargin + (kAnswerContainerHeight - kCountdownClockHeight)/2
    left    : kAnswerContainerHorizontalMargin + (kAnswerContainerWidth - kCountdownClockWidth)/2
    height  : kCountdownClockHeight
    width   : kCountdownClockWidth
    zIndex  : @zIndexActive + 2

  # ----------------------------------------------------------------------------------------------------------------
  pauseButtonOptions: ()->
    zIndex : @zIndexActive + 2
    height : kPauseButtonHeight
    width  : kPauseButtonWidth
    top    : kPauseButtonVerticalMargin
    right  : kPauseButtonHorizontalMargin

  # ----------------------------------------------------------------------------------------------------------------
  pauseButtonTextOptions: ()->
    textHeight = 25
    buttonOptions = this.pauseButtonOptions()

    options = 
      top    : buttonOptions.top - (textHeight + 5)
      right  : buttonOptions.right
      width  : buttonOptions.width
      height : textHeight
      zIndex : buttonOptions.zIndex

    options

  # ----------------------------------------------------------------------------------------------------------------
  questionInfoPanelOptions: ()->
    top   : kQuestionInfoVerticalMargin
    right : kQuestionInfoHorizontalMargin

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super

    @sound?.play()

    if not @showingAnswers 
      @answerCritterPanel.start()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    @sound.stop() if @sound?.isPlaying()

    if @showingAnswers 
      @answerCritterPanel.stop()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    @sound.pause() if @sound?.isPlaying()
    @answerCritterPanel.pause()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    super

    @sound.play() if @sound? and not @sound.isPlaying()
    @answerCritterPanel.resumed()

    this

  # ----------------------------------------------------------------------------------------------------------------
  openWindow: (options={})->

    super options

    this

  # ----------------------------------------------------------------------------------------------------------------
  continue_: ()->

    super

    @sound.play() if @sound? and not @sound.isPlaying()

    this

  # ----------------------------------------------------------------------------------------------------------------
  shouldInitializeWebViewForCurrentPage: ()->

    this.isQuestionMode()  

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (mode, controlFns, questionSpec = null)->

    if questionSpec?
      @questionSpec = questionSpec
        
    # Do some initialization before super-ing up to parent web view
    switch mode
      when "question"
        @showingAnswers = false
        @consoleAnswered = false
        @showingAnswersClicked = false

      when "answer"
        @showingAnswers = true

    f = super controlFns

    switch mode
      when "question"
        @answerCritterPanel.initialize()

      when "answer"
        this.revealAnswer()

    @sound?.reset()

    @questionInfoPanel.initialize(@questionSpec.iQuestion+1, @questionSpec.nQuestions, this.labelColor())

    f # return false if we want to wait for the webview

  # ----------------------------------------------------------------------------------------------------------------
  isQuestionMode: ()-> not @showingAnswers

  # ----------------------------------------------------------------------------------------------------------------
  webViewOptionsForCurrentPage: (data = {})->

    this.addDataSection(data, "customize", "questionpage", this.customizeContent())    

    qpContent = 
     question: {text: @questionSpec.contestQuestion.getQuestionText()}
     answers:  (for i in [0..3]
      {text: @questionSpec.contestQuestion.getAnswerText(i)})

    this.addDataSection(data, "content", "questionpage", qpContent)

    super data
    
    data

  # ----------------------------------------------------------------------------------------------------------------
  dump: ()->
    Hy.Trace.debug "QuestionPage::dump (Question=#{@questionSpec.contestQuestion.getQuestionID()}/#{@questionSpec.contestQuestion.getQuestionText()})"

    for i in [0..3]
      Hy.Trace.debug "QuestionPage::dump (#{i} #{@questionSpec.contestQuestion.getAnswerText(i)})"   

    this

  # ----------------------------------------------------------------------------------------------------------------
  labelColor: ()->
    if @showingAnswers then Hy.UI.Colors.paleYellow else Hy.UI.Colors.white

  # ----------------------------------------------------------------------------------------------------------------
  animateCountdown: (init, value)->
  
    super

    color = Hy.UI.Colors.white

    if not init
      if not @showingAnswers
        if value <= Hy.Config.Dynamics.panicAnswerTime
          color = Hy.Customize.map("bordercolor", this.getPath(), Hy.UI.Colors.MrF.Red) # ignore transparency

#    @questionLabel.setUIProperty("color", color)

    this

  # ----------------------------------------------------------------------------------------------------------------
  countdownAnimationOptions: (value)->

    _style: if @showingAnswers then "normal" else "frantic"
         
  # ----------------------------------------------------------------------------------------------------------------
  # Called from ConsoleApp
  animateCountdownQuestionCompleted: ()->

    this.getCountdownPanel().animateCountdown({_style: "completed"})

    this

  # ----------------------------------------------------------------------------------------------------------------
  customizeContent: ()->

    customizations = null

    fn_push = (customization = null)=>
      if customization?
        customizations.push customization
      null

    if not (this.isSameCustomization() and this.isSameSingleUserMode())
      customizations = []

      path = this.getPath()
      qPath = this.getPath(["question"])
      aPath = this.getPath(["answers"])

      # If page-level borderColor is set, cascade it down to question/answers    
      # Might get overridden, of course
      if (b = Hy.Customize.map("bordercolor", path))?
        fn_push this.addCustomizationValue("bordercolor", qPath, b)
        fn_push this.addCustomizationValue("bordercolor", aPath, b)

      for panel in ["question", "answers"]
        p = this.getPath([panel])
        fn_push this.addCustomization("bordercolor",      p)
        fn_push this.addCustomization("background.url",   p)
        fn_push this.addCustomization("background.color", p)
        fn_push this.addCustomization("font.color",       p)
        fn_push this.addCustomization("font.name",        p)
        fn_push this.addCustomization("font.style",       p)
        fn_push this.addCustomization("font.weight",      p) 

      # "align" supported only for question
      fn_push this.addCustomization("align", qPath)

      # We send size/position/offset info for Q and Answers via psuedo-directive
  
      questionSizing = {}
      Hy.Customize.mapOptions(["size"], qPath, questionSizing)
      this.computeOffsets(qPath, questionSizing)
      fn_push this.addCustomizationValue("_sizeAndOffset", qPath, questionSizing)

      answersSizing = {}
      Hy.Customize.mapOptions(["size"], aPath, answersSizing)
      this.computeOffsets(aPath, answersSizing)
      fn_push this.addCustomizationValue("_sizeAndOffset", aPath, answersSizing)

    customizations

  # ----------------------------------------------------------------------------------------------------------------
  webViewReady: (event = null)->

    if event? and event.data.sizes?
      this.initClickTargets(event.data.sizes)

    super event
    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewShowConsoleSelection: (indexSelectedAnswer)->
    this.pokeWebView("showConsoleSelection", {indexSelectedAnswer: indexSelectedAnswer})

  # ----------------------------------------------------------------------------------------------------------------
  webViewRevealAnswer: (indexCorrectAnswer)->
    this.pokeWebView("revealAnswer", {indexCorrectAnswer: indexCorrectAnswer})

  # ----------------------------------------------------------------------------------------------------------------
  computeOffsets: (path, options)->

    # Is there a customized offset?
    if (o = Hy.Customize.map("offset", path))?
      offsetOptions = o.getOptionsRaw()
      options._hOffset = if (l = offsetOptions.left)?
        l
      else
        if (r = offsetOptions.right)?
          -r
        else
          0

       options._vOffset = if (t = offsetOptions.top)?
          t
        else
          if (b = offsetOptions.bottom)?
            -b
          else
            0

    options

  # ----------------------------------------------------------------------------------------------------------------
  initClickTargets: (sizes)->

    if sizes.answers?
      for answerInfo in sizes.answers
        this.addChild(this.createAnswerClickTarget(answerInfo))

    this

  # ----------------------------------------------------------------------------------------------------------------
  answerOptions: (answerInfo)->

    options = 
      height            : answerInfo.rect.height,
      width             : answerInfo.rect.width, 
      top               : answerInfo.rect.top, 
      left              : answerInfo.rect.left
      _tag              : "Answer click target #{answerInfo.index}"
      zIndex            : @zIndexActive + 1

    options

  # ----------------------------------------------------------------------------------------------------------------
  createAnswerClickTarget: (answerInfo)->

    answerView = new Hy.UI.ViewProxy(this.answerOptions(answerInfo))

    # Add handler for console player
    answerView.addEventListener("click", (evt)=>this.answerClicked(answerInfo.index))
        
    answerView

  # ----------------------------------------------------------------------------------------------------------------
  answerClicked: (answerIndex)->

    Hy.Trace.debug "QuestionPage::answerClicked (##{answerIndex} allowEvents=#{this.getAllowEvents()} showingAnswers=#{@showingAnswers} consoleAnswered=#{@consoleAnswered} showingAnswersClicked=#{@showingAnswersClicked} PageState.state=#{PageState.get().getState()})"

    fn = null

    if this.getAllowEvents()
      if answerIndex?
        if @showingAnswers 
          if not @showingAnswersClicked
            @showingAnswersClicked = true
            fn = ()=>
              Hy.Trace.debug "QuestionPage::answerClicked (done showing answers)"
              this.getApp().questionAnswerCompleted()
              null
        else 
          if not @consoleAnswered
            @consoleAnswered = true
            this.webViewShowConsoleSelection(answerIndex)
            fn = ()=>
              Hy.Trace.debug "QuestionPage::answerClicked (console answered)"
              this.getApp().consolePlayerAnswered(answerIndex)
              null
  
    if fn?
      this.haltCountdown()
      Hy.Utils.Deferral.create(0, ()=>fn())

    null

  # ----------------------------------------------------------------------------------------------------------------
  createAnswerCritterPanel: ()->

    options = 
      zIndex: Page.kPageContainerZIndex + 1
      left: 0
      bottom: 0

    this.addChild(@answerCritterPanel = new Hy.Panels.AnswerCritterPanel(this, options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  countdownSound: (value)->

    sound = null

    if not @showingAnswers and value isnt 0
      sound = @soundKeys[@soundCounter++ % @nSounds]
    sound

  # ----------------------------------------------------------------------------------------------------------------
  playerAnswered: (response)->

    @answerCritterPanel.playerAnswered(response)
    this

  # ----------------------------------------------------------------------------------------------------------------
  revealAnswer: ()->

    this.webViewRevealAnswer(@questionSpec.contestQuestion.indexCorrectAnswer)

    # We want to display highest scorers first
    correct = []
    incorrect = []

    for response in Hy.Contest.ContestResponse.selectByQuestionID(@questionSpec.contestQuestion.getQuestionID())
      if response.getCorrect()
        correct.push response
      else
        incorrect.push response

    sortedCorrect = correct.sort((r1, r2)=> r2.getScore() - r1.getScore())    

    players = []
    playerOptions = []
 
    for response in [].concat(correct, incorrect)
      players.push response.getPlayer()
      playerOptions.push {_correctness: response.getCorrect(), _score: response.getScore()}

    @answerCritterPanel.reportResponses(players, playerOptions)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getLogoOptions: (logoName)->

    options = switch logoName
      when "logo1"
        # Only if customization provided
        if this.requiresCustomLogo("logo1")
          super logoName
        else
          null
      else
        super logoName

    options

# ==================================================================================================================
class ContestCompletedPage extends WebContentExPage

  kDefaultLogo1Top = 65
  kDefaultLogo1Height = 100
  kDefaultLogo1Width = 500

  kDefaultPlayAgainButtonPadding = 20
  kDefaultPlayAgainButtonTop = 200
  kDefaultPlayAgainButtonHeight = 72
  kDefaultPlayAgainButtonTextLabelWidth = 130
  kDefaultPlayAgainButtonContainerHeight = kDefaultPlayAgainButtonHeight
  kDefaultPlayAgainButtonContainerWidth = kDefaultPlayAgainButtonHeight + (2*kDefaultPlayAgainButtonPadding) + (2*kDefaultPlayAgainButtonTextLabelWidth)

  kCustomizePlayAgainButtonSizeSpec = "gordo"

  kDefaultScoreboardCritterPanelBackgroundTop = 65
  kDefaultScoreboardCritterPanelBackgroundWidth = 800
  kDefaultScoreboardCritterPanelBackgroundHeight = 635
  kDefaultScoreboardCritterPanelTop = 235

  kDefaultSingleUserModeScoreboardTop = 450
  kDefaultSingleUserModeScoreboardWidth = 600
  kDefaultSingleUserModeScoreboardHeight = 100

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    this.addPlayAgainButton()

    # We might need to show one or the other at any given time
    @singleUserModeScoreboard = null
    @scoreboardCritterPanel = null

    @playAgainButtonClicked = false

    @fnClickPlayAgain = (evt)=>
      if not @playAgainButtonClicked
        @playAgainButtonClicked = true
        this.playAgainClicked()
      null

    @playAgainButton.addEventListener("click", @fnClickPlayAgain)

    this

  # ----------------------------------------------------------------------------------------------------------------
  @validatePlayAgainButtonCustomization: (positionSpec)->

    # We want to ensure that the "Play" button is on the screen
    kCustomizedHeight = kCustomizedWidth = Hy.UI.ButtonProxy.getDimension(kCustomizePlayAgainButtonSizeSpec)

    # We base constraints on whichever is larger. If there were an easier way to 
    # scan the customizations for specific values, w/o requiring the customization to be
    # active...
    height = Math.max(kCustomizedHeight, kDefaultPlayAgainButtonContainerHeight)
    width = Math.max(kCustomizedWidth, kDefaultPlayAgainButtonContainerWidth)

    sh = Hy.UI.iPad.screenHeight
    sw = Hy.UI.iPad.screenWidth

    constraint =
      min: 
        left:   0
        right:  0
        top:    0 
        bottom: 0
      max:
        left:   (sw - width) + 1
        right:  (sw - width) + 1
        top:    (sh - height) + 1
        bottom: (sh - height) + 1

    (new Hy.UI.PositionEx(positionSpec)).isValid(constraint)

  # ----------------------------------------------------------------------------------------------------------------
  addPlayAgainButton: ()->

    defaultOptions = 
      top: kDefaultPlayAgainButtonTop
      left: null

    if Hy.Customize.required("button", this.getPath(["playagainbutton"]))
      this.addPlayAgainButtonAndTextCustomized(defaultOptions)
    else
      this.addPlayAgainButtonAndTextMrF(defaultOptions)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addPlayAgainButtonAndTextMrF: (defaultOptions)->

    containerOptions = 
      height: kDefaultPlayAgainButtonContainerHeight
      width: kDefaultPlayAgainButtonContainerWidth
      zIndex: Page.kTouchZIndex - 1
      _tag: "Play Again Container"
#      borderColor: Hy.UI.Colors.white
#      borderWidth: 1

    mergedOptions = Hy.UI.ViewProxy.mergeOptions(defaultOptions, containerOptions)

    # Can only do this after size has been set
    Hy.Customize.mapOptions(["position"], this.getPath(["playagainbutton"]), mergedOptions)

    this.addChild(container = new Hy.UI.ViewProxy(mergedOptions))

    buttonOptions = 
      top: 0
      height: kDefaultPlayAgainButtonHeight
      width: kDefaultPlayAgainButtonHeight
      backgroundImage: "assets/icons/button-play-small-blue.png"
      zIndex: Page.kTouchZIndex
      _tag: "Play Again Button"
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1

    container.addChild(@playAgainButton = new Hy.UI.ButtonProxy(buttonOptions))

    textOptions = 
      top: 0
      height: kDefaultPlayAgainButtonContainerHeight
      width: kDefaultPlayAgainButtonTextLabelWidth
#      borderColor: Hy.UI.Colors.blue
#      borderSize: 1
      zIndex: Page.kTouchZIndex
      color:  Hy.UI.Colors.white
      _tag:   "Button Text"
      font:   Hy.UI.Fonts.specBigMrF
      textAlign: "center"

    specs =  [ 
      {left: kDefaultPlayAgainButtonPadding, text: "play"}, 
      {right: kDefaultPlayAgainButtonPadding, text: "again"} 
    ]

    for spec in specs
      container.addChild(new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(textOptions, spec)))

    this

  # ----------------------------------------------------------------------------------------------------------------
  addPlayAgainButtonAndTextCustomized: (defaultOptions)->

    height = Hy.UI.ButtonProxy.getDimension("large")

    buttonOptions = 
      _style: "round"
      _size: kCustomizePlayAgainButtonSizeSpec
      _text: Hy.Localization.T("Play-Again", "Play Again")
      zIndex: Page.kTouchZIndex
      _tag: "Play Again"
      _path: this.getPath(["playagainbutton"], "buttons")

    this.addChild(@playAgainButton = new Hy.UI.ButtonProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, buttonOptions)))

    # a little unconventional, but now that the button exists, customize its position
    options = @playAgainButton.getUIPropertiesAsOptions(["height", "width", "top", "bottom", "left", "right"])    
    Hy.Customize.mapOptions(["position"], this.getPath(["playagainbutton"]), options)
    @playAgainButton.setUIProperties(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  @validateScoreboardCustomization: (positionSpec)->

    # We want to ensure that the scoreboard is on the screen

    height = kDefaultSingleUserModeScoreboardHeight
    width = kDefaultSingleUserModeScoreboardWidth

    sh = Hy.UI.iPad.screenHeight
    sw = Hy.UI.iPad.screenWidth

    constraint =
      min: 
        left:   0
        right:  0
        top:    0 
        bottom: 0
      max:
        left:   (sw - width) + 1
        right:  (sw - width) + 1
        top:    (sh - height) + 1
        bottom: (sh - height) + 1

    (new Hy.UI.PositionEx(positionSpec)).isValid(constraint)


  # ----------------------------------------------------------------------------------------------------------------
  initializeSingleUserModeScoreboard: ()->

    if not @singleUserModeScoreboard?
      options = 
        top: kDefaultSingleUserModeScoreboardTop
        width: kDefaultSingleUserModeScoreboardWidth
        height: kDefaultSingleUserModeScoreboardHeight
        zIndex: Page.kPageContainerZIndex + 1
        _tag: "Single User Scoreboard"
        font: Hy.UI.Fonts.specBiggerNormal
        color: Hy.UI.Colors.black
        textAlign: "center"
#        borderColor: Hy.UI.Colors.red
#        borderWidth: 1

      Hy.Customize.mapFont(null, this.getPath(["scoreboard"]), options)
      if options.font? and (h = options.font.fontSize)?
        options.height = Math.min(options.font.fontSize, kDefaultSingleUserModeScoreboardHeight)

      Hy.Customize.mapOptions(["position", "background"], this.getPath(["scoreboard"]), options)
  
      this.addChild(@singleUserModeScoreboard = new Hy.UI.LabelProxy(options))

    this.updateSingleUserModeScoreboard()

    this

  # ----------------------------------------------------------------------------------------------------------------
  doneWithSingleUserModeScoreboard: ()->
    @singleUserModeScoreboard = null
    this

  # ----------------------------------------------------------------------------------------------------------------
  updateSingleUserModeScoreboard: ()->

    fnGetConsoleScore = ()=>
      score = if (consolePlayer = Hy.Player.ConsolePlayer.findConsolePlayer())?
        consolePlayer.score(Hy.ConsoleApp.get().getContest())
      else
        0
      score

    score = fnGetConsoleScore()

    text = if (t = Hy.Customize.map("text", this.getPath(["scoreboard"])))?
      Hy.Utils.String.replaceTokens(t, {score: score})
    else
      Hy.Localization.T( (if score is 1 then "score-point" else "score-points"), "Your Score: #\{score}", {score: score})

    @singleUserModeScoreboard?.setUIProperty("text", text)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getLogoOptions: (logoName)->

    options = super logoName

    switch logoName
      when "logo1"
        if not this.requiresCustomLogo("logo1")
          options.top = kDefaultLogo1Top
          options._tag = "Contest Completed Page Logo1"

          if this.hasLogoCustomization("logo1", ["font.*"])
            options.text = "Game Over"
            options.fontSize = 56
            options.url = null
            options.height = kDefaultLogo1Height
            options.width =  kDefaultLogo1Width
          else
            # Show MrF "Game Over" at the top
            options.url = "assets/icons/label-Game-Over.png"
            options.height = 74
            options.width =  374

    options

  # ----------------------------------------------------------------------------------------------------------------
  initializeScoreboardCritterPanel: ()->

    if not @scoreboardCritterPanel?

      backgroundOptions = this.addScoreboardCritterPanelBackground()

      top = kDefaultScoreboardCritterPanelBackgroundTop
      padding = 10
      width = backgroundOptions.width - 40
      height = backgroundOptions.height - ((top - backgroundOptions.top) + (6*padding))
      scoreboardOptions = 
        top: top
        height: height
        width: width
        left: (Hy.UI.iPad.screenWidth - width)/2
        zIndex: Page.kPageContainerZIndex + 2
        _orientation: "horizontal"
        borderWidth: 0
        borderColor: Hy.UI.Colors.red

      # Note that position customization is not supported...!
      Hy.Customize.mapOptions(["font"], this.getPath(["scoreboard"]), scoreboardOptions)

      this.addChild(@scoreboardCritterPanel = new Hy.Panels.ScoreboardCritterPanel(this, scoreboardOptions))

    @scoreboardCritterPanel?.initialize().displayScores()
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  addScoreboardCritterPanelBackground: ()->

    backgroundOptions =
      top: kDefaultScoreboardCritterPanelBackgroundTop
      height: kDefaultScoreboardCritterPanelBackgroundHeight
      width: kDefaultScoreboardCritterPanelBackgroundWidth
      zIndex: Page.kPageContainerZIndex + 1
      _tag: "Scoreboard Background"

    view = if (color = Hy.Customize.map("bordercolor", this.getPath(["scoreboard"])))? # ignore transparency
      backgroundOptions.borderColor = color
      backgroundOptions.borderWidth = 3 # Same as navGroup on StartPage (ContentOptionsPanel)
      backgroundOptions.backgroundColor = Hy.UI.Colors.gray # HACK
      new Hy.UI.ViewProxy(backgroundOptions)
    else
      backgroundOptions.image = "assets/icons/scoreboard-background.png"
      @scoreboardCritterPanelBackground = new Hy.UI.ImageViewProxy(backgroundOptions)

#    this.addChild(view) # TODO

    backgroundOptions

  # ----------------------------------------------------------------------------------------------------------------
  doneWithScoreboardCritterPanel: ()->
    @scoreboardCritterPane?.stop()
    @scoreboardCritterPanel = null
    @scoreboardCritterPanelBackground = null
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    f = super
    
    @playAgainButtonClicked = false

    if Hy.Network.PlayerNetwork.isSingleUserMode() or Hy.Player.Player.isConsolePlayerOnly()
      this.doneWithScoreboardCritterPanel()
      this.initializeSingleUserModeScoreboard()
    else
      this.doneWithSingleUserModeScoreboard()
      this.initializeScoreboardCritterPanel()

    f

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    @scoreboardCritterPanel?.stop()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  playAgainClicked: ()->
    Hy.Utils.Deferral.create(0, ()=>this.getApp().contestRestart(true))

  # ----------------------------------------------------------------------------------------------------------------
  getLeaderboard: ()->
    @scoreboardCritterPanel?.getLeaderboard()

# ==================================================================================================================
class AboutPage extends UtilityPage

  _.extend AboutPage, Hy.Utils.Observable 

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    this

  # ----------------------------------------------------------------------------------------------------------------
  getLogoOptions: (logoName)->

    # Special case for this page: Unlike other Utility Pages, we show no logos

    null

  # ----------------------------------------------------------------------------------------------------------------
  addBackgroundPanel: ()->

    # Special case for this page: Unlike other Utility Pages, we don't show the background 
    # panel natively. Instead, we show content on a panel on the web view

    this

  # ----------------------------------------------------------------------------------------------------------------
  getStandardButtonSpecs: ()->

    fn_resetButton = (buttonName)=>
      Hy.Utils.Deferral.create(5 * 1000, ()=>
        if (button = this.getStandardButtons().getButtonByName(buttonName))?
          button.setEnabled(true)
        null)
      null

    fnClickDone = ()=>
      # If we did a restore, we need to reinitialize the content list on the Start Page
      r = @restored
      @restored = false
      # ContentOptionsPanel is no longer on the start page
      this.getApp().showStartPage()
      null

    backButtonSpec = 
      name: "Back"
      buttonOptions:
        _style: "round"
        _size: "medium"
        _text: "Back"
      text: "Return To\nStart Page"
      fnClick: ()=> fnClickDone()

    fnClickRestore = ()=>
      # Must be online
      if Hy.Network.NetworkService.isOnline() 

        # If an update is available, force it first
        if Hy.Content.ContentManifestUpdate.getUpdate()?
          options = 
            message: "Trivially requires an update before purchases can be restored.\nTap \"update\" to begin"
            buttonNames: ["update", "cancel"]
            cancel: 1
          dialog = new Hy.UI.AlertDialog(options)
          dialog.addEventListener("click", fnUpdateClicked)
        else
          @restored = true
          Hy.Content.ContentManager.get()?.restore() # Let's present the restore UI on the About page
#          this.getApp().restoreAction()
      else
        new Hy.UI.AlertDialog("Please connect to Wifi and try again")

      null

    restoreButtonSpec = null # Hide for Triv Pro v1
    foo = 
      name: "Restore"
      buttonOptions: 
        _style: "round"
        _size: "medium"
        _text: "$"
      text: "Restore\nPurchases"
      fnClick: ()=>fnClickRestore()

    fnClickUpdate = ()=>
      if Hy.Network.NetworkService.isOnline()
         # Check for Content Update, then App Update
        if Hy.Content.ContentManifestUpdate.getUpdate()?
          Hy.Content.ContentManager.get()?.updateManifests()
        else if (update = Hy.Update.ConsoleAppUpdate.getUpdate())?
          update.doURL()
          fn_resetButton("Update")
        null

    updateButtonSpec = 
      name: "Update"
      buttonOptions: 
        _style: "round"
        _size: "medium"
        _text: this.updateAvailDisplay()
      text: "Updates\nAvailable?"
      fnClick: ()=> fnClickUpdate()

    contactUsButtonSpec = 
      name: "Contact"
      buttonOptions: 
        _style: "round"
        _size: "medium"
        _text: "Contact"
        font: Hy.UI.ButtonProxy.mergeDefaultFont({fontSize: 18}, "medium")      
      text: "Feedback?\nQuestions?"
      fnClick: ()=> 
        this.launchURL(Hy.Config.Support.contactUs)
        fn_resetButton("Contact")
        null

    helpButtonSpec = 
      name: "Help"
      buttonOptions: 
        _style: "round"
        _size: "medium"
        _text: "Help"
      text: "Get Help\nOn The Web"
      fnClick: ()=> 
        this.launchURL(this.getHelpButtonURL())
        fn_resetButton("Help")
        null
        

    [backButtonSpec, restoreButtonSpec, updateButtonSpec, contactUsButtonSpec, helpButtonSpec]

  # ----------------------------------------------------------------------------------------------------------------
  updateUpdateAvailableButtonState: ()->

    if this.isPageEnabled()
      if (button = this.getStandardButtons().getButtonByName("Update"))?
        button.setUIProperty("title", this.updateAvailDisplay())
        button.setEnabled(this.isUpdateAvailable())

    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewOptionsForCurrentPage: (data = {})->

    about = {}

    about.version = {}
    about.version.major =   Hy.Config.Version.Console.kConsoleMajorVersion
    about.version.minor =   Hy.Config.Version.Console.kConsoleMinorVersion
    about.version.minor2 =  Hy.Config.Version.Console.kConsoleMinor2Version
    about.version.moniker = Hy.Config.Version.Console.kVersionMoniker

    about.copyright = {}
    for i in ["copyright1", "copyright2"]
     about.copyright[i] = Hy.Config.Version[i]

    about.contact = "Tap \"Contact\" to visit ? or email us: ?"

    about.logos = {}
    about.logos.crowdgame = "assets/icons/CrowdGame-white.png"
    about.logos.trivially = "assets/icons/label-TriviallyPro-white.png" 

    this.addDataSection(data, "content", "aboutpage", about)

    super data
    
    data

  # ----------------------------------------------------------------------------------------------------------------
  getHelpButtonURL: ()-> Hy.Config.kHelpPage

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    f = super
    
    if (button = this.getStandardButtons().getButtonByName("Update"))?
      button.setEnabled(this.isUpdateAvailable())
      
    f

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super

    this.updateUpdateAvailableButtonState()

    Hy.Content.ContentManagerActivity.addObserver this
    Hy.Update.Update.addObserver this

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    this.updateUpdateAvailableButtonState()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    super

    Hy.Content.ContentManagerActivity.removeObserver this
    Hy.Update.Update.removeObserver this
    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_restoreInitiated: (report)->

    this.setPageEnabled(false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_restoreProgressReport: (report)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_restoreCompleted: (report)->

    this.setPageEnabled(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  isUpdateAvailable: ()->

    Hy.Network.NetworkService.isOnline() and (Hy.Content.ContentManifestUpdate.getUpdate()? or Hy.Update.ConsoleAppUpdate.getUpdate()?)

  # ----------------------------------------------------------------------------------------------------------------
  updateAvailDisplay: ()->

    display = if Hy.Network.NetworkService.isOnline()
      if this.isUpdateAvailable()
        "Yes!"
      else
        "No"
    else
      "?"

    display

  # ----------------------------------------------------------------------------------------------------------------
  obs_updateAvailable: (update)->

    this.updateUpdateAvailableButtonState()

    this

# ==================================================================================================================
class PageState

  gOperationIndex = 0

  @Any            = -1
  @None           =  0
  @Splash         =  1
  @Start          =  2
  @Question       =  3
  @Answer         =  4
  @Scoreboard     =  5
  @Completed      =  6
  @About          =  7
  @ContentOptions =  8
  @JoinCodeInfo   =  9
  @GameOptions    = 10

  stateToPageClassMap = [
#    {state: PageState.Splash,         display: "SplashPage",         pageClass: SplashPage},
    {state: PageState.Start,          display: "StartPage",          pageClass: StartPage},
    {state: PageState.Question,       display: "QuestionPage",       pageClass: QuestionPage},
    {state: PageState.Answer,         display: "QuestionPage",       pageClass: QuestionPage},
    {state: PageState.Completed,      display: "CompletedPage",      pageClass: ContestCompletedPage},
    {state: PageState.About,          display: "AboutPage",           pageClass: AboutPage}
    {state: PageState.ContentOptions, display: "ContentOptionsPage", pageClass: ContentOptionsPage},
    {state: PageState.JoinCodeInfo,   display: "JoinPage",           pageClass: JoinCodeInfoPage},
    {state: PageState.GameOptions,    display: "GameOptionsPage",    pageClass: GameOptionsPage}
  ]

  @defaultAnimateOut = {duration: 250, _startOpacity: 1, opacity: 0}
  @defaultAnimateIn  = {duration: 250, _startOpacity: 0, opacity: 1}

  transitionMaps = [  
    # For initial startup
    {
     oldState:               [PageState.None],
     newState:               [PageState.Start],   
     animateIn:              {duration: 1500, _startOpacity: 0, opacity: 1}
    },
    {
     oldState:               [PageState.Start],
     newState:               [PageState.Question],   
     animateOut:             {duration: 500, opacity: 0},
     animateIn:              {duration: 500, _startOpacity: 0, opacity: 1}
    },
    {
     oldState:               [PageState.Question],
     newState:               [PageState.Answer]
     animateOut:             {duration: 100, opacity: 1},
     animateIn:              {duration: 100, _startOpacity: 1, opacity: 1}
    },
    {
     oldState:               [PageState.Answer],
     newState:               [PageState.Question],
     animateOut:             {duration: 500, opacity: 0},
     animateIn:              {duration: 500, _startOpacity: 0, opacity: 1}
    },

    # Catch all - should be last
    {
     oldState:               [PageState.Any],
     newState:               [PageState.Any],
     animateOut:             PageState.defaultAnimateOut,
     animateIn:              PageState.defaultAnimateIn
    }

  ]

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @findTransitionMap: (oldPage, newPageState)->
    for map in transitionMaps
      if (oldPage? and oldPage.state in map.oldState) or ( (not oldPage?) and (PageState.None in map.oldState)) or (PageState.Any in map.oldState) # 2.5.0 
        if (newPageState in map.newState) or (PageState.Any in map.newState) # 2.5.0 
          return map

    return null

  # ----------------------------------------------------------------------------------------------------------------
  @getPageMap: (pageState)->
    for map in stateToPageClassMap
      if map.state is pageState
        return map
    return null
  
  # ----------------------------------------------------------------------------------------------------------------
  @getPageName: (pageState)->
    name = null
    map = this.getPageMap(pageState)
    if map?
      name = map.pageClass.name
    return name

  # ----------------------------------------------------------------------------------------------------------------
  @getPageDisplayName: (pageState)->
    name = null
    map = this.getPageMap(pageState)
    if map?
      name = map.display
    return name

  # ----------------------------------------------------------------------------------------------------------------
  @findPage: (pageState)->

    page = if (map = this.getPageMap(pageState))?
      Page.findPage(map.pageClass)
    else
      null

    page

  # ----------------------------------------------------------------------------------------------------------------
  @getPage: (pageState)->
    
    page = if (map = this.getPageMap(pageState))?
      Page.getPage(map)
    else
      null

    page

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @doneWithPage: (pageState)->
  
    if (map = this.getPageMap(pageState))?
      Page.doneWithPage(map)
      
    null

  # ----------------------------------------------------------------------------------------------------------------
  @doneWithPageState: ()->
    gInstance = null
    Page.doneWithPages()
    null

  # ----------------------------------------------------------------------------------------------------------------
  @init: (app)->
    if not gInstance?
      gInstance = new PageState(app)
    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  display: ()->
    s = "PageState::display"

    s += "("
    if (state = this.getState())?
      s += "#{state.oldPageState}->#{state.newPageState}"
    s += ")"

    s
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@app)->

    this.initialize()
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    @state = null

    timedOperation = new Hy.Utils.TimedOperation("PAGE INITIALIZATION")

    timedOperation.mark("DONE")
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    if (page = this.getApp().getPage())?
      page?.closeWindow()
      page?.stop()
      this.getApp().setPage(null)

    this
  
  # ----------------------------------------------------------------------------------------------------------------
  getApp: ()-> @app

  # ----------------------------------------------------------------------------------------------------------------
  getState: ()-> @state

  # ----------------------------------------------------------------------------------------------------------------
  setState: (state)-> @state = state

  # ----------------------------------------------------------------------------------------------------------------
  isTransitioning: ()-> 
    if (state = this.getState())?
      state.newPageState
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  getOldPageState: ()->
    this.getState()?.oldPageState

  # ----------------------------------------------------------------------------------------------------------------
  stopTransitioning: ()->
    this.setState(null)

  # ----------------------------------------------------------------------------------------------------------------
  addPostTransitionAction: (fnPostTransition)->

    if (state = this.getState())?
      @postFunctions.push(fnPostTransition)

    this

  # ----------------------------------------------------------------------------------------------------------------
  hasPostFunctions: ()-> _.size(@postFunctions) > 0

  # ----------------------------------------------------------------------------------------------------------------
  # I've re-written this function about 5 times so far. "This time for sure".
  # I've re-written this function about 6 times so far. "This time for sure".
  #
  showPage: (newPageState, fn_newPageInit, postFunctions = [])->

    initialState = 
      oldPage: this.getApp().getPage()
#      newPage: Hy.Pages.PageState.getPage(newPageState)
      newPage_: null # defer creating the new page 
      oldPageState: (if (oldPage = this.getApp().getPage())? then oldPage.getState() else null)
      newPageState: newPageState
      fn_newPageInit: fn_newPageInit

    if (existingState = this.getState())?
      s = "OLD STATE: oldPageState=#{if existingState.oldPage? then existingState.oldPage.getState() else "(NONE)"} newPageState=#{existingState.newPageState}"
      s += " NEW STATE: oldPageState=#{if initialState.oldPage? then initialState.oldPage.getState() else "(NONE)"} newPageState=#{initialState.newPageState}"      

      Hy.Trace.debug "PageState::showPage (RECURSION #{s})", true
      new Hy.Utils.ErrorMessage("fatal", "PageState::showPage", s)
      return

    @postFunctions = [].concat(postFunctions)

    this.setState(this.showPage_setup(initialState))

    this.showPage_execute()

    this

  # ----------------------------------------------------------------------------------------------------------------
  showPage_setup: (state)->

    state.spec = Hy.Pages.PageState.findTransitionMap(state.oldPage, state.newPageState)
    state.delay = if state.spec? then (if state.spec.delay? then state.spec.delay else 0) else 0
    state.animateOut = if state.spec? then state.spec.animateOut else Hy.Pages.PageState.defaultAnimateOut
    state.animateOutFn = if state.spec? then state.spec.animateOutFn
    state.animateInFn = if state.spec? then state.spec.animateInFn
    state.animateIn = if state.spec? then state.spec.animateIn else Hy.Pages.PageState.defaultAnimateIn
    state.networkServiceLevel = null
    state.operationIndex = ++gOperationIndex # For logging
    state.fnIndex = 0 # 
    state.fnCompleted = false

    fnDebug = (fnName, s="")=>
      p = ""
      if (state = this.getState())?
        p += "##{state.operationIndex} fn:#{state.fnIndex} "
        p += if (oldPageState = this.getState().oldPageState)? then oldPageState else "NONE"
        p += ">#{this.getState().newPageState}"
      else
        p = "(NO STATE!)"

      Hy.Trace.debug("PageState::showPage (#{p} #{fnName} #{if s? then s else ""})")
      null

    fnExecuteNext = (restart = false)=>
      ok = false

      if (state = this.getState())?
        if restart and not state.fnCompleted
          # Try the last operation again
          null 
        else
          ++state.fnIndex

        if state.fnIndex <= state.fnChain.length
          state.fnCompleted = false
          ok = true
          state.fnChain[state.fnIndex-1]()
          state.fnCompleted = true
      ok

    fnExecutePostFunction = ()=>
      if (f = @postFunctions.shift())?
        f(this.getApp().getPage())
      null

    fnExecuteRemaining = ()=>
      if (state = this.getState())?
        while fnExecuteNext()
          null

        this.showPage_exit(state.operationIndex)

        while _.size(@postFunctions) > 0
          fnExecutePostFunction()

      null

    fnIndicateActive = ()=>
      Hy.Network.NetworkService.setIsActive()
      fnExecuteNext()
      null

    fnSuspendNetwork = ()=>
      fnDebug("fnSuspendNetwork")
      if (ns = Hy.Network.NetworkService.get())?
        l = this.getState().networkServiceLevel = ns.getServiceLevel()
        fnDebug("fnSuspendNetwork (from \"#{l}\")")
        ns.setSuspended()
      fnExecuteNext()
      null

    fnResumeNetwork = ()=>
      fnDebug("fnResumeNetwork")
      if (serviceLevel = this.getState().networkServiceLevel)?
        Hy.Network.NetworkService.get().setServiceLevel(serviceLevel)
      fnExecuteNext()
      null

    # Returns existing instance of this kind of page, if it exists. 
    fnCheckNewPage =  ()=>
      Hy.Pages.PageState.findPage(state.newPageState)
     
    fnGetNewPage = ()=>
      this.getState().newPage_

    fnCreateNewPage = ()=>
      s = this.getState()
      if not s.newPage_?
        s.newPage_ = Hy.Pages.PageState.getPage(state.newPageState)
      s.newPage_
       
    fnSetBackground = (backgroundName = null)=>
      fnDebug("fnSetBackground", backgroundName)
      bkgnd = if backgroundName? then this.getState().spec?[backgroundName] else null
      this.getApp().setBackground(bkgnd)
      fnExecuteNext()

    fnStopOldPage = ()=>
      fnDebug("fnStopOldPage")
      oldPage = this.getState().oldPage
      if oldPage?
        oldPage.stop()
      fnExecuteNext()
      null

    fnAnimateOut = ()=>
      fnDebug("fnAnimateOut")
      duration = 0
      if (oldPage = this.getState().oldPage)?
        animateOut = this.getState().animateOut
        animateOutFn = this.getState().animateOutFn
        if animateOut?
          if animateOut._startOpacity?
            oldPage.window.setUIProperty("opacity", animateOut._startOpacity)
          oldPage.animateWindow(animateOut)
          duration = animateOut.duration
        else
          if animateOutFn?
            duration = animateOutFn(oldPage)
      if duration is -1 # -1 means we'll get called back to resume page transition
        fnDebug("fnAnimateOut", "WAITING")
      else
        Hy.Utils.Deferral.create(duration, fnExecuteNext)
      null

    fnCloseOldPage = ()=>
      fnDebug("fnCloseOldPage")
      if (oldPage = this.getState().oldPage)?
        newPage = fnCheckNewPage() # Might be null if page hasn't been created/used before #this.getState().newPage
        if oldPage isnt newPage
          oldPage.closeWindow()
        this.getApp().setPage(null)        
      fnExecuteNext()
      null

    fnInitNewPage = ()=>
      fnDebug("fnInitNewPage")
      newPage = fnCreateNewPage() #this.getState().newPage
      this.getApp().setPage(newPage)
      newPage.setState(this.getState().newPageState)

      if (newPage isnt this.getState().oldPage) and newPage.isWebContentPage()
        # apparently, the window has to be open in order for the webview to work...
        # But this causes problems with the subsequent window open call coming from 
        # "fnAnimateInAndOpenNewPage"
        newPage.getWindow().setUIProperty("opacity", 0)
        newPage.openWindow()

      if (result = this.getState().fn_newPageInit(newPage))
        fnExecuteNext()
      else
        fnDebug("fnInitNewPage: waiting")
      null

    fnAnimateInAndOpenNewPage = ()=>
      fnDebug("fnAnimateInAndOpenNewPage")
      duration = 0
      newPage = fnGetNewPage() #this.getState().newPage
      animateIn = this.getState().animateIn
      animateInFn = this.getState().animateInFn

      if animateIn? 
        duration = animateIn.duration
        if animateIn._startOpacity?
          newPage.window.setUIProperty("opacity", animateIn._startOpacity)

        if newPage is this.getState().oldPage
          newPage.animateWindow(animateIn)
        else
          newPage.openWindow(animateIn)
      else
        if animateInFn?
#          if newPage isnt this.getState().oldPage
#            newPage.openWindow()
          duration = animateInFn(newPage)
        else
          if newPage isnt this.getState().oldPage
            newPage.openWindow({opacity:1, duration:0})
          else
            newPage.animateWindow({opacity:1, duration:0})

      if duration is -1 # -1 means we'll get called back to resume page transition
        fnDebug("fnAnimateInAndOpenNewPage", "Waiting for callback")
      else
        fnDebug("fnAnimateInAndOpenNewPage", "Waiting #{duration}")
        Hy.Utils.Deferral.create(duration, fnExecuteNext)
      null

    fnStartNewPage = ()=>
      fnDebug("fnStartNewPage")
      fnGetNewPage().start()      
      fnExecuteNext()
      null

    # We do it this way since it makes it easier to change the order and timing of things,
    # and ensure the integrity of the transition across pause/resumed
    state.fnChain = # 2.5.0: removed default fnChain... 
      [
        fnSuspendNetwork,
        fnStopOldPage,
        fnAnimateOut, 
        ()=>fnSetBackground("animateOutBackground"),
        fnCloseOldPage,
        ()=>fnSetBackground("interstitialBackground"),
        ()=>Hy.Utils.Deferral.create(this.getState().delay, fnExecuteNext),

        ()=>fnSetBackground("animateInBackground"),
        fnInitNewPage,
        fnAnimateInAndOpenNewPage,
        ()=>fnSetBackground(),
        fnStartNewPage, 
        fnResumeNetwork,
        fnIndicateActive,
        fnExecuteRemaining
      ]

    state.fnExecuteNext = fnExecuteNext

    state

  # ----------------------------------------------------------------------------------------------------------------
  showPage_execute: (restart = false)->

    @state?.fnExecuteNext(restart) 

    this

  # ----------------------------------------------------------------------------------------------------------------
  showPage_exit: (operationIndex)->

    Hy.Trace.debug "PageState::showPage_exit (##{operationIndex})"

    this.setState(null)

  # ----------------------------------------------------------------------------------------------------------------
  resumed: (restart = false)->
    Hy.Trace.debug "PageState::resumed"

    if this.getState()?
      this.showPage_execute(restart)
    else
      if (page = this.getApp().getPage())?
        page.resumed()
      else
        Hy.Trace.debug "PageState::showPage (RESUMED BUT NO WHERE TO GO)"

    null

# ==================================================================================================================
class CountdownTicker
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@fnInitView, @fnUpdateView, @fnCompleted, @fnSound)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  init: (@value, startingDelay)->
    @startValue = @value

    this.clearTimers()

    this.display true

    fnTick = ()=>
      this.tick()

    f = ()=>
      this.display false
      @countdownInterval = setInterval fnTick, 1000
      @startingDelay = null

    if startingDelay > 0
      @startingDelay = Hy.Utils.Deferral.create startingDelay, f
    else
      f()
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  getValue: ()->
    @value

  # ----------------------------------------------------------------------------------------------------------------
  clearTimers: ()->

    if @countdownInterval?
      clearInterval(@countdownInterval)
      @countdownInterval = null

    if @startingDelay?
      @startingDelay.clear() 
      @startingDelay = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  display: (init)->

    if init
      @fnInitView @value
    else
      @fnSound @value
      @fnUpdateView @value

    this

  # ----------------------------------------------------------------------------------------------------------------
  exit: ()->
    this.pause()
    @value = null
    null

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    this.clearTimers()

    this

  # ----------------------------------------------------------------------------------------------------------------
  continue_: ()->
    this.init(@value||@startValue, 0)

  # ----------------------------------------------------------------------------------------------------------------
  reset: ()->
    @value = @startValue || 10 # TODO: should get default value from app

  # ----------------------------------------------------------------------------------------------------------------
  tick: ()->
    @value -= 1
    
    if @value >= 0
      this.display false

    if @value <= 0
      this.exit()
      @fnCompleted(source:this) 
    this

# ==================================================================================================================
Hyperbotic.Pages =
  Page: Page
  AboutPage: AboutPage
  GameOptionsPage: GameOptionsPage
  ContentOptionsPage: ContentOptionsPage
  JoinCodeInfoPage: JoinCodeInfoPage
  StartPage: StartPage
  QuestionPage: QuestionPage
  ContestCompletedPage: ContestCompletedPage
  PageState: PageState
  CountdownPage: CountdownPage

