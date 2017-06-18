# ==================================================================================================================
#
class Session

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  log: (errorMessage, data = null)->

    Session.log(errorMessage, data)

  # ----------------------------------------------------------------------------------------------------------------
  @log: (errorMessage, data = null)->

    Hy.Trace.debug "Session::log"

    log = {}

    log.date = (new Date()).toString()

    if data?
      log.data = data

    log.errorMessage = errorMessage

    text = JSON.stringify(log)

    Hy.Trace.debug("Session::log (#{text})", true)

    Session.addToLogFile(text)

    null

  # ----------------------------------------------------------------------------------------------------------------
  @addToLogFile: (text)->

    logFile = Ti.Filesystem.getFile(Hy.Config.Commerce.kPurchaseLogFile)

    if not logFile.exists()
      logFile.createFile()
      logFile.setRemoteBackup(true)

    logFile.write(text + "\n\n", true)

    null

  # ----------------------------------------------------------------------------------------------------------------
  @writeLog: ()->

    logFile = Ti.Filesystem.getFile(Hy.Config.Commerce.kPurchaseLogFile)

    txt = null
   
    if logFile.exists() and (txt = logFile.read())?
      txt = txt.toString()
      Hy.Trace.debug "#{txt}"
        
    this

# ==================================================================================================================
#
class InventorySession extends Session

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@fnPreCallback, @fnPostCallback = null)->

    super

    @purchaseItems = null

    f = this
    fnPost = (status, errorMessage, products)=>f.doInventoryPostCallback(status, errorMessage, products)

    @iapInventory = Hy.IAP.InventoryService.create((()=>this.doInventoryPreCallback()), fnPost)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doImmediate: ()->

    @iapInventory?.doImmediate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  doInventoryPreCallback: ()->

    if _.size(@purchaseItems = @fnPreCallback()) > 0
      Hy.Trace.debug "InventorySession::doInventoryPreCallback (products=#{_.size(@purchaseItems)})"

    _.map(@purchaseItems, (c)=>c.getAppStoreProductId())

  # ----------------------------------------------------------------------------------------------------------------
  doInventoryPostCallback: (status, errorMessage, inventoriedProducts)=>

    Hy.Trace.debug "InventorySession::doInventoryPostCallback (status=#{status} errorMessage=#{errorMessage} products=#{_.size(inventoriedProducts)})"

    s = null

    if status
      for c in @purchaseItems
        if (appStoreProduct = _.detect(inventoriedProducts, (p)=>p.getIdentifier() is c.getAppStoreProductId()))?
          Hy.Trace.debug "InventorySession::doInventoryPostCallback (#{c.getAppStoreProductId()})"
          c.setAppStoreInventoryInfo(appStoreProduct)
        else
          Hy.Trace.debug "InventorySession::doInventoryPostCallback (ERROR INVALIDATED #{c.getAppStoreProductId()})"

    else
      Hy.Trace.debug "InventorySession::doInventoryPostCallback (ERROR - canMakePayments=#{Hy.IAP.PurchaseService.canMakePayments()})"
      s = "Unable to connect. Will try again later..."
#      if errorMessage?
#        s += "\n(#{errorMessage})"

    @fnCallback?(status, s, @purchaseItems)

    status

