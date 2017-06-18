# ==================================================================================================================
class Position

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@top = null, @left = null)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  getTop: ()-> @top

  # ----------------------------------------------------------------------------------------------------------------
  getLeft: ()-> @left

  # ----------------------------------------------------------------------------------------------------------------
  isValid: (device = Hy.UI.iPad)->
    valid = false

    if (this.getTop() >= 0) and (this.getTop() <= device["screenHeight"])
      if (this.getLeft() >= 0) and (this.getLeft() <= device["screenWidth"])
        valid = true

    valid

# ==================================================================================================================
#
# Based on the objects returned from the PEG-based parser in Hy.Customize
#

class CustomizationCoordinateSpec

  # ----------------------------------------------------------------------------------------------------------------
  @reportError: (message)->
    new Hy.Utils.ErrorMessage("fatal", "PositionEX", message) #will display popup dialog
    null

  # ----------------------------------------------------------------------------------------------------------------
  #
  #
  constructor: (dimensionSpecs = [])->

    @dimensionSpecs = []
    for d in dimensionSpecs
      @dimensionSpecs.push _.clone(d)

    this

  # ----------------------------------------------------------------------------------------------------------------
  _getSpecInfo: ()-> []

  # ----------------------------------------------------------------------------------------------------------------
  _findSpecInfo: (dimensionName)->
    s = _.find(this._getSpecInfo(), (s)=>s.name is dimensionName)
    
  # ----------------------------------------------------------------------------------------------------------------
  _getDimensionNames: ()->
    _.pluck(this._getSpecInfo(), "name")

  # ----------------------------------------------------------------------------------------------------------------
  _numDimensions: ()-> @dimensionSpecs.length

  # ----------------------------------------------------------------------------------------------------------------
  _addDimensionSpec: (dimensionSpec)->
    @dimensionSpecs.push dimensionSpec
    this

  # ----------------------------------------------------------------------------------------------------------------
  _setDefaults: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  _get: (dimensionSpec, options)->
    null

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Apply function "f" to each dimension, which is passed the dimension
  #
  _apply: (f)-> 
    # Apply function to result
    _.each(@dimensionSpecs, (d)=>f?(d))
    this

  # ----------------------------------------------------------------------------------------------------------------
  _find: (dimensionName)-> 
    _.find(@dimensionSpecs, (d)=>d.dimension is dimensionName)

  # ----------------------------------------------------------------------------------------------------------------
#  get: (dimensionName, options = {})->
#
#    value = if (dimensionSpec = this._find(dimensionName))?
#      this._get(dimensionSpec, options)
#    else
#      null
#
#    value

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Returns an "options" (object/hash) with appropriate values set corresponding to the
  # RAW values on this object. Does no processing for relative/offsets and "center", etc.
  #
  getOptionsRaw: (options = {})->

    fn_get = (dimensionSpec, options)=>

      d = dimensionSpec.dimension

      options[d] = switch dimensionSpec.kind
        when "absolute"
          this._get(dimensionSpec)
        when "relative"
          this._get(dimensionSpec)
        when "directive"
          null
      null

    this._apply((d)=>fn_get(d, options))
    options

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Returns an "options" (object/hash) with appropriate values set corresponding to the
  # interpreted values on this object. Does processing for relative/offsets and "center", etc.
  # The only real way to get a value off one of these things.
  #
  getOptions: (options = {})->

    fn_nullOpposite = (dimensionSpec, options)=>
      # A little post-processing... if we set top, unset bottom, and so on
      if (s = this._findSpecInfo(dimensionSpec.dimension))?
        if (o = s.opposite)?
          options[o] = null
      null

    fn_get = (dimensionSpec, options)=>

      d = dimensionSpec.dimension

      switch dimensionSpec.kind
        when "absolute"
          options[d] = this._get(dimensionSpec)
          fn_nullOpposite(dimensionSpec, options)
        when "relative"
          this._computeRelative(dimensionSpec, options)
          # We don't 'nullOpposite" here, since we may have actually set the opposite
        when "directive"
          options[d] = this._computeDirective(dimensionSpec, options)
          fn_nullOpposite(dimensionSpec, options)
      null

    this._apply((d)=>fn_get(d, options))
    options

  # ----------------------------------------------------------------------------------------------------------------
  setOptions: (options)->

    for d in this._getDimensionNames()
      if (v = options[d])?
        if (ds = this._find(d))?
          ds.kind = "absolute"
          ds.absolute = v
        else
          this.addDimensionSpec({kind: "absolute", dimension: dimensionName, absolute: v})
          
    this

  # ----------------------------------------------------------------------------------------------------------------
  isValid: (constraint = {})->

    message = null

    fn_check = (d)=>
      if (m = this._constraintCheck(d, constraint))?
        m = "\"#{d.dimension}\" #{m}"
        message = if message?
          message = "#{message}, #{m}"
        else
          m
      null

    count = 0

    this._apply((d)=>fn_check(d))

    message

  # ----------------------------------------------------------------------------------------------------------------
  _constraintCheck: (dimensionSpec, constraint = {})->

    # Check default constraints
    message = this._constraintCheckOnDimensionDefault(dimensionSpec, constraint)
    
    message

  # ----------------------------------------------------------------------------------------------------------------
  #
  # We only check basic constraint here
  #
  _constraintCheckOnDimensionDefault: (dimensionSpec, constraint = {})->

    message = null

    if (s = this._findSpecInfo(dimensionSpec.dimension))?
      if (value = this._get(dimensionSpec))?
        if not (value >= s.min)
          message = "must be >= #{s.min.toFixed(0)}"

        if not (value < s.max)
          message = "must be < #{s.max.toFixed(0)}"

    message

  # ----------------------------------------------------------------------------------------------------------------
  _constraintCheckOnDimension: (dimensionSpec, constraint = {})->

    message = null

    d = dimensionSpec.dimension

    if (value = this._get(dimensionSpec))?
      if constraint.min? and (cMin = constraint.min[d])? and not (value >= cMin)
        message = "must be >= #{cMin.toFixed(0)}"

      if constraint.max? and (cMax = constraint.max[d])? and not (value < cMax)
        message = "must be < #{cMax.toFixed(0)}"

    message

# ==================================================================================================================
#
#
#

class PositionEx extends CustomizationCoordinateSpec

  # ----------------------------------------------------------------------------------------------------------------
  @createCenteringPoint: (dimensions = ["top", "left"])->

    dimensionSpecs = (for d in dimensions
      {kind: "directive", directive: "center", dimension: d})

    new PositionEx(dimensionSpecs)

  # ----------------------------------------------------------------------------------------------------------------
  #
  #
  constructor: (dimensionSpecs = [])->

    super dimensionSpecs

    this

  # ----------------------------------------------------------------------------------------------------------------
  _getSpecInfo: (device = Hy.UI.iPad)->

    specInfo = [
      {name: "top",    opposite: "bottom", associated: "height", min: 0, max: device["screenHeight"] }
      {name: "bottom", opposite: "top",    associated: "height", min: 0, max: device["screenHeight"] }
      {name: "left",   opposite: "right",  associated: "width",  min: 0, max: device["screenWidth"]  }
      {name: "right",  opposite: "left",   associated: "width",   min: 0, max: device["screenWidth"]  }
    ]

    specInfo

  # ----------------------------------------------------------------------------------------------------------------
  _setDefaults: ()->
    super

    this._addDimensionSpec({kind: "absolute", dimension: "top", absolute: 0})
    this._addDimensionSpec({kind: "absolute", dimension: "left", absolute: 0})
    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Returns computed value
  #
  _computeDirective: (dimensionSpec, options, device = Hy.UI.iPad)->
    value = 0

    lName = null
    span = null

    switch dimensionSpec.directive
      when "center"
        switch dimensionSpec.dimension
          when "top", "bottom"
            lName = "height"
            span = device["screenHeight"]
          when "left", "right"
            lName = "width"
            span = device["screenWidth"]
          else
            null
    if span?
      if (l = options[lName])?
        value = (span - l)/2

    value

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Modifies "options"
  #
  _computeRelative: (dimensionSpec, options = {})->

    fn_getRelative = ()=>
      r = parseInt(dimensionSpec.relative)
      if isNaN(r)
        r = 0
      r

    relativeValue = null
    dimensionToSet = dimensionSpec.dimension
    dimensionToNull = null

    oppositeName = if (s = this._findSpecInfo(dimensionToSet))?
      s.opposite
    else
      null

    if (currentValue = options[dimensionToSet])?
      relativeValue = currentValue + fn_getRelative()
      dimensionToNull = oppositeName
    else
      # If we are trying to compute "right:-10", but right isn't set
      # Let's see if the opposite dimension ("left") has a value and compute it from there
      if oppositeName?
        if (oppositeValue = options[oppositeName])?
          # Ok, so "left" has a value... increment it in the inverse direction
          dimensionToSet = oppositeName
          relativeValue = oppositeValue - fn_getRelative()

    if relativeValue?
      options[dimensionToSet] = relativeValue

    if dimensionToNull
      options[dimensionToNull] = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  _computeRelative2: (dimensionSpec, options = {})->

    fn_getRelative = ()=>
      r = parseInt(dimensionSpec.relative)
      if isNaN(r)
        r = 0
      r

    currentValue = null
    d = dimensionSpec.dimension

    if not (currentValue = options[d])?
      # If we are trying to compute "right:-10", but right isn't set
      # Let's see if the opposite dimension ("left") has a value and compute it from there
      if (s = this._findSpecInfo(d))?
        if (oppositeName = s.opposite)? 
          if (opposite = this._findSpecInfo(oppositeName))?
            if (oppositeValue = options[oppositeName])?
              # Ok, so "left" has a value... now need the "width"
              if s.associated?
                if (associatedDimValue = options[s.associated])?
                  currentValue = (opposite.max - oppositeValue) - associatedDimValue

    if not currentValue?
      currentValue = 0

    fn_getRelative() + currentValue

  # ----------------------------------------------------------------------------------------------------------------
  # Returns the "raw" or unprocessed value
  #
  _get: (dimensionSpec)->

    value = switch dimensionSpec.kind
      when "absolute"
        dimensionSpec.absolute
      when "relative"
        dimensionSpec.relative
      when "directive"
        null
      else
        null

    value

  # ----------------------------------------------------------------------------------------------------------------
  isDirective: (dimensionName, directiveName)->
    result = false

    if (dimensionSpec = this._find(dimensionName))?
      if dimensionSpec.kind is "directive"
        if dimensionSpec.directive is "center"
          result = true

    result

  # ----------------------------------------------------------------------------------------------------------------
  _constraintCheck: (dimensionSpec, constraint = {})->

    message = switch dimensionSpec.kind
      when "absolute", "relative"
        this._constraintCheckOnDimension(dimensionSpec, constraint)
      else
        null

    if not message? and (dimensionSpec.kind is "absolute")
      message = super dimensionSpec, constraint
    
    message

# ==================================================================================================================
#
#
#

class SizeEx extends CustomizationCoordinateSpec

  # ----------------------------------------------------------------------------------------------------------------
  #
  #
  constructor: (dimensionSpecs = [])->

    super dimensionSpecs

    this

  # ----------------------------------------------------------------------------------------------------------------
  _getSpecInfo: (device = Hy.UI.iPad)->

    specInfo = [
      {name: "height", opposite: null,  min: 0, max: device["screenHeight"]+1 }
      {name: "width",  opposite: null, min: 0, max: device["screenWidth"]+1 }
    ]

    specInfo

  # ----------------------------------------------------------------------------------------------------------------
  _getDimensionNames: ()-> ["height", "width"]

  # ----------------------------------------------------------------------------------------------------------------
  _setDefaults: ()->
    super

    this._addDimensionSpec({kind: "absolute", dimension: "height", absolute: 100})
    this._addDimensionSpec({kind: "absolute", dimension: "width",  absolute: 0})
    this

  # ----------------------------------------------------------------------------------------------------------------
  _get: (dimensionSpec, options)->

    value = switch dimensionSpec.kind
      when "absolute"
        dimensionSpec.absolute
      else
        null

    value

  # ----------------------------------------------------------------------------------------------------------------
  _constraintCheck: (dimensionSpec, constraint = {})->

    if not (message = this._constraintCheckOnDimension(dimensionSpec, constraint))?
      message = super dimensionSpec, constraint
    
    message
 
# ==================================================================================================================
# UIElement: must be subclassed, and can't have children
# Width and Height must be set
# 
# options:
#  _imageSelected
#  _imageNotSelected
#
# Responds to:
#  
#  initialize
#  start
#  stop
#  pause
#  resumed
#
# Subclasses may implement:
#  viewOptions
#  createView
#

