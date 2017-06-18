# ==================================================================================================================
class Metric

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@name)->
    @value = null
    @init = false
    this

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()->
    @name

  # ----------------------------------------------------------------------------------------------------------------
  getDBName: ()->
    Hy.Config.Analytics.Namespace + "." + this.getName()

  # ----------------------------------------------------------------------------------------------------------------
  getValue: ()->
    Hy.Trace.debug "Metric::getValue ERROR UNIMPLEMENTED #{this.getName()}"
    null

  # ----------------------------------------------------------------------------------------------------------------
  setValue: ()->
    Hy.Trace.debug "Metric::setValue ERROR UNIMPLEMENTED #{this.getName()}"
    null

  # ----------------------------------------------------------------------------------------------------------------
  clear: ()->
    Hy.Trace.debug "Metric::setValue ERROR UNIMPLEMENTED #{this.getName()}"
    null
  
  # ----------------------------------------------------------------------------------------------------------------
  dump: ()->
    Hy.Trace.debug "Metric::dump (name=#{this.getName()}, value=#{this.getValue()})"
    this

# ==================================================================================================================
class MetricInt extends Metric

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@name)->
    super
    this.getValue()
    this

  # ----------------------------------------------------------------------------------------------------------------
  getValue: ()->

    if @init
    else
      @init = true

      if (v = Ti.App.Properties.getInt(this.getDBName()))?
        @value = v
      else
        @value = 0

    @value

  # ----------------------------------------------------------------------------------------------------------------
  setValue: (v)->
    if v != @value
#      Hy.Trace.debug "MetricInt::setValue (Name=#{this.getName()} #{this.getDBName()} Value=#{v})"
      @value = v
      Ti.App.Properties.setInt(this.getDBName(), v)
    @init = true
    @value

  # ----------------------------------------------------------------------------------------------------------------
  clear: ()->
    this.setValue 0
    null

# ==================================================================================================================
class MetricString extends Metric
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@name)->
    super
    this.getValue()

  # ----------------------------------------------------------------------------------------------------------------
  getValue: ()->

    if @init
    else
      @init = true

      if (v = Ti.App.Properties.getString(this.getDBName()))?
        @value = v
      else
        @value = ""

    @value

  # ----------------------------------------------------------------------------------------------------------------
  setValue: (v)->
    if v != @value
      @value = v
      Ti.App.Properties.setString(this.getDBName(), v)
    @init = true
    @value

  # ----------------------------------------------------------------------------------------------------------------
  clear: ()->
    this.setValue ""
    null

# ==================================================================================================================
class Analytics

  kString = 1
  kInt = 2

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @init: ()->

    if not gInstance?
      if Hy.Config.Analytics.active
        gInstance = new Analytics()

    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    @eventCategory = "TriviallyConsole-#{Hy.Config.Analytics.Version}"

    @metrics = []

#    this.dump()

    @google = new GoogleAnalytics(this, @eventCategory)
    this

  # ----------------------------------------------------------------------------------------------------------------
  dump: ()->
    for m in @metrics
      m.dump()
    this

  # ----------------------------------------------------------------------------------------------------------------
  @dumpStats: ()->
    Hy.ConsoleApp.get()?.analytics?.dump()

  # ----------------------------------------------------------------------------------------------------------------
  createMetric: (name, kind)->
    
    @metrics.push(m = new kind(name))

    m

  # ----------------------------------------------------------------------------------------------------------------
  findMetricByName: (name)->
    _.detect(@metrics, (m)=>m.name is name)

  # ----------------------------------------------------------------------------------------------------------------
  # Will create it if necessary
  getMetric: (name, kind)->

    if not (m = this.findMetricByName(name))?
      m = this.createMetric(name, kind)      

    m

  # ----------------------------------------------------------------------------------------------------------------
  clearMetricByName: (name)->
