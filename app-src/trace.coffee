# ==================================================================================================================
class Trace
  messages = []
  file = null

  # ----------------------------------------------------------------------------------------------------------------
  @init: (app)->

    # Did we leave a reminder to ourselves to turn on debugging?
    if Trace.checkMarkerFile(true) # Delete the reminder
      Trace.setDebugState(true)

    fnChord = ()->
      if Hy.Trace.getDebugState()
        Hy.Trace.sendLog()
      else
        Hy.Trace.setDebugState(true, true) # Turn on debugging, and leave a reminder file

    Hy.Utils.HiddenChord.init(app, fnChord, [Titanium.UI.PORTRAIT, Titanium.UI.UPSIDE_PORTRAIT])

    null

  # ----------------------------------------------------------------------------------------------------------------
  @getDebugState: ()->
    Hy.Config.Trace.messagesOn

  # ----------------------------------------------------------------------------------------------------------------
  # 
  # If <persistent> is set, write a file reminding us to turn on debug state when the app
  # starts next time
  #
  @setDebugState: (state, persistent = false)->
    Hy.Config.Trace.messagesOn = state

    if state and persistent
      Trace.writeMarkerFile()

    Hy.Config.Trace.messagesOn

  # ----------------------------------------------------------------------------------------------------------------
  @debug: (msg, force=false)->
    if force or Hy.Config.Trace.messagesOn
      Trace.log_("debug", msg)

    true

  # ----------------------------------------------------------------------------------------------------------------
  @debugM: (msg, force=false)->
    Hy.Trace.debug "#{msg} #{Hy.Utils.MemInfo.info()}", true

  # ----------------------------------------------------------------------------------------------------------------
  @info: (msg, force=false)->
    if force or Hy.Config.Trace.messagesOn
      Trace.log_("info", msg)

    true

  # ----------------------------------------------------------------------------------------------------------------
  @log_: (level, message)->

    messages.push "[#{level}] /#{(new Date()).toString()}/ #{message}"

    # Ti.API.info msg  # no longer appears to log to device console, as of SDK 2.0.1
    Ti.API.log(level, message)

    null

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Write a file that will remind us to turn on debugging when the app is next restarted
  #
  @writeMarkerFile: ()->
    markerFile = Ti.Filesystem.getFile(Hy.Config.Trace.MarkerFilename)

    Trace.log_("info", "[info] Trace::writeMarkerFile (creating marker log file)")
    markerFile.deleteFile()
    markerFile.createFile() 
    markerFile.write("#{(new Date()).toString()}")

    null

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Is there a marker file from last time?
  # Also, if "del" is set, delete it
  #
  @checkMarkerFile: (del = true)->
    markerFile = Ti.Filesystem.getFile(Hy.Config.Trace.MarkerFilename)
    exists = markerFile.exists()

    if exists and del
      markerFile.deleteFile()

    exists

  # ----------------------------------------------------------------------------------------------------------------
  @writeLogFile: ()->
    Trace.log_("info", "[info] Trace::writeLogFile (#messages = #{messages.length} Memory=#{Ti.Platform.availableMemory} debug=#{Trace.getDebugState()})")

    # According to Apple, this is an example of "Temporary Data":
    # http://developer.apple.com/library/ios/#qa/qa1719/_index.html
    #
    # "This is short lived data that the app needs to write out to local storage for its internal operation, 
    # but that is not expected to persist for an extended period of time. Temporary data should be put in
    # the <Application_Home>/tmp directory. Files in this directory may be cleaned up by the system. 
    # Files in this directory are not backed up by iTunes or iCloud. Temporary data files should be removed
    # as soon as they are no longer needed to avoid using unnecessary storage space on the user's device.
    #
    logFilename = Hy.Config.Trace.LogFileDirectory + "/log.txt"

    logFile = Ti.Filesystem.getFile(logFilename)

    Trace.log_("info", "[info] Trace::writeLogFile (Deleting existing log file)")
    logFile.deleteFile();

    logFile.createFile() 

    Trace.log_("info", "[info] Trace::writeLogFile USAGE DB LOG ++++++++++++++++++++++++++")
    Trace.log_("info", "[info] Trace::writeLogFile USAGE DB LOG ++++++++++++++++++++++++++")
    Trace.log_("info", "[info] Trace::writeLogFile USAGE DB LOG ++++++++++++++++++++++++++")

    Hy.Content.Questions.writeDBLog()

    Trace.log_("info", "[info] Trace::writeLogFile ANALYTICS ++++++++++++++++++++++++++")
    Trace.log_("info", "[info] Trace::writeLogFile ANALYTICS ++++++++++++++++++++++++++")
    Trace.log_("info", "[info] Trace::writeLogFile ANALYTICS ++++++++++++++++++++++++++")

    Hy.Analytics.Analytics.dumpStats()

    Trace.log_("info", "[info] Trace::writeLogFile PURCHASE LOG ++++++++++++++++++++++++++")
    Trace.log_("info", "[info] Trace::writeLogFile PURCHASE LOG ++++++++++++++++++++++++++")
    Trace.log_("info", "[info] Trace::writeLogFile PURCHASE LOG ++++++++++++++++++++++++++")

    Hy.Commerce.CommerceManager.writeLog()

    Trace.log_("info", "[info] Trace::writeLogFile (wrote DB Log #messages = #{messages.length})")
    Trace.log_("info", "[info] Trace::writeLogFile DEBUG LOG ++++++++++++++++++++++++++")
    Trace.log_("info", "[info] Trace::writeLogFile DEBUG LOG ++++++++++++++++++++++++++")
    Trace.log_("info", "[info] Trace::writeLogFile DEBUG LOG ++++++++++++++++++++++++++")

    s = ""
    for message in messages
      s += message + "\n"

    logFile.write(s)

    s = null

    messages = []

    Trace.log_("info", "[info] Trace::writeLogFile (cleared Messages Memory=#{Ti.Platform.availableMemory})")
 
    logFile

  # ----------------------------------------------------------------------------------------------------------------
  @sendLog: ()->
    Trace.log_("info", "[info] Trace::sendLog (Creating email dialog)")

    emailDialog = Ti.UI.createEmailDialog()

    emailDialog.subject = "CrowdGame Trivially diagnostic log"
    emailDialog.toRecipients = ['??']
    emailDialog.messageBody = "Created on #{(new Date()).toString()} (#{Hy.Config.Version.Console.kConsoleMajorVersion}.#{Hy.Config.Version.Console.kConsoleMinorVersion}.#{Hy.Config.Version.Console.kConsoleMinor2Version})"
    emailDialog.addAttachment(Trace.writeLogFile())
    emailDialog.open()
    Trace.log_("info", "[info] Trace::sendLog (Created email dialog)")

    null

# ==================================================================================================================
Hy.Trace = Trace