class UIElement

  kDefaultWidth = 100
  kDefaultHeight = 100
  
  gInstanceCount = 0
  gEventHandlerIndex = 0

  # Minimum time in milliseconds that must pass between click events
  # 2.5.0
  kClickEventMinDebounceTime = 0 # 700
  kAppListenerEventDelay = 700 # NOT USED


  # ----------------------------------------------------------------------------------------------------------------
  @mergeOptions: (optionSets...)->

    result = {}

    for optionSet in optionSets
      for name, value of optionSet
        result[name] = value

    result

  # ----------------------------------------------------------------------------------------------------------------
  @getPath: (options, kind = null)->

    p = if options._path?
      Hy.Customize.pathSetKind(options._path, kind)
    else
      Hy.Customize.path(null, [], kind)

    p

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@options={})->

    @index = ++gInstanceCount
    @uiProperties = {}
    @view = null
    @parent = null
    @enabled = true
    @lastClickEventTime = null # The timestamp of the last "click" event, for debouncing logic # 2.5.0

    @isView = false

    @listenerInfos = []
    @traces = []
    @traceAll = false

    this.initializeFromOptions(@options)

    @view = this.createView(@options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initializeFromOptions: (@options = {})=>

    @options._index = @index
    @options._topIndex = 0

#    @options.borderWidth = 1
#    @options.borderColor = Hy.UI.Colors.white

    @options = ViewProxy.mergeOptions(this.viewOptions(), @options)

    this.interpretOptions()

    this.setUIProperties(@options)

    this
  # ----------------------------------------------------------------------------------------------------------------
  # Fast way to distinguish
  #
  isViewProxy: ()-> @isView

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()-> {}

  # ----------------------------------------------------------------------------------------------------------------
  convertPointToView: (point, parentView)->

    this.getView().convertPointToView(point, parentView.getView())

  # ----------------------------------------------------------------------------------------------------------------
  mapUIPropertyIntoView: (propName, parentView)->

    dimensionToMap = null
    dimensionToIgnore = null

    mappedDimension = null

    switch propName
      when "top", "bottom"
        dimensionToMap = "y"
        dimensionToIgnore = "x"
      when "left", "right"
        dimensionToMap = "x"
        dimensionToIgnore = "y"

    if dimensionToMap? and dimensionToIgnore?
      point = {}
      point[dimensionToMap] = if (v = this.getUIProperty(propName))? then v else 0
      point[dimensionToIgnore] = 0

      if (mappedPoint = this.convertPointToView(point, parentView))?
        mappedDimension = mappedPoint[dimensionToMap]
 
    mappedDimension

  # ----------------------------------------------------------------------------------------------------------------
  getDumpStr: ()->
    s = "#{this.constructor.name}##{@index} #{if @tag? then @tag else ""} "

    if (p = this.getParent())?
      s += p.getDumpStr() + " > "

    s += "ME: w=#{this.getUIProperty("width")} h=#{this.getUIProperty("height")}"

    s

  # ----------------------------------------------------------------------------------------------------------------
  getParent: ()-> @parent

  # ----------------------------------------------------------------------------------------------------------------
  getTag: ()-> if @tag? then @tag else "?UIElement?"

  # ----------------------------------------------------------------------------------------------------------------
  interpretOptions: ()->

    if @options._tag?
      @tag = @options._tag

    this

  # ----------------------------------------------------------------------------------------------------------------
  getIndex: ()-> @index

  # ----------------------------------------------------------------------------------------------------------------
  getTopLevelIndex: ()-> this.getUIProperty("_topIndex")

  # ----------------------------------------------------------------------------------------------------------------
  isTopLevelView: ()-> 
    this.getUIProperty("_topIndex") is this.getIndex()

  # ----------------------------------------------------------------------------------------------------------------
  setTopLevelIndex: (parentTopLevelIndex, isTopLevel = false)->

    this.setUIProperty("_topIndex", (if isTopLevel then this.getIndex() else parentTopLevelIndex))

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->
 
    null

  # ----------------------------------------------------------------------------------------------------------------
  getUIProperties: ()-> @uiProperties

  # ----------------------------------------------------------------------------------------------------------------
  getUIPropertiesAsOptions: (propNames = [])->

    options = {}
    for propName in propNames
      if (v = this.getUIProperty(propName))?
        options[propName] = v

    options

  # ----------------------------------------------------------------------------------------------------------------
  getView: ()-> @view

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  show: (options = null)->

    if options?
      this.getView()?.show(options)
    else
      # Seeing random exceptions at this line in the simulator:
      # [ERROR] While executing Timer, received script error. 
      #'Result of expression '_ref2.show' [] is not a function. at views.js (line 169)'

      this.getView()?.show() 

    this

  # ----------------------------------------------------------------------------------------------------------------
  hide: ()->

    this.getView()?.hide()

  # ----------------------------------------------------------------------------------------------------------------
  startAnimation: ()->

    this.getView().start()

  # ----------------------------------------------------------------------------------------------------------------
  animate: (options, fn = null)->

    s = this.getDumpStr()

    fnDefault = (evt)=>
      null

    fnHandler = (evt)=>
      fn(evt)
      null

    this.getView().animate(options, if fn? then fnHandler else fnDefault)

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateDumpStr: (options, fn)->

    s = ""
    for name, value of options
      s += "#{name}=#{value} "

    s    

  # ----------------------------------------------------------------------------------------------------------------
  findEventListenerInfo: (eventName)->

    _.find(@listenerInfos, (l)=>l.eventName is eventName)

  # ----------------------------------------------------------------------------------------------------------------
  addEventListener: (eventName, fn_listener)->

    newlyAdded = false
    if not (listenerInfo = this.findEventListenerInfo(eventName))?
      @listenerInfos.push (listenerInfo = {eventName: eventName, processing: false, appSpecs: []})
      newlyAdded = true

    listenerInfo.appSpecs.push {fn_listener: fn_listener, index: ++gEventHandlerIndex}

    # For any given event, we register a handler only once
    if newlyAdded 
      f = (e)=>this.builtinListener(e)
      listenerInfo.fn_builtinListener = f

      # Do this last, once everthing is wired up 
      @view.addEventListener(eventName, f)

    gEventHandlerIndex

  # ----------------------------------------------------------------------------------------------------------------
  builtinListener: (e)->

    Hy.Trace.debug("UIElement::builtinHandler (ENTER \"#{e.type}\" on UIElement \"#{this.getTag()}/#{this.getIndex()}\")")

    fn_executeAppListeners = (l)=>

      # Should we disable this element here?
#      this.setEnabled(false) #? #TODO

      # Make a copy to avoid weirdness in case app code tries to add/remove handlers
      appSpecsCopy = [].concat(l.appSpecs) 

      # Now call all of the app-level listeners that have been registered
      for appSpec in appSpecsCopy
        this.executeAppListener(appSpec, e)

      l.processing = false
      e.source.touchEnabled = true
      Hy.Trace.debug("UIElement::builtinHandler (Completed executing #{appSpecsCopy.length} app handlers for \"#{e.type}\" on UIElement \"#{this.getTag()}/#{this.getIndex()}\")")
   
      null

    if this.isEnabled()
      if this.clickEventDebounce(e) # 2.5.0
        if (listenerInfo = this.findEventListenerInfo(e.type))?
          if listenerInfo.processing
            Hy.Trace.debug("UIElement::builtinHandler (Ignoring \"#{e.type}\" on UIElement \"#{this.getTag()}/#{this.getIndex()}\")")
          else
            if e.type is "click"
              e.source.touchEnabled = false # 2.5.0         
              listenerInfo.processing = true # 2.5.0 to deal with apparent problem with events in new NavGroup window
            
            Hy.Trace.debug("UIElement::builtinHandler (Executing #{listenerInfo.appSpecs.length} app handlers for \"#{e.type}\" on UIElement \"#{this.getTag()}/#{this.getIndex()}\")")

            Hy.Utils.Deferral.create(0, ()=>fn_executeAppListeners(listenerInfo))
        else
          # Whoops!
          new Hy.Utils.ErrorMessage("fatal", "UIElement", "Encountered event with no handler #{e.type}") #will display popup dialog
    else
      # Not enabled
      Hy.Trace.debug("UIElement::builtinHandler (NOT ENABLED \"#{e.type}\" on UIElement \"#{this.getTag()}/#{this.getIndex()}\")")

      null # For debugging

    # Event handlers really shouldn't return anything!
    #http://developer.appcelerator.com/question/134316/fyi-be-careful-what-you-return-in-certain-event-handlers#comment-120003
    null

  # ----------------------------------------------------------------------------------------------------------------
  builtinListener2: (e)->

    fn_executeAppListeners = (l)=>
      # Make a copy to avoid weirdness in case app code tries to add/remove handlers
      appSpecsCopy = [].concat(l.appSpecs) 

      # Now call all of the app-level listeners that have been registered
      for appSpec in appSpecsCopy
        this.executeAppListener(appSpec, e)

      l.processing = false
      Hy.Trace.debug("UIElement::builtinHandler (Completed executing #{appSpecsCopy.length} app handlers for \"#{e.type}\" on UIElement \"#{this.getTag()}/#{this.getIndex()}\")")
   
      null

    # We want to delay certain transitions due to apparent bug(s) in Titanium 3.1.3 # 2.5.0
    delay = if this.getUIProperty("_delayListenerEvent")? is true then kAppListenerEventDelay else 0

    if this.isEnabled()
      if (delay is 0) or ( (delay > 0) and this.clickEventDebounce(e) ) # 2.5.0
        if (listenerInfo = this.findEventListenerInfo(e.type))?
          if listenerInfo.processing
            Hy.Trace.debug("UIElement::builtinHandler (Ignoring \"#{e.type}\" on UIElement \"#{this.getTag()}/#{this.getIndex()}\")")
          else
            if e.type is "click"
              e.source.touchEnabled = false # 2.5.0         
              listenerInfo.processing = true
            
            Hy.Trace.debug("UIElement::builtinHandler (Executing #{listenerInfo.appSpecs.length} app handlers for \"#{e.type}\" on UIElement \"#{this.getTag()}/#{this.getIndex()}\" with delay=#{delay})")

            delay = 0 # 2.5.0
            Hy.Utils.Deferral.create(delay, ()=>fn_executeAppListeners(listenerInfo))
        else
          # Whoops!
          new Hy.Utils.ErrorMessage("fatal", "UIElement", "Encountered event with no handler #{e.type}") #will display popup dialog

    # Event handlers really shouldn't return anything!
    #http://developer.appcelerator.com/question/134316/fyi-be-careful-what-you-return-in-certain-event-handlers#comment-120003
    null

  # ----------------------------------------------------------------------------------------------------------------  
  executeAppListener: (appSpec, e)->

    Hy.Trace.debug("UIElement::executeAppListener (UIElement \"#{this.getTag()}/#{this.getIndex()}\" fn=#{appSpec.fn_listener?})")

    appSpec.fn_listener?(e, this.findAppListenerView(e))

    null

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Subclasses may provide alternate implementations
  #
  findAppListenerView: (e)->

    _topIndex = e.source._topIndex

    clickedView = null
    currentView = this

    # First check that this view isn't _topIndex, and then 
    # look up the parent chain for a match with _topIndex

    while currentView? and not clickedView?
      if currentView.getIndex() is _topIndex
        clickedView = currentView
      else
        currentView = currentView.getParent()

    clickedView
      
  # ----------------------------------------------------------------------------------------------------------------
  # Remove the specified app-level listener
  #
  removeEventListener: (name, fn_listener)->

    if (listenerInfo = this.findEventListenerInfo(eventName))?
      if (appSpec = _.find(listenerInfo.appSpecs, (s)=>s.fn_listener is fn_listener))?
        this.removeEventListener_(listenerInfo, appSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  removeEventListenerByIndex: (index)->

    for listenerInfo in @listenerInfos
      if (appSpec = _.find(listenerInfo.appSpecs, (s)=>s.index is index))?
        this.removeEventListener_(listenerInfo, appSpec)
        break
      
    this

  # ----------------------------------------------------------------------------------------------------------------
  removeEventListener_: (listenerInfo, appSpec)->

    listenerInfo.appSpecs = _.without(listenerInfo.appSpecs, appSpec)

    if listenerInfo.appSpecs.length is 0
      this.clearListener(listenerInfo)

    this

  # ----------------------------------------------------------------------------------------------------------------
  clearListener: (listenerInfo)-> 
    @view.removeEventListener(listenerInfo.eventName, listenerInfo.fn_builtinListener)
    @listenerInfos = _.reject(@listenerInfos, (l)=>l.eventName is listenerInfo.eventName)
    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Return true if a sufficient amount of time has passed since the last time this element was "click"-ed
  #
  clickEventDebounce: (evt)-> # 2.5.0

    return true # 2.5.0

    ok = true 

    if evt.type is "click" 
      if @lastClickEventTime?
        delta = @lastClickEventTime.getDelta()
        if delta < kClickEventMinDebounceTime
          Hy.Trace.debug "UIElement::clickEventDebounce (ignoring - #{delta}ms)"
          ok = false

      @lastClickEventTime = new Hy.Utils.TimedOperation("ClickEventDebounce")

    ok

  # ----------------------------------------------------------------------------------------------------------------
  setTraceAll: (flag = true)->

    @traceAll = flag

    this

  # ----------------------------------------------------------------------------------------------------------------
  setTrace: (propName, diagnostic = "")->

    Hy.Trace.debug("UIElement::TRACE (set trace for #{this.getDumpStr()} #{propName} #{diagnostic})")    
    @traces.push {propName: propName, diagnostic: diagnostic}

    this

  # ----------------------------------------------------------------------------------------------------------------
  checkTrace: (uiElement, propName, oldValue, newValue)->

    fn_display = (propName, oldValue, newValue, diagnostic = "")=>
      Hy.Trace.debug("UIElement::TRACE (#{this.getDumpStr()} #{propName} #{diagnostic} CHANGED #{oldValue}->#{newValue})")
      null

    if Hy.Config.Trace.uiTrace

      if @traceAll
        fn_display(propName, oldValue, newValue, "")
      else
        for trace in _.select(@traces, (t)=>t.propName is propName)
          fn_display(propName, oldValue, newValue, trace.diagnostic)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addBorder: (borderColor = Hy.UI.Colors.white)->

    this.setUIProperty("borderWidth", 1)
    this.setUIProperty("borderColor", borderColor)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setPosition: (point)->
    this.setUIProperties({top: point.getTop(), left: point.getLeft()})
    this
    
  # ----------------------------------------------------------------------------------------------------------------
  setUIProperty: (propName, propValue)->

    this.checkTrace(this, propName, @uiProperties[propName], propValue)

    @uiProperties[propName] = propValue
    @view?[propName] = propValue

    this

  # ----------------------------------------------------------------------------------------------------------------
  setUIProperties: (options)->
    for name, value of options
      this.setUIProperty(name, value)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getUIProperty: (propName)->

    if not (propValue = this.getUIProperty_(propName))?
      propValue = this.getUIPropertyComputed_(propName)

    propValue

  # ----------------------------------------------------------------------------------------------------------------
  getUIProperty_: (propName)->

    @uiProperties?[propName] 

  # ----------------------------------------------------------------------------------------------------------------
  getUIPropertyComputed_: (propName)->

    fnAlert = ()=>
      null

    fnGetParentProperty = (propName)=>
      value = if this.getParent()?
        this.getParent().getUIProperty(propName)
      else
        null
      value

    propValue = null

    switch propName
      when "right"
        if (left = this.getUIProperty_("left"))? and (width = this.getUIProperty_("width"))? and (parentWidth = fnGetParentProperty("width"))?
          propValue = parentWidth - (left + width)

      when "left"
        if (right = this.getUIProperty_("right"))? and (width = this.getUIProperty_("width"))? and (parentWidth = fnGetParentProperty("width"))?
          propValue = parentWidth - (right + width)

      when "bottom"
        if (top = this.getUIProperty_("top"))? and (height = this.getUIProperty_("height"))? and (parentHeight = fnGetParentProperty("height"))?
          propValue = parentHeight - (top + height)

      when "top"
        if (bottom = this.getUIProperty_("bottom"))? and (height = this.getUIProperty_("height"))? and (parentHeight = fnGetParentProperty("height"))?
          propValue = parentHeight - (bottom + height)

      when "width"
        if (right = this.getUIProperty_("right"))? and (left = this.getUIProperty_("left"))? and (parentWidth = fnGetParentProperty("width"))?
          propValue = parentWidth - (right + left)

      when "height"
        if (top = this.getUIProperty_("top"))? and (bottom = this.getUIProperty_("bottom"))? and (parentHeight = fnGetParentProperty("height"))?
          propValue = parentHeight - (bottom + top)

    if propValue?
      fnAlert() # For debugging

    propValue

  # ----------------------------------------------------------------------------------------------------------------
  incrementNumericProperty: (propName, increment)->

    if not (value = this.getUIProperty(propName))?
      value = 0

    this.setUIProperty(propName, value + increment)

  # ----------------------------------------------------------------------------------------------------------------
  setEmphasisUI_NOT_USED: (emphasis)->

    switch emphasis
      when "selected"
        this.setUIProperty("borderColor", Hy.UI.Colors.white)
        this.setUIProperty("borderWidth", 2)
      when "none", "notSelected"
        this.setUIProperty("borderColor", Hy.UI.Colors.black)
        this.setUIProperty("borderWidth", 0)

    this

  # ----------------------------------------------------------------------------------------------------------------
  attachToView: (viewB, attachOptions = {})->

    viewA = this

    adjustA = null
    adjustB = null

    _attach = if attachOptions._attach? then attachOptions._attach else "top"
    _padding = if attachOptions._padding? then attachOptions._padding else 0

    switch _attach
      when "top"
        adjustA = {name: "top", value: 0}
        adjustB = {name: "top", value: viewA.getUIProperty("height") + _padding}
      when "bottom"
        adjustA = {name: "top", value: viewB.getUIProperty("height") + _padding}
        adjustB = {name: "top", value: 0}
      when "left"
        adjustA = {name: "left", value: 0}
        adjustB = {name: "left", value: viewA.getUIProperty("width") + _padding}
      when "right"
        adjustA = {name: "left", value: viewB.getUIProperty("width") + _padding}
        adjustB = {name: "left", value: 0}
      else
        null

    if adjustA?
      viewA.setUIProperty(adjustA.name, adjustA.value)

    if adjustB?
      viewB.setUIProperty(adjustB.name, adjustB.value)

    this

  # ----------------------------------------------------------------------------------------------------------------
  isEnabled: ()-> @enabled

  # ----------------------------------------------------------------------------------------------------------------
  # If set false, we inhibit event handling
  #
  setEnabled: (enabled)->

    @enabled = enabled
    
    anim = false

    if anim
      this.animate({opacity: (if @enabled then 1.0 else 0.5), duration: 250})
    else
      this.setUIProperty("opacity", if @enabled then 1.0 else 0.5)

    this

      
# ==================================================================================================================
# ViewProxy: can have children
#  Options can include:
#
#   _verticalLayout and/or _horizontalLayout
#      "group"                           : Groups children together, with _padding spacing, centered in the dimension
#      "distribute"                      : Distribute children evenly across the specific dimension (height or width)
#                                          Ignores _padding
#      "center"                          : center children in the specific dimension
#      "left", "right", "top", "bottom"  : as specified
#
#   _padding
#

class ViewProxy extends UIElement

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options={})->

    super options

    @isView = true 

    @children = []

    @childrenExtent = {}
    @childrenExtent.height = 0
    @childrenExtent.width = 0

    this

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

    super
  
    Ti.UI.createView(options)

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Replaces implementation on UIElement
  #
  findAppListenerView: (evt)->

    _topIndex = evt.source._topIndex
    _index = evt.source._index

    view = null

    if this.getIndex() is _topIndex
      view = this
    else
      if _.size(results = this.findChildrenByUIProperty("_index", _topIndex)) isnt 0
        view = _.first(results) 

    view

  # ----------------------------------------------------------------------------------------------------------------
  numChildren: ()-> _.size(this.getChildren())

  # ----------------------------------------------------------------------------------------------------------------
  hasChildren: ()-> this.numChildren() > 0

  # ----------------------------------------------------------------------------------------------------------------
  getChildren: ()-> @children

  # ----------------------------------------------------------------------------------------------------------------
  hasChild: (uiElement)->

#    _.detect(this.getChildren(), (c)=>c is view)?
    _.contains(this.getChildren(), uiElement)

  # ----------------------------------------------------------------------------------------------------------------
  applyToChildren: (action)->

    _.select(this.getChildren(), (c)=>c[action]?())

  # ----------------------------------------------------------------------------------------------------------------
  setUIProperty: (propName, propValue, deep=false)->

    super

    if deep
      for child in this.getChildren()
        child.setUIProperty(propName, propValue, deep)
   
    this

  # ----------------------------------------------------------------------------------------------------------------
  findChildrenByUIProperty: (name, value, deep = false)->

    results = []

    for child in this.getChildren()
      if (property = child.uiProperties[name])? and (property is value)
        results.push child
      if deep and child.isViewProxy()
         if _.size(subResults = child.findChildrenByUIProperty(name, value, deep)) > 0
           results.push subResults
 
    _.flatten(results)

  # ----------------------------------------------------------------------------------------------------------------
  findChildrenByProperty: (name, value)->

    _.select(this.getChildren(), (child)=>child[name] is value)

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->
    super

#    this.applyToChildren("initialize")

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    super

#    this.applyToChildren("initialize")

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super

#    this.applyToChildren("initialize")

  # ----------------------------------------------------------------------------------------------------------------
  # addChildOptions:
  #
  #  isTopLevel  : Indicates that this view should respond to events on its children
  #
  #  _verticalLayout and _horizontalLayout: possible values are:
  #
  #    "center"  : center the child in the specific dimension
  #    "distribute"
  #    "left", "right", "bottom"
  #    "group"
  #    "distribute"
  #
  #  This directive is applied after any parent directives that may be in force, such as "_horizontalLayout"
  #
  addChild: (child, isTopLevel = false, addChildOptions = null)->

    if child?
      if this.addChild_(child, isTopLevel)?
        this.layoutChildren()

        if addChildOptions?
          this.layoutChild(child, addChildOptions)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addChild_: (child, isTopLevel)->

    result = null

    if child?
      if child is this
        parentTag = "\"#{if t = this.getUIProperty("_tag") then t else "?"}\""
        s = "Parent #{parentTag} trying to itself as a child"
        new Hy.Utils.ErrorMessage("fatal", "View", s) #will display popup dialog
      else
        if _.indexOf(this.getChildren(), child) is -1

          if (parent = child.getParent())? and (parent isnt this)
            parent.removeChild(child)

          @children.push(child)
          child.parent = this

          if (view = child.getView())?
            this.getView().add(view)

        child.setTopLevelIndex(this.getIndex(), isTopLevel)

        result = this

    result

  # ----------------------------------------------------------------------------------------------------------------
  addChildren: (children)->

    if children?
      for child in children
        this.addChild_(child, false)

      this.layoutChildren()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Arranges children according to _verticalLayout/_horizontalLayout directives specified on the parent (this)
  #
  layoutChildren: ()->

    this.layoutChildren_(this.getChildren(), this.getUIProperties())

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Arranges child according to _verticalLayout/_horizontalLayout directives supplied to addChild()
  #
  layoutChild: (child, directives)->

    this.layoutChildren_([child], directives)

    this

  # ----------------------------------------------------------------------------------------------------------------
  layoutChildren_: (children, directives)->

    for dimension in ["horizontal", "vertical"]
      if (directive = directives["_#{dimension}Layout"])?
        this.layoutChildrenInDimension(dimension, directive, children)

    this

  # ----------------------------------------------------------------------------------------------------------------
  layoutChildren_2: (directivesSource, children)->

    for dimension in ["horizontal", "vertical"]
      if (directive = directivesSource.getUIProperty("_#{dimension}Layout"))?
        this.layoutChildrenInDimension(dimension, directive, children)

    this

  # ----------------------------------------------------------------------------------------------------------------
  layoutChildrenInDimension: (dimension, directive, children)->

    # Inter-child spacing
    if (not (_padding = this.getUIProperty("_padding"))?) or (directive is "distribute")
      _padding = 0

    # Extra spacing along the sides of the parent view
    if not (_margin = this.getUIProperty("_margin"))?
      _margin = 0

    if dimension is "horizontal" 
        propToAdjust = "left"
        propToMeasure = "width"
        propToCopy = "top"
        propToTrack = "height"
    else 
        propToAdjust = "top"
        propToMeasure = "height"
        propToCopy = "left"
        propToTrack = "width"

    fnFindAndAdjustExtent = ()=>
      adjust = 0
      extent = _.reduce(children, ((memo, c)=>memo + c.getUIProperty(propToMeasure)), 0) + ((_.size(children)-1) * _padding)     
      extent += 2 * _margin # Add in space along the sides

      if (parentPropToMeasure = this.getUIProperty(propToMeasure))?
        adjust = Math.max(parentPropToMeasure - extent, 0)       
      else
        adjust = 0
        this.setUIProperty(propToMeasure, extent)
      if not (parentPropToAdjust = this.getUIProperty(propToAdjust))?
        this.setUIProperty(propToAdjust, 0)

      adjust

    remaining = fnFindAndAdjustExtent()

    lastChild = null

    adjust = switch directive
      when "left", "top", "none"
        0
      when "right", "bottom"
        remaining
      when "group"
        remaining/2
      when "distribute"
        remaining/(_.size(children) + 1) # We divide up the space evenly between the children

    for child in children

      switch directive
        when "center"
          diff = Math.max(0, this.getUIProperty(propToMeasure) - ( (2 * _margin) + child.getUIProperty(propToMeasure)))
          child.setUIProperty(propToAdjust, _margin + diff/2)
        else
          if lastChild?
            interChildDelta = if directive is "distribute" then adjust else _padding

            child.setUIProperty(propToAdjust, lastChild.getUIProperty(propToAdjust) + lastChild.getUIProperty(propToMeasure) + interChildDelta)
          else
            child.setUIProperty(propToAdjust, adjust + _margin)

      lastChild = child

    @childrenExtent[propToMeasure] = if lastChild? then (lastChild.getUIProperty(propToAdjust) + lastChild.getUIProperty(propToMeasure)) else 0
    @childrenExtent[propToTrack] = Math.max(@childrenExtent[propToTrack], if lastChild? then lastChild.getUIProperty(propToTrack) else 0)

    this

  # ----------------------------------------------------------------------------------------------------------------
  computeChildrenExtent: ()->

  # ----------------------------------------------------------------------------------------------------------------
  getChildrenExtent: (dimension)->

    @childrenExtent[dimension]

  # ----------------------------------------------------------------------------------------------------------------
  setTopLevelIndex: (parentTopLevelIndex, isTopLevel = false)->

    super

    for child in this.getChildren()
      if child.isTopLevelView()
        null
      else
        child.setTopLevelIndex(if isTopLevel then this.getIndex() else parentTopLevelIndex)

    this

  # ----------------------------------------------------------------------------------------------------------------
  conformToChildren: (dimension = null)->

    d = []    
    if dimension?
      d.push dimension
    else
      d.push "height"
      d.push "width"

    for dimen in d
      this.setUIProperty(dimen, this.getChildrenExtent(dimen))

    this

  # ----------------------------------------------------------------------------------------------------------------
  removeChild_: (child)->

    if _.indexOf(@children, child) isnt -1
      @children = _.without(@children, child)

      if (view = child.getView())?
        this.getView().remove(view)

    child.parent = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  removeChild: (child)->

    this.removeChild_(child)

    this.layoutChildren()

    this

  # ----------------------------------------------------------------------------------------------------------------
  removeChildren: (children = @children)->

    if children?
      # Handle the case where children is @children, which will be modified by removeChild
      for child in children.slice() 
        this.removeChild_(child)

      this.layoutChildren()

    this

# ==================================================================================================================
class WindowProxy extends ViewProxy

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

    Ti.UI.createWindow(options)

  # ----------------------------------------------------------------------------------------------------------------
  open: (options = {})->
    this.getView().open(options)

  # ----------------------------------------------------------------------------------------------------------------
  close: (options = {})-> # 2.5.0 added options
    this.getView().close(options)


# ==================================================================================================================
class LabelProxy extends ViewProxy

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

    Ti.UI.createLabel(options)

  # ----------------------------------------------------------------------------------------------------------------
  setText: (text)->

    this.getView().setText(text)

    this

# ==================================================================================================================
class TextAreaProxy extends ViewProxy

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

    Ti.UI.createTextArea(options)

# ==================================================================================================================
# Responds to:
#   _value, _text
#
class SystemButtonProxy extends UIElement

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

    Ti.UI.createButton(options)


# ==================================================================================================================
# Responds to:
#   _value, _text, backgroundImage, _debounce
#
class ButtonProxy extends SystemButtonProxy

  # Just like Olives
  @defaultFont =
    tiny:    {fontSize: 16, fontWeight: 'bold', fontFamily: "Trebuchet MS"}
    small:   {fontSize: 20, fontWeight: 'bold', fontFamily: "Trebuchet MS"}
    medium:  {fontSize: 26, fontWeight: 'bold', fontFamily: "Trebuchet MS"}
    medium2: {fontSize: 26, fontWeight: 'bold', fontFamily: "Trebuchet MS"}
    large:   {fontSize: 36, fontWeight: 'bold', fontFamily: "Trebuchet MS"}
    gordo:   {fontSize: 32, fontWeight: 'bold', fontFamily: "Trebuchet MS"}
    jumbo:   {fontSize: 48, fontWeight: 'bold', fontFamily: "Trebuchet MS"}

  # 1.4.0: Changed tiny to 38 from 40
  @dimensions = {tiny: 38, small: 54, medium: 76, medium2: 86, large: 110, gordo: 170, jumbo: 200}

  # ----------------------------------------------------------------------------------------------------------------
  @getDimension: (size)->
    ButtonProxy.dimensions[size]

  # ----------------------------------------------------------------------------------------------------------------
  @getDefaultFont: (size = "small")->
    ButtonProxy.defaultFont[size]

  # ----------------------------------------------------------------------------------------------------------------
  @mergeDefaultFont: (font, size = small)->
    Hy.UI.Fonts.mergeFonts(ButtonProxy.getDefaultFont(size), font)

  # ----------------------------------------------------------------------------------------------------------------
  @mergeDefaultFontSize: (fontSize, size = small)->
    Hy.UI.Fonts.mergeFonts(ButtonProxy.getDefaultFont(size), {fontSize: fontSize})

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options)->

    mergedOptions = Hy.UI.ViewProxy.mergeOptions(options, this.processOptions(options))

    # http://developer.appcelerator.com/question/129864/titaniumuicreatebutton---background-selected-image-is-not-working-in-the-1801-titanium-platform
    # Regression!

    if mergedOptions.backgroundSelectedImage?
      mergedOptions.backgroundFocusedImage = mergedOptions.backgroundSelectedImage

    super mergedOptions

    this

  # ----------------------------------------------------------------------------------------------------------------
  # backgroundImage overrides everything else
  #
  # _style = round
  #          if specified, _size (tiny, small, medium, medium2, large, etc) must also be specified
  #
  # title is ignored, use:
  # _text, _value, _symbol (in that order)
  #

  processOptions: (options)->

    defaultOptions = {}

    defaultOptions._size = if options._size? 
      options._size
    else
      "small"

    defaultOptions.font = Hy.UI.Fonts.mergeFonts(ButtonProxy.getDefaultFont(defaultOptions._size), options.font)
    defaultOptions.color = Hy.UI.Colors.white

    # We pass in "buttons" as elementKind, since the user can specify customizations
    # that affect all buttons at the global or page level
    Hy.Customize.mapFont(null, UIElement.getPath(options, "buttons"), defaultOptions)

    size = ButtonProxy.dimensions[defaultOptions._size]

    switch options._style
      when "round"
        if size?
          defaultOptions.width = defaultOptions.height = size
          defaultOptions.borderRadius = size/2

    if options.backgroundImage?
      defaultOptions.backgroundImage = options.backgroundImage
      defaultOptions.backgroundSelectedImage = options.backgroundSelectedImage
    else
      defaultOptions.borderWidth = switch defaultOptions._size
        when "tiny"
          1
        when "large", "gordo", "jumbo"
          4
        else
          if options.borderWidth? 
            options.borderWidth
          else
            2

      defaultOptions.borderColor = Hy.Customize.map("borderColor", UIElement.getPath(options, "buttons"), Hy.UI.Colors.white) # ignore transparency

      defaultOptions.backgroundColor =  Hy.Customize.map("buttons.color", UIElement.getPath(options), Hy.UI.Colors.black) # ignore transparency

    defaultOptions.title = if options._text? 
      options._text 
    else 
      if options._value?
        options._value
      else
        if options._symbol?
          this.processSymbolOptions(options._symbol, defaultOptions)
          defaultOptions._text
        else
          options.title

    defaultOptions

  # ----------------------------------------------------------------------------------------------------------------
  isSymbol: ()-> this.getUIProperty("_symbol")?

  # ----------------------------------------------------------------------------------------------------------------
  @kSymbolSpecs = 
    check:      
      font: null
      fontSize: {tiny: 30, small: 36, medium: 36, large: 36, gordo: 36, jumbo: 48}
      text: "\u2713"
    rightArrow: # http://www.fileformat.info/info/unicode/char/2192/index.htm
      font: {fontSize: 36, fontWeight: 'bold', fontFamily: "Courier Bold"}
      fontSize: {tiny: 18, small: 24, medium: 36, large: 36, gordo: 36, jumbo: 48}
      text: "\u2192"
    leftArrow: 
      font: {fontSize: 24, fontWeight: 'bold', fontFamily: "Courier Bold"}
      fontSize: {tiny: 20, small: 24, medium: 36, large: 36, gordo: 36, jumbo: 48}
      text: "\u2190"
    topArrow: 
      font: {fontSize: 24, fontWeight: 'bold', fontFamily: "Courier Bold"}
      fontSize: {tiny: 20, small: 24, medium: 36, large: 36, gordo: 36, jumbo: 48}
      text: "\u2191"
    bottomArrow: 
      font: {fontSize: 24, fontWeight: 'bold', fontFamily: "Courier Bold"}
      fontSize: {tiny: 20, small: 24, medium: 36, large: 36, gordo: 36, jumbo: 48}
      text: "\u2193"

  # ----------------------------------------------------------------------------------------------------------------
  processSymbolOptions: (symbol, defaultOptions)->

    if (symbolSpec = ButtonProxy.kSymbolSpecs[symbol])?
      defaultOptions._text = symbolSpec.text

      if symbolSpec.font?
        defaultOptions.font = symbolSpec.font

      if symbolSpec.fontSize? and (fontSize = symbolSpec.fontSize[defaultOptions._size])?
        defaultOptions.font.fontSize = fontSize

    defaultOptions

  # ----------------------------------------------------------------------------------------------------------------
  # If set false, button won't respond to user manipulation (?)
  #
  setEnabled: (enabled)->

    this.setUIProperty("enabled", enabled) # Titanium property, which appears to work sometimes

    super

    this