#    Hy.Trace.info "Analytics::clearMetricByName (name=#{name})"

    for m in @metrics
      if m.name is name
        m.clear()
        return null
          
    null

  # ----------------------------------------------------------------------------------------------------------------
  log: (name, kind, label, value, clearAfterSend = true)->

    @google.send(name, label, value, ((e, status)=>if status and clearAfterSend then this.clearMetricByName(name) else null))

    this

  # ----------------------------------------------------------------------------------------------------------------
  logIncremental: (name, kind, increment = 1)->

    m = this.getMetric(name, kind)

    value = m.getValue() + increment

    m.setValue(value)

    this.log(name, kind, "", value)

    this

  # ----------------------------------------------------------------------------------------------------------------
  logContentUpdate: ()->
    this.logIncremental("numContentUpdate", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logContentUpdateFailure: ()->
    this.logIncremental("numContentUpdateFailure", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logContentUpdateRequired: ()->
    this.logIncremental("numContentUpdateRequired", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logContentUpdateSuggested: ()->
    this.logIncremental("numContentUpdateSuggested", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logContentUpdateSuggestedIgnored: ()->
    this.logIncremental("numContentUpdateSuggestedIgnored", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logConsoleAppUpdate: ()->
    this.logIncremental("numConsoleAppUpdate", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logConsoleAppUpdateRequired: ()->
    this.logIncremental("numConsoleAppUpdateRequired", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logConsoleAppUpdateSuggested: ()->
    this.logIncremental("numConsoleAppUpdateSuggested", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logConsoleAppUpdateSuggestedIgnored: ()->
    this.logIncremental("numConsoleAppUpdateSuggestedIgnored", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logConsoleAppUpdateLaunched: ()->
    this.logIncremental("numConsoleAppUpdateLaunched", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logRateAppReminderIgnored: ()->
    this.logIncremental("numlogRateAppReminderIgnored", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logRateAppReminderPostponed: ()->
    this.logIncremental("numlogRateAppReminderPostponed", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logRateAppReminderDeclined: ()->
    this.logIncremental("numlogRateAppReminderDeclined", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logRateAppReminderAccepted: ()->
    this.logIncremental("numlogRateAppReminderAccepted", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logPurchaseStart: (kind)->
    this.logIncremental("numContentPackPurchaseStarted-#{kind}", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logPurchaseCompleted: (kind)->
    this.logIncremental("numContentPackPurchaseCompleted-#{kind}", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logPurchaseFailed: (kind)->
    this.logIncremental("numContentPackPurchaseFailed-#{kind}", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logRestoreStart: ()->
    this.logIncremental("numRestoreStart", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logRestoreCompleted: ()->
    this.logIncremental("numRestoreCompleted", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logRestoreFailed: ()->
    this.logIncremental("numRestoreFailed", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logContentPackPurchaseDownloadCompleted: ()->
    this.logIncremental("numContentPackPurchaseCompleted", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logContentPackPurchaseDownloadFailed: ()->
    this.logIncremental("numContentPackPurchaseFailed", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logURLClick: ()->
    this.logIncremental("numURLClick", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logApplicationLaunch: ()->

    this.logIncremental("numLaunch", MetricInt)
    this.logIncremental("applicationVersion-#{Hy.Config.Version.Console.kConsoleMajorVersion}.#{Hy.Config.Version.Console.kConsoleMinorVersion}.#{Hy.Config.Version.Console.kConsoleMinor2Version}", MetricInt)
    this.logIncremental("deviceInfo-#{Ti.Platform.osname}-#{Ti.Platform.version}", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logContestStart: ()->

    this.logIncremental("numStart", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logContestEnd: (completed, numQuestions, numAnswers, topics, numUserCreatedQuestions)->

    if completed
      this.logIncremental("numComplete", MetricInt)
    else
      this.logIncremental("numInterrupted", MetricInt)

    this.logIncremental("numQuestions", MetricInt, numQuestions)
    this.logIncremental("numAnswers", MetricInt, numAnswers)

    this.logIncremental("numQuestionsUserCreated", MetricInt, numUserCreatedQuestions)

    topicCounter = {}
    for topic in topics
      if topicCounter[topic]?
        topicCounter[topic] += 1
      else
        topicCounter[topic] = 1

    for topic, count of topicCounter
      this.logIncremental("topic_#{topic}", MetricInt, count)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Keep track of number of simultaneous players, and log the maximum
  logNewPlayer2: (playerNum)-> 
#    Hy.Trace.info "Analytics::logNewPlayer (playerNum=#{playerNum})"

    mMNP = this.getMetric("maxNumPlayer", MetricInt)

    if playerNum > (loggedMaxNumPlayer = mMNP.getValue())
#       Hy.Trace.info "Analytics::logNewPlayer (Previous=#{loggedMaxNumPlayer} New=#{playerNum})"
      loggedMaxNumPlayer = mMNP.setValue(playerNum)

      this.log("maxNumPlayer", MetricInt, loggedMaxNumPlayer, 1, false)

    loggedMaxNumPlayer

  # ----------------------------------------------------------------------------------------------------------------
  # Keep track of number of simultaneous players, and log the maximum
  logNewPlayer: (playerNum)-> 

    this.logIncremental("numSimultaneousPlayers_#{playerNum}", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  # UCC Operations
  logUCCAddSuccess: ()-> 

    this.logIncremental("UCC_AddSuccess", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logUCCAddFailure: ()-> 

    this.logIncremental("UCC_AddFailure", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logUCCRefreshSuccess: ()-> 

    this.logIncremental("UCC_RefreshSuccess", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logUCCRefreshFailure: ()-> 

    this.logIncremental("UCC_RefreshFailure", MetricInt)

  # ----------------------------------------------------------------------------------------------------------------
  logFatalError: (message)-> 

    s = message.replace(/\s/g, "_")
    v = "#{Hy.Config.Version.Console.kConsoleMajorVersion}.#{Hy.Config.Version.Console.kConsoleMinorVersion}.#{Hy.Config.Version.Console.kConsoleMinor2Version}"
    this.logIncremental("FatalError__#{v}_#{s}", MetricInt)


# ==================================================================================================================
# Borrowing from sample code by Roger Chapman, via "Titanium Mobile Google Analytics Example Project"

class GoogleAnalyticsEvent extends Hy.Network.HTTPEvent

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@google, @eventCategory, @eventAction, @eventLabel, @eventValue)->
#    Hy.Trace.debug "GoogleAnalyticsEvent::constructor (eventAction=#{@eventAction} eventLabel=#{@eventLabel} eventValue=#{@eventValue})"

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  dump: ()->
    return "#=#{@instanceCount} eventAction=#{@eventAction} eventLabel=#{@eventLabel} eventValue=#{@eventValue} state=#{@state}"  

  # ----------------------------------------------------------------------------------------------------------------
  getArgs: ()->
#    Hy.Trace.debug "GoogleAnalyticsEvent::getArgs (eventAction=#{@eventAction} eventLabel=#{@eventLabel} eventValue=#{@eventValue})"

    random_val = 1

    arg = "/__utm.gif"
    arg += "?utmwv=4.4mi"
    arg += "&utmn=#{random_val}"
    arg += "&utmcs=UTF-8"
    arg += "&utmsr=" + Ti.Platform.displayCaps.platformWidth + "x" + Ti.Platform.displayCaps.platformHeight
    arg += "&utmsc=24-bit"
    arg += "&utmul="+ Ti.Platform.locale + "-" + Ti.Platform.countryCode
    arg += "&utmac=#{Hy.Config.Analytics.Google.accountID}"
		
    arg += "&utmt=event"
    arg += "&utme=5(#{@eventCategory}*#{@eventAction}"

    if @eventLabel?
      arg += "*#{@eventLabel})"
    else
      arg += "*)"

    if @eventValue?
      arg += "(#{@eventValue})"
		
    arg += "&utmcc="
		
    arg

  # ---------------------------------------------------------------------------------------------------------------- 
  getURL: ()->
    'http://www.google-analytics.com' + this.getArgs() + "&" + @google.getCookie()

  # ---------------------------------------------------------------------------------------------------------------- 
  getUAS: ()->
    @google.getUserAgentString()

# ==================================================================================================================
class GoogleAnalytics

  # ---------------------------------------------------------------------------------------------------------------- 
 constructor: (@analytics, @eventCategory)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  send: (eventAction, eventLabel, eventValue, fn)->
#    Hy.Trace.debug "GoogleAnalytics::send (Start)"

    event = new GoogleAnalyticsEvent(this, @eventCategory, eventAction, eventLabel, eventValue)
    event.setFnPost(fn)

    if not event.enqueue()
      Hy.Trace.debug "GoogleAnalytics::send (ERROR could not enqueue event)"

    event

  # ----------------------------------------------------------------------------------------------------------------
  getSession: ()->
    now = Math.round(new Date().getTime() / 1000)

    m = @analytics.getMetric("GoogleSession", MetricString)
    s = m.getValue()
    if s is ""
      session = {
        user_id:Math.floor(Math.random()*9999999999),
        timestamp_first:now,
        timestamp_previous:now,
        timestamp_current:now,
        visits:1 }
    else
#      Hy.Trace.debug "GoogleAnalytics::getSession (Old Session=#{s})"
      oldSession = JSON.parse(s)

      session = {
        user_id:oldSession.user_id,
        timestamp_first:oldSession.timestamp_first,
        timestamp_previous:oldSession.timestamp_current,
        timestamp_current:now,
        visits:oldSession.visits + 1 }

    s = m.setValue JSON.stringify(session)
#    Hy.Trace.debug "GoogleAnalytics::getSession (New Session=#{s})"

    session

  # ----------------------------------------------------------------------------------------------------------------
  getCookie: ()->
    session = this.getSession()

    cookie = "__utma="
    cookie += "737325" + "."
    cookie += "#{session.user_id}."
    cookie += "#{session.timestamp_first}."
    cookie += "#{session.timestamp_previous}."
    cookie += "#{session.timestamp_current}."
    cookie += "#{session.visits}"

    cookie

  # ----------------------------------------------------------------------------------------------------------------
  getUserAgentString: ()->
    "Analytics/1.0 ("+ "Titanium" +"; U; CPU "+ Ti.Platform.name + " " + Ti.Platform.version + " like Mac OS X; " + Ti.Platform.locale + "-" + Ti.Platform.countryCode + ")"

# ==================================================================================================================
# assign to global namespace:
Hy.Analytics =
  Analytics: Analytics
