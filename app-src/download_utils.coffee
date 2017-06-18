# ==================================================================================================================
# Represents a download attempt
class DownloadEvent extends Hy.Network.HTTPEvent

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@obj)->

    this.setDownloadStatus(DownloadManager.kStatusNotEnqueued)

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDownloadStatus: ()-> @downloadStatus

  # ----------------------------------------------------------------------------------------------------------------
  setDownloadStatus: (@downloadStatus)->

  # ----------------------------------------------------------------------------------------------------------------
  enqueue: ()->

    this.setDownloadStatus(DownloadManager.kStatusPending)

    if not super
      this.setDownloadStatus(DownloadManager.kStatusFailed)

    this

  # ----------------------------------------------------------------------------------------------------------------
  isNotEnqueued: ()->  this.getDownloadStatus() is DownloadManager.kStatusNotEnqueued
  # ----------------------------------------------------------------------------------------------------------------
  isPending: ()->      this.getDownloadStatus() is DownloadManager.kStatusPending
  # ----------------------------------------------------------------------------------------------------------------
  isSuccess: ()->      this.getDownloadStatus() is DownloadManager.kStatusSuccess
  # ----------------------------------------------------------------------------------------------------------------
  isFailed:  ()->      this.getDownloadStatus() is DownloadManager.kStatusFailed

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    super + " display=#{@obj.display} status=#{this.getDownloadStatus()}"

# ==================================================================================================================
# Provides higher-level interface for downloading one or more files at a time

class DownloadManager

  @kStatusNotEnqueued = 0
  @kStatusPending     = 1
  @kStatusFailed      = 2
  @kStatusSuccess     = 3

  gInstanceCount = 0

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@reference, @fn_setup, @fn_done, @display)->

    @gInstanceCount++

    @events = []
    this.init()
    this.topOffQueue()
    this

  # ----------------------------------------------------------------------------------------------------------------
  init: ()->

    eventSpecs = this.invokeSetup()

    if eventSpecs?
      for spec in eventSpecs
        @events.push this.createEvent(spec)

    if _.size(@events) is 0
      this.invokeDone()
    
    null

  # ----------------------------------------------------------------------------------------------------------------
  invokeSetup: ()->

    eventSpecs = null

    if @fn_setup?
      Hy.Trace.debug "DownloadManager::invokeSetup (##{gInstanceCount} ENTER setup function #{@display})"
      eventSpecs = @fn_setup(@reference)
      Hy.Trace.debug "DownloadManager::invokeSetup (##{gInstanceCount} EXIT setup function #{@display} #eventSpecs=#{_.size(eventSpecs)})"

    return eventSpecs
    
  # ----------------------------------------------------------------------------------------------------------------
  createEvent: (eventSpec)=>

    f = (event, status)=>this.invokeCallback(event, status)

    event = new DownloadEvent(eventSpec)
    event.setFnPost(f)
    event.setURL(eventSpec.URL)

    if eventSpec.fnPre?
      event.setFnPre(eventSpec.fnPre) # V1.0.2

    event

  # ----------------------------------------------------------------------------------------------------------------
  topOffQueue: ()->

    numNewDownloads = 0
    for e in _.filter(@events, (e)=>e.isNotEnqueued())
      if numNewDownloads < Hy.Config.DownloadManager.kMaxSimultaneousDownloads
        numNewDownloads++
        Hy.Trace.debug "DownloadManager::topOffQueue (##{gInstanceCount} numNewDownloads=#{numNewDownloads}: #{e.obj.display})"
        this.enqueueEvent(e)
      else
        break

    numNewDownloads isnt 0

  # ----------------------------------------------------------------------------------------------------------------
  enqueueEvent: (event)->

    if event.enqueue()
      Hy.Trace.debug "DownloadManager::enqueueEvent (##{gInstanceCount} event #{@display} #{event.obj.display})"
    else
      Hy.Trace.debug "DownloadManager::enqueueEvent (##{gInstanceCount} ERROR could not enqueue event #{@display} #{event.obj.display})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  dumpEvents: ()->
    for e in @events
      Hy.Trace.debug "DownloadManager.dumpEvents (##{gInstanceCount} #{e.dumpStr()})"
    this

  # ----------------------------------------------------------------------------------------------------------------
  invokeCallback: (event, status)->

    Hy.Trace.debug "DownloadManager.invokeCallback (##{gInstanceCount} #{event.obj.display} #{if status then "SUCCESS" else "FAIL"})"

    f = (event)=>
#      Hy.Trace.debug "DownloadManager::invokeCallback (##{gInstanceCount} ENTER #{event.dumpStr()} callback=#{event.obj.callback?})"

      stat = true

      if event.obj.callback?
        stat = event.obj.callback(@reference, event, event.obj) # trying to hide class DownloadEvent

      event.setDownloadStatus(if stat then DownloadManager.kStatusSuccess else DownloadManager.kStatusFailed)

      this.areWeDoneYet()

      null

    if status
      Hy.Utils.PersistentDeferral.create(0, ()=>f(event))
    else
      event.setDownloadStatus(DownloadManager.kStatusFailed)

      this.areWeDoneYet()

    null

  # ----------------------------------------------------------------------------------------------------------------
  areWeDoneYet: ()->

    if this.topOffQueue()
      # found some more downloads to kick off, so not done
      null
    else
      if (pending = _.filter(@events, (e)=>e.isPending())).length isnt 0
        Hy.Trace.debug "DownloadManager::areWeDoneYet (##{gInstanceCount} #events=#{_.size(@events)} Pending=#{pending.length})"
        # Still waiting for some events to complete, so not done
        null
      else
        # Here means done
        this.invokeDone()

    this
    
  # ----------------------------------------------------------------------------------------------------------------
  invokeDone: ()->

    Hy.Trace.debug "DownloadManager::invokeDone (##{gInstanceCount})"

    f = (status)=>
      Hy.Trace.debug "DownloadManager::invokeDone (##{gInstanceCount} ENTER #{@display})"
      if @fn_done?
        @fn_done(@reference, status)
      null

    status = []
    for e in @events
      status.push {object: e.obj, status: e.isSuccess()}

    Hy.Utils.PersistentDeferral.create 0, ()=>f(status)

    null