# ==================================================================================================================
#
# Keeps track of its pressed state... when the user taps it, it lights up, etc.
#

class ButtonProxyWithState extends ButtonProxy

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options)->

    super options

    this.setSelected(false)

    this.addEventListener("click", (e, v)=>this.toggleHandler(e, v))

    this

  # ----------------------------------------------------------------------------------------------------------------
  toggleHandler: (e, v)-> # 2.5.0

    if this.isEnabled() # Theoretically, this test isnt needed, since handler wont be fired in the first place
      this.toggleSelected()
    this

  # ----------------------------------------------------------------------------------------------------------------
  processOptions: (options)->

    defaultOptions = super options

    defaultOptions

  # ----------------------------------------------------------------------------------------------------------------
  isSelected: ()-> @selected

  # ----------------------------------------------------------------------------------------------------------------
  toggleSelected: ()->

    this.setSelected(not this.isSelected())

    this.isSelected()

  # ----------------------------------------------------------------------------------------------------------------
  setSelected: (isSelected)->

    @selected = isSelected

    switch @selected
      when true
        if (backgroundSelectedImage = this.getUIProperty("backgroundSelectedImage"))?
          this.setUIProperty("backgroundSelectedImage", backgroundSelectedImage)
        else
          selectedColor = Hy.Customize.map("buttons.color", UIElement.getPath(@options), Hy.UI.Colors.MrF.DarkBlue) # ignore transparency
          this.setUIProperty("backgroundColor", selectedColor) # ignore transparency

      when false
        if (backgroundImage = this.getUIProperty("backgroundImage"))?
          this.setUIProperty("backgroundImage", backgroundImage)
        else
          this.setUIProperty("backgroundColor", Hy.UI.Colors.black)

    if this.isSymbol()
      this.setSelectedSymbol(isSelected)
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  setSelectedSymbol: (isSelected)->

    if (symbol = this.getUIProperty("_symbol"))?
      text = switch isSelected
        when true
          if (symbolSpec = ButtonProxy.kSymbolSpecs[symbol])?
            symbolSpec.text
        when false
          ""
      this.setUIProperty("title", text)
    this 