# ==================================================================================================================
class PurchaseSession extends Session

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Returns null if conditions are generally right for a PurchaseSession, such as network connectivity,
  # or whether the user's account is enabled for purchasing.
  #
  # Otherwise, returns a string with an error message suitable for presentation to the user
  #
  @isReady: ()->

    fnCheckConnectedToWeb = ()=>
      if not Hy.Network.NetworkService.isOnline()
        "Please connect to the web and try again"
      else
        null

    fnCheckAccountEnabledForInAppPurchase = ()=>
      if not CommerceManager.accountEnabledForPurchase()
        "Sorry - your App Store account is not enabled for purchasing"
      else
        null

    for f in [fnCheckConnectedToWeb, fnCheckAccountEnabledForInAppPurchase]
      if (s = f())?
        return s

    null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@purchaseItem, @fn_buyCompleted)->

    super

    @iapReceipt = null
    @iapPurchase = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  purchase: ()->
    Hy.Trace.debug "PurchaseSession::buy (#{@purchaseItem.getDisplayName()})"

    errorMessage = null

    if @iapPurchase?
      Hy.Trace.debug "PurchaseSession::purchase (ERROR PURCHASE ALREADY IN PROGRESS)"
      errorMessage = "Sorry - a purchase operation is still in progress"
    else
      p = this
      f = (errorMessage, purchaseItem, purchaseInfo)=>this.buyCallback(errorMessage, purchaseItem, purchaseInfo)

      if @purchaseItem.isReadyForPurchase()
        if (@iapPurchase = Hy.IAP.PurchaseService.create(f, @purchaseItem.getAppStoreInventoryInfo(), @purchaseItem))?
          if @iapPurchase.purchase()
            Hy.Utils.Deferral.create(5 * 1000, ()=>Hy.ConsoleApp.get().analytics?.logPurchaseStart(@purchaseItem.constructor.name))
          else
            errorMessage = "Sorry - could not initiate a purchase at this time. Please try again later."
        else
          errorMessage = "Sorry - your App Store account is not enabled for purchasing."
      else
        errorMessage = "Sorry - \"#{@purchaseItem.getDisplayName()}\" is not available for puchase at this time. Please try again later."

    errorMessage

  # ----------------------------------------------------------------------------------------------------------------
  buyCallback: (errorMessage, purchaseItem, purchaseInfo=null)->
    Hy.Trace.debug "PurchaseSession::buyCallback (errorMessage=#{errorMessage} purchaseInfo=#{purchaseInfo?} #{purchaseItem.getDisplayName()})"

    if @iapPurchase?
      if not errorMessage?
        fnPost = (errorMessage, purchaseItem, receiptConfirmation)=>this.buyReceiptCallback(errorMessage, purchaseItem, receiptConfirmation)

        if Hy.IAP.ReceiptService.shouldVerifyReceipt()
          if (@iapReceipt = Hy.IAP.ReceiptService.create(fnPost, purchaseItem, purchaseInfo))?
            null
          else
            errorMessage = "Sorry - could not confirm receipt. Please try again later."
        else
          Hy.Trace.debug "PurchaseSession::buyCallback (NOT VERIFYING RECEIPT)"
          this.buyCompleted(null, purchaseItem)
          
    else
      errorMessage = "No Purchase In Progress!"
      Hy.Trace.debug "PurchaseSession::buyCallback (ERROR NO PURCHASE IN PROGRESS)"

    if errorMessage?
      this.buyCompleted(errorMessage, purchaseItem)

    errorMessage?

  # ----------------------------------------------------------------------------------------------------------------
  buyReceiptCallback: (errorMessage, purchaseItem, receiptConfirmation=null)->

    Hy.Trace.debug "PurchaseSession::buyReceiptCallBack (errorMessage=#{errorMessage} receipt=#{receiptConfirmation} #{purchaseItem.getDisplayName()})"

    if not errorMessage?
      if receiptConfirmation?
        purchaseItem.setAppStoreReceipt(receiptConfirmation)
      else
        errorMessage = "Sorry - encountered a problem while confirming Receipt. Please try again."

    this.buyCompleted(errorMessage, purchaseItem)

    errorMessage?

  # ----------------------------------------------------------------------------------------------------------------
  buyCompleted: (errorMessage, purchaseItem)->

    if errorMessage?
      Hy.ConsoleApp.get().analytics?.logPurchaseFailed(@purchaseItem.constructor.name)
    else
      Hy.ConsoleApp.get().analytics?.logPurchaseCompleted(@purchaseItem.constructor.name)

    this.log(errorMessage)

    @fn_buyCompleted?(errorMessage, purchaseItem)

    @iapPurchase = null
    @iapReceipt = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  log: (errorMessage)->

    data = {}

    if @iapPurchase?
      data.purchase = @iapPurchase.getLog()

    if @iapReceipt?
      data.receipt = @iapReceipt.getLog()

    super errorMessage, data

    null

