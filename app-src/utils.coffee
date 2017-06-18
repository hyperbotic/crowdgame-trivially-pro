# ==================================================================================================================
class MathUtils
  # ----------------------------------------------------------------------------------------------------------------
  @random: (n)-> Math.floor(Math.random()*n)

class UUID

  # ----------------------------------------------------------------------------------------------------------------
  @generate: ()->
    Hy.uuid() # Defined in "Resources/uuid.js"

# ==================================================================================================================
class ArrayUtils
  # ----------------------------------------------------------------------------------------------------------------
  @shuffle: (xs)->
    # Fisher-Yates algorithm:
    i = xs.length;
    return xs if i is 0

    while --i
      j = MathUtils.random i+1
      tmp = xs[j]
      xs[j] = xs[i]
      xs[i] = tmp
    return xs

  # ----------------------------------------------------------------------------------------------------------------
  @inject: (xs, seed, fn)->
    r = seed
    for x in xs
      r = fn r, x
    r

# ==================================================================================================================
Array::each = (fn)->
  for item in this
    fn(item)
  null
Array::inject = (seed, fn)->ArrayUtils.inject(this, seed, fn)
Array::sum = ()->this.inject(0, (acc, item)->acc+item)
Array::product = ()->this.inject(1, (acc, item)->acc*item)
Array::map = (fn)-> fn(item) for item in this


# ==================================================================================================================
class HashUtils
  @clone: (source)->HashUtils.merge {}, source
  @merge: (destination, source)->
    destination[property] = value for property, value of source
    destination


# ==================================================================================================================
class DateUtils
  toDoubleDigit = (val)->
    if val < 10 then "0#{val}" else val

  # ----------------------------------------------------------------------------------------------------------------
  @now: ()->
    d = new Date()

    yr = d.getFullYear()
    mo = toDoubleDigit d.getMonth()
    dy = toDoubleDigit d.getDay()
    
    hrs = toDoubleDigit d.getHours()
    min = toDoubleDigit d.getMinutes()
    sec = toDoubleDigit d.getSeconds()
    msec = d.getMilliseconds()
    
    "#{yr}-#{mo}-#{dy} #{hrs}:#{min}:#{sec}.#{msec}"


# ==================================================================================================================
Observable =
  # ----------------------------------------------------------------------------------------------------------------
  addObserver: (observer) ->
#    Hy.Trace.debug "Observable::addObserver"
    @observers ||= []
    @observers.push observer
    this

  # ----------------------------------------------------------------------------------------------------------------
  removeObserver: (observer)->
#    Hy.Trace.debug "Observable::removeObserver (ENTER)"
    @observers ||= []
    @observers = _.reject @observers, (item)->item is observer
    this

  # ----------------------------------------------------------------------------------------------------------------
  notifyObservers: (fnNotify)->
#    Hy.Trace.debug "Observable::notifyObservers"
    @observers ||= []
    for observer in @observers
      fnNotify observer
    this


# ==================================================================================================================
Eventable =
  # ----------------------------------------------------------------------------------------------------------------
  addEventListener: (name, fn) ->
#    Hy.Trace.debug "Eventable::addEventListener"
    @listeners ||= {}
    @listeners[name] ||= []
    @listeners[name].push fn
    this

  # ----------------------------------------------------------------------------------------------------------------
  removeEventListener: (name, fn)->
#    Hy.Trace.debug "Eventable::removeEventListener"
    @listeners ||= {}
    return unless @listeners[name]?
    @listeners[name] = _.reject @listeners[name], (fn1)=>fn1 is fn
    this

  # ----------------------------------------------------------------------------------------------------------------
  removeAllEventListeners: (name)->
#    Hy.Trace.debug "Eventable::removeAllEventListeners"
    @listeners ||= {}
    return unless @listeners[name]?
    @listeners[name] = []
    this

  # ----------------------------------------------------------------------------------------------------------------
  fireEvent: (name, event)->
#    Hy.Trace.debug "Eventable::fireEvent"
    @listeners ||= {}
    return unless @listeners[name]?
    fn(event) for fn in @listeners[name]
    this


# ==================================================================================================================
Iterable =
  # ----------------------------------------------------------------------------------------------------------------
  count: ()->this.collection().length

  # ----------------------------------------------------------------------------------------------------------------
  map: (fn)->fn(item) for item in this.collection()

  # ----------------------------------------------------------------------------------------------------------------
  each: (fn)->
    for item in this.collection()
      fn(item)
    this