# ==================================================================================================================
# Special properties:
#   _imageSelected: image to show when selected
#
class ImageViewProxy extends ViewProxy

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

    Ti.UI.createImageView(options)

# ==================================================================================================================
#
class WebViewProxy extends ViewProxy

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

    Ti.UI.createWebView(options)

# ==================================================================================================================
#
# Responds to:
# 
#   choiceOptions:
#       _buttons []
#            (passed on to Button)
#            _value
#            _text         
#            _fnCallback
#       _style
#       _appOption
#       _state: "none", "toggle"
#
class OptionsListBase extends ViewProxy

  kDefaultTextColor = Hy.UI.Colors.white
  kDefaultLabelHeight = 30

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@page, options, @labelOptions, @choiceOptions, @stackingOptions)->

    @currentButtonSpec = null # Points to current "buttonSpec", in @choiceOptions.buttons

    super options
   
    this.addChoices()

    @choices.conformToChildren()

    this.addLabel()

    if @choiceOptions._appOption?
      this.syncCurrentChoiceWithAppOption()

    this 

  # ----------------------------------------------------------------------------------------------------------------
  getPage: ()-> @page

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->

    options =
      zIndex: Hy.Pages.Page.kPageContainerZIndex + 1
#      borderColor: Hy.UI.Colors.white
#      borderWidth: 1

    options

  # ----------------------------------------------------------------------------------------------------------------
  addChoices: ()->

    options = 
      _tag: "Choices Container"

    this.checkButtonSpecs()

    @choices = new ViewProxy(Hy.UI.ViewProxy.mergeOptions(options, @stackingOptions))
    this.addChild(@choices, true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  checkButtonSpecs: ()->

    index = 0
    for buttonSpec in this.getButtonSpecs()
      buttonSpec._index = index++ # Optimize lookups
      if @choiceOptions._appOption? 
        if not @choiceOptions._appOption.isValidValue(buttonSpec._value)
          new Hy.Utils.ErrorMessage("fatal", "OptionsListBase", "ERROR Choice option #{buttonSpec._value} has no match") #will display popup dialog

    this

  # ----------------------------------------------------------------------------------------------------------------
  addLabel: ()->

    defaultOptions =
      zIndex: Hy.Pages.Page.kPageContainerZIndex + 1
      font: Hy.UI.Fonts.specTinyNormal
      textAlign: "center"
      text: "DEFAULT"
      color: kDefaultTextColor
      width: this.getUIProperty("width")
      height: kDefaultLabelHeight
      _padding: 0

    path = Hy.Customize.path(this.getPage(), [], "buttons")
    options = Hy.Customize.mapOptions(["font"], path, Hy.UI.ViewProxy.mergeOptions(defaultOptions, @labelOptions))

#    options = Hy.Customize.mapOptions(["font"], this.getPage().getPath(["buttons"]), Hy.UI.ViewProxy.mergeOptions(defaultOptions, @labelOptions))

    @label = new LabelProxy(options)

    this.addChild(@label, true, {_verticalLayout: "center"})

    for name, value of @label.getUIProperties()
      switch name
        when "_attach"
          @label.attachToView(@choices, {_attach: value, _padding: @label.getUIProperty("_padding")})

    this

  # ----------------------------------------------------------------------------------------------------------------
  syncCurrentChoiceWithAppOption: ()->
  
    if @choiceOptions._appOption?
      currentValue = @choiceOptions._appOption.getValue()

      currentButtonSpec = switch @choiceOptions._appOption.constructor.name
        when "ChoicesOption"
          this.findButtonSpecByValue(currentValue)

        when "ListOption" # Not implemented
          null
        when "ToggleOption" # Not implemented
          null
        else
          null

      if not currentButtonSpec?
        # We depend on a sanity check in console_app.coffee in case there's a problem here
        # But let's be extra careful
        currentButtonSpec = this.findButtonSpecByIndex(0)

      this.setCurrentButtonSpec(currentButtonSpec)            

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  optionClicked: (evt, view, buttonSpec)->

    buttonSpec?._fnCallback?(evt, view)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getCurrentButtonSpec: ()->

    @currentButtonSpec

  # ----------------------------------------------------------------------------------------------------------------
  getCurrentButtonSpecIndex: ()->
    this.findIndexOfButtonSpec(this.getCurrentButtonSpec())

  # ----------------------------------------------------------------------------------------------------------------
  setCurrentButtonSpec: (newButtonSpec)->

    @currentButtonSpec = newButtonSpec

    if @choiceOptions._appOption?
      switch @choiceOptions._appOption.constructor.name
        when "ChoicesOption"
          @choiceOptions._appOption.setValue(newButtonSpec._value)
        when "ListOption"
          null
        when "ToggleOption"
          null

    this

  # ----------------------------------------------------------------------------------------------------------------
  getButtonSpecs: ()->

    @choiceOptions._buttons

  # ----------------------------------------------------------------------------------------------------------------
  findButtonSpecByValue: (value)->

    _.find(this.getButtonSpecs(), (b)=>b._value is value)

  # ----------------------------------------------------------------------------------------------------------------
  findIndexOfButtonSpec: (buttonSpec)->

    return buttonSpec._index

    i = 0
    for b in this.getButtonSpecs()
      if b is buttonSpec
        return i
      i++

    -1 

  # ----------------------------------------------------------------------------------------------------------------
  findButtonSpecByIndex: (index)->

    return _.find(this.getButtonSpecs(), (bs)=>bs._index is index)
  
    if 0 <= index < this.getNumButtonSpecs()
      this.getButtonSpecs()[index]
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  getNumButtonSpecs: ()->
    this.getButtonSpecs().length
    
# ==================================================================================================================
#
# OptionsList: renders a series of buttons with specific values, such as "off" and "on", for "sound"
#
# Responds to:
# 
#   choiceOptions:
#       _buttons []
#            (passed on to Button)
#            _value
#            _text         
#            _fnCallback
#       _style
#       _appOption
#       _state: "none", "toggle"
#
class OptionsList extends OptionsListBase

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options, labelOptions, choiceOptions, stackingOptions)->

    super page, options, labelOptions, choiceOptions, stackingOptions
   
    this 

  # ----------------------------------------------------------------------------------------------------------------
  addChoices: ()->

    if not @choiceOptions._state?
      @choiceOptions._state = "none"

    super

    for buttonSpec in this.getButtonSpecs()
      this.addChoice(buttonSpec)

    this.setChoiceEventListener()

    this

  # ----------------------------------------------------------------------------------------------------------------
  addChoice: (buttonSpec)->

    options = 
      _style: @choiceOptions._style
      _size: @choiceOptions._size
      font: Hy.UI.Fonts.specSmallNormal
      color: Hy.UI.Colors.white
      _path: this.getPage().getPath()
      _tag: "Choice Button #{if buttonSpec._value? then buttonSpec._value else ""}"

    kind = switch @choiceOptions._state
      when "none"
        ButtonProxy
      when "toggle"
        ButtonProxyWithState
      else
        ButtonProxy

    choice = new kind(ViewProxy.mergeOptions(options, buttonSpec))

    @choices.addChild(choice, true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setCurrentButtonSpec: (newButtonSpec)->

    if (c = this.getCurrentButtonSpec())?
      if @choiceOptions._state is "toggle"
         if (v = this.findButtonViewByButtonSpec(c))?
           v.setSelected(false)

    super newButtonSpec

    if (v = this.findButtonViewByButtonSpec(newButtonSpec))?
       v.setSelected(true)
        
    this

  # ----------------------------------------------------------------------------------------------------------------
  findButtonViewByValue: (value)->

    buttonViews = @choices.findChildrenByUIProperty("_value", value)
    
    buttonView = if _.size(buttonViews) is 1
      _.first(buttonViews)
    else
      null

    buttonView

  # ----------------------------------------------------------------------------------------------------------------
  findButtonViewByButtonSpec: (buttonSpec)->

    this.findButtonViewByValue(buttonSpec._value)

  # ----------------------------------------------------------------------------------------------------------------
  findButtonSpecByButtonView: (buttonView)->

    this.findButtonSpecByValue(buttonView.getUIProperty("_value"))

  # ----------------------------------------------------------------------------------------------------------------
  setChoiceEventListener: ()->

    @choices.addEventListener("click", (evt, view = null)=>this.choiceClicked(evt, view))

    this

  # ----------------------------------------------------------------------------------------------------------------
  choiceClicked: (evt, view)->

    buttonView = if view? and (view isnt this) and (view isnt @choices)
      view
    else
      null

    if buttonView? and (buttonSpec = this.findButtonSpecByButtonView(buttonView))?

      if @choiceOptions._state is "toggle"
        this.setCurrentButtonSpec(buttonSpec)

      this.optionClicked(evt, view, buttonSpec)

    buttonView

# ==================================================================================================================
#
# OptionsSelector: user can tap "more" or "less" to browse through a list of options represented in _buttons. 
#                  Used for "Time Per Question", which offers to the user a choice of many values
#
# Responds to:
# 
#   choiceOptions:
#       _buttons []
#            (passed on to Button)
#            _value
#            _text         
#            _fnCallback
#       _style
#       _appOption
#
class OptionsSelector extends OptionsListBase

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (page, options, labelOptions, choiceOptions, stackingOptions)->

    @valueDisplay = null

    super page, options, labelOptions, choiceOptions, stackingOptions

    this 

  # ----------------------------------------------------------------------------------------------------------------
  addChoices: ()->

    super

    @downSelector = this.addSelectorControl("less")
    this.addValueDisplay()
    @upSelector = this.addSelectorControl("more")

    this

  # ----------------------------------------------------------------------------------------------------------------
#
# We use the passed-in choiceOptions to set the size of the + and - buttons
#
  addSelectorControl: (selectorText)->

    options = 
      _style: @choiceOptions._style
      _size: @choiceOptions._size
      font: Hy.UI.ButtonProxy.mergeDefaultFont({fontSize: 20}, @choiceOptions._size)
      _tag: "Selector Button #{selectorText}"
      _text: selectorText
      _path: this.getPage().getPath()

    Hy.Customize.mapOptions(["font"], options._path, options)

    selector = new ButtonProxy(options)

    selector.addEventListener("click", (evt, view = null)=>this.selectorClicked(evt, view, selectorText))

    @choices.addChild(selector, true)

    selector

  # ----------------------------------------------------------------------------------------------------------------
#
# We use the passed-in choiceOptions to set some of the options for this
#
  addValueDisplay: ()->

    options = 
      width: (@choiceOptions.width * 2) + ( if (padding = @stackingOptions._padding)? then padding else 0)
      height: @choiceOptions.height
      font: Hy.UI.Fonts.specTinyNormal
      color: @labelOptions.color
      _tag: "Value Display"
      text: ""
      textAlign: 'center'
#      borderColor: Hy.UI.Colors.black
#      borderWidth: 1

    path = Hy.Customize.path(this.getPage(), [], "buttons")
    Hy.Customize.mapOptions(["font"], path, options)

#    Hy.Customize.mapOptions(["font"], this.getPage().getPath(["buttons"]), options)

    @choices.addChild(@valueDisplay = new LabelProxy(options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  setValueDisplay: (buttonSpec)->

    @valueDisplay.setText(buttonSpec._text)

    this

  # ----------------------------------------------------------------------------------------------------------------
  selectorClicked: (evt, view, selectorText)->

    selectorView = if view? and (view isnt this) and (view isnt @choices)
      view
    else
      null

    if selectorView?
      index = if (b = this.getCurrentButtonSpec())?
        this.findIndexOfButtonSpec(b)
      else
        0 # just being extra careful

      switch selectorText
        when "less"
          index--
        when "more"
          index++

      if index < 0
        index = 0
      
      if index > (m = this.getNumButtonSpecs())
        index = m-1

      if (b = this.findButtonSpecByIndex(index))?
        this.setCurrentButtonSpec(b)
      
      this.optionClicked(evt, view, b)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setCurrentButtonSpec: (newButtonSpec)->

    super newButtonSpec
    this.setValueDisplay(newButtonSpec)
    this.checkSelectorLimits()

    this

  # ----------------------------------------------------------------------------------------------------------------
  checkSelectorLimits: ()->

    index = this.getCurrentButtonSpecIndex()
    @downSelector.setEnabled(index isnt 0)
    @upSelector.setEnabled(index isnt (this.getNumButtonSpecs()-1))

    this

# ==================================================================================================================
# Supports these special options
#
#             _orientation" "vertical" or "horizontal"
#             _padding
#             _rowHeight
#             _rowWidth
#             _divider (true or false)
#             _appOption (NOT IMPLEMENTED)
#             _numVisible (NOT IMPLEMENTED)
#
class ScrollView extends ViewProxy

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@page, options, @childViewOptions, fnClick = null, fnTouchAndHold = null, @fnScroll = null, @fnReInitViewsFired = null)->

    defaultOptions = 
      _tag: "ScrollView"

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this.addEventListener('scroll', (e, view)=>this.scrollHandler(e, view))

    # TODO: Move this into a separate function once it's settled down
    @eventInProgress = false
    @clickEventCoords = null
    @dragging = false

    fnDoClick = (e, view)=>
      if view? and _.detect(@viewSpecs, (v)=>v.view is view)
        fnClick?(e, view)
      null

    fnDoTouchAndHold = (e, view)=>
      if view? and _.detect(@viewSpecs, (v)=>v.view is view)
        fnTouchAndHold?(e, view)

    longDeferral = null
    mediumDeferral = null

    fnClearDeferral = (deferral)=>
      if deferral?
        deferral.clear()
      null

    fnSetHighlight = (view, flag)=>
#      view.setUIProperty("backgroundColor", if flag then Hy.UI.Colors.gray else null)
      null
    
    fnMedium = (e, view)=>
      mediumDeferral = fnClearDeferral(mediumDeferral)
      if @eventInProgress
        fnSetHighlight(view, true)
      null

    fnLong = (e, view)=> 
      longDeferral = fnClearDeferral(longDeferral)
      if @eventInProgress
        fnSetHighlight(view, false)
        fnDoTouchAndHold(e, view)
      @eventInProgress = false

    fnMisc = (e, view)=> 
      switch e.type

        # Sometimes we don't get coordinates for some touch events. With this handler, we try to fuse
        # 'click' event info to ensure we can send good coord info off to the touch-and-hold handler
        when "click"
          if e.x? and e.y?
            @clickEventCoords = {x: e.x, y: e.y}

        when "touchstart"
          if @eventInProgress
            null
          else
            @eventInProgress = true

            children = this.findChildrenByUIProperty("_index", e.source._index, true)

            longDeferral = fnClearDeferral(longDeferral)
            longDeferral = Hy.Utils.Deferral.create(Hy.Config.UI.kTouchAndHoldDuration, ()=>fnLong(e, view))

            mediumDeferral = fnClearDeferral(mediumDeferral)
            mediumDeferral = Hy.Utils.Deferral.create(Hy.Config.UI.kTouchAndHoldDurationStarting, ()=>fnMedium(e, view))

        when "touchend"
          if @eventInProgress
            @eventInProgress = false

            if @dragging
              null
            else
              fnSetHighlight(view, false)
              mediumDeferral = fnClearDeferral(mediumDeferral)
              longDeferral = fnClearDeferral(longDeferral)
 
              if @clickEventCoords? and (not e.x? or not e.y?)
                e.x = @clickEventCoords.x
                e.y = @clickEventCoords.y


              fnDoClick(e, view)
          @clickEventCoords = null
          @dragging = false
          null

        when "dragStart"
          @dragging = true

    if fnClick? or fnTouchAndHold?
      for kind in ["touchstart", "touchend", "click", "dragStart"]
        this.addEventListener(kind, fnMisc)

    switch this.getUIProperty("_orientation")
      when "horizontal"
       this.setUIProperty("_horizontalLayout", "left")
      when "vertical"
       this.setUIProperty("_verticalLayout", "top")

    @viewSpecs = []
    this.initViews()

    @numVisibleViews = this.computeNumVisibleViews()
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  isEventInProgress: ()-> @eventInProgress

  # ----------------------------------------------------------------------------------------------------------------
  getNumVisibleViews: ()-> @numVisibleViews

  # ----------------------------------------------------------------------------------------------------------------
  computeNumVisibleViews: ()->

    if this.getUIProperty("_orientation") is "vertical"
      propThickness = "height"
      viewPropThickness = "_rowHeight"
    else
      propThickness = "width"
      viewPropThickness = "_rowWidth"

    viewThickness = this.getUIProperty(viewPropThickness)

    if not (dividerThickness = this.getUIProperty("_dividerThickness"))?
      dividerThickness = 0

    f = (i)=>(i*viewThickness) + ((i-1)*dividerThickness)

    count = 1

    while f(count) < this.getUIProperty(propThickness)
      count++

    count-1

  # ----------------------------------------------------------------------------------------------------------------
  initViews: ()->

    @viewSpecs = []
    offset = 0

    if this.getUIProperty("_orientation") is "vertical"
      propThickness = "height"
      propBoundary1 = "top"
      propBoundary2 = "bottom"
    else
      propThickness = "width"
      propBoundary1 = "left"
      propBoundary2 = "right"

    addDivider = false

    width = this.getUIProperty("_rowWidth")
    height = this.getUIProperty("_rowHeight")

    for child in this.getUIProperty("_fnViews")()

      if addDivider
        this.addChild(this.createDivider(propThickness))

      child.setUIProperty("width", width)
      child.setUIProperty("height", height)

      this.addChild(child, true, @childViewOptions)  # set as top-level view so that our handler is supplied with this view
      viewSpec = {view:child}
      viewSpec[propBoundary1] = this.getChildrenExtent(propThickness) - child.getUIProperty(propThickness)
      viewSpec[propBoundary2] = this.getChildrenExtent(propThickness)

      @viewSpecs.push viewSpec

      addDivider = true

    this.computeChildSizes()

    this
  # ----------------------------------------------------------------------------------------------------------------
  createDivider: (propThickness)->

    divider = null

    if (hasDivider = this.getUIProperty("_divider"))? and hasDivider

      dividerOptions = {}

      thickness = 2
      path = @page.getPath()
      dividerOptions.backgroundColor = Hy.Customize.map("bordercolor", path, Hy.UI.Colors.MrF.Gray) # ignore transparency

#      dividerOptions.backgroundColor = Hy.Customize.map("bordercolor", [@page.getDisplayName()], Hy.UI.Colors.MrF.Gray) # ignore transparency
      dividerOptions.width = this.getUIProperty("width") # HACK

      dividerOptions[propThickness] = thickness
      this.setUIProperty("_dividerThickness", thickness)
    
      divider = new ImageViewProxy(dividerOptions)

    divider

  # ----------------------------------------------------------------------------------------------------------------
  getNumViews: ()-> _.size(@viewSpecs)

  # ----------------------------------------------------------------------------------------------------------------
  findViewByProperty: (name, value)->
    view = if (viewSpec = _.detect(@viewSpecs, (v)=>v.view[name] is value))?
      viewSpec.view
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  findViewsByUIProperty: (name, value)->
    views = for viewSpec in _.select(@viewSpecs, (v)=>v.view.getUIProperty(name) is value)
      viewSpec.view

  # ----------------------------------------------------------------------------------------------------------------
  applyToViews: (action)->
    _.select(@viewSpecs, (v)=>v.view[action]?())
    this

  # ----------------------------------------------------------------------------------------------------------------
  reInitViews: (autoScroll = true)->

    fn = (e)=>
      this.removeChildren()
      this.initViews()
      @fnReInitViewsFired?()
      this.animate({opacity:1.0, duration: 250})
      null
 
    this.animate({opacity:0, duration: 250}, fn)


    this

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->

    {}

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

    Ti.UI.createScrollView(options)

  # ----------------------------------------------------------------------------------------------------------------
  computeChildSizes: ()->

    if (_orientation = this.getUIProperty("_orientation"))? and (_orientation is "vertical")
      this.setUIProperty("contentWidth", @childViewOptions.width)
      this.setUIProperty("contentHeight", this.getChildrenExtent("height"))
    else
      this.setUIProperty("contentWidth", this.getChildrenExtent("width"))
      this.setUIProperty("contentHeight", @childViewOptions.height)

    this

  # ----------------------------------------------------------------------------------------------------------------
  scrollToViewIndex: (index)->

    if (index >= 0) and (index < _.size(@viewSpecs))

      viewSpec = @viewSpecs[index]

      if this.getUIProperty("_orientation") is "vertical"
        x = 0
        y = viewSpec.top
      else
        x = viewSpec.left
        y = 0

      this.getView().scrollTo(x, y)

    this  

  # ----------------------------------------------------------------------------------------------------------------
  makeViewVisible: (index)->

    if index < 0
      index = 0

    if index >= (totalNumViews = this.getNumViews())
      index = totalNumViews - 1

    targetIndex = Math.max(0, index + 1 - this.getNumVisibleViews())

    this.scrollToViewIndex(targetIndex)

    this    

  # ----------------------------------------------------------------------------------------------------------------
  getCurrentViewIndex: ()->

    if not (contentOffset = this.getView().contentOffset)?
      contentOffset = {x:0, y:0}

    if this.getUIProperty("_orientation") is "vertical"
      propBoundary1 = "top"
      propBoundary2 = "bottom"
      eventProp = "y"
    else
      propBoundary1 = "left"
      propBoundary2 = "right"
      eventProp = "x"

    i = 0
    lastViewSpec = null
    found = false

    for viewSpec in @viewSpecs
      # if in the separator between views, count it as a hit
      if contentOffset[eventProp] < viewSpec[propBoundary1]
        if lastViewSpec?
          if contentOffset[eventProp] > lastViewSpec[propBoundary2]
            found = true
      else
        if contentOffset[eventProp] <= viewSpec[propBoundary2]
          found = true

      if found
        return i

      lastViewSpec = viewSpec
      i++

    -1

  # ----------------------------------------------------------------------------------------------------------------
  scrollHandler: (e, view)->
    @fnScroll?(view)

# ==================================================================================================================
# Options this view responds to:
#
# options.
#      _backgroundImage
#      _backgroundImageHeight
#      _backgroundImageWidth
#
# scrollOptions -> passed on to ScrollView
# childViewOptions -> passed on to addChild
# labelOptions -> not implemented
# arrowsOptions: If not null:
#      _parent: view that should host scroll arrows.
#      top / left / bottom / right: controls placement of arrows
#
class ScrollOptions extends ViewProxy

  kArrowOffset = 5

  kArrowRemainderLabelOffset = 5

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@page, options = {}, @labelOptions = {}, @scrollOptions = {}, @childViewOptions = {}, arrowsOptions = null, @fnClicked, @fnTouchAndHold, @fnReInitViewsFired)->

    options.zIndex = Hy.Pages.Page.kPageContainerZIndex + 1
    super options

    this.addChild(this.createScrollView())

    this.addBackgroundImage()

    @arrows = []

    if arrowsOptions?
      this.addArrows(arrowsOptions)

    this.scrolled()

    this 

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->

    {}

  # ----------------------------------------------------------------------------------------------------------------
  getPage: ()-> @page
  # ----------------------------------------------------------------------------------------------------------------
  createScrollView: ()->

    scrollViewContainerOptions = 
      height: @scrollOptions.height
      width: if (w = @scrollOptions.width)? then w else this.getProperty("width")
      top: (this.getUIProperty("height") - @scrollOptions.height)/2
      left: (this.getUIProperty("width") - @scrollOptions.width)/2
      zIndex: this.getUIProperty("zIndex") + 10
#      borderColor: Hy.UI.Colors.blue
      borderWidth: 0

    scrollViewContainer = new ViewProxy(scrollViewContainerOptions)

    @scrollOptions.top = 0
    @scrollOptions.left = 0

    scrollViewContainer.addChild(@scrollView = new ScrollView(@page, @scrollOptions, @childViewOptions, @fnClicked, @fnTouchAndHold, ((view)=>this.scrolled()), @fnReInitViewsFired), true)

    scrollViewContainer    

  # ----------------------------------------------------------------------------------------------------------------
  getScrollView: ()-> @scrollView

  # ----------------------------------------------------------------------------------------------------------------
  scrollToViewIndex: (index)->

    @scrollView.scrollToViewIndex(index)

    this

  # ----------------------------------------------------------------------------------------------------------------
  makeViewVisible: (index)->

    @scrollView.makeViewVisible(index)

  # ----------------------------------------------------------------------------------------------------------------
  scrolled: ()->

    if _.size(@arrows) > 0
      currentViewIndex = Math.max(0, @scrollView.getCurrentViewIndex())

      numViews = @scrollView.getNumViews()

      remainders = []
      remainders.push (numViews - (currentViewIndex + @scrollView.numVisibleViews))
      remainders.push currentViewIndex

      for i in [0,1]
        remaining = remainders[i]
        label = @arrowRemainderLabels[i]
        arrow = @arrows[i]

#      Hy.Trace.debug "SCROLLING #{remaining}"

        label.setUIProperty("text", if remaining > 0 then (remainders[i] + " more") else "")
        arrow.setEnabled(remaining > 0)
      
    this

  # ----------------------------------------------------------------------------------------------------------------
  reInitViews: (autoScroll = true)->

    @scrollView.reInitViews(autoScroll)
    this.scrolled()

  # ----------------------------------------------------------------------------------------------------------------
  findViewByProperty: (name, value)->
    @scrollView?.findViewByProperty(name, value)

  # ----------------------------------------------------------------------------------------------------------------
  findViewsByUIProperty: (name, value)->

    @scrollView?.findViewsByUIProperty(name, value)

  # ----------------------------------------------------------------------------------------------------------------
  applyToViews: (action)->

    @scrollView?.applyToViews(action)

  # ----------------------------------------------------------------------------------------------------------------
  addBackgroundImage: ()->

    if (image = this.getUIProperty("_backgroundImage"))?

      options = 
        image: image
        width: this.getUIProperty("_backgroundImageWidth")
        height: this.getUIProperty("_backgroundImageHeight")
        top: (this.getUIProperty("height")-this.getUIProperty("_backgroundImageHeight"))/2
        left: (this.getUIProperty("width")-this.getUIProperty("_backgroundImageWidth"))/2
        zIndex: this.getUIProperty("zIndex")

      this.addChild(new ImageViewProxy(options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  backgroundOptions: ()->
    

  # ----------------------------------------------------------------------------------------------------------------
  setArrowsEnabled: (flag)->

    for arrow in @arrows
      arrow.setEnabled(flag)

    for label in @arrowRemainderLabels
      if flag
        label.show()
      else
        label.hide()

    if flag
      this.scrolled()

    this

  # ----------------------------------------------------------------------------------------------------------------
  addArrows: (arrowsOptions)->

    @arrows = []
    @arrowRemainderLabels = []

    arrowDimension = Hy.UI.ButtonProxy.getDimension("small")
    
    options = 
     _size: "tiny"
     _style: "round"
     _path: this.getPage().getPath(null, "buttons")
#     zIndex: this.getUIProperty("zIndex") + 10

    remainderLabelOptions =
      font: Hy.UI.Fonts.specTinyNormal
      color: Hy.Customize.map("font.color", this.getPage().getPath(), Hy.UI.Colors.white) # ignore transparency
#      borderColor: Hy.UI.Colors.red      
      height: arrowDimension
      width: 100

    if @scrollOptions._orientation is "vertical"
      propToMeasure = "width"
      propToAdjust = "left"
      coordToAdjust = "x"
      arrows = ["top", "bottom"]
    else
      prop = "height"
      propToAdjust = "top"
      arrows = ["left", "right"]

#    adjust = (this.getUIProperty(propToMeasure)-options[propToMeasure])/2
    adjust = (this.getUIProperty(propToMeasure)-arrowDimension)/2

    for a in arrows
      specificOptions = 
        _symbol: "#{a}Arrow"
        _id: a

      specificOptions[a] = arrowsOptions[a] + kArrowOffset
      specificOptions[propToAdjust] = arrowsOptions[propToAdjust] + adjust

      arrow = new ButtonProxy(ViewProxy.mergeOptions(specificOptions, options))
      arrowsOptions._parent.addChild(arrow, true) # mark this as a "top-level" view so that our handler below is supplied with this view

      @arrows.push arrow

      t = this
      arrow.addEventListener("click", (e, view)=>if view? and view.isEnabled() then this.arrowHandler(e, view))

      specificLabelOptions = {}
      specificLabelOptions[a] = specificOptions[a]
      specificLabelOptions[propToAdjust] = specificOptions[propToAdjust] + kArrowRemainderLabelOffset + arrowDimension

      arrowsOptions._parent.addChild (label = new LabelProxy(ViewProxy.mergeOptions(remainderLabelOptions, specificLabelOptions)))

      @arrowRemainderLabels.push label

    this

  # ----------------------------------------------------------------------------------------------------------------
  addArrows2: (arrowsOptions)->

    @arrows = []
    @arrowRemainderLabels = []
    
    options = 
     height: kArrowHeight
     width: kArrowWidth
#     zIndex: this.getUIProperty("zIndex") + 10

    if @scrollOptions._orientation is "vertical"
      propToMeasure = "width"
      propToAdjust = "left"
      coordToAdjust = "x"
      arrows = ["top", "bottom"]
    else
      prop = "height"
      propToAdjust = "top"
      arrows = ["left", "right"]

    adjust = (this.getUIProperty(propToMeasure)-options[propToMeasure])/2

    remainderLabelOptions =
      font: Hy.UI.Fonts.specTinyNormal
      color: Hy.UI.Colors.black
#      borderColor: Hy.UI.Colors.red      
      height: kArrowHeight
      width: 100

    for a in arrows
      specificOptions = {}
      specificOptions.backgroundImage = "assets/icons/arrow-#{a}.png"
      specificOptions.backgroundSelectedImage = "assets/icons/arrow-#{a}-selected.png"
      specificOptions._id = a

      specificOptions[a] = arrowsOptions[a] + kArrowOffset
      specificOptions[propToAdjust] = arrowsOptions[propToAdjust] + adjust

      arrow = new ButtonProxy(ViewProxy.mergeOptions(specificOptions, options))
      arrowsOptions._parent.addChild(arrow, true) # mark this as a "top-level" view so that our handler below is supplied with this view

      @arrows.push arrow

      t = this
      arrow.addEventListener("click", (e, view)=>if view? and view.isEnabled() then this.arrowHandler(e, view))

      specificLabelOptions = {}
      specificLabelOptions[a] = specificOptions[a]
      specificLabelOptions[propToAdjust] = specificOptions[propToAdjust] + kArrowRemainderLabelOffset + kArrowWidth

      arrowsOptions._parent.addChild (label = new LabelProxy(ViewProxy.mergeOptions(remainderLabelOptions, specificLabelOptions)))

      @arrowRemainderLabels.push label

    this

  # ----------------------------------------------------------------------------------------------------------------
  arrowHandler: (e, view)->

    if (currentViewIndex = @scrollView.getCurrentViewIndex()) isnt -1
      switch e.source._id
        when "top", "left"
          numViews = @scrollView.getNumViews()
          numVisibleViews = @scrollView.getNumVisibleViews()
          newViewIndex = Math.min(numViews, currentViewIndex+1, (numViews-numVisibleViews))

        when "right", "bottom"
          newViewIndex = Math.max(0, currentViewIndex-1)

        else
          newViewIndex = 0

      @scrollView.scrollToViewIndex(newViewIndex)

  this

# ==================================================================================================================
class NavGroupStack

  constructor: (@navGroup)->

    @navStack = []

    @busy = false

    @currentNavViewSpecIndex = 0 # 1-based index of current view, if any, on the stack

    this

  # ----------------------------------------------------------------------------------------------------------------
  error: (message)->
    new Hy.Utils.ErrorMessage("fatal", "NavGroupStack", message) #will display popup dialog

    this
  
  # ----------------------------------------------------------------------------------------------------------------
  numElements: (kind = null)->

    _.size(if kind? then _.select(@navStack, (e)=>e.kind is kind) else @navStack)

  # ----------------------------------------------------------------------------------------------------------------
  findNavViewSpec: (target)->

    _.detect(@navStack, (e)=>e.kind is "view" and e.navViewSpec.navSpec._id is target)
      
  # ----------------------------------------------------------------------------------------------------------------
  pushNavViewSpec: (navViewSpec)->

    # Sanity Check
    if navViewSpec.navSpec._id? and this.findNavViewSpec(navViewSpec.navSpec._id)?
      this.error("Pushing a navSpec that\'s already on the stack: #{navViewSpec.navSpec._id}")

    navViewSpec.index = this.numElements("view") + 1

    @navStack.push {kind: "view", navViewSpec: navViewSpec}

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Two kinds of guard specs:
  #   "viewDismiss"
  #   "navGroupDismissCheck"

  pushFnGuardSpec: (fnGuardSpec)->

    @navStack.push {kind: "fnGuard", fnGuardSpec: fnGuardSpec}

    this

  # ----------------------------------------------------------------------------------------------------------------
  removeFnGuard: (owner, kind)->

    @navStack = _.reject(@navStack, (e)=>e.kind is "fnGuard" and e.fnGuardSpec.kind is kind and e.fnGuardSpec.owner is owner)

  # ----------------------------------------------------------------------------------------------------------------
  getFnGuardSpecs: (kind)->

    _.select(@navStack, (e)=>e.kind is "fnGuard" and e.fnGuardSpec.kind is kind)

  # ----------------------------------------------------------------------------------------------------------------
  getCurrentNavViewSpec: ()->

    navViewSpec = if @currentNavViewSpecIndex is 0 # 1-based view index
      null
    else
      if (element = _.detect(@navStack, (e)=>e.kind is "view" and e.navViewSpec.index is @currentNavViewSpecIndex))?
        element.navViewSpec
      else
        this.error("Expected navViewSpec at current viewIndex, but found: #{if element? then element.kind else "<null>"}")
        null

    navViewSpec      

  # ----------------------------------------------------------------------------------------------------------------
  canAdvanceToNextViewSpec: ()->

    @currentNavViewSpecIndex + 1 <= this.numElements("view")

  # ----------------------------------------------------------------------------------------------------------------
  advanceToNextViewSpec: ()->

    if (@currentNavViewSpecIndex + 1 > this.numElements("view"))
      this.error("Attempting to advanceToNextViewSpec, but no view there #{@currentNavViewSpecIndex}")
    else
      @currentNavViewSpecIndex++

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Pop off as many navViews as necessary to find the one with "_id" === target.
  # If not found, pops 'em all off.
  # We leave the current index pointing at the navView we want to be displayed.
  # We invoke any guard functions along the way
  #
  # Possible values for "target":
  #  _previous: goes back one view
  #  _root:     goes back to a view with "_root: true"
  #  name:      goes back to view with _id === name. If none found, pops everything
  #
  pop: (target = "_previous")->

    fnClose = (navViewSpec, animated)=>
      @navGroup.closeNavView(navViewSpec.navView, {animated: animated})
      null

    fnDoFnGuard = (fnGuardSpec)=>
      fnGuardSpec.fn?()
      null

    # We have to worry a bit that functions called within this loop might
    # change the stack while we're in the loop

    if @busy
      this.error("Trying to pop while already popping (target=#{target})")
    else
      @busy = true

      viewsToBeClosed = []
      newStack = []

      # Walk the stack, from top to bottom, looking for our target
      last = true
      found = false
      element = null

      while _.size(@navStack) > 0 and not found
        switch (element = @navStack.pop()).kind
          when "fnGuard"
            if element.fnGuardSpec.kind is "viewDismiss"
              fnDoFnGuard(element.fnGuardSpec) # Execute guard function as we blow through the stack
          when "view"
            found = switch target
              when "_previous"
                not last
              when "_root"
                element.navViewSpec.navSpec._root?
              else
                element.navViewSpec.navSpec._id is target

            last = false

            if found
              # Whoops. Put it back on. Elegant, eh?
              @navStack.push element
            else
              viewsToBeClosed.push element.navViewSpec

      @currentNavViewSpecIndex = if found then element.navViewSpec.index else 0

      # Close intermediate ones w/o animation
      for nvs in _.rest(viewsToBeClosed)
        fnClose(nvs, false)

      if (first = _.first(viewsToBeClosed))?
        fnClose(first, true)

      @busy = false

    this
       

# ==================================================================================================================
#
# An iPad NavGroup
#
# https://developer.apple.com/library/IOs/#documentation/UserExperience/Conceptual/MobileHIG/UIElementGuidelines/UIElementGuidelines.html#//apple_ref/doc/uid/TP40006556-CH13-SW36
#
#
#   navSpec looks like:
#
#    _id:                       (required) text: internal label for the spec
#    _fnVisible = (navSpec):    (optional) function is called when navSpec becomes visible. navSpec is passed in.
#    _title:                    (optional) text: applied to the title bar of the menu window
#    _backButtonLabel:          (optional) text: if provided, a backbutton with this label is added to the title bar
#    _backButton:               (optional) text: one of:
#
#        "_previous"             Returns to the previous window
#        "id"                    Returns to the NavGroup with _id === "id"
#
#    _explain:                  (optional) text: rendered in a multiline text view
#    _view:                     (optional) view: rendered in the NavGroup
#    _buttonSpecs:              (optional) array: of buttonSpec:
#
#       _value:                 text for the button
#
#         and one of:
#
#       _fnCallback:            callback function, passed the usual (event, view). 
#                               Can also be used in combination with _dismiss.
#
#         or
#       _navViewSpecFnCallback: callback function, passed (event, view, actionsheetMenuView). If the function returns true, the
#                               navGroup is kept open. The function can then send updates to the navGroup
#         or
#
#       _navGroupSpec:             A nested version of navSpec
#                     
#        or
#
#       _dismiss:                Similar to _backButton: names a target view to pop back to.
#
class NavGroup extends WindowProxy # ViewProxy # 2.5.0

  # Apple iOS Guidelines: at least 320 characters wide
  # http://developer.apple.com/library/ios/#DOCUMENTATION/UserExperience/Conceptual/MobileHIG/UIElementGuidelines/UIElementGuidelines.html#//apple_ref/doc/uid/TP40006556-CH13-SW40
  #
  kTitleHeight = 50 # A Guess
  kPanelCoreWidth = 360 # Doesn't include tip arrow thingie
  kPanelCoreHeight = 300 # Doesn't include window title bar
  kHorizontalBorderPadding = 5
  kVerticalBorderPadding = 5  

  kButtonHeight =  53
  kButtonPadding = 2
  kButtonFont = {fontSize: 16, fontWeight: 'bold', fontFamily: "Trebuchet MS"}

  kExplainFont = {fontSize: 14, fontWeight: 'bold', fontFamily: "Trebuchet MS"}
  kExplainPerLineHeight = kExplainFont.fontSize + 5
  kExplainMaxCharsPerLine = 40
  kExplainHeightFudge = 10

  kMinNavViewTransitionTime = 1000

  # ----------------------------------------------------------------------------------------------------------------
  @getExplainMaxCharsPerLine: ()-> kExplainMaxCharsPerLine

  # ----------------------------------------------------------------------------------------------------------------
  @getHorizontalBorderPadding: ()-> kHorizontalBorderPadding

  # ----------------------------------------------------------------------------------------------------------------
  @getVerticalBorderPadding: ()-> kVerticalBorderPadding

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {}, @navSpec = {})->

    @initialNavView = null

    @navGroupStack = new NavGroupStack(this)

    @dismissInProgress = false

    o = Hy.UI.ViewProxy.mergeOptions(this.navGroupOptions(), options)
    super o
  
    this

  # ----------------------------------------------------------------------------------------------------------------
  error: (message)->
    new Hy.Utils.ErrorMessage("fatal", "NavGroup", message) #will display popup dialog

    this

  # ----------------------------------------------------------------------------------------------------------------
  isPopover: ()-> false

  # ----------------------------------------------------------------------------------------------------------------
  # Called by app after instantiation to get things rolling

  start: ()->

    # Is this the right order? 2.5.0
    this.open() # 2.5.0 
    this.pushNavViewSpec(@navSpec, @initialNavView)

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Push a navView onto the stack and queue it up for viewing.
  #
  pushNavSpec: (navSpec)->

    this.pushNavViewSpec(navSpec, this.createNavView(navSpec))

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Replaces the view/navSpec associated with a navView that's already on the stack, based on _id.
  # If target view isn't found, ignore
  #
  replaceNavView: (navSpec)->

    if not navSpec._id?
      this.error("Replacing a navView, but new navSpec has no _id")
    else 
      if (e =  this.getNavGroupStack().findNavViewSpec(navSpec._id))?
        this.updateNavViewContent(e.navViewSpec.navView, navSpec)
        e.navViewSpec.navSpec = navSpec

        if e.navViewSpec.status is "open"
          e.navViewSpec.navSpec._fnVisible?(e.navViewSpec.navSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  pop: (target)->

    this.getNavGroupStack().pop(target)

  # ----------------------------------------------------------------------------------------------------------------
  pushFnGuard: (owner, kind, fn)-> 

    this.getNavGroupStack().pushFnGuardSpec({owner: owner, kind: kind, fn: fn})

  # ----------------------------------------------------------------------------------------------------------------
  removeFnGuard: (owner, kind)->

    this.getNavGroupStack().removeFnGuard(owner, kind)

  # ----------------------------------------------------------------------------------------------------------------
  # ----------------------------------------------------------------------------------------------------------------
  # Less public functions
  #

  # ----------------------------------------------------------------------------------------------------------------
  getNavGroupStack: ()-> @navGroupStack

  # ----------------------------------------------------------------------------------------------------------------
  pushNavViewSpec: (navSpec, navView)=>

    this.getNavGroupStack().pushNavViewSpec({navSpec: navSpec, navView: navView, status: "waiting"})

    this.startNavViewTransition()

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  navGroupOptions: ()->

    defaultNavigationGroupOptions = 
      top: 0
      height: kPanelCoreHeight  + (if this.hasTitleBar() then kTitleHeight else 0)
      width: kPanelCoreWidth
      _tag: "NavGroup Navigation Group"
      borderRadius: 15
#      backgroundColor: Hy.UI.Colors.MrF.Gray
      backgroundColor: Hy.UI.Colors.MrF.black
#      borderColor: Hy.UI.Colors.red
      borderWidth: 1

  # ----------------------------------------------------------------------------------------------------------------
  getBodyHeight: (navSpec = @navSpec)->

    this.getUIProperty("height") - (if this.hasTitleBar(navSpec) then kTitleHeight else 0)

  # ----------------------------------------------------------------------------------------------------------------
  getBodyWidth: (navSpec = @navSpec)->

    this.getUIProperty("width")

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

    # We make this assignment here since the NavView sizing code interrogates this object's UI properties, which aren't
    # set until just before 'createView' is called
    #
    @initialNavView = this.createNavView(@navSpec)

    this.setUIProperty("window", (options.window = @initialNavView.getView()))

#    Ti.UI.iPhone.createNavigationGroup(options)
    Ti.UI.iOS.createNavigationWindow(options) # 2.5.0: Titanium 3.1.3 deprecates iPhone.NavigationGroup... 


  # ----------------------------------------------------------------------------------------------------------------
  showCurrentNavView: ()->

    if (currentViewSpec = this.getNavGroupStack().getCurrentNavViewSpec())?
      if currentViewSpec.index is 1 # 1-based index
        # First view is special... it's assigned when the navGroup is created, so nothing to do here
        null
      else
        if currentViewSpec.status is "waiting"
#          this.getView().open(currentViewSpec.navView.getView(), {animated:true})
          this.getView().openWindow(currentViewSpec.navView.getView(), {animated:true}) # 2.5.0

      currentViewSpec.status = "open-and-waiting"

      currentViewSpec.navSpec._fnVisible?(currentViewSpec.navSpec)

      # Schedule check of stack after min transition time, to update "status" and see if there are any pending views waiting
      Hy.Utils.PersistentDeferral.create(kMinNavViewTransitionTime, ()=>this.endNavViewTransition())

    this

  # ----------------------------------------------------------------------------------------------------------------
  closeNavView: (navView, options = {})->

    # If trying to close the root view, need to close NavView windows instead. 2.5.0
    if this.getNavGroupStack().numElements("view") > 0
      this.getView().closeWindow(navView.getView(), options) # 2.5.0
    else
      this.close(options) # 2.5.0

    this

  # ----------------------------------------------------------------------------------------------------------------
  # We're here because a new View has been pushed onto the stack for display. 
  # We may or may not be currently showing a view. We may currently be transitioning to other views, so this one may
  # have to wait its turn.
  #
  startNavViewTransition: ()->

    if (currentViewSpec = this.getNavGroupStack().getCurrentNavViewSpec())?
      switch currentViewSpec.status
        when "open", "closed"
          # Current view is open and just sitting there. Move things alog.
          this.doNavViewTransition()
        when "open-and-waiting"
          # Timer will trigger soon and move things along, so nothing to do here
          null
    else
      # Initial state - transition immediately
      this.doNavViewTransition()

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  doNavViewTransition: ()->

    # If there is a current view, mark it as closed
    if (currentViewSpec = this.getNavGroupStack().getCurrentNavViewSpec())?
      currentViewSpec.status = "closed"

    this.getNavGroupStack().advanceToNextViewSpec()

    # Show new view
    this.showCurrentNavView()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # We've waited the min time for a view to be on display. Is there another view waiting for it's chance?
  #
  endNavViewTransition: ()->

    # Mark the current view as open
    if (currentViewSpec = this.getNavGroupStack().getCurrentNavViewSpec())?
      currentViewSpec.status = "open"

    # Any views waiting?
    if this.getNavGroupStack().canAdvanceToNextViewSpec()
      this.doNavViewTransition()

    this

  # ----------------------------------------------------------------------------------------------------------------
  hasTitleBar: (navSpec = @navSpec)->

    navSpec._title? or navSpec._backButtonLabel?

  # ----------------------------------------------------------------------------------------------------------------
  hasBackButton: (navSpec = @navSpec)->

    navSpec._backButton? 

  # ----------------------------------------------------------------------------------------------------------------
  # Can't have a back button if there's no back to go to
  #
  canHaveBackButton: (navSpec)->

    this.hasBackButton(navSpec) and this.getNavGroupStack().numElements("view") > 0

  # ----------------------------------------------------------------------------------------------------------------
  computeBackButtonRequirements: (navSpec)->

    # 2.5.0: it seems that we get a back button image no matter what, as
    # "leftNavButton" being set to null is being ignored, and the system-default image used instead,
    # which looks different than our image.
    # So let's make sure that our image is used, but add a handler only if we really want it
    #
    hack = true
    v = null

    if hack # 2.5.0
      f = this.canHaveBackButton(navSpec) 

      button = this.createBackButton(navSpec, f)

      if f
        this.addBackButtonHandler(button, navSpec)

      v = button.getView() # Returns a Ti view
    else # Pre-2.5.0
      if this.canHaveBackButton(navSpec)
        button = this.createBackButton(navSpec)
        this.addBackButtonHandler(button, navSpec)
        v = button.getView() # Returns a Ti view

    v

  # ----------------------------------------------------------------------------------------------------------------
  backButtonClicked: (navSpec)->

    switch target = navSpec._backButton
      when "_previous"
        this.dismiss(false, "_previous")
      else
        this.dismiss(false, target)

    null

  # ----------------------------------------------------------------------------------------------------------------
  createBackButton: (navSpec, isActive = true)-> # v2.5.0 - added isActive

    backButtonOptions = 
      height: if isActive then 30 else 1
      width: if isActive then 24 else 1
#      image: if isActive then "assets/icons/arrow-left-small.png" else "assets/bkgnds/pixel-overlap.png"
      image: if isActive then "assets/icons/arrow-left-small-white.png" else "assets/bkgnds/pixel-overlap.png" # v1.0.7

  
    new ImageViewProxy(backButtonOptions)

  # ----------------------------------------------------------------------------------------------------------------
  addBackButtonHandler: (button, navSpec)->
    button.addEventListener("click", (evt, view)=>this.backButtonClicked(navSpec))
    button

  # ----------------------------------------------------------------------------------------------------------------
  updateNavViewContent: (navView, navSpec)->

    navView.removeChildren()
    navView.addChild(this.addNavViewContent(navSpec))

    navView

  # ----------------------------------------------------------------------------------------------------------------
  addNavViewContent: (navSpec)->

    # Holds child views, such as the "explain" and buttons views
    navViewContentContainerOptions = 
      width: this.getBodyWidth(navSpec)
      top: 0
      left: 0
      height: this.getBodyHeight(navSpec)
#      borderColor: Hy.UI.Colors.yellow
      borderWidth: 0
      _horizontalLayout: "center"

    buttonOptions = {}

    # If layout is "manual", place buttons at the bottom
    if navSpec._verticalLayout? and navSpec._verticalLayout is "manual"
      buttonOptions.bottom = NavGroup.getVerticalBorderPadding()
    else
      navViewContentContainerOptions._verticalLayout = "distribute"

    navViewContentContainer = new Hy.UI.ViewProxy(navViewContentContainerOptions)

    # Now figure out which child views to create and add, based on what we find in the navSpec
    if (explain = navSpec._explain)?
      explainView = this.createExplain({}, explain)

    if (buttonSpecs = navSpec._buttonSpecs)? and buttonSpecs.length > 0
      buttonView = this.createButtons(buttonOptions, buttonSpecs)

    # Start with supplied view (if any)...
    navViewContentContainer.addChildren([navSpec._view, explainView, buttonView])

    navViewContentContainer

  # ----------------------------------------------------------------------------------------------------------------
  createNavView: (navSpec)->

    color = switch this.getUIProperty("_colorScheme")
      when "black"
        Hy.UI.Colors.black
      else
        Hy.UI.Colors.MrF.Gray

    # top-level nav view window, with title bar and everything
    navViewOptions = 
      backgroundColor: color
      barColor:  color
      width: this.getBodyWidth(navSpec)
      top: 0
      left: 0
      height: this.getBodyHeight(navSpec)  + 15 # HACK 2.5.0 This is border radius of NavGroup. Should this be applied only on PopOvers?
      navBarHidden: if this.hasTitleBar(navSpec) then false else true
      _tag: "NavGroup Nav View Window #{if navSpec._title? then navSpec._title else "?"}"
#      backButtonTitle: if navSpec._backButtonLabel? then navSpec._backButtonLabel else ""
      backButtonTitle: ""
      leftNavButton: this.computeBackButtonRequirements(navSpec)
      rightNavButton: null
      title: if navSpec._title? then navSpec._title else ""
#      borderColor: Hy.UI.Colors.MrF.Orange
      borderWidth: 0
      # Need the following in order to get white text on back background.
      statusBarStyle: Titanium.UI.iPhone.StatusBar.OPAQUE_BLACK # 2.5.0
      translucent: false  # 2.5.0

    navView = new Hy.UI.WindowProxy(navViewOptions)

    navView.addChild(this.addNavViewContent(navSpec))

    navView

  # ----------------------------------------------------------------------------------------------------------------
  getButtonWidth: ()->
    this.getUIProperty("width") - (2 * kHorizontalBorderPadding)

  # ----------------------------------------------------------------------------------------------------------------
  createButtons: (options, buttonSpecs)->

    defaultButtonOptions = 
      width: this.getButtonWidth()
      height: kButtonHeight
      font: kButtonFont
      borderRadius: 15
      color: Hy.UI.Colors.black
      borderColor: Hy.UI.Colors.black
      selectedColor: Hy.UI.Colors.black
#      style: Titanium.UI.iPhone.SystemButton.CANCEL

    height = 0
    buttonViews = []

    # Display a red button at the top of the action sheet, because the closer to the top of the 
    # action sheet a button is, the more eye-catching it is. 
    # https://developer.apple.com/library/IOs/#documentation/UserExperience/Conceptual/MobileHIG/UIElementGuidelines/UIElementGuidelines.html#//apple_ref/doc/uid/TP40006556-CH13-SW36

    if buttonSpecs?
      for buttonSpec in buttonSpecs
        title = buttonSpec._value

        backgroundColor = Hy.UI.Colors.white
        color = Hy.UI.Colors.black

        if buttonSpec._cancel?
          # backgroundColor = Hy.UI.Colors.MrF.GrayLight
          color = Hy.UI.Colors.MrF.Gray

        # On both devices, use the red button color if you need to provide a button that 
        # performs a potentially destructive action. 
        # https://developer.apple.com/library/IOs/#documentation/UserExperience/Conceptual/MobileHIG/UIElementGuidelines/UIElementGuidelines.html#//apple_ref/doc/uid/TP40006556-CH13-SW36

        if buttonSpec._destructive?
          backgroundColor = "#ECD4D4"
          color = Hy.UI.Colors.MrF.Red

        buttonOptions = 
          title: title
          color: color
          backgroundColor: backgroundColor
          top: height
          _tag: "NavGroup Button: #{buttonSpec._value}"
#          style: Titanium.UI.iPhone.SystemButtonStyle.PLAIN

        buttonOptions = Hy.UI.ViewProxy.mergeOptions(defaultButtonOptions, buttonSpec, buttonOptions)
        height += buttonOptions.height + kButtonPadding

        if this.shouldAddButtonListenerDelay(buttonOptions) # 2.5.0
          null # buttonOptions._delayListenerEvent = true # 2.5.0

        buttonViews.push buttonView = new Hy.UI.SystemButtonProxy(buttonOptions)

        # If no action specified, mark it as unenabled
        isEnabled = buttonSpec._navSpec? or buttonSpec._navSpecFnCallback? or buttonSpec._fnCallback? or buttonSpec._dismiss?
        buttonView.setEnabled(isEnabled)

        buttonView.addEventListener("click", (e, view)=>this.doButtonCallback(e, view))
   
      height -= kButtonPadding

    buttonContainerViewOptions = 
      height: height
#      left: kHorizontalBorderPadding
#      right: kHorizontalBorderPadding
      width: this.getBodyWidth()
      _tag: "NavGroup Button parent view"
#      borderColor: Hy.UI.Colors.red
      borderWidth: 0

    buttonsView = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(buttonContainerViewOptions, options))

    for buttonView in buttonViews
      buttonsView.addChild(buttonView, true)

    buttonsView

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Returns true if we should slightly delay responses to button events, due to apparent but
  # in Titanium 3.1.3
  # 2.5.0
  # NOT ACTUALLY USED

  shouldAddButtonListenerDelay: (options)->
    options._navSpecFnCallback? or options._navSpec?

  # ----------------------------------------------------------------------------------------------------------------
  createExplain: (options, explain = "")->

#    explain = "12345678901234567890123456789012345678901234567890\n123456"

    fnTrim = (s)=>
      return s
      Hy.Utils.String.trimWithElipsis(s, NavGroup.getExplainMaxCharsPerLine())

    numLines = 1

    t = if (splits = explain.split("\n")) isnt 0
      t = ""
      for sub in splits
        if numLines > 1
          t += "\n"
        t += fnTrim(sub)
        numLines++
      t
    else
      explain

    # An extra check to try to ensure that the field is large enough to display all of the message
    if (n = Math.ceil(explain.length / NavGroup.getExplainMaxCharsPerLine())) > numLines
      numLines = n

    switch this.getUIProperty("_colorScheme")
      when "black"
        backgroundColor = Hy.UI.Colors.black
        textColor = Hy.UI.Colors.white
      else
        backgroundColor = Hy.UI.Colors.MrF.Gray
        textColor = Hy.UI.Colors.white

    textAreaOptions = 
      height: (numLines * kExplainPerLineHeight) + kExplainHeightFudge
      width: this.getUIProperty("width") - (2 * NavGroup.getHorizontalBorderPadding())
      value: t
      font: kExplainFont
      textAlign: "center"
      backgroundColor: backgroundColor
      color: textColor
      enabled: false
      editable: false
      touchEnabled: false
#      borderColor: Hy.UI.Colors.green
      borderWidth: 0
      _tag: "Explain"
 
    new Hy.UI.TextAreaProxy(Hy.UI.ViewProxy.mergeOptions(textAreaOptions, options))

  # ----------------------------------------------------------------------------------------------------------------
  # We want to be able to dismiss the nav group if the user picks something on it
  #
  doButtonCallback: (event, view)->

    fnCallback = view.getUIProperty("_fnCallback")   
    navSpecFnCallback = view.getUIProperty("_navSpecFnCallback")
    navSpec = view.getUIProperty("_navSpec")

    dismissTarget = view.getUIProperty("_dismiss")

    if fnCallback?
      if dismissTarget?
        this.dismiss(true, dismissTarget)
      fnCallback(event, view)
    else if navSpecFnCallback? 
      navSpecFnCallback(event, view, this)
    else if navSpec?
      this.pushNavSpec(navSpec)
    else if dismissTarget?
      this.dismiss(false, dismissTarget)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # This is here in support of the popover version of NavGroup
  # We ask the app code to tell us if it's OK to dismiss or not; if OK,
  # we do the equivalent of {_dismiss: _root}
  #
  dismissRequested: (target = "_root")->

    # Find and run all NavGroup dismiss functions. They must all say "ok"
    ok = true
    for fnDismissCheck in this.getNavGroupStack().getFnGuardSpecs("navGroupDismissCheck")
      if (f = fnDismissCheck.fnGuardSpec.fn)?
        if not f()
          ok = false

    if ok
      this.dismiss(false, target) # animate out
    
    this
  
  # ----------------------------------------------------------------------------------------------------------------
  # Dismiss current view, or maybe the entire nav group. If not "immediate", do it with style. 
  #
  dismiss: (immediate = true, target = "_root")=>

    if not @dismssInProgress
      @dismissInProgress = true
      this.pop(target)

      this.doDismiss(immediate, target, this.getNavGroupStack().numElements("view") is 0)

      this.showCurrentNavView()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Dismiss w/prejudice (i.e., don't ask the app if it's OK)
  #
  doDismiss: (immediate, target, dismissedEntirely)->
    
    this.dismissEnd(dismissedEntirely)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # "dismissedEntirely" is set to true if we dismissed all views
  #
  dismissEnd: (dismissedEntirely)->

    @dismissInProgress = false

    this


# ==================================================================================================================
# In support of NavGroupPopover: we need to hook the dismiss-related functions, to be able to animate/clean-up appropriately
#
class NavGroupExtensionForNavGroupPopover extends NavGroup

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@navGroupPopover, options = {}, navSpec = {})->

    super options, navSpec

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Dismiss w/prejudice (i.e., don't ask the app if it's OK)
  #
  doDismiss: (immediate, target, dismissedEntirely)->
    
    if dismissedEntirely 
      @navGroupPopover.animateOut(immediate, (evt)=>this.dismissEnd(dismissedEntirely))

    this

  # ----------------------------------------------------------------------------------------------------------------
  dismissEnd: (dismissedEntirely)->

    super

    if dismissedEntirely
      @navGroupPopover.dismissedEntirely()

    this

# ==================================================================================================================
#
# An iPad NavGroup in a Popover.
#
# In app code using this class, we may find ourselves treating instances of this class as subclasses of NavGroup, but
# they actually aren't.
#
#
# Options:
#
#   See doc for NavGroup for "navSpec"
#
#   _hasTip:      true or false
#   _pointsAt:    A Point that this NavGroup should point at. If not supplied, or {0,0}, placed in the middle
#                 of the screen w/o a tip
#   _tipLocation: One of "right", "left", "top", "bottom". Not implemented - defaults to "right" for now
#
#
#

class NavGroupPopover

  kTipWidth = 39
  kTipHeight = 50
  kTipOffset = 5

  kOverlayZIndex = 10000

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@options = {}, navSpec = null)->

    @window = Hy.UI.Application.get().getPage().getWindow()

    @hidden = false

    @doTip = @options._hasTip? # Might be overridden later
  
    # This transparent window covers the entire screen. It's job is to detect when the user touches outside the nav group
    this.createOverlayView()
        .addOverlayView()
        .addOverlayViewHandlers()

    # Create the NavGroup
    this.createNavGroup(navSpec)
    height = this.getNavGroup().getUIProperty("height")
    width = this.getNavGroup().getUIProperty("width")

    # Now create the outermost container for the nav group and tip
    this.createNavGroupContainer(height, width)