# ==================================================================================================================
#
class RestoreSession extends Session

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Returns null if conditions are generally right for a RestoreSession, such as network connectivity
  #
  # Otherwise, returns a string with an error message suitable for presentation to the user
  #
  @isReady: ()->

    fnCheckConnectedToWeb = ()=>
      if not Hy.Network.NetworkService.isOnline()
        "Please connect to the web and try again"
      else
        null

    for f in [fnCheckConnectedToWeb]
      if (s = f())?
        return s

    null


  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@fn_restoreCompleted)->

    super

    @iapRestore = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  restore: ()->

    errorMessage = null

    if @iapRestore?
      Hy.Trace.debug "RestoreSession::restore (ERROR RESTORE ALREADY IN PROGRESS)"
      errorMessage = "Sorry - a restore operation is still in progress."
    else
      f = (errorMessage, results)=>this.restoreCallback(errorMessage, results)

      if (@iapRestore = Hy.IAP.RestoreTransactionsService.create(f))? and @iapRestore.restore()
        Hy.Utils.Deferral.create(5 * 1000, ()=>Hy.ConsoleApp.get().analytics?.logRestoreStart())
      else
        errorMessage = "Sorry - couldn\'t initiate a restore operation. Please try again later."

    errorMessage

  # ----------------------------------------------------------------------------------------------------------------
  restoreCallback: (errorMessage, results)->
    Hy.Trace.debug "RestoreSession::restoreCallback (#{errorMessage} results=#{if results? then _.size(results) else "null"})"

    this.restoreCompleted(errorMessage, results)

  # ----------------------------------------------------------------------------------------------------------------
  restoreCompleted: (errorMessage, results)->

    if errorMessage?
      Hy.ConsoleApp.get().analytics?.logRestoreFailed()
    else
      Hy.ConsoleApp.get().analytics?.logRestoreCompleted()

    this.log(errorMessage)

    normalizedResults = []

    if results?
      for result in results
        normalizedResults.push
          success: result.success
          productId: this.getProductId(result.productIdentifier)
          receipt: result.receipt

    @fn_restoreCompleted?(errorMessage, normalizedResults)

    @iapRestore = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  getProductId: (identifier)-> identifier.replace("#{Hy.Config.AppId}.", "")
  
  # ----------------------------------------------------------------------------------------------------------------
  log: (errorMessage)->

    Hy.Trace.debug "RestoreSession::log (#{errorMessage} #{@iapRestore?})"

    data = {}

    data.errorMessage = errorMessage

    if @iapRestore?
      data.restore = @iapRestore.getLog()

    super errorMessage, data

    null

# ==================================================================================================================
#

class PurchaseItem

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@productID, @reference, @displayName)->

    # Initialize purchase state
    this.initPurchaseState()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getReference: ()-> @reference

  # ----------------------------------------------------------------------------------------------------------------
  getDisplayName: ()-> @displayName

  # ----------------------------------------------------------------------------------------------------------------
  getProductID: ()-> @productID

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    "#{this.constructor.name} #{this.getDisplayName}"

  # ----------------------------------------------------------------------------------------------------------------
  getAppStoreProductId: ()-> "#{Hy.Config.AppId}.#{this.getProductID()}" 

  # ----------------------------------------------------------------------------------------------------------------
  isReadyForPurchase: ()-> 

    this.hasAppStoreInventoryInfo() # yes if we have fresh inventory data

  # ----------------------------------------------------------------------------------------------------------------
  isPurchased: ()->

    this.hasAppStoreReceipt()

  # ----------------------------------------------------------------------------------------------------------------
  initPurchaseState: ()->

    @appStoreInventoryInfo = null
    @appStoreReceipt = null
    
  # ----------------------------------------------------------------------------------------------------------------
  # This is set with info obtained via an Inventory, which we do every time the app starts up
  #
  setAppStoreInventoryInfo: (appStoreInventoryInfo)->

    @appStoreInventoryInfo = appStoreInventoryInfo

    @appStoreInventoryInfo

  # ----------------------------------------------------------------------------------------------------------------
  getAppStoreInventoryInfo: ()-> @appStoreInventoryInfo

  # ----------------------------------------------------------------------------------------------------------------
  hasAppStoreInventoryInfo: ()-> this.getAppStoreInventoryInfo()?

  # ----------------------------------------------------------------------------------------------------------------
  getAppStoreReceipt: ()-> @appStoreReceipt

  # ----------------------------------------------------------------------------------------------------------------
  hasAppStoreReceipt: ()-> @appStoreReceipt?

  # ----------------------------------------------------------------------------------------------------------------
  setAppStoreReceipt: (receipt)->
  
    @appStoreReceipt = receipt

    true

  # ----------------------------------------------------------------------------------------------------------------
  clearAppStoreReceipt: ()->

    @appStoreReceipt = null

  # ----------------------------------------------------------------------------------------------------------------
  getDisplayPrice: ()->

    price = if (appStoreInventoryInfo = this.getAppStoreInventoryInfo())?
      appStoreInventoryInfo.getPrice()
    else
      null

    price

