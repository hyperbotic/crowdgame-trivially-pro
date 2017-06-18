# ==================================================================================================================
class Backgrounds

  @pixelOverlay   = "assets/bkgnds/pixel-overlay.png"

# ==================================================================================================================
class Device

  @getDensity: ()-> Ti.Platform.displayCaps.density

class iPad extends Device
  @screenWidth = 1024
  @screenHeight = 768

class iPhone extends Device
  @screenWidth =  320
  @screenHeight = 480

class iPhoneRetina #THIS IS WRONG
  @screenWidth =  640
  @screenHeight = 960

# ==================================================================================================================
class Fonts
  @Font1 = "Trebuchet MS"
  @Font2 = "Courier New"
  @Font3 = "Helvetica Neue, Condensed Bold"
  @font4 = "Helvetica Neue"
  @MrF   = "Mr. F blockserif"

  @defaultDarkShadowColor = '#666'
  @defaultLightShadowColor = '#fff'
  @defaultShadowOffset = {x:2,y:2}

  @specGiantMrF =  {fontSize: 84, fontWeight: 'bold', fontFamily: "Mr. F blockserif"}
  @specBigMrF =    {fontSize: 48, fontWeight: 'bold', fontFamily: "Mr. F blockserif"}
  @specMediumMrF = {fontSize: 36, fontWeight: 'bold', fontFamily: "Mr. F blockserif"}
  @specSmallMrF =  {fontSize: 30, fontWeight: 'bold', fontFamily: "Mr. F blockserif"}
  @specTinyMrF  =  {fontSize: 14, fontWeight: 'bold', fontFamily: "Mr. F blockserif"}

  @specBiggerNormal =     {fontSize:48,fontWeight:'bold', fontFamily: "Trebuchet MS"}
  @specBigNormal =        {fontSize:36,fontWeight:'bold', fontFamily: "Trebuchet MS"}
  @specMediumNormal =     {fontSize:28,fontWeight:'bold', fontFamily: "Trebuchet MS"}
  @specSmallNormal =      {fontSize:22,fontWeight:'bold', fontFamily: "Trebuchet MS"}  
  @specTinyNormal =       {fontSize:18,fontWeight:'bold', fontFamily: "Trebuchet MS"}  
  @specTinyNormalNoBold = {fontSize:18,fontWeight:'bold', fontFamily: "Trebuchet MS"}  
  @specMinisculeNormal =  {fontSize:12,fontWeight:'bold', fontFamily: "Trebuchet MS"}  

  @specMediumCode =   {fontSize:28,fontWeight:'bold', fontFamily: "Courier New"}
  @specTinyCode =     {fontSize:14,fontWeight:'bold', fontFamily: "Courier New"}

  # ----------------------------------------------------------------------------------------------------------------
  # Returns a new font object based on merging the properties of fontA and fontB. fontB overrides fontA
  #
  @mergeFonts: (fontA, fontB)->

    newFont = {}

    for font in [fontA, fontB] 
      if font?   
        for prop, value of font
          newFont[prop] = value

    newFont

  @cloneFont: (font)->

    _.clone(font)

  # ----------------------------------------------------------------------------------------------------------------
  # http://support.apple.com/kb/HT5878
  #
  @customizationFonts = [
    "Academy Engraved LET Plain",
    "Al Nile",
    "Al Nile Bold",
    "American Typewriter",
    "American Typewriter Bold",
    "American Typewriter Condensed",
    "American Typewriter Condensed Bold",
    "American Typewriter Condensed Light",
    "American Typewriter Light",
    "Apple Color Emoji",
    "Apple SD Gothic Neo Bold",
    "Apple SD Gothic Neo Light",
    "Apple SD Gothic Neo Medium",
    "Apple SD Gothic Neo Regular",
    "Apple SD Gothic Neo SemiBold",
    "Apple SD Gothic Neo Thin",
    "AppleGothic Regular",
    "Arial",
    "Arial Bold",
    "Arial Bold Italic",
    "Arial Hebrew",
    "Arial Hebrew Bold",
    "Arial Hebrew Light",
    "Arial Italic",
    "Arial Rounded MT Bold",
    "Avenir Black",
    "Avenir Black Oblique",
    "Avenir Book",
    "Avenir Book Oblique",
    "Avenir Heavy",
    "Avenir Heavy Oblique",
    "Avenir Light",
    "Avenir Light Oblique",
    "Avenir Medium",
    "Avenir Medium Oblique",
    "Avenir Next Bold",
    "Avenir Next Bold Italic",
    "Avenir Next Condensed Bold",
    "Avenir Next Condensed Bold Italic",
    "Avenir Next Condensed Demi Bold",
    "Avenir Next Condensed Demi Bold Italic",
    "Avenir Next Condensed Heavy",
    "Avenir Next Condensed Heavy Italic",
    "Avenir Next Condensed Italic",
    "Avenir Next Condensed Medium",
    "Avenir Next Condensed Medium Italic",
    "Avenir Next Condensed Regular",
    "Avenir Next Condensed Ultra Light",
    "Avenir Next Condensed Ultra Light Italic",
    "Avenir Next Demi Bold",
    "Avenir Next Demi Bold Italic",
    "Avenir Next Heavy",
    "Avenir Next Heavy Italic",
    "Avenir Next Italic",
    "Avenir Next Medium",
    "Avenir Next Medium Italic",
    "Avenir Next Regular",
    "Avenir Next Ultra Light",
    "Avenir Next Ultra Light Italic",
    "Avenir Oblique",
    "Avenir Roman",
    "Bangla Sangam MN",
    "Bangla Sangam MN Bold",
    "Baskerville",
    "Baskerville Bold",
    "Baskerville Bold Italic",
    "Baskerville Italic",
    "Baskerville SemiBold",
    "Baskerville SemiBold Italic",
    "Bodoni 72 Bold",
    "Bodoni 72 Book",
    "Bodoni 72 Book Italic",
    "Bodoni 72 Oldstyle Bold",
    "Bodoni 72 Oldstyle Book",
    "Bodoni 72 Oldstyle Book Italic",
    "Bodoni 72 Smallcaps Book",
    "Bodoni Ornaments",
    "Bradley Hand Bold",
    "Chalkboard SE Bold",
    "Chalkboard SE Light",
    "Chalkboard SE Regular",
    "Chalkduster",
    "Cochin",
    "Cochin Bold",
    "Cochin Bold Italic",
    "Cochin Italic",
    "Copperplate",
    "Copperplate Bold",
    "Copperplate Light",
    "Courier",
    "Courier Bold",
    "Courier Bold Oblique",
    "Courier New",
    "Courier New Bold",
    "Courier New Bold Italic",
    "Courier New Itali",
    "Courier Oblique",
    "DIN Alternate Bold",
    "DIN Condensed Bold",
    "Damascus",
    "Damascus Bold",
    "Damascus Medium",
    "Damascus Semi Bold",
    "Devanagari Sangam MN",
    "Devanagari Sangam MN Bold",
    "Didot",
    "Didot Bold",
    "Didot Italic",
    "Diwan Mishafi",
    "Euphemia UCAS",
    "Euphemia UCAS Bold",
    "Euphemia UCAS Italic",
    "Farah",
    "Futura Condensed ExtraBold",
    "Futura Condensed Medium",
    "Futura Medium",
    "Futura Medium Italic",
    "Geeza Pro",
    "Geeza Pro Bold",
    "Geeza Pro Light",
    "Georgia",
    "Georgia Bold",
    "Georgia Bold Italic",
    "Georgia Italic",
    "Gill Sans",
    "Gill Sans Bold",
    "Gill Sans Bold Italic",
    "Gill Sans Italic",
    "Gill Sans Light",
    "Gill Sans Light Italic",
    "Gujarati Sangam MN",
    "Gujarati Sangam MN Bold",
    "Gurmukhi MN",
    "Gurmukhi MN Bold",
    "Heiti SC Medium",
    "Heiti TC Light",
    "Heiti TC Medium",
    "Helvetica",
    "Helvetica Bold",
    "Helvetica Bold Oblique",
    "Helvetica Light",
    "Helvetica Light Oblique",
    "Helvetica Neue",
    "Helvetica Neue Bold",
    "Helvetica Neue Bold Italic",
    "Helvetica Neue Condensed Black",
    "Helvetica Neue Condensed Bold",
    "Helvetica Neue Italic",
    "Helvetica Neue Light",
    "Helvetica Neue Light Italic",
    "Helvetica Neue Medium",
    "Helvetica Neue Medium Italic",
    "Helvetica Neue Thin",
    "Helvetica Neue Thin Italic",
    "Helvetica Neue UltraLight",
    "Helvetica Neue UltraLight Italic",
    "Helvetica Oblique",
    "Hiragino Kaku Gothic ProN W3",
    "Hiragino Kaku Gothic ProN W6",
    "Hiragino Mincho ProN W",
    "Hiragino Mincho ProN W",
    "Hoefler Text",
    "Hoefler Text Black",
    "Hoefler Text Black Italic",
    "Hoefler Text Italic",
    "Iowan Old Style Bold",
    "Iowan Old Style Bold Italic",
    "Iowan Old Style Italic",
    "Iowan Old Style Roman",
    "Kailasa Bold",
    "Kailasa Regular",
    "Kannada Sangam MN",
    "Kannada Sangam MN Bold",
    "Malayalam Sangam MN",
    "Malayalam Sangam MN Bold",
    "Marion Bold",
    "Marion Italic",
    "Marion Regular",
    "Marker Felt Thin",
    "Marker Felt Wide",
    "Menlo Bold",
    "Menlo Bold Italic",
    "Menlo Italic",
    "Menlo Regular",
    "Noteworthy Bold",
    "Noteworthy Light",
    "Optima Bold",
    "Optima Bold Italic",
    "Optima ExtraBlack",
    "Optima Italic",
    "Optima Regular",
    "Oriya Sangam MN",
    "Oriya Sangam MN Bold",
    "Palatino",
    "Palatino Bold",
    "Palatino Bold Italic",
    "Palatino Italic",
    "Papyrus",
    "Papyrus Condensed",
    "Party LET Plain",
    "Savoye LET Plain C",
    "Savoye LET Plain",
    "Sinhala Sangam MN",
    "Sinhala Sangam MN Bold",
    "Snell Roundhand",
    "Snell Roundhand Black",
    "Snell Roundhand Bold",
    "Superclarendon Black",
    "Superclarendon Black Italic",
    "Superclarendon Bold",
    "Superclarendon Bold Italic",
    "Superclarendon Italic",
    "Superclarendon Light",
    "Superclarendon Light Italic",
    "Superclarendon Regular",
    "Symbol",
    "Tamil Sangam MN",
    "Tamil Sangam MN Bold",
    "Telugu Sangam MN",
    "Telugu Sangam MN Bold",
    "Thonburi",
    "Thonburi Bold",
    "Thonburi Light",
    "Times New Roman",
    "Times New Roman Bold",
    "Times New Roman Bold Italic",
    "Times New Roman Italic",
    "Trebuchet MS",
    "Trebuchet MS Bold",
    "Trebuchet MS Bold Italic",
    "Trebuchet MS Italic",
    "Verdana",
    "Verdana Bold",
    "Verdana Bold Italic",
    "Verdana Italic",
    "Zapf Dingbats",
    "Zapfino"
  ]

  # ----------------------------------------------------------------------------------------------------------------
  @isCustomizationFont: (fontName)->
    _.find(@customizationFonts, (f)-> (f.toLowerCase() is fontName.toLowerCase()))

  kMaxCustomizationFontSize = 76
  # ----------------------------------------------------------------------------------------------------------------
  @isValidCustomizationFontSize: (fontSize)->

    message = if fontSize <= 0
      "font.size must be > 0"
    else
      if fontSize > kMaxCustomizationFontSize
        "font.size must be < #{kMaxCustomizationFontSize + 1}"
      else
        null

    message