# ==================================================================================================================
class DeferralBase
  gInstanceCount = 0
  gInstances = []

  kStatusNull      = 0
  kStatusEnqeueued = 1
  kStatusTriggered = 2
  kStatusCleared   = 3

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@delay, @fn)->
    if not @delay?
      @delay = 0

    @status = kStatusNull
    @instance = ++gInstanceCount
    fnWrapper = ()=>this.trigger()
    @handle = setTimeout fnWrapper, @delay
    @status = kStatusEnqeueued
    Deferral.add(this)
    this

  # ----------------------------------------------------------------------------------------------------------------
  @cleanup: ()->
    for instance in gInstances
      instance?.cleanup() # a little more defensive...
    null

  # ----------------------------------------------------------------------------------------------------------------
  @add: (instance)->
    gInstances.push(instance)
    null

  # ----------------------------------------------------------------------------------------------------------------
  @remove: (instance)->
    gInstances = _.without(gInstances, instance)
    null

  # ----------------------------------------------------------------------------------------------------------------
  # Instance Methods:
  # ----------------------------------------------------------------------------------------------------------------
  trigger: ()->
    return null if @status is kStatusCleared
    @status = kStatusTriggered
    @fn?()
    @handle = null
    Deferral.remove(this)
    null

  # ----------------------------------------------------------------------------------------------------------------
  clear: ()->
    return null if @status is kStatusTriggered
    @status = kStatusCleared
    clearTimeout(@handle) if @handle?
    @handle = null
    Deferral.remove(this)
    null

  # ----------------------------------------------------------------------------------------------------------------
  enqueued: ()->
    @status is kStatusEnqeueued

  # ----------------------------------------------------------------------------------------------------------------
  triggered: ()->
    @status is kStatusTriggered

  # ----------------------------------------------------------------------------------------------------------------
  cleared: ()->
    @status is kStatusCleared

# ==================================================================================================================
class Deferral extends DeferralBase

  # ----------------------------------------------------------------------------------------------------------------
  @create: (delay, fn)->
    new Deferral(delay, fn)

  # ----------------------------------------------------------------------------------------------------------------
  cleanup: ()->
    this.clear()

# ==================================================================================================================
class PersistentDeferral extends DeferralBase

  # ----------------------------------------------------------------------------------------------------------------
  @create: (delay, fn)->
    new PersistentDeferral(delay, fn)

  # ----------------------------------------------------------------------------------------------------------------
  cleanup: ()->
    null

# ==================================================================================================================
# Shake to turn on debugging, and shake again to send the log
class HiddenChord

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @init: (app, fn, arr)->

    if not gInstance?
      gInstance = new Hy.Utils.HiddenChord(app, fn, arr)

    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@app, @action, @chordPattern)->
    this.reset()
    Ti.Gesture.addEventListener 'shake', (evt)=>this.logGesture()
    this

  # ----------------------------------------------------------------------------------------------------------------
  reset: ()->
    @chordCount = -1
    this

  # ----------------------------------------------------------------------------------------------------------------
  timerStart: ()->
    Hy.Trace.debug "HiddenChord::timerStart"
    @chordTimer = (new Date()).getTime()
    this

  # ----------------------------------------------------------------------------------------------------------------
  timerDiff: ()->
    return ((new Date().getTime())-@chordTimer)

  # ----------------------------------------------------------------------------------------------------------------
  inProgress: ()->
    return @chordCount != -1

  # ----------------------------------------------------------------------------------------------------------------
  timerIsExpired: ()->
    return this.timerDiff() > (30*1000)

  # ----------------------------------------------------------------------------------------------------------------
  gestureIsMatch: ()->
    return Ti.Gesture.orientation is @chordPattern[@chordCount+1]

  # ----------------------------------------------------------------------------------------------------------------
  prepareForNextGesture: ->
    @chordCount++
    return @chordCount is (@chordPattern.length-1)

  # ----------------------------------------------------------------------------------------------------------------
  orientationName: (o)->
    return switch o
      when Titanium.UI.PORTRAIT then 'portrait'
      when Titanium.UI.UPSIDE_PORTRAIT then 'upside portrait'
      when Titanium.UI.LANDSCAPE_LEFT then 'landscape left'
      when Titanium.UI.LANDSCAPE_RIGHT then 'landscape right'
      when Titanium.UI.FACE_UP then 'face up'
      when Titanium.UI.FACE_DOWN then 'face down'
      when Titanium.UI.UNKNOWN then 'unknown'
      else '?'

  # ----------------------------------------------------------------------------------------------------------------
  logGesture: ()->
    Hy.Trace.debug "HiddenChord::logGesture (#=#{@chordCount} current=#{this.orientationName Ti.Gesture.orientation} looking for #{this.orientationName @chordPattern[@chordCount+1]} timer=#{this.timerDiff()}"

    if this.inProgress() and this.timerIsExpired()
#      Hy.Trace.debug "HiddenChord::logGesture - Timeout"
      this.reset()

    if this.gestureIsMatch()
#      Hy.Trace.debug "HiddenChord::logGesture - Match"

      Hy.Media.SoundManager.get().playEvent("hiddenChord")

      this.timerStart() unless this.inProgress()      

      if this.prepareForNextGesture()
#        Hy.Trace.debug "HiddenChord::logGesture - Chord Completed"
        @action()
        this.reset()
        true
    
    false

# ==================================================================================================================
class MemInfo

  gInitialized = false

  # ----------------------------------------------------------------------------------------------------------------
  @init: ()->

    if not gInitialized
      if Hy.Config.Trace.memoryLogging
        setInterval((()=>MemInfo.log()), 1 * 1000)
      gInitialized = true

    null

  # ----------------------------------------------------------------------------------------------------------------
  @log: (op=null)->
    Hy.Trace.debug "MemInfo (#{MemInfo.info()} #{if op? then op else ""})", true

  @info: ()->
    "Memory*#{Ti.Platform.availableMemory}*"