# ==================================================================================================================
class UnmanagedPurchaseItem extends PurchaseItem


# ==================================================================================================================
class ManagedPurchaseItem extends PurchaseItem

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (productID, reference, displayName)->

    super productID, reference, displayName

    CommerceManager.addManagedFeature(this)

    @receiptFileVersionNum = 0
    @receiptFileTimestamp = null

    # this.reconcileWithReceiptFile() # HACK
    this.setAppStoreReceipt("FAKED", false) # HACK
    

    this

  # ----------------------------------------------------------------------------------------------------------------
  reportError: (report)->
    new Hy.Utils.ErrorMessage("fatal", "ManagedPurchaseItem", report) #will display popup dialog

  # ----------------------------------------------------------------------------------------------------------------
  getReceiptFileVersionNum: ()-> @receiptFileVersionNum

  # ----------------------------------------------------------------------------------------------------------------
  verifyReceipt: (receipt)->

    true

  # ----------------------------------------------------------------------------------------------------------------
  reconcileWithReceiptFile: ()->

    if (versionNum = this.findLatestReceiptFile())?
      @receiptFileVersionNum = versionNum

      # Read file to get receipt
      if (receipt = this.readReceiptFile(versionNum))?
        if this.verifyReceipt(receipt)
          this.setAppStoreReceipt(receipt, false)
      else
        this.reportError("Could not read receipt file (#{this.makeFilename(versionNum)})")
    
    this
  
  # ----------------------------------------------------------------------------------------------------------------
  getDirectory: ()-> Hy.Config.Commerce.kReceiptDirectory

  # ----------------------------------------------------------------------------------------------------------------
  setAppStoreReceipt: (receipt, writeFile = true)->

    super
  
    if writeFile
      # Now write receipt
      if (status = this.writeReceiptFile(receipt, this.getReceiptFileVersionNum() + 1))
        @receiptFileVersionNum++

    status

  # ----------------------------------------------------------------------------------------------------------------
  getReceiptFile: (versionNum = @receiptFileVersionNum)->

    receiptFile = Ti.Filesystem.getFile(this.getDirectory(), this.makeFilename(versionNum))

    if not receiptFile.exists()
      receiptFile = null

    receiptFile

  # ----------------------------------------------------------------------------------------------------------------
  readReceiptFile: (versionNum)->

    text = null

    if (receiptFile = this.getReceiptFile(versionNum))?
      text = receiptFile.read().toString()

      try
        receipt = JSON.parse(text)
      catch e
        this.reportError("Could not parse receipt file (#{this.makeFilename(versionNum)})")
        receipt = null

    receipt
  
  # ----------------------------------------------------------------------------------------------------------------
  writeReceiptFile: (receipt, versionNum)->

    receiptFile = Ti.Filesystem.getFile(this.getDirectory(), this.makeFilename(versionNum))

    if not receiptFile.exists()
      receiptFile.createFile()
      receiptFile.setRemoteBackup(true)

      try
        text = JSON.stringify(receipt)
      catch e
        this.reportError("Could not write receipt file (JSON) (#{this.makeFilename(versionNum)})")
        text = null

    if text?
      receiptFile.write(text, true)

    @receiptFileTimestamp = null

    true

  # ----------------------------------------------------------------------------------------------------------------
  makeFilename: (version = this.getReceiptFileVersionNum())->

    "v--#{version}--#{this.getProductID()}.receipt"

  # ----------------------------------------------------------------------------------------------------------------
  matchFilename: (filename)->

    if filename.match(/^v--[0-9]+--(.)+.receipt$/g)?
      this.extractVersionNumberFromFilename(filename)
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  extractVersionNumberFromFilename: (filename)->

    id = null

    p = "v--"
    if (i = filename.indexOf(p)) is 0
      s = filename.substr(i + p.length)
      if (i = s.indexOf("--")) > -1
        id = s.substr(0, i)

    id

  # ----------------------------------------------------------------------------------------------------------------
  findLatestReceiptFile: ()->

    directory = this.getDirectory()

    d = Ti.Filesystem.getFile(directory)

    if not d.exists()
      d.createDirectory()

    dirList = d.getDirectoryListing()

    versions = []
    for f in dirList
      if (versionNum = this.matchFilename(f))?
        Hy.Trace.debug "ManagedPurchaseItem::findLatestReceiptFile (file=#{f} version=#{versionNum})"
        versions.push versionNum

    foundVersion = if _.size(v = _.sortBy(versions, (v)=>v)) > 0
      parseInt(_.last(v))
    else
      null
    
  # ----------------------------------------------------------------------------------------------------------------
  getReceiptFileTimestamp: ()->

    if not @receiptFileTimestamp?
      if (receiptFile = this.getReceiptFile())?
        @receiptFileTimestamp = receiptFile.createTimestamp()

    @receiptFileTimestamp
  
