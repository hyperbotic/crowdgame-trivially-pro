#
# We assume that the Firebase SDK will buffer all operations as appropriate across 
# connected/disconnected states
#

class Firebase

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (networkManager, fn_observeEventTypeWithBlockWithCancelBlock, fn_setValueWithCompletionBlock)->

    this.init()

    @networkManager = networkManager
    @fn_observeEventTypeWithBlockWithCancelBlock = fn_observeEventTypeWithBlockWithCancelBlock
    @fn_setValueWithCompletionBlock = fn_setValueWithCompletionBlock

    this  

  # ----------------------------------------------------------------------------------------------------------------
  init: ()->
    Hy.Trace.debug "Firebase::init"

    @networkManager = null

    @fn_observeEventTypeWithBlockWithCancelBlock = null
    @fn_setValueWithCompletionBlock = null

    @firebaseModule = null
    @authenticated = false
    @expires = null

    @fn_authResult = null
    @fn_authCancelled = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  initModule: ()->

    Hy.Trace.debug "Firebase::initModule"

    if (success = (@firebaseModule = require('com.crowdgame.trivfirebase2'))?)

      @firebaseModule.addEventListener("firebase_observeEventTypeWithBlockWithCancelBlock", (e)=>this.eventHandler_observeEventTypeWithBlockWithCancelBlock(e))

      @firebaseModule.addEventListener("firebase_setValueWithCompletionBlock", (e)=>this.eventHandler_setValueWithCompletionBlock(e))

      @firebaseModule.addEventListener("firebase_authResult", (e)=>this.authResult(e))

      @firebaseModule.addEventListener("firebase_authCancelled", (e)=>this.authCancelled(e))
    success

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    this.init()
    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  isAuthenticated: ()-> @authenticated

  # ----------------------------------------------------------------------------------------------------------------
  getExpires: ()-> @expires

  # ----------------------------------------------------------------------------------------------------------------
  authWithCredential: (url, authToken, @fn_authResult, @fn_authCancelled)->

    Hy.Trace.debug "Firebase::authWithCredential #{url}"

    @firebaseModule.authWithCredential(url, authToken)

    this

  # ----------------------------------------------------------------------------------------------------------------
  authResult: (e)->

    Hy.Trace.debug "Firebase::authResult (#{e.status} expires:#{e.expires})"

    if (@authenticated = e.status is "OK")
      @expires = e.expires

    if (f = @fn_authResult)?
      f(e)
    else
      Hy.Trace.debug "Firebase::authResult (IGNORING - NO HANDLER)"

    this

  # ----------------------------------------------------------------------------------------------------------------
  authCancelled: (e)->

    Hy.Trace.debug "Firebase::authCancelled"

    @authenticated = false
    @expires = null

    if (f = @fn_authCancelled)?
      f()
    else
      Hy.Trace.debug "Firebase::authCanceled (IGNORING - NO HANDLER)"
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  eventHandler_observeEventTypeWithBlockWithCancelBlock: (e)->
    Hy.Trace.debug "Firebase::eventHandler_observeEventTypeWithBlockWithCancelBlock #{e.status} #{e.url}"

    @fn_observeEventTypeWithBlockWithCancelBlock?(e)

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Currently, our Firebase module only fires this on errors
  #
  eventHandler_setValueWithCompletionBlock: (e)=>

    Hy.Trace.debug "Firebase::eventHandler_setValueWithCompletionBlock #{e.name}"

    @fn_setValueWithCompletionBlock?(e)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setValueWithCompletionBlock: (url, value)->

    Hy.Trace.debug "Firebase::setValueWithCompletionBlock (#{url}->#{value})"

    @firebaseModule?.setValueWithCompletionBlock(url, value)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setValueObjWithCompletionBlock: (url, obj)->

    Hy.Trace.debug "Firebase::setValueObjWithCompletionBlock (#{url})"

    for p, v of obj
      @firebaseModule?.setValueWithCompletionBlock("#{url}/#{p}", v)

    url

  # ----------------------------------------------------------------------------------------------------------------
  childByAutoId: (parentURL)->

    url = @firebaseModule?.childByAutoId(parentURL)

    Hy.Trace.debug "Firebase::childByAutoId (#{url})"

    url

  # ----------------------------------------------------------------------------------------------------------------
  childByAppendingPath: (parentURL, childPath)->

    Hy.Trace.debug "Firebase::childByAppendingPath (#{parentURL} / #{childPath})"

    @firebaseModule?.childByAppendingPath(parentURL, childPath)

    this
    
  # ----------------------------------------------------------------------------------------------------------------
  onDisconnect: (url, value)->

    Hy.Trace.debug "Firebase::onDisconnect (#{url} / #{value})"

    @firebaseModule?.onDisconnect(url, value)

    this

  # ----------------------------------------------------------------------------------------------------------------
  cancelDisconnectOperations: (url)->

    Hy.Trace.debug "Firebase::cancelDisconnect (#{url})"

    @firebaseModule?.cancelDisconnectOperations(url)

  # ----------------------------------------------------------------------------------------------------------------
  observeEventTypeWithBlockWithCancelBlock: (kind, url)->

    Hy.Trace.debug "Firebase::observeEventTypeWithBlock (#{kind} #{url})"

    @firebaseModule.observeEventTypeWithBlockWithCancelBlock(kind, url)

    this

  # ----------------------------------------------------------------------------------------------------------------
  removeAllObservers: (url)->

    Hy.Trace.debug "Firebase::removeAllObservers (#{url})"

    @firebaseModule?.removeAllObservers(url)

  # ----------------------------------------------------------------------------------------------------------------
  # Simulates calling "name()" on a firebase Ref

  name: (url)->

    a = url.split("/")

    n = if a.length > 0
      a[a.length-1]
    else
      null

    n

# ==================================================================================================================
# assign to global namespace:
if not Hy.Network?
  Hy.Network = {}

Hy.Network.Firebase = Firebase
