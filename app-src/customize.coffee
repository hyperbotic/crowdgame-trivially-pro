# ==================================================================================================================
# 
# Representing Color: http://www.avajava.com/tutorials/lessons/what-are-the-different-ways-to-represent-colors-in-css.html
#
# Grammar: http://pegjs.majda.cz/online
#

# ==================================================================================================================

class Customize

  gCurrentCustomization = null
  gFn_CustomizationActivated = null

  # ----------------------------------------------------------------------------------------------------------------
  @getCurrentCustomization: ()-> gCurrentCustomization

  # ----------------------------------------------------------------------------------------------------------------
  # Returns [found, status, message]
  #
  #   found: true/false, if property is a supported property
  #   status: true/false, set to false if fatal error
  #   message: if non-null, a helpful human-readable message string
  #
  @checkProp: (name, value)->
    found = false
    status = true
    message = null

    [found, status, message, output] = Customize.parse(name, value)

    # backpatching for screw case: when the value is of a kind where case is important
    # undo the lowercasing...

    if output?
      switch output.kind
        when "String","URL", "StringDelim", "FontName"
          output.value = value

    [found, status, message, output]

  # ----------------------------------------------------------------------------------------------------------------
  @init: (fn_customizationActivated = null)->

    gFn_CustomizationActivated = fn_customizationActivated

  # ----------------------------------------------------------------------------------------------------------------
  @parse: (name, value)->
    found = true
    status = true
    output = null
    message = null

    input = "#{name}=#{value}".toLowerCase().trim()

    output = try
      (Hy.PEG.parse(input))[0]
    catch e
      status = false
      found = false

      column = if e.column?
        " (character ##{e.column})"
      else
        ""

      message = if e.found?
        "Incorrect setting, starting with \"#{e.found}\"#{column} (ignored)"
      else
        "Problem with \"#{name}\" or value (ignored)"

      if e.message?
        message = e.message

      null

    if found and status and not message?
      [status, message, output] = Customize.validateValue(name, value, output)

    [found, status, message, output]

  # ----------------------------------------------------------------------------------------------------------------
  # 
  # Do some level of early validation on the value part of the setting
  #
  @validateValue: (name, value, output)->

    message = null
    status = true

    [status, message] = switch output.kind
      when "RGBInteger"
        [status, hex, message] = Hy.UI.Colors.convertRGBInteger16ToHex(output.value.r, output.value.g, output.value.b)
        [status, message]

      when "RGBPercentage"
        [status, hex, message] = Hy.UI.Colors.convertRGBPercentageToHex(output.value.r, output.value.g, output.value.b)
        [status, message]

      when "Hex"
        [status, hex, message] = Hy.UI.Colors.validateHex(output.value)
        [status, message]

      when "URL", "Integer", "String"
        [true, null]

      when "StringDelim"
