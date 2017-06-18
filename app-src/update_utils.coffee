# ==================================================================================================================
class CheckForUpdatesEvent extends Hy.Network.HTTPEvent

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->
    super

    this

# ==================================================================================================================
class UpdateService

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @init: ()->
    UpdateService.get()
  
  # ----------------------------------------------------------------------------------------------------------------
  @get: ()->
    if not gInstance?
      gInstance = new UpdateService()

    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->
    Hy.Trace.debug "UpdateService::constructor"

    @updateCheckInProgress = false
    @event = null
    @subsequentEvent = null

    this.scheduleUpdate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  scheduleUpdate: ()->

    url = Hy.Config.Update.kUpdateBaseURL + "/" + Hy.Config.Update.kUpdateFilename

    f = (e, status)=>
      Hy.Trace.debug "UpdateServices::checkForUpdate (callback status=#{status})"
      if status
        this.processUpdate(e)
      else
        s = "Couldn\'t load config file: #{url} (#{@event.getTimeSinceSent()} #{e.getErrorInfo()})"
        new Hy.Utils.ErrorMessage("fatal", "UpdateService::scheduleUpdate", s)

      return null

    @event = new CheckForUpdatesEvent()
    @event.setFnPost(f)
    @event.setURL url

    @event.setSendLimit(-1) # No Limit to the number of times it should be sent
    @event.setInitialDelay(0)
    @event.setRecurringDelay(Hy.Config.Update.kUpdateCheckInterval) # Wait this many milliseconds before each send

    ok = false
    if @event.enqueue()
      ok = true
    else
      Hy.Trace.debug "UpdateServices::checkForUpdate (ERROR could not enqueue event)"

    return ok

  # ----------------------------------------------------------------------------------------------------------------
  processUpdate: (e)->

    response = e.responseText
    numDirectives = 0

    Hy.Trace.debug "UpdateService::processUpdate (response=#{response.length} chars)"

    if @updateCheckInProgress
      Hy.Trace.debug "UpdateService::processUpdate (ERROR UPDATE IN PROGRESS)"
      return

    @updateCheckInProgress = true

    try
      directives = JSON.parse response
    catch e
      s = "ERROR parsing update manifest"
      new Hy.Utils.ErrorMessage("fatal", "UpdateServices::processUpdate", s) #will display popup dialog
      return false

    Update.clearAll()

    for directive in directives
      if Update.processDirective(directive)?
        numDirectives++

    Hy.Trace.debug "UpdateService::processUpdate (#directives=#{numDirectives})"

    @updateCheckInProgress = false

    true