# ==================================================================================================================
class LimitedDurationPurchaseItem extends ManagedPurchaseItem

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (productID, reference, displayName, @durationDays)->

    super productID, reference, displayName

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDurationDays: ()-> @durationDays

  # ----------------------------------------------------------------------------------------------------------------
  verifyReceipt: (receipt)->

    if (isExpired = this.isExpired())? then not isExpired else false

  # ----------------------------------------------------------------------------------------------------------------
  getAgeInDays: ()->

    ageInDays = if (receiptFileTimestamp = this.getReceiptFileTimestamp())?
      ((new Date().getTime()) - receiptFileTimestamp.getTime()) / (60 * 60 * 24 * 1000)
    else
      null

    ageInDays

  # ----------------------------------------------------------------------------------------------------------------
  # Returns null if no active/valid subscription, or the number of days (rounded up) remaining
  #
  getRemainingDays: ()->

    remainingDays = if (ageInDays = this.getAgeInDays())?
      this.getDurationDays() - ageInDays
    else
      null
            
    Hy.Trace.debug "LimitedDurationPurchaseItem::getRemainingDays (age (days):#{ageInDays} remaining (days):#{remainingDays})"

    if remainingDays?    
      remainingDays = Math.ceil(remainingDays)
  
    remainingDays

  # ----------------------------------------------------------------------------------------------------------------
  isExpired: ()->

    if (remainingDays = this.getRemainingDays())?
      remainingDays <= 0
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  isPurchased: ()->

    super and if (isExpired = this.isExpired())? then not isExpired else false

# ==================================================================================================================
class CommerceManager

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @init: ()->
  
    if not gInstance?
      gInstance = new CommerceManager()

    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @addManagedFeature: (purchaseItem)->

    if (manager = CommerceManager.get())?
      manager.addManagedFeature(purchaseItem)

    null

  # ----------------------------------------------------------------------------------------------------------------
  @inventoryManagedFeatures: ()->

    if (manager = CommerceManager.get())?
      manager.inventoryManagedFeatures()

    null

  # ----------------------------------------------------------------------------------------------------------------
  @writeLog: ()->

    Session.writeLog()

  # ----------------------------------------------------------------------------------------------------------------
  @accountEnabledForPurchase: ()->
    Hy.IAP.PurchaseService.canMakePayments()

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->
    
    @managedFeatures = []

    @iapInventory = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  addManagedFeature: (purchaseItem)->

    @managedFeatures.push purchaseItem

  # ----------------------------------------------------------------------------------------------------------------
  inventoryManagedFeatures: ()->

    fnPreCallback = ()=>_.select(@managedFeatures, (f)=>not f.hasAppStoreInventoryInfo())

    fnPostCallback = (status, errorMessage, inventoriedItems)=>
      Hy.Trace.debug "CommerceManager::inventoryManagedFeatures (DONE)"

    Hy.Trace.debug "CommerceManager::inventoryManagedFeatures (features=#{_.size(@managedFeatures)})"

    @iapInventory = new Hy.Commerce.InventorySession(fnPreCallback, fnPostCallback)

    this


# ==================================================================================================================
# assign to global namespace:
Hy.Commerce =
  InventorySession : InventorySession
  PurchaseSession  : PurchaseSession
  PurchaseItem : PurchaseItem
  ManagedPurchaseItem : ManagedPurchaseItem
  UnmanagedPurchaseItem : UnmanagedPurchaseItem
  LimitedDurationPurchaseItem: LimitedDurationPurchaseItem
  CommerceManager: CommerceManager
  RestoreSession: RestoreSession
  Session: Session