# ==================================================================================================================
Colors2 = 
  white:  '#fff'
  black:  '#000'
  red:    '#f00'
  green:  '#0a5' #<00><176><80>
  blue:   '#07c' #<00><112><192>
  yellow: '#ea0' #<255><192><0>
  gray:   '#ccc'
  
  darkRed:    '#900'
  darkGreen:  '#072'
  darkBlue:   '#049'
  darkYellow: '#b70'
  paleYellow: '#ffc'

  MrF:
    DarkBlue:  '#0099ff'
    LightBlue: '#66ccff'

    Red:       '#ec2f2f'
    RedDark:   '#B32424'

    Orange:    '#ff6600'

    Gray:      '#9a9a9a'
    GrayLight: '#CCCCCC'
# ==================================================================================================================
class Colors
  @white = '#fff'
  @black = '#000'
  @red =   '#f00'
  @green = '#0a5' #<00><176><80>
  @blue =  '#07c' #<00><112><192>
  @yellow = #ea0' #<255><192><0>
  @gray =  '#ccc'
  
  @darkRed =   '#900'
  @darkGreen = '#072'
  @darkBlue =  '#049'
  @darkYellow = #b70'
  @paleYellow = #ffc'

  @MrF =
    DarkBlue:  '#0099ff'
    LightBlue: '#66ccff'

    Red:       '#ec2f2f'
    RedDark:   '#B32424'

    Orange:    '#ff6600'

    Gray:      '#9a9a9a'
    GrayLight: '#CCCCCC'

  # From http://www.w3schools.com/html/html_colornames.asp
  @customizationColors = [
    {name: "aliceblue",             hex: "#F0F8FF"},
    {name: "antiquewhite",          hex: "#FAEBD7"},
    {name: "aqua",                  hex: "#00FFFF"},
    {name: "aquamarine",            hex: "#7FFFD4"},
    {name: "azure",                 hex: "#F0FFFF"},
    {name: "beige",                 hex: "#F5F5DC"},
    {name: "bisque",                hex: "#FFE4C4"},
    {name: "black",                 hex: "#000000"},
    {name: "blanchedalmond",        hex: "#FFEBCD"},
    {name: "blue",                  hex: "#0000FF"},
    {name: "blueviolet",            hex: "#8A2BE2"},
    {name: "brown",                 hex: "#A52A2A"},
    {name: "burlywood",             hex: "#DEB887"},
    {name: "cadetblue",             hex: "#5F9EA0"},
    {name: "chartreuse",            hex: "#7FFF00"},
    {name: "chocolate",             hex: "#D2691E"},
    {name: "coral",                 hex: "#FF7F50"},
    {name: "cornflowerblue",        hex: "#6495ED"},
    {name: "cornsilk",              hex: "#FFF8DC"},
    {name: "crimson",               hex: "#DC143C"},
    {name: "cyan",                  hex: "#00FFFF"},
    {name: "darkblue",              hex: "#00008B"},
    {name: "darkcyan",              hex: "#008B8B"},
    {name: "darkgoldenrod",         hex: "#B8860B"},
    {name: "darkgray",              hex: "#A9A9A9"},
    {name: "darkgreen",             hex: "#006400"},
    {name: "darkkhaki",             hex: "#BDB76B"},
    {name: "darkmagenta",           hex: "#8B008B"},
    {name: "darkolivegreen",        hex: "#556B2F"},
    {name: "darkorange",            hex: "#FF8C00"},
    {name: "darkorchid",            hex: "#9932CC"},
    {name: "darkred",               hex: "#8B0000"},
    {name: "darksalmon",            hex: "#E9967A"},
    {name: "darkseagreen",          hex: "#8FBC8F"},
    {name: "darkslateblue",         hex: "#483D8B"},
    {name: "darkslategray",         hex: "#2F4F4F"},
    {name: "darkturquoise",         hex: "#00CED1"},
    {name: "darkviolet",            hex: "#9400D3"},
    {name: "deeppink",              hex: "#FF1493"},
    {name: "deepskyblue",           hex: "#00BFFF"},
    {name: "dimgray",               hex: "#696969"},
    {name: "dodgerblue",            hex: "#1E90FF"},
    {name: "firebrick",             hex: "#B22222"},
    {name: "floralwhite",           hex: "#FFFAF0"},
    {name: "forestgreen",           hex: "#228B22"},
    {name: "fuchsia",               hex: "#FF00FF"},
    {name: "gainsboro",             hex: "#DCDCDC"},
    {name: "ghostwhite",            hex: "#F8F8FF"},
    {name: "gold",                  hex: "#FFD700"},
    {name: "goldenrod",             hex: "#DAA520"},
    {name: "gray",                  hex: "#808080"},
    {name: "green",                 hex: "#008000"},
    {name: "greenyellow",           hex: "#ADFF2F"},
    {name: "honeydew",              hex: "#F0FFF0"},
    {name: "hotpink",               hex: "#FF69B4"},
    {name: "indianred",             hex: "#CD5C5C"},
    {name: "indigo",                hex: "#4B0082"},
    {name: "ivory",                 hex: "#FFFFF0"},
    {name: "khaki",                 hex: "#F0E68C"},
    {name: "lavender",              hex: "#E6E6FA"},
    {name: "lavenderblush",         hex: "#FFF0F5"},
    {name: "lawngreen",             hex: "#7CFC00"},
    {name: "lemonchiffon",          hex: "#FFFACD"},
    {name: "lightblue",             hex: "#ADD8E6"},
    {name: "lightcoral",            hex: "#F08080"},
    {name: "lightcyan",             hex: "#E0FFFF"},
    {name: "lightgoldenrodyellow",  hex: "#FAFAD2"},
    {name: "lightgray",             hex: "#D3D3D3"},
    {name: "lightgreen",            hex: "#90EE90"},
    {name: "lightpink",             hex: "#FFB6C1"},
    {name: "lightsalmon",           hex: "#FFA07A"},
    {name: "lightseagreen",         hex: "#20B2AA"},
    {name: "lightskyblue",          hex: "#87CEFA"},
    {name: "lightslategray",        hex: "#778899"},
    {name: "lightsteelblue",        hex: "#B0C4DE"},
    {name: "lightyellow",           hex: "#FFFFE0"},
    {name: "lime",                  hex: "#00FF00"},
    {name: "limegreen",             hex: "#32CD32"},
    {name: "linen",                 hex: "#FAF0E6"},
    {name: "magenta",               hex: "#FF00FF"},
    {name: "maroon",                hex: "#800000"},
    {name: "mediumaquamarine",      hex: "#66CDAA"},
    {name: "mediumblue",            hex: "#0000CD"},
    {name: "mediumorchid",          hex: "#BA55D3"},
    {name: "mediumpurple",          hex: "#9370DB"},
    {name: "mediumseagreen",        hex: "#3CB371"},
    {name: "mediumslateblue",       hex: "#7B68EE"},
    {name: "mediumspringgreen",     hex: "#00FA9A"},
    {name: "mediumturquoise",       hex: "#48D1CC"},
    {name: "mediumvioletred",       hex: "#C71585"},
    {name: "midnightblue",          hex: "#191970"},
    {name: "mintcream",             hex: "#F5FFFA"},
    {name: "mistyrose",             hex: "#FFE4E1"},
    {name: "moccasin",              hex: "#FFE4B5"},
    {name: "navajowhite",           hex: "#FFDEAD"},
    {name: "navy",                  hex: "#000080"},
    {name: "oldlace",               hex: "#FDF5E6"},
    {name: "olive",                 hex: "#808000"},
    {name: "olivedrab",             hex: "#6B8E23"},
    {name: "orange",                hex: "#FFA500"},
    {name: "orangered",             hex: "#FF4500"},
    {name: "orchid",                hex: "#DA70D6"},
    {name: "palegoldenrod",         hex: "#EEE8AA"},
    {name: "palegreen",             hex: "#98FB98"},
    {name: "paleturquoise",         hex: "#AFEEEE"},
    {name: "palevioletred",         hex: "#DB7093"},
    {name: "papayawhip",            hex: "#FFEFD5"},
    {name: "peachpuff",             hex: "#FFDAB9"},
    {name: "peru",                  hex: "#CD853F"},
    {name: "pink",                  hex: "#FFC0CB"},
    {name: "plum",                  hex: "#DDA0DD"},
    {name: "powderblue",            hex: "#B0E0E6"},
    {name: "purple",                hex: "#800080"},
    {name: "red",                   hex: "#FF0000"},
    {name: "rosybrown",             hex: "#BC8F8F"},
    {name: "royalblue",             hex: "#4169E1"},
    {name: "saddlebrown",           hex: "#8B4513"},
    {name: "salmon",                hex: "#FA8072"},
    {name: "sandybrown",            hex: "#F4A460"},
    {name: "seagreen",              hex: "#2E8B57"},
    {name: "seashell",              hex: "#FFF5EE"},
    {name: "sienna",                hex: "#A0522D"},
    {name: "silver",                hex: "#C0C0C0"},
    {name: "skyblue",               hex: "#87CEEB"},
    {name: "slateblue",             hex: "#6A5ACD"},
    {name: "slategray",             hex: "#708090"},
    {name: "snow",                  hex: "#FFFAFA"},
    {name: "springgreen",           hex: "#00FF7F"},
    {name: "steelblue",             hex: "#4682B4"},
    {name: "tan",                   hex: "#D2B48C"},
    {name: "teal",                  hex: "#008080"},
    {name: "thistle",               hex: "#D8BFD8"},
    {name: "tomato",                hex: "#FF6347"},
    {name: "turquoise",             hex: "#40E0D0"},
    {name: "violet",                hex: "#EE82EE"},
    {name: "wheat",                 hex: "#F5DEB3"},
    {name: "white",                 hex: "#FFFFFF"},
    {name: "whitesmoke",            hex: "#F5F5F5"},
    {name: "yellow",                hex: "#FFFF00"},
    {name: "yellowgreen",           hex: "#9ACD32"}
  ]

  # ----------------------------------------------------------------------------------------------------------------
  @getHexForColorName: (name)->
    value = if (c = _.find(Colors.customizationColors, (c)=>c.name is name))?
      c.hex
    else
      null

    value

  # ----------------------------------------------------------------------------------------------------------------
  @_convertPercentageToInteger16: (i)->
    Math.round(255 *(i/100))
  
  @_convertInteger16ToHex = (i)->
    h = i.toString(16)
    if h.length < 2
      h = "0#{h}"
    h

  # ------------
  
  @convertRGBInteger16ToHex: (r, g, b)->
    hex = "#"
    for i in [r, g, b]
      if (i >= 0) and (i <= 255)
        hex += "#{Colors._convertInteger16ToHex(i)}"
      else
        return [false, null, "color code \"#{i}\" is invalid, must be the range \"0\" through \"255\""]
       
    [true, hex, null]

  # ------------
  
  @convertRGBPercentageToHex: (r, g, b)->
  
    hex = "#"
    for p in [r, g, b]
      h = null
      if (p >= 0) and (p <= 100) and (i = Colors._convertPercentageToInteger16(p))? and (h = Colors._convertInteger16ToHex(i))?
        hex += "#{h}"
      else
        return [false, null, "color percentage \"#{p}\" is invalid, must be the range \"0%\" through \"100%\""]
       
    [true, hex, null]

  # ------------

  @validateHex: (hex)->

    if hex.length isnt 6
      return [false, null, "# must be followed by 6 color code characters"]

    for i in [0..5]
      h = hex.substr(i,1)
      if not h.match(/[a-f,A-F,0-9]/g)?
        return [false, null, "color code \"#{h}\" is invalid, must be the range \"a\" through \"f\" or \"0\" through \"9\""]

    [true, hex, null]

  # ----------------------------------------------------------------------------------------------------------------
  # 
  # Returns true if <elementName> - such as "background.color" or "bordercolor" - supports 
  # "transparent"
  # If not supported, also returns some helpful (says me) feedback for the user
  #
  @supportsTransparent: (elementName)->

    details = null

    yesElements = [ "bordercolor$", "background.color$" ]

    noElements = [
      {pattern: "^background.color$",     detail: "on global \"backgroundcolor\" setting"},
      {pattern: "page.background.color$", detail: "on page background"}
    ]

    n = elementName
    n.toLowerCase()

    supported = false

    for e in yesElements
      regex = new RegExp(e)

      if regex.test(n)
        supported = true

    if not supported
      return [false, details]

    # I suppose that if I were better at regular expressions, this might be simpler
    for e in noElements
      regex = new RegExp(e.pattern)

      if regex.test(n)
        return [false, e.detail]

    return [true, null]

  # ----------------------------------------------------------------------------------------------------------------
  @mapTransparent: (color = null, defaultColor = null)->

    c = if color?
      if color is "transparent" and defaultColor?
        defaultColor
      else
        color
    else
      defaultColor

  # ----------------------------------------------------------------------------------------------------------------