# ==================================================================================================================
# Parent class of all update classes, representing available updates
class Update

  _.extend Update, Hy.Utils.Observable

  gUpdates = []

  @kNewsUpdateDirectiveName            = "news"
  @kContentManifestUpdateDirectiveName = "content_manifest_update"
  @kConsoleAppUpdateDirectiveName      = "app_update_console"
  @kFlagUpdateDirectiveName            = "flag_update"
  @kRateAppReminderDirectiveName       = "rate_app_reminder"
  @kSamplesUpdateDirectiveName         = "samples_update"

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directive)->

    @type = directive.type
    @id = directive.id
    @date = directive.date
    @display = directive.display

    gUpdates[@id] = this 

    @required = directive.required? and directive.required is "true"
    @popover = directive.popover
    @reminderInterval = if isNaN(directive.remind_interval) then null else directive.remind_interval # time in minutes

    this.resetReminderTimer()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getType: ()->@type

  # ----------------------------------------------------------------------------------------------------------------
  isNews: ()-> @type is Update.kNewsUpdateDirectiveName

  # ----------------------------------------------------------------------------------------------------------------
  isContentManifestUpdate: ()-> 
    @type is Update.kContentManifestUpdateDirectiveName

  # ----------------------------------------------------------------------------------------------------------------
  isConsoleAppUpdate: ()-> @type is Update.kConsoleAppUpdateDirectiveName

  # ----------------------------------------------------------------------------------------------------------------
  isFlagUpdate: ()-> @type is Update.kFlagUpdateDirectiveName

  # ----------------------------------------------------------------------------------------------------------------
  isRateAppReminder: ()-> @type is Update.kRateAppReminderDirectiveName

  # ----------------------------------------------------------------------------------------------------------------
  isSamplesUpdate: ()-> @type is Update.kSamplesUpdateDirectiveName

  # ----------------------------------------------------------------------------------------------------------------
  getFriendlyType: ()->
    return switch @type
      when Update.kNewsUpdateDirectiveName
        "News"
      when Update.kContentManifestUpdateDirectiveName
        "Content Manifest"
      when Update.kConsoleAppUpdateDirectiveName
        "Console App"
      when Update.kFlagUpdateDirectiveName
        "Flag Update"
      when Update.kRateAppReminderDirectiveName
        "Rate App Reminder"
      when Update.kSamplesUpdateDirectiveName
        "Samples Update"
      else
        "?"

  # ----------------------------------------------------------------------------------------------------------------
  getID: ()->@id

  # ----------------------------------------------------------------------------------------------------------------
  getDate: ()->@date

  # ----------------------------------------------------------------------------------------------------------------
  getDisplay: ()->@display

  # ----------------------------------------------------------------------------------------------------------------
  getDumpString: ()->
    "id=#{@id} type=#{@type} display=#{@display}"

  # ----------------------------------------------------------------------------------------------------------------
  dump: ()->
    Hy.Trace.debug "Update::dump (#{this.getDumpString()})"
    this

  # ----------------------------------------------------------------------------------------------------------------
  isRequired: ()-> @required

  # ----------------------------------------------------------------------------------------------------------------
  shouldRemind: ()->
  
    this.isTimeToRemind()

  # ----------------------------------------------------------------------------------------------------------------
  isPopover: ()-> @popover?

  # ----------------------------------------------------------------------------------------------------------------
  getPopover: ()-> @popover

  # ----------------------------------------------------------------------------------------------------------------
  # ----------------------------------------------------------------------------------------------------------------
  resetReminderTimer: ()->

    @lastReminderTime = new Hy.Utils.TimedOperation()

    this

  # ----------------------------------------------------------------------------------------------------------------
  isTimeToRemind: ()->

    @reminderInterval? and @lastReminderTime.getDelta() > (@reminderInterval * 1000 * 60)

  # ----------------------------------------------------------------------------------------------------------------
  @getUpdatesByID: (id)->
    results = _.select gUpdates, (u)->u.id is id

    if results? and (results.length is 0)
      results = null

    results

  # ----------------------------------------------------------------------------------------------------------------
  @getUpdatesByType: (type)->

    results = _.select gUpdates, (u)->u.type is type

#    Hy.Trace.debug "Update::getUpdatesByType (Looking for type=#{type} results=#{results.length})"

    if results? and (results.length is 0)
      results = null

    results

  # ----------------------------------------------------------------------------------------------------------------
  @processDirective: (directive)->

    update = null

    if (Update.getUpdatesByID directive.id)?
      Hy.Trace.debug "Update::processDirective (ignoring id=#{directive.id})"
    else
      update = this.createUpdate directive

    update

  # ----------------------------------------------------------------------------------------------------------------
  @createUpdate: (directive)->

    update = null

    f = switch directive.type
      when Update.kNewsUpdateDirectiveName
        NewsUpdate.create
      when Update.kContentManifestUpdateDirectiveName
        Hy.Content.ContentManifestUpdate.create
      when Update.kConsoleAppUpdateDirectiveName
        ConsoleAppUpdate.create
      when Update.kFlagUpdateDirectiveName
        FlagUpdate.create
      when Update.kRateAppReminderDirectiveName
        RateAppReminder.create
      when Update.kSamplesUpdateDirectiveName
        SamplesUpdate.create
      else
        Hy.Trace.debug "Update::createUpdate (UNIMPLEMENTED DIRECTIVE #{directive.type})"
        null

    if (update = f?(directive))?
      update.dump()
      Update.notifyObservers (observer)=>observer.obs_updateAvailable?(update)

    update

  # ----------------------------------------------------------------------------------------------------------------
  @clearAll: ()->
    gUpdates = []
 
  # ----------------------------------------------------------------------------------------------------------------
  @clear: (update)->
    gUpdates = _.without gUpdates, update
  
# ==================================================================================================================
class UpdateWithURL extends Update
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directive)->
    super

    if directive.url?
      @url = directive.url

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDumpString: ()->
    out = super
    out += " url=#{@url}"

    out

  # ----------------------------------------------------------------------------------------------------------------
  getURL: ()-> @url

  # ----------------------------------------------------------------------------------------------------------------
  hasURL: ()-> @url?

  # ----------------------------------------------------------------------------------------------------------------
  doURL: ()->
    Hy.Trace.debug "UpdateWithURL::doURL (url=#{@url})"
    if this.hasURL()
      Hy.Utils.Deferral.create 0, ()=>Ti.Platform.openURL(this.getURL())