#    this.getNavGroupContainer().addChildren([this.getNavGroup(), this.createTip(height, width)]) # 2.5.0
    this.getNavGroupContainer().addChildren([this.createTip(height, width)]) # 2.5.0

    # And align the NavGroup with the Container, since, as of 2.5.0, 
    # the former is not a child of the latter
    for dimension in ["top", "bottom", "left", "right"]
      this.getNavGroup().setUIProperty(dimension, this.getNavGroupContainer().getUIProperty(dimension))

    this.getOverlayView().addChild(this.getNavGroupContainer())

    this.getNavGroup().start()

    this

  # ----------------------------------------------------------------------------------------------------------------
  isPopover: ()-> true

  # ----------------------------------------------------------------------------------------------------------------
  pushNavSpec: (navSpec)->

    this.getNavGroup().pushNavSpec(navSpec)  

    this

  # ----------------------------------------------------------------------------------------------------------------
  pushFnGuard: (owner, kind, fn)-> 

    this.getNavGroup().pushFnGuard(owner, kind, fn)

    this

  # ----------------------------------------------------------------------------------------------------------------
  removeFnGuard: (owner, kind)->

    this.getNavGroup().removeFnGuard(owner, kind)

  # ----------------------------------------------------------------------------------------------------------------
  pop: (target)->

    this.getNavGroup().pop(target)

    this

  # ----------------------------------------------------------------------------------------------------------------
  replaceNavView: (navSpec)->

    this.getNavGroup().replaceNavView(navSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Dismiss current view, or maybe the entire nav group. If not "immediate", do it with style. 
  #
  dismiss: (immediate = true, target = "_root")=>

   this.getNavGroup().dismiss(immediate, target)

   this

  # ----------------------------------------------------------------------------------------------------------------
  # ----------------------------------------------------------------------------------------------------------------
  # ----------------------------------------------------------------------------------------------------------------
  # ----------------------------------------------------------------------------------------------------------------
  createNavGroup: (navSpec)->

    defaultNavGroupOptions = {}

    @navGroup = new NavGroupExtensionForNavGroupPopover(this, defaultNavGroupOptions, navSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getNavGroup: ()-> @navGroup

  # ----------------------------------------------------------------------------------------------------------------
  getOverlayView: ()-> @overlayView

  # ----------------------------------------------------------------------------------------------------------------
  createOverlayView:()->

    options = 
      left: 0
      right: 0
      top: 0
      bottom: 0
      _tag: "NavGroup Overlay"
      zIndex: kOverlayZIndex

    @overlayView = new Hy.UI.ViewProxy(options)

    underlayOptions = 
      left: 0
      right: 0
      top: 0
      bottom: 0
      _tag: "NavGroup Underlay"
      zIndex: kOverlayZIndex - 1
#      backgroundColor: Hy.UI.Colors.black
      backgroundImage: Hy.UI.Backgrounds.pixelOverlay

    @overlayView.addChild(@underlayView = new Hy.UI.ViewProxy(underlayOptions))

#    @underlayView.setUIProperty("zIndex", underlayOptions.zIndex)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addOverlayViewHandlers: ()->

    fnHandler = (e, view)=>
      this.overlayTouched()
      null

    @underlayView.addEventListener("click", fnHandler)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addOverlayView: ()->

    if @overlayView?
      @underlayView.setUIProperty("opacity", 0)
      @window.addChild(@overlayView)
      @underlayView.animate({opacity: 0.5, duration: 250})

    this

  # ----------------------------------------------------------------------------------------------------------------
  removeOverlayView: ()->

    if @overlayView?
      @underlayView.animate({opacity: 0.0, duration: 250}, (evt)=>@window.removeChild(@overlayView))
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  getNavGroupContainer: ()-> @navGroupContainer

  # ----------------------------------------------------------------------------------------------------------------
  # We look at "_pointsAt" option, a Point, to derive "top", "left"
  #
  createNavGroupContainer: (height, width)->

    if (pointsAt = @options._pointsAt)? and (pointsAt.x isnt 0) and (pointsAt.y isnt 0)
      right = pointsAt.x
      top = pointsAt.y

      tipAdjust = if this.hasTip() then (kTipWidth + kTipOffset) else 0

      # Position the box to the left of the target location
      right += tipAdjust
      top -= (height/2)

    else
      # default to the middle of the screen, with no tip
      right = (Hy.UI.iPad.screenWidth - width)/2
      top = (Hy.UI.iPad.screenHeight - height)/2      

      @doTip = false

    # Make sure we're still on the screen
    top = Math.max(top, 0)
    right = Math.min(right, Hy.UI.iPad.screenWidth - width)

    navGroupContainerOptions = 
      top: top
      right: right
      width: width
      height: height
      zIndex: kOverlayZIndex + 1
      opacity: 1
      _tag: "NavGroup Navigation Group Container"
#      borderColor: Hy.UI.Colors.green
      borderWidth: 0

    @navGroupContainer = new Hy.UI.ViewProxy(navGroupContainerOptions)

  # ----------------------------------------------------------------------------------------------------------------
  hasTip: ()-> 
    
    @doTip

  # ----------------------------------------------------------------------------------------------------------------
  # We always put it on the left, for now
  #
  createTip: (height, width)->

    tip = null

    if this.hasTip()
      top = (height/2) - (kTipWidth/2)

      tipOptions = 
        width: kTipWidth
        height: kTipHeight
        top: top
        left: width + kTipOffset
        image: "assets/icons/arrow-right.png"
        _tag: "NavGroup tip"

      tip = new Hy.UI.ImageViewProxy(tipOptions)

    tip

  # ----------------------------------------------------------------------------------------------------------------
  hide: ()->

    if not @hidden
      @hidden = true
      this.removeOverlayView()

      this.getNavGroup().hide()

    this

  # ----------------------------------------------------------------------------------------------------------------
  show: ()->

    if @hidden
      hidden = false
      this.addOverlayView()

      this.getNavGroup().show()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Called by our subclass of NavGroup
  #
  animateOut: (immediate, fnDone)->

    options= 
      opacity: 0
      duration: if immediate then 0 else 250

    this.getNavGroupContainer().animate(options, fnDone)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Called by our subclass of NavGroup
  #
  dismissedEntirely: ()->

    this.removeOverlayView()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # If the user touches outside the nav group: We inform the NavGroup, which will decide if we actually should go
  # away. This is where our subclass of NavGroup comes into play.
  #
  overlayTouched: ()->

    this.getNavGroup().dismissRequested()

    this
    
# ==================================================================================================================
#
class AlertDialog extends ViewProxy

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options)->

    defaultOptions = 
      title: "Message from #{Hy.Config.DisplayName}"
      buttonNames: ["OK"]
      message: "Message"

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this.show()

    this

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

   Ti.UI.createAlertDialog(options)

# ==================================================================================================================
if not Hyperbotic.UI?
  Hyperbotic.UI = {}

Hyperbotic.UI.Position = Position
Hyperbotic.UI.PositionEx = PositionEx
Hyperbotic.UI.SizeEx = SizeEx
Hyperbotic.UI.ViewProxy = ViewProxy
Hyperbotic.UI.ImageViewProxy = ImageViewProxy
Hyperbotic.UI.WebViewProxy = WebViewProxy
Hyperbotic.UI.LabelProxy = LabelProxy
Hyperbotic.UI.ButtonProxy = ButtonProxy
Hyperbotic.UI.ButtonProxyWithState = ButtonProxyWithState
Hyperbotic.UI.ScrollOptions = ScrollOptions
Hyperbotic.UI.WindowProxy = WindowProxy
Hyperbotic.UI.AlertDialog = AlertDialog
Hyperbotic.UI.OptionsList = OptionsList
Hyperbotic.UI.OptionsSelector = OptionsSelector
Hyperbotic.UI.SystemButtonProxy = SystemButtonProxy
Hyperbotic.UI.NavGroup = NavGroup
Hyperbotic.UI.NavGroupPopover = NavGroupPopover
Hyperbotic.UI.TextAreaProxy = TextAreaProxy