#        # Trim the delimiters we added
#        value.substr(1, value.length-2)
#        ACTUALLY, that wouldn't work here anyway
        [true, null]

      when "FontName"
        if Hy.UI.Fonts.isCustomizationFont(output.value)?
          [true, null]
        else
          [false, "\"#{Hy.Utils.String.trimWithElipsis(value, 15)}\" is not a supported font"]

      when "LanguageCode"
        if Hy.Localization.isValidLanguageCode(output.value)?
          [true, null]
        else
          [false, "\"#{Hy.Utils.String.trimWithElipsis(value, 15)}\" is not a supported language code"]

      when "ColorName"
        if Hy.UI.Colors.getHexForColorName(output.value)?
          [true, null]
        else
          if output.value is "transparent"
            [supported, details] = Hy.UI.Colors.supportsTransparent(output.name)
            if supported
              [true, null]
            else
              if details?
                [false, "\"transparent\" is not supported #{details}"]
              else
                [false, "\"transparent\" is only supported on \"bordercolor\" or \"backgroundcolor\""]
          else
            [false, "Unrecognized color name \"#{Hy.Utils.String.trimWithElipsis(value, 15)}\""]

      when "Boolean"
        [true, null]

      when "Coordinate"
        [true, null]

      when "Size"
        [true, null]

      when "Align"
        [true, null]

      else
        [true, null]

    if status
      message = null

    [status, message, output]

  # ----------------------------------------------------------------------------------------------------------------
  # 
  # Do some level of early validation on the setting itself
  #
  @validateSettings: (customizationProps, fn_addWarning, fn_addError)->

    status = true

    iPadWidth = Hy.UI.iPad.screenWidth
    iPadHeight = Hy.UI.iPad.screenHeight

    # full screen constraints
    fsPosition = 
      min: {top: 0, bottom: 0, left: 0, right: 0}
      max: {top: iPadHeight, bottom: iPadHeight, left: iPadWidth, right: iPadWidth}

    fsSize = 
      min: {height: 0, width: 0}
      max: {height: iPadHeight+1, width: iPadWidth+1}

    tests = [
      { 
        filter:        ".(response|correct|incorrect).", 
        fn_validate:   (prop)=> Hy.UI.PlayerStage.validateCustomization() },

      {
        filter:        ".startbutton.position", 
        fn_validate:   (prop)=> Hy.Pages.StartPage.validatePlayButtonCustomization(prop.value) },

      {
        filter:        ".playagainbutton.position", 
        fn_validate:   (prop)=> Hy.Pages.ContestCompletedPage.validatePlayAgainButtonCustomization(prop.value) },

      {
        filter:        ".scoreboard.position", 
        fn_validate:   (prop)=> Hy.Pages.ContestCompletedPage.validateScoreboardCustomization(prop.value) },

      {
        filter:        ".question.size", 
        fn_validate:   (prop)=> Hy.Pages.QuestionPage.validateQuestionCustomizationSize(prop.value) },

      {
        filter:        ".question.offset", 
        fn_validate:   (prop)=> Hy.Pages.QuestionPage.validateQuestionCustomizationOffset(prop.value) },

      {
        filter:        ".answers.size", 
        fn_validate:   (prop)=> Hy.Pages.QuestionPage.validateAnswersCustomizationSize(prop.value) },

      {
        filter:        ".answers.offset", 
        fn_validate:   (prop)=> Hy.Pages.QuestionPage.validateAnswersCustomizationOffset(prop.value) },

      #
      # Last ditch / global
      #

      {
        filter:        ".position$", 
        fn_validate:   (prop)=> 
          for d in prop.value
            if not ( (d.kind is "absolute") or (d.kind is "directive") )
              return "don\'t use \"+\" or \"-\" in position"
            if (m = (new Hy.UI.PositionEx(prop.value)).isValid(fsPosition))?
              return m
          null},
      {
        filter:        ".size$", 
        fn_validate:   (prop)=> 
          if (m = (new Hy.UI.SizeEx(prop.value)).isValid(fsSize))?
            return m
          null},

      {
        filter:        ".font.size$", 
        fn_validate:   (prop)=> Hy.UI.Fonts.isValidCustomizationFontSize(prop.value) }

    ]

    for prop in customizationProps
      for test in tests
        regex = new RegExp(test.filter)
        if regex.test(prop.name)
          if (message = test.fn_validate?(prop))?
            fn_addWarning(message, prop.lineNum)
            break # One warning per property

    status

  # ----------------------------------------------------------------------------------------------------------------
  @map: (propName, path = [], defaultValue = null)->

    if not (value = gCurrentCustomization?._map(propName, path))?
      value = defaultValue

    value

  # ----------------------------------------------------------------------------------------------------------------
  @mapFont: (propName, path = [], defaultOptions = null)->

    if not (value = gCurrentCustomization?._mapFont(propName, path, defaultOptions))?
      value = defaultOptions

    value

  # ----------------------------------------------------------------------------------------------------------------
  @mapOptions: (propNames, path = [], options = {})->

    gCurrentCustomization?._mapOptions(propNames, path, options)

    options

  # ----------------------------------------------------------------------------------------------------------------
  @has: (propNames, path = [], explicitOnly = false)->

   result = if gCurrentCustomization?
     gCurrentCustomization._has(propNames, path, explicitOnly)
   else 
     false

    result      

  # ----------------------------------------------------------------------------------------------------------------
  @isActive: (contentPack = null)->
    active = if contentPack?
      if gCurrentCustomization?
        gCurrentCustomization.getContentPack() is contentPack
      else
        false
    else
      gCurrentCustomization?

    active

  # ----------------------------------------------------------------------------------------------------------------
  @
  # ----------------------------------------------------------------------------------------------------------------
  @activate: (customization = null, options = null)->

    if gCurrentCustomization isnt customization
      gCurrentCustomization = customization

      Hy.Localization.setLanguageCode()

      if (languageCode = Hy.Customize.map("language"))?
        Hy.Localization.setLanguageCode(languageCode)

      Customize._executeFn_Completed(options)

    null

  # ----------------------------------------------------------------------------------------------------------------
  @deactivate: (options = null)->

    gCurrentCustomization = null

    Customize._executeFn_Completed(options)

    null

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Establishes policy for when we customize various screen elements

  @required: (elementKind, path = [])=>

    props = switch elementKind
      when "button"
        ["buttons.*", "color", "bordercolor", "font.*"]
      when "logo1", "logo2"
        ["text", "background.url"]
      else
        null

    needsCustomization = if props?
      Hy.Customize.has(props, path, true) # explicitOnly search
    else
      false

    needsCustomization

  # ----------------------------------------------------------------------------------------------------------------
  @_executeFn_Completed: (options)->
    gFn_CustomizationActivated?(gCurrentCustomization, options)
    null

  # ----------------------------------------------------------------------------------------------------------------
  #
  # where "kind" is buttons or logos, or any other type that we expose to the user
  #
  @path: (page = null, intermediate = [], kind = null)->

    path = {}
    path.pageName = if page? then page.getCustomizeName().toLowerCase() else ""
    path.kind = kind
    path.intermediate = intermediate.slice()

    path    

  # ----------------------------------------------------------------------------------------------------------------
  @pathSetKind: (path, kind)->
    path.kind = kind
    path

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@contentPack, customizationSpecs = [])->

    @customizations = []

    for customizationSpec in customizationSpecs
      this._processCustomization(customizationSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getContentPack: ()-> @contentPack

  # ----------------------------------------------------------------------------------------------------------------
  getCustomizations: ()-> @customizations

  # ----------------------------------------------------------------------------------------------------------------
  _processCustomization: (customizationSpec)->

    fn_report = (cs, propValue)->
      Hy.Trace.debug("Customize::_processCustomization (line:#{cs.lineNum} #{cs.kind} #{cs.name}=#{cs.value} interpreted as: #{propValue})")
      null
      
    kind = customizationSpec.kind
    value = customizationSpec.value
    name = customizationSpec.name
    lineNum = customizationSpec.lineNum

    propValue = switch kind
      when "RGBInteger"
        [status, hex, message] = Hy.UI.Colors.convertRGBInteger16ToHex(value.r, value.g, value.b)
        hex
      when "RGBPercentage"
        [status, hex, message] = Hy.UI.Colors.convertRGBPercentageToHex(value.r, value.g, value.b)
        hex
      when "Hex"
        [status, hex, message] = Hy.UI.Colors.validateHex(value)
        hex
      when "URL", "Integer", "String"
        value
      when "ColorName"
        if (c = Hy.UI.Colors.getHexForColorName(value))?
          c
        else
          if value is "transparent"
            [supported, details] = Hy.UI.Colors.supportsTransparent(name)
            if supported
              value
            else
              null
          else
            null

      when "LanguageCode"
        value

      when "FontName"
        value

      when "StringDelim"
#        # Trim the delimiters we added
#        value.substr(1, value.length-2)

        # \n is converted into \ and n, fix that now
        if value?
          value = value.replace("\\n", "\n")
         
        value
      when "Boolean"
        if value? then value else false
      when "Coordinate"
        new Hy.UI.PositionEx(value)
      when "Size"
        new Hy.UI.SizeEx(value)
      when "Align"
        value
      else
        null

    fn_report(customizationSpec, propValue)

    if propValue?
      @customizations.push {propName: name, kind: kind, value: propValue, lineNum: lineNum}
      
    this

  # ----------------------------------------------------------------------------------------------------------------

  kLocalOnlyProperties = [
    "background.url"
  ]

  _isLocalOnly: (propName)->

    _.find(kLocalOnlyProperties, (p)=>p is propName)?


  # ----------------------------------------------------------------------------------------------------------------
  #
  # Scenarios:
  #
  # Looking for borderColor to customize Play Button
  #
  # Search:
  #   PlayButton.borderColor
  #   StartPage.buttons.borderColor
  #   StartPage.borderColor
  #   buttons.borderColor
  #   borderColor
  #
  # In this case, path.kind is "buttons"
  # and the search path is: PlayButton > StartPage
  #

  _find: (propName, path, fn_test, explicitOnly = false)->

    fn_lowercasePath = (path)=>
      path.intermediate = _.map(path.intermediate, (c)=>c.toLowerCase())
      path.kind = if path.kind?
        path.kind.toLowerCase()
      else
        null
      path
  
    fn_makePathname = (pageName, inter, kind, prop)=>
      pathname = ""
      if pageName?
        pathname += "#{pageName}."

      if inter?
        for i in inter
          pathname += "#{i}."

      if kind?
        pathname += "#{kind}."
      pathname += prop
      pathname

    fn_compare = (pathname)=>
      _.find(this.getCustomizations(), (c)=>fn_test(c.propName, pathname))

    fn_searchRegularHierarchy = ()=>
      # Now search non-"kind" space:
      #  startpage.logo1.
      #  startpage.
      #  .
      #
      # Handle the abstract case like this:
      #  startpage.element1.element2.element3.prop
      #  startpage.element1.element2.prop
      #  startpage.element1.prop
      #  startpage.prop
      #  prop
       
      i = inter.slice()
      while i.length > 0
        search.push {pageName: pageName, inter: i, kind: null}
        i.pop()

      search.push {pageName: pageName, inter: null, kind: null}
      search.push {pageName: null,     inter: null, kind: null}
      null

    lPropName = propName.toLowerCase()
    path = fn_lowercasePath(path)
    pageName = path.pageName
    inter = path.intermediate
    kind = path.kind

    customization = null

    search = []

    # If a full path specified, search it first
    if pageName? and inter.length > 0
      search.push {pageName: pageName, inter: inter, kind: null}

    if kind?

      # If "kind" is specified, such as "logos", search for match in that space
      #  startpage.logos.
      #  logos.

      search.push {pageName: pageName, inter: null, kind: kind}
      search.push {pageName: null,     inter: null, kind: kind}

      # Then search the "regular" hiearchy, for most props
      if (not this._isLocalOnly(lPropName)) and not explicitOnly
        fn_searchRegularHierarchy()

    else

      fn_searchRegularHierarchy()

      # Exception: some properties - background.url - aren't inherited
      if this._isLocalOnly(lPropName)
        search = [search[0]]

    for s in search    
      if (customization = fn_compare(fn_makePathname(s.pageName, s.inter, s.kind, lPropName)))?
        return customization

    return null

  # ----------------------------------------------------------------------------------------------------------------
  _map: (propName, path = [])->

    value = if (customization = this._find(propName, path, (n1, n2)=>n1 is n2))?
      # Special case: cached files for URLs
      if (customization.kind is "URL") and (value isnt "none")
          if (u = Hy.Network.DownloadCache.getCachePathname(customization.value, false))?
            u
          else
            customization.value
      else
        customization.value
    else
      null

    value

  # ----------------------------------------------------------------------------------------------------------------
  #
  # "prop" should be used for cases like "buttons.font"... send in "buttons"
  #
  _mapFont: (prefixprop = null, path = [], defaultOptions = {})=>

    if not defaultOptions.font?
      defaultOptions.font = Hy.UI.Fonts.specBigNormal

    defaultOptions.font = Hy.UI.Fonts.cloneFont(defaultOptions.font)

    fn_prop = (propName)=>
      "#{if prefixprop? then prefixprop + "." else ""}#{propName}"

    if (f = this._map(fn_prop("font.size"), path))?
      defaultOptions.font.fontSize = f

    if (f = this._map(fn_prop("font.style"), path))?
      defaultOptions.font.fontStyle = f

    if (f = this._map(fn_prop("font.weight"), path))?
      defaultOptions.font.fontWeight = f

    if (f = this._map(fn_prop("font.name"), path))?
      defaultOptions.font.fontFamily = f

    if (f = this._map(fn_prop("font.color"), path))?
      defaultOptions.color = f
    
    defaultOptions

  # ----------------------------------------------------------------------------------------------------------------
  #
  # this should only be used with simple propNames, not compound ones (like, say, "buttons.font")
  #
  _mapOptions: (propNames = [], path = [], options = {})->

    fn_map = (prop, f = null)=> 
      status = true
      if not (value = this._map(prop, path))?
        status = false
      if status and value?
        f?(value)
      [status, value]

    for propName in propNames
      switch propName
        when "position", "size", "offset"
          fn_map(propName, (v)=>v.getOptions(options))
        when "font"
          this._mapFont(null, path, options)
        when "background"
          fn_map("background.color", (v)=>options.backgroundColor = v)
          fn_map("background.url", (v)=>options.backgroundImage = v)
        when "bordercolor"
          fn_map("bordercolor", (v)=>
            options.borderColor = v
            if v?
              options.borderWidth = 3
            null)
        when "text"
          fn_map("text", (v)=>options.text = v)

    options

  # ----------------------------------------------------------------------------------------------------------------
  _has: (propNames, path = [], explicitOnly = false)->

    fn_test = (n1, n2)=>

      result = if n2.indexOf("*") isnt -1
        (new RegExp("^#{n2}")).test(n1)
      else
        n1 is n2

      if result # For debugging
        null
      else
        null
      result

    for propName in propNames
      if this._find(propName, path, fn_test, explicitOnly)
        return true

    false

  # ----------------------------------------------------------------------------------------------------------------
  hasAssets: ()->
    _.find(this.getCustomizations(), (c)=>c.kind is "URL")?

  # ----------------------------------------------------------------------------------------------------------------
#
#  http://stackoverflow.com/questions/10311092/displaying-files-e-g-images-stored-in-google-drive-on-a-website
#  https://www.debuggex.com/
#
#  Example:
#    https://drive.google.com/file/d/0B_Vyfy1LBTe3WVRtLVp3YTNwWDQ/edit?usp=sharing
#
#   transform to
#
#    https://drive.google.com/uc?id=0B_Vyfy1LBTe3WVRtLVp3YTNwWDQ
#

  transformGoogleDriveURL: (url)->

    fn_isGoogleDrive = (url)=>
      url.match(/^https:\/\/drive.google.com\/file\/[^\/]\/(.)+\/edit(.)*/gi)?

    fn_transform = (url)=>
      u = url.replace(/^https:\/\/drive.google.com\/file\/[^\/]\//i, "https://drive.google.com/uc?id=")
      u = u.replace(/\/edit\?usp=sharing$/i, "")
      u

    newURL = if fn_isGoogleDrive(url)
      fn_transform(url)
    else
      null

    newURL

  # ----------------------------------------------------------------------------------------------------------------
  prepareAssetDownloadEventSpecs: (@fn_progressReport, @fn_addMessage)->

    fn_makeEventSpec = (customization)=>
      url = if (newURL = this.transformGoogleDriveURL(customization.value))?
        newURL
      else
        customization.value

      eventSpec = 
        callback: ((cm, event, eventSpec)=>cm.assetDownloaded(event, eventSpec)), 
        URL: url
        customization: customization
        display: "Customization: #{customization.propName} #{customization.value}"
        fnPre: (e, s)=>
          @fn_progressReport("Downloading #{customization.propName}...")
          true
      eventSpec

    eventSpecs = []

    for customization in this.getCustomizations()
      if customization.kind is "URL" and customization.value isnt "none"
        if Hy.Network.DownloadCache.getCachePathname(customization.value)?
          Hy.Trace.debug "Customize::prepareAssetDownloadEventSpecs (ALREADY IN CACHE #{customization.propName} #{customization.value})"
          null # Already in the cache
        else
          if (d = _.find(eventSpecs, (s)=>s.customization.value is customization.value))?
            Hy.Trace.debug "Customize::prepareAssetDownloadEventSpecs (ALREADY QUEUED FOR DOWNLOAD #{customization.propName} #{d.customization.propName} #{d.customization.value})"
            null # already scheduled to be downloaded
          else
            Hy.Trace.debug "Customize::prepareAssetDownloadEventSpecs (QUEUING FOR DOWNLOAD #{customization.propName} #{customization.value})"
            eventSpecs.push fn_makeEventSpec(customization)

    if eventSpecs.length > 0 then eventSpecs else null

  # ----------------------------------------------------------------------------------------------------------------
  checkIsValidAssetType: (event)->
    valid = true

    fn_checkIsHTML = ()=>
      isHTML = if (r = event.responseText)?
        responseText = r.substr(0, 20)
        responseText.indexOf("<!DOCTYPE html>") isnt -1
      else
        false
      isHTML

    # For now, just check that it's not HTML
    if fn_checkIsHTML()
      valid = false

    valid
    
  # ----------------------------------------------------------------------------------------------------------------
  assetDownloaded: (event, eventSpec)->

    Hy.Trace.debug "Customize::assetDownloaded (#{eventSpec.URL}-> #{event.getLocationURL()})"
    cust = event.obj.customization
    message = null

    if event.isErrorState()
      message = "Couldn\'t download #{eventSpec.customization.propName}. Please check URL and permissions and try again."
    else
      if this.checkIsValidAssetType(event)
        @fn_progressReport("Downloaded #{eventSpec.customization.propName}...")

        # We map the asset to the original URL, not the transformed one (if different)
        #
        eventSpec.customization.cachePathname = Hy.Network.DownloadCache.put(eventSpec.customization.value, event.responseData, true)
        eventSpec.customization.downloadURL = event.getLocationURL() # To help with debugging
      else
        message = "Couldn\'t download #{eventSpec.customization.propName}. Please check URL and permissions and try again."

    if message?
      this.clearAssetDownloadFailure(cust)
      @fn_addMessage("error", cust.lineNum, message)

    message?

  # ----------------------------------------------------------------------------------------------------------------
  clearAssetDownloadFailure: (failedCustomization)->

    Hy.Trace.debug "Customize::clearAssetDownloadFailure (#{failedCustomization.propName} #{failedCustomization.value})"

    # Find all customizations with the same URL, and clear 'em
    for c in _.filter(this.getCustomizations(), (c)=>(c.kind is "URL") and (c.value is failedCustomization.value))
      c.value = null # Prevent problems later, such as if the WebView tries to load it
 
    this



# ==================================================================================================================
Hyperbotic.Customize = Customize