# ==================================================================================================================
class NewsUpdate extends UpdateWithURL

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directive)->
    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDumpString: ()->
    out = super
    out

  # ----------------------------------------------------------------------------------------------------------------
  @create: (directive)->
    new NewsUpdate(directive)

  # ----------------------------------------------------------------------------------------------------------------
  @getUpdates: ()->
    Update.getUpdatesByType Update.kNewsUpdateDirectiveName

# ==================================================================================================================
# Represents an available app update
class AppUpdate extends UpdateWithURL
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directive)->
    super

#    Hy.Trace.debug "AppUpdate::constructor (#{directive.version_major}.#{directive.version_minor})"   

    if directive.version_major? 
      @versionMajor = directive.version_major

    if directive.version_minor?
      @versionMinor = directive.version_minor

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDumpString: ()->
    out = super
    out += " version=#{@versionMajor}.#{@versionMinor}"

    out

  # ----------------------------------------------------------------------------------------------------------------
  @getUpdate_: (name, f_compare)-> 

    applicableUpdate = null

    if (updates = Update.getUpdatesByType(name))?

      # We expect one update at a time   
      if f_compare(update = _.first(updates))
        Hy.Trace.debug "AppUpdate::getUpdates (version available=#{update.versionMajor}.#{update.versionMinor})"
        applicableUpdate = update

    applicableUpdate

# ==================================================================================================================
#
#  {"id": "34",   "type" : "app_update_console", "date" : "today", 
#    "display": "Tap here to update to the latest version of Trivially!", 
#    "version_major": "2", 
#    "version_minor": "0", 
#    "url": "itms-apps://itunes.apple.com/us/app/crowdgame-trivially/id477571106?mt=8", 
#    "popover": "A major new version of Trivially. 2.0, is available", 
#    "required" : "false", 
#    "remind_interval" : "2"},
#
#
class ConsoleAppUpdate extends AppUpdate

  # ----------------------------------------------------------------------------------------------------------------
  @create: (directive)->
    new ConsoleAppUpdate(directive)

  # ----------------------------------------------------------------------------------------------------------------
  @getUpdate: ()->

    f_compare = (update)=>
      (update.versionMajor > Hy.ConsoleApp.get().getMajorVersion()) or (update.versionMinor > Hy.ConsoleApp.get().getMinorVersion())

    AppUpdate.getUpdate_ Update.kConsoleAppUpdateDirectiveName, f_compare

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directive)->
    super

#    Hy.Trace.debug "ConsoleAppUpdate::constructor (#{directive.version_major}.#{directive.version_minor})"   
    this

  # ----------------------------------------------------------------------------------------------------------------    
  # Check if there's a required or strongly-urged update pending
  #
  doRequiredUpdateCheck: ()->

    reason = null
    required = false

    if true #not this.isBusy() 

      if this.isPopover()
        if (r = this.isRequired()) or this.shouldRemind()
          this.resetReminderTimer()
          reason = this.getPopover()
          required = required or r

      if reason?
        this.doAppUpdate(reason, required)

    reason?

  # ----------------------------------------------------------------------------------------------------------------
  # if "reason", we show that to the user and ask for ack, unless "required" is true
  #
  doAppUpdate: (reason = null, required = false)->

    @required = required
    @recommended = not @required and reason?

    fnCancelled = (e, v)=>
      Hy.ConsoleApp.get().analytics?.logConsoleAppUpdateSuggestedIgnored()
      null

    fnCreateNavGroup = (navSpec)=>
      @navGroup = new Hy.UI.NavGroupPopover({}, navSpec)
      @navGroup.pushFnGuard(this, "navGroupDismissCheck", ()=>not required)

    fnUpdateApp = (context)=>
      @navGroup.dismiss(true)
      Hy.ConsoleApp.get().analytics?.logConsoleAppUpdateLaunched()
      this.doURL()
      null

    fnCreateNavSpec = (counter = null)=>
      navSpec = if @required
        {
          _title: "Required App Update"
          _explain: "Trivially requires an app update\n#{if reason? then reason else ""}\n\n#{if counter? then "Starting update in " + counter + " second#{if counter > 1 then "s" else ""}" else ""}"
          _fnVisible: if counter isnt 1 then null else (navSpec)=>fnUpdateApp(context)
        }
      else
        if @recommended
          {
            _title: "App Update"
            _explain: "#{if reason? then reason else "An app update is available!"}\nWould you like to download it?"
            _buttonSpecs: [
              {_value: "yes", _navSpecFnCallback: (event, view, navGroup)=>fnUpdateApp(context)},
              {_value: "cancel", _cancel: true, _dismiss: "_root", _fnCallback: (e,v)=>fnCancelled(e,v)}
            ]
          }
        else
          {
            _title: "App Update"
            _explain: "Starting App Update...\nThis won\'t take long..."
          }
      navSpec._id = "AppUpdate"
      navSpec

    fnCountdown = (counter)=>
      context.navGroup.replaceNavView(fnCreateNavSpec(counter))

      if counter > 1
        Hy.Utils.PersistentDeferral.create(1000, ()=>fnCountdown(counter-1))

      null

    counter = 6
    context = {}
    context.navGroup = fnCreateNavGroup(fnCreateNavSpec(null))
        
    if @required
      Hy.ConsoleApp.get().analytics?.logConsoleAppUpdateRequired()
    else
      if @suggested
        Hy.ConsoleApp.get().analytics?.logConsoleAppUpdateSuggested()

    # Kick it off
    if @required or not @recommended
      Hy.Utils.PersistentDeferral.create(2000, if @required then (()=>fnCountdown(counter)) else (()=>fnUpdateApp(context)))

    this