# ==================================================================================================================
class TimedOperation
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@label = null)->
    Hy.Trace.debug "TimedOperation Start=#{@label}"

    this.reset()

    @updateString = ""

    this

  # ----------------------------------------------------------------------------------------------------------------
  reset: ()->

    @startTime = (new Date()).getTime()

    this
    
  # ----------------------------------------------------------------------------------------------------------------
  mark: (comment)->

    @updateString += "/ #{comment}"

    Hy.Trace.debug "TimedOperation Time=#{this.getDelta()} End=#{@label} #{@updateString}"

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDelta: ()->

    ((new Date()).getTime()) - @startTime

# ==================================================================================================================
class ErrorMessage
  _.extend ErrorMessage, Eventable
  _.extend ErrorMessage, Iterable

  gMessages = []

  # ----------------------------------------------------------------------------------------------------------------
  # Constructor:
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@category, @code, @msg)->
    Hy.Trace.debug "ErrorMessage::constructor(category => #{@category}, code => #{@code}, msg => #{@msg})", true
    @createdAt = new Date()
    gMessages.push(this)
    gMessages = gMessages.reverse()

    @constructor.fireEvent 'created', {source: this}

    m = "Sorry, #{Hy.Config.DisplayName} has a problem"

    if @category is "fatal"
      m += " and must be restarted"

    m += ".\nPlease report this to\n#{Hy.Config.Support.email}\n\n#{@code}\n#{@msg}"

    Hy.ConsoleApp.get().analytics?.logFatalError(@msg)
    dialog = new Hy.UI.AlertDialog({message: m})

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Class Methods:
  # ----------------------------------------------------------------------------------------------------------------
  @collection: ()->gMessages

# ==================================================================================================================
# Parse a CSV string into an array of rows, each row an array of "cells"
#
# With thanks to:
# http://bennolan.com/2011/10/24/csv-parser.html
#
class CSVParser

  kRAW = 1
  kESC = 2

  # ----------------------------------------------------------------------------------------------------------------
  # If maxNumRows is specified, and exceeded, will throw "TooManyRows"
  #
  @parse: (raw, maxNumRows = null)->

    rows = []
    row = []
    cell = ""

    offset = 0

    mode = kRAW

    fnAddChar = ()=>
      cell += ch

    fnAddCell = ()=>
      row.push cell
      cell = ""

    fnAddRow = ()=>
      if maxNumRows? and rows.length is maxNumRows
        throw TooManyRows
    
      rows.push row
      row = []

    while offset < raw.length
      ch = raw.charAt(offset)
      adjacent = raw.charAt(offset+1)

      switch mode
        when kRAW
          switch ch
            when ","
              fnAddCell()
            when "\r", "\n"
              fnAddCell()
              fnAddRow()
            when "\""
              mode = kESC
            else
              fnAddChar()

        when kESC
          switch ch
            when  "\""
              if adjacent == "\""
                fnAddChar()
                offset += 1
              else
                mode = kRAW
            when "\n", "\r" # Disallow embedded linefeeds, etc
              null
            else
              fnAddChar()
    
      offset += 1

    if cell isnt ""
      fnAddCell()
      fnAddRow()

    rows

# ==================================================================================================================
# Who uses Tab separated value files?
#
class TSVParser

  # ----------------------------------------------------------------------------------------------------------------
  @parse: (raw)->

    results = []
    stringSoFar = ""
    line = []

    fnAddToken = ()=>
      line.push stringSoFar
      stringSoFar = ""

    fnAddLine = ()=>
      results.push line
      line = []

    fnAddChar = (c)=>
      stringSoFar += c

    for i in [0..raw.length-1]
      switch (c = raw[i])
        when "\t"
          fnAddToken()
        when "\n"
          fnAddToken()
          fnAddLine()
        else
          fnAddChar(c)

    if stringSoFar isnt ""
      fnAddToken()
      fnAddLine()

    results

# ==================================================================================================================
class String

  @trimWithElipsis: (s, maxLength)->

    if s.length > maxLength
      "#{s.substr(0, maxLength - 3)}..."
    else
      s

  # ----------------------------------------------------------------------------------------------------------------
  @replaceTokens: (text, context)->
    if (t = text)? and context?
      for n, v of context
        s = "#" + "{" + n + "}"
        t = t.replace(s, v)
    t

# ==================================================================================================================
# assign to global namespace:
Hy.Utils =
  Math: MathUtils
  Array: ArrayUtils
  Hash: HashUtils
  Date: DateUtils
  Observable: Observable
  Eventable: Eventable
  Iterable: Iterable
  DeferralBase: DeferralBase
  Deferral: Deferral
  PersistentDeferral: PersistentDeferral
  HiddenChord: HiddenChord
  MemInfo: MemInfo
  TimedOperation: TimedOperation
  UUID: UUID
  ErrorMessage: ErrorMessage
  CSVParser: CSVParser
  TSVParser: TSVParser
  String: String