# ==================================================================================================================
class DownloadCache

  gInstance = null
  kMapFilename = "_map"

  # ----------------------------------------------------------------------------------------------------------------
  @init: ()->
    if not gInstance?
      gInstance = new DownloadCache()
    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @put: (url, contents, update = false)->
    gInstance?.put(url, contents, update)

  # ----------------------------------------------------------------------------------------------------------------
  @getCachePathname: (url, relative = true)->
    gInstance?.getCachePathname(url, relative)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->
    @map = []
    @dirty = false

    this._makeDirectory()

    this._readMap()

    this

  # ----------------------------------------------------------------------------------------------------------------
  _isDirty: ()-> @dirty

  # ----------------------------------------------------------------------------------------------------------------
  _setDirty: (dirty = true)-> 
    if (@dirty = dirty)
      this._writeMap()
    this

  # ----------------------------------------------------------------------------------------------------------------
  _makeDirectory: ()->

    d = Ti.Filesystem.getFile(Hy.Config.DownloadManager.kCacheDirectoryPath)
  
    if not d.exists()
      d.createDirectory()

    this

  # ----------------------------------------------------------------------------------------------------------------
  _getDirectory: ()-> 

    Hy.Config.DownloadManager.kCacheDirectoryPath    

  # ----------------------------------------------------------------------------------------------------------------
  _writeMap: ()->

    if this._isDirty()
      file = Ti.Filesystem.getFile(this._getDirectory(), kMapFilename)

      if file.exists()
        file.deleteFile()

      try
        text = JSON.stringify(@map)
        file.write(text)
      catch e
        this._cacheError("_writeMap", "stringify error")

      file.setRemoteBackup(false) # Don't need to backup

      this._setDirty(false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  _readMap: ()->

    @map = []

    file = Ti.Filesystem.getFile(this._getDirectory(), kMapFilename)

    if file.exists()
      contents = file.read().toString()

      try
        results = JSON.parse(contents)
      catch e
        this._cacheError("_readMap", "parse error")
        results = null

      if results?
        for result in results
          @map.push {url: result.url, cacheFilename: result.cacheFilename, fileSize: result.fileSize}

      this._setDirty(false)
    this


  # ----------------------------------------------------------------------------------------------------------------
  _cacheError: (operation, message)->
    s = "While doing this: #{operation}, ran into this: #{message}"
    new Hy.Utils.ErrorMessage("fatal", "DownloadCache", s) #will display popup dialog
    this

  # ----------------------------------------------------------------------------------------------------------------
  _makeCacheFilename: ()->
    "c_" + Hy.Utils.UUID.generate()

  # ----------------------------------------------------------------------------------------------------------------
  _writeFile: (filename, contents)->

    file = Ti.Filesystem.getFile(this._getDirectory(), filename)

    if file.exists()
      file.deleteFile()

    file.write(contents)
    file.setRemoteBackup(false) # Don't need to backup

    file.getSize()

  # ----------------------------------------------------------------------------------------------------------------
  _find: (url)->
    _.find(@map, (m)=>m.url is url)
    
  # ----------------------------------------------------------------------------------------------------------------
  #
  #
   put: (url, contents, update = false)->

    size = 0

    cacheFilename = if (m = this._find(url))?
      size = m.fileSize

      if update
        m.cacheFilename
      else
        null
    else
      this._makeCacheFilename()

    if cacheFilename?
      size = this._writeFile(cacheFilename, contents)

      if not m?
        @map.push (m= {url: url, cacheFilename: cacheFilename, fileSize: size})

      this._setDirty()
  
    this._getCachePathname(m.cacheFilename)

  # ----------------------------------------------------------------------------------------------------------------
  _getCachePathname: (cacheFilename)->

    "#{this._getDirectory()}/#{cacheFilename}"

  # ----------------------------------------------------------------------------------------------------------------
  _getCacheRelativePathname: (cacheFilename)->

    "#{Hy.Config.DownloadManager.kCacheDirectoryName}/#{cacheFilename}"

  # ----------------------------------------------------------------------------------------------------------------
  getCachePathname: (url, relative = true)->
    
    if (m = this._find(url))?
      if relative
        this._getCacheRelativePathname(m.cacheFilename)
      else
        this._getCachePathname(m.cacheFilename)
    else
      null

# ==================================================================================================================
# assign to global namespace:

if not Hy.Network?
  Hy.Network = {}

Hy.Network.DownloadManager = DownloadManager
Hy.Network.DownloadCache = DownloadCache