# ==================================================================================================================
# Represents an available content manifest update
# As specified in the trivially console update manifest
#
class FlagUpdate extends Update

  # ----------------------------------------------------------------------------------------------------------------
  @create: (directive)->

    new FlagUpdate(directive)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directive)->

    super

    @flagName = directive.flagName
    @flagValue = directive.flagValue

    this.checkSpecificUpdates()

    this

  # ----------------------------------------------------------------------------------------------------------------
  checkSpecificUpdates: ()->

    func = null

    if not FlagUpdate.checkBooleanFlag("flag-x1", true)
      funcx1()
    this

  # ----------------------------------------------------------------------------------------------------------------
  @getUpdate: (flagName)->

    update = if (updates = Hy.Update.Update.getUpdatesByType(Hy.Update.Update.kFlagUpdateDirectiveName))?
      _.find(updates, (u)=>u.flagName is flagName)
    else
      null

    update

  # ----------------------------------------------------------------------------------------------------------------
  getDumpString: ()->
    out = super
    out += " flagName=#{@flagName}=#{@flagValue}"

    out

  # ----------------------------------------------------------------------------------------------------------------
  @checkBooleanFlag: (flagName, defaultValue)->

    flagUpdateValue = null

    if (update = Hy.Update.FlagUpdate.getUpdate(flagName))?
      flagUpdateValue = switch update.flagValue
        when "true"
          true
        when "false"
          false
        else
          null
          Hy.Trace.debug "FlagUpdate::checkBooleanFlag (EXPECTED BOOLEAN, IGNORING #{flagName}=#{update.flagValue})"

    m = null

    flagValue = if flagUpdateValue?
      m = "Using FlagUpdate value"
      flagUpdateValue
    else
      m = "Using default value"
      defaultValue

    Hy.Trace.debug "FlagUpdate::checkBooleanFlag (setting #{flagName}: #{m} #{flagValue})"

    flagValue

# ==================================================================================================================
# Represents an available content manifest update
# As specified in the trivially console update manifest
#
class SamplesUpdate extends Update

  # ----------------------------------------------------------------------------------------------------------------
  @create: (directive)->

    new SamplesUpdate(directive)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directive)->

    super

    @samples = directive.samples

    this

  # ----------------------------------------------------------------------------------------------------------------
  @getUpdate: ()->

    update = if (updates = Hy.Update.Update.getUpdatesByType(Hy.Update.Update.kSamplesUpdateDirectiveName))?
      _.first(updates)
    else
      null

    update

  # ----------------------------------------------------------------------------------------------------------------
  getDumpString: ()->
    out = super
    out += " SamplesUpdate=#{@samplesUpdate}"

    out

  # ----------------------------------------------------------------------------------------------------------------
  @getSamplesUpdate: (defaultValue = Hy.Config.Content.kSampleCustomContestsDefault)->

    samples = defaultValue

    if (update = Hy.Update.SamplesUpdate.getUpdate())?
      Hy.Trace.debug "FlagUpdate::getSamplesUpdate"
      samples = update.samples

    return if samples? and samples.length > 0 then samples else null