# ==================================================================================================================
class Application

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()->
    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@backgroundWindow = null, @tempImage = null)->
    Hy.Trace.info "Application::constructor"

    gInstance = this

    @page = null

    @argURL = null

    Ti.App.addEventListener('close', 
                            (evt)=>
                               this.exit(evt)
                               null)

    if Hy.Config.Version.isiOS4Plus()
      Ti.App.addEventListener('resume', 
                              (evt)=>
                                this.resume(evt)
                                null)
      Ti.App.addEventListener('resumed', 
                              (evt)=>
                                this.resumed(evt)
                                null)
      Ti.App.addEventListener('pause', 
                              (evt)=>
                                this.pause(evt)
                                null)

    Ti.App.idleTimerDisabled = true

    this

  # ----------------------------------------------------------------------------------------------------------------
  getBackgroundWindow: ()-> @backgroundWindow

  # ----------------------------------------------------------------------------------------------------------------
  setBackground: (background)->

     this.getBackgroundWindow().backgroundImage = background

     if @tempImage? # 2.5.0
       this.getBackgroundWindow().remove(@tempImage)
       @tempImage = null

     this
    
  # ----------------------------------------------------------------------------------------------------------------
  getMajorVersion: ()-> Hy.Config.Version.Console.kConsoleMajorVersion

  # ----------------------------------------------------------------------------------------------------------------
  getMinorVersion: ()-> Hy.Config.Version.Console.kConsoleMinorVersion

  # ----------------------------------------------------------------------------------------------------------------
  getVersionString: ()->
    this.getMajorVersion() + "." + this.getMinorVersion()

  # ----------------------------------------------------------------------------------------------------------------
  init: ()->
    Hy.Trace.info "Application::init"

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    Hy.Trace.info "Application::run"

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: (evt)->
    Hy.Trace.info "Application::pause (ENTER)"

    Hy.Utils.DeferralBase.cleanup()

    Hy.Trace.info "Application::pause (EXIT)"
    this

  # ----------------------------------------------------------------------------------------------------------------
  exit: (evt)->
    Hy.Trace.info "Application::exit"

    this

  # ----------------------------------------------------------------------------------------------------------------
  resume: (evt)->
    Hy.Trace.info "Application::resume"

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: (evt)->
    Hy.Trace.info "Application::resumed"

    Hy.Utils.DeferralBase.cleanup()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getPage: ()-> @page

  # ----------------------------------------------------------------------------------------------------------------
  setPage: (page)-> @page = page

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (evt)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  checkURLArg: ()->

    args = Ti.App.getArguments()

    hasChanged = if (url = args.url)?
      if @argURL?
        if @argURL is url
          false
        else
          true
      else
        true

    @argURL = url

    if hasChanged then @argURL else null

# ==================================================================================================================
Hyperbotic.UI =
  Colors: Colors
  Application: Application
  Fonts: Fonts
  Device: Device
  iPad: iPad
  Backgrounds: Backgrounds



 