# ==================================================================================================================
#
# A request to the user to rate the app
#
#
# Attributes:
#   required: ignored, always assumed "true"
#   popover: ignored
#   display: required (text to display)
#   reminder_interval: required (minutes)
#   url: required
#
#
#  {"id": "34",   "type" : "rate_app_reminder", "date" : "today", 
#   "popover": "Life Trivially? Tap here to rate and review in the App Store", 
#   "url": "itms-apps://itunes.apple.com/us/app/crowdgame-trivially/id477571106?mt=8", 
#   "remind_interval" : "2"},
#
# Behavior
#
#   We don't want to bug the user too often. "reminder" is the number of minutes between requests.
#   We only check when the Start Page is rendered, so the actual time between requests may be longer.
#
#   1 - If the user has responded by agreeing to rate, don't ask again (for this installation)
#
#   2 - If the user selects "remind me later", or otherwise dimisses the request, then remind again in
#       "reminder" minutes
#
#   3 - If the user selects "don't ask again", then don't ask again.
#
#   We implement the "don't ask again" behavior of #1 and #3 via the existence of a specific file in the app
#   installation.
#
#   ALSO:
#

class RateAppReminder extends UpdateWithURL

  # ----------------------------------------------------------------------------------------------------------------
  @create: (directive)->

    new RateAppReminder(directive)

  # ----------------------------------------------------------------------------------------------------------------
  @getUpdate: (flagName)->

    update = if (updates = Hy.Update.Update.getUpdatesByType(Hy.Update.Update.kRateAppReminderDirectiveName))?
      _.find(updates, (u)=>u.flagName is flagName)
    else
      null

    update

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directive)->

    super

    @reminderFileExists = null  
    this

  # ----------------------------------------------------------------------------------------------------------------    
  # Check if it's time to nag the user again
  #
  doRateAppReminderCheck: ()->

    checked = false

    if (not this.checkReminderFileExists()) and this.shouldRemind()
      checked = true
      this.resetReminderTimer()
      this.doRateApp(this.getPopover())

    checked

  # ---------------------------------------------------------------------------------------------------------------- 
  getReminderFile: ()->
    Ti.Filesystem.getFile(Hy.Config.Update.kRateAppReminderFileName)

  # ----------------------------------------------------------------------------------------------------------------    
  createReminderFile: (content = "App Reminder")->
    f = this.getReminderFile()
    f.write("#{content} / #{(new Date()).toString()}")
    f.remoteBackup = true
    @reminderFileExists = true

  # ----------------------------------------------------------------------------------------------------------------    
  checkReminderFileExists: ()->
    if not @reminderFileExists?
      @reminderFileExists = this.getReminderFile().exists()
    @reminderFileExists

  # ----------------------------------------------------------------------------------------------------------------
  # Show "reason" to the user, ask if we should redirect to URL to rate the app
  #
  doRateApp: (reason)->

    buttonPressed = false

    fnCreateNavGroup = (navSpec)=>
      @navGroup = new Hy.UI.NavGroupPopover({}, navSpec)
      @navGroup.pushFnGuard(this, "navGroupDismissCheck", ()=>fnDismissed())

    fnDismissed = ()=>
      if not buttonPressed
        fnIgnored()
      true

    fnIgnored = ()=>
      Hy.ConsoleApp.get().analytics?.logRateAppReminderIgnored()
      null

    fnDontRateApp = ()=>
      buttonPressed = true
      this.createReminderFile("declined")
      Hy.ConsoleApp.get().analytics?.logRateAppReminderDeclined()
      null

    fnRateAppNow = ()=>
      buttonPressed = true
      this.createReminderFile("accepted")
      @navGroup.dismiss(true)
      Hy.ConsoleApp.get().analytics?.logRateAppReminderAccepted()
      this.doURL()
      null

    fnRateAppLater = ()=>
      buttonPressed = true
      Hy.ConsoleApp.get().analytics?.logRateAppReminderPostponed()
      null

    fnCreateNavSpec = ()=>
      navSpec = 
        {
          _title: "Will you rate Trivially?"
          _explain: "#{reason}"
          _buttonSpecs: [
#            {_value: "yes", _navSpecFnCallback: (event, view, navGroup)=>fnRateAppNow()},
            {_value: "yes!"           , _dismiss: "_root", _fnCallback: (e,v)=>fnRateAppNow()}
            {_value: "remind me later", _dismiss: "_root", _fnCallback: (e,v)=>fnRateAppLater()}
            {_value: "no, and don't ask again!", _dismiss: "_root", _fnCallback: (e,v)=>fnDontRateApp()}
          ]
        }
      navSpec._id = "RateApp"
      navSpec

    # Kick it off
    fnCreateNavGroup(fnCreateNavSpec())

    this


# ==================================================================================================================

# assign to global namespace:
Hy.Update = 
  Update           : Update
  NewsUpdate       : NewsUpdate
  ConsoleAppUpdate : ConsoleAppUpdate
  UpdateService    : UpdateService
  FlagUpdate       : FlagUpdate
  RateAppReminder  : RateAppReminder
  SamplesUpdate    : SamplesUpdate




