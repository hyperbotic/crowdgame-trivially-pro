# For now, only supports Appcelerator's interface to the Apple App Store. When the time comes to support
# other platforms/stores, we'll sublclass these classes appropriately

# Breaking changes in StoreKit 2.x.x

# It was previously possible for a transaction to complete after the application had been moved to the 
# background due to the app store needing to obtain information from the user. Although your application 
# may have received a FAILED notification when your application was moved to the background, your application
# would not have received a PURCHASED notification if the user completed the transaction from the app store. 
# In order to support this situation, purchase notifications are now sent to your application as an event 
# rather than through a callback.

# If you are upgrading from an earlier version of this module (prior to version 2.0.0) you should be aware of
# the following breaking changes to the API:
#
# The purchase function no longer returns a Ti.Storekit.Payment object.
# The callback parameter has been removed from the purchase function. You must now register an event 
# listener for the transactionState event to receive notification of FAILED and PURCHASED transaction events.
# The payment property is no longer returned as part of the transaction complete notification.
#

# ==================================================================================================================
# 
class AppStoreEvent extends Hy.Network.NetworkEvent

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    super

    @errorMessage = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  getErrorMessage: ()-> @errorMessage

  # ----------------------------------------------------------------------------------------------------------------
  setErrorMessage: (errorMessage)->
    @errorMessage = errorMessage

  # ----------------------------------------------------------------------------------------------------------------
  clearErrorMessage: ()->
    @errorMessage = null

  # ----------------------------------------------------------------------------------------------------------------
  send: ()->
    super
    this.clearErrorMessage()

    this

  # ----------------------------------------------------------------------------------------------------------------
  response: ()->
    super
    this

  # ----------------------------------------------------------------------------------------------------------------
  timedout: ()->
    super
    this

# ==================================================================================================================
# 
class AppStoreInventoryCheck extends AppStoreEvent

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    Hy.Trace.debug "AppStoreInventoryCheck::constructor"

    super

    @productRequest = null
    @inventoryResponse = null

    @requestedProducts = null

    @validProducts = []

  # ----------------------------------------------------------------------------------------------------------------
  setRequestedProducts: (requestedProducts)->

    Hy.Trace.debug "AppStoreInventoryCheck::setRequestedProducts (products=#{_.size(requestedProducts)})"

    @requestedProducts = []
    for z in requestedProducts
      @requestedProducts.push z
      Hy.Trace.debug "AppStoreInventoryCheck::setRequestedProducts (product=#{z})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  getRequestedProducts: ()-> @requestedProducts

  # ----------------------------------------------------------------------------------------------------------------
  getValidProducts: ()-> @validProducts

  # ----------------------------------------------------------------------------------------------------------------
  setValidProducts: (products)->
    @validProducts = products

  # ----------------------------------------------------------------------------------------------------------------
  send: ()->

    Hy.Trace.debug "AppStoreInventoryCheck::send"

    state = Hy.Network.NetworkServiceEventState.SendError

    @productRequest = Hy.IAP.storekit.requestProducts(this.getRequestedProducts(), (e)=>(this.response(e)))

    if @productRequest?
      state = Hy.Network.NetworkServiceEventState.Sent

    this.setState(state)

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  response: (e)->

    # success[boolean]: Whether or not the request succeeded 
    # message[string]: If the request failed, the reason why 
    # products[array]: An array of Ti.Storekit.Product objects which represent the valid products retrieved 
    # invalid[array]: An array of identifiers passed to the request that did not correspond to a product ID.
    #                 Changed with 1.5: Only present when at least one requested product is invalid.

    Hy.Trace.debug "AppStoreInventoryCheck::response (success=#{e.success})"

    state = Hy.Network.NetworkServiceEventState.CompletedSuccess
    
    @inventoryResponse = e

    if e.success
      if e.invalid?
        for p in e.invalid
          Hy.Trace.debug "AppStoreInventoryCheck::response (INVALID product=#{p})"

      for p in e.products
        Hy.Trace.debug "AppStoreInventoryCheck::response (product=#{p.title}/#{p.identifier})"

      this.setValidProducts(e.products)
      
    else
      state = Hy.Network.NetworkServiceEventState.CompletedError
      this.setErrorMessage(e.message)
    
    this.setState(state)

    super

    this.doFnPost()

    null # Event handlers should return null or other non-objects, I think

  # ----------------------------------------------------------------------------------------------------------------
  timedout: ()->
    this.setErrorMessage("No response from AppStore while collecting product inventory. Will try again shortly.")
    super
    this


# ==================================================================================================================
# 
class AppStorePurchase extends AppStoreEvent

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@product)->

#    use this for StoreKit 1.6 and above
    Hy.IAP.storekit.receiptVerificationSandbox = AppStorePurchase.checkSandboxFlag()

    shouldVerifyReceipt = AppStoreReceiptCheck.shouldVerifyReceipt()
      
    @payment = null
    @listener = null
    super

  # ----------------------------------------------------------------------------------------------------------------
  @checkSandboxFlag: ()->

    Hy.Update.FlagUpdate.checkBooleanFlag("flag1", Hy.Config.Commerce.StoreKit.kUseSandbox)

  # ----------------------------------------------------------------------------------------------------------------
  # Version 1.6 of StoreKit
  send16: ()->

    Hy.Trace.debug "AppStorePurchase::send16"

    state = Hy.Network.NetworkServiceEventState.SendError

    @payment = Hy.IAP.storekit.purchase(@product.getReference(), (e)=>this.response16(e))

    if @payment?
      state = Hy.Network.NetworkServiceEventState.Sent

    this.setState(state)

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Version 2.1.1 of StoreKit
  send: ()->

    Hy.Trace.debug "AppStorePurchase::send211 (sandbox=#{Hy.IAP.storekit.receiptVerificationSandbox})"

    @listener = (e)=>this.response(e)
    Hy.IAP.storekit.addEventListener('transactionState', @listener)

    state = Hy.Network.NetworkServiceEventState.SendError

    Hy.IAP.storekit.purchase(@product.getReference())

    state = Hy.Network.NetworkServiceEventState.Sent

    this.setState(state)

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  response16: (e)->

    # Pre StoreKit 2.x:
    # payment[object]: The Ti.Storekit.Payment object associated with the purchase 
    # state[int]: A constant specifying the state
    #   For state Ti.Storekit.FAILED: 
    #     cancelled[boolean]: Whether the failure is due to cancellation of the request or not 
    #     message[string]: If not cancelled, what the error message is
    #   For state Ti.Storekit.PURCHASED or Ti.Storekit.RESTORED: 
    #     date[date]: Transaction date 
    #     identifier[string]: The transaction identifier 
    #     receipt[object]: A blob of type "text/json" which contains the receipt information for the purchase.
    

    Hy.Trace.debug "AppStorePurchase::response (status=#{e.state})"

    state = null

    switch e.state
      when Hy.IAP.storekit.FAILED
        Hy.Trace.debug("AppStorePurchase::response (FAILED canceled= #{e.cancelled} #{e.message})", true)
        this.setErrorMessage("Sorry - couldn\'t complete purchase. Please try again later.")
        state = Hy.Network.NetworkServiceEventState.CompletedError

      when Hy.IAP.storekit.PURCHASED, Hy.IAP.storekit.RESTORED
        Hy.Trace.debug("AppStorePurchase::response (SUCCESS)")
        state = Hy.Network.NetworkServiceEventState.CompletedSuccess
        @purchaseInfo = e

      else
        Hy.Trace.debug "AppStorePurchase::response (WAITING status=#{e.state})"

    if state?
      this.setState(state)
      super
      this.doFnPost()

    null

  # ----------------------------------------------------------------------------------------------------------------
  response: (e)->

    # Occurs if you call Ti.Storekit.purchase and the purchase request's state changes. 
    # The following event information will be provided:
    #
    # state[int]: The current state of the transaction; either 
    #             Ti.Storekit.FAILED, Ti.Storekit.PURCHASED, Ti.Storekit.PURCHASING, or Ti.Storekit.RESTORED
    # quantity[int]: The number of items purchased or requested to purchase.
    # productIdentifier[string]: The product's identifier in the in-app store.
    #
    # For state Ti.Storekit.FAILED, the following additional information will be provided:
    #   cancelled[boolean]: Whether the failure is due to cancellation of the request or not
    #   message[string]: If not cancelled, what the error message is
    #
    # For state Ti.Storekit.PURCHASED and Ti.Storekit.RESTORED, the following additional information 
    #   will be provided:
    #
    #   date[date]: Transaction date
    #   identifier[string]: The transaction identifier
    #   receipt[object]: A blob of type "text/json" which contains the receipt information for the purchase.

    Hy.Trace.debug "AppStorePurchase::response211 (status=#{e.state})"

    state = null

    switch e.state
      when Hy.IAP.storekit.FAILED
        Hy.Trace.debug("AppStorePurchase::response (FAILED canceled= #{e.cancelled} #{e.message})", true)
        this.setErrorMessage(if e.cancelled then "Sorry - you canceled the transaction." else "Sorry - couldn\'t complete purchase. Please try again later.")
        state = Hy.Network.NetworkServiceEventState.CompletedError

      when Hy.IAP.storekit.PURCHASED, Hy.IAP.storekit.RESTORED
        Hy.Trace.debug("AppStorePurchase::response (SUCCESS)")
        state = Hy.Network.NetworkServiceEventState.CompletedSuccess
        @purchaseInfo = e

      else
        Hy.Trace.debug "AppStorePurchase::response (WAITING status=#{e.state})"

    if state?

      if @listener?
        Hy.IAP.storekit.removeEventListener('transactionState', @listener)
        @listener = null

      this.setState(state)
      super
      this.doFnPost()

    null

  # ----------------------------------------------------------------------------------------------------------------
  timedout: ()->
    this.setErrorMessage("No response from AppStore during Purchase transaction. Please try again later.")
    super
    this

# ==================================================================================================================
# 
class AppStoreReceiptCheck extends AppStoreEvent

  # ----------------------------------------------------------------------------------------------------------------
  # @purchaseInfo is a TiStorekitPayment
  #
  constructor: (@purchaseInfo)->

    Hy.Trace.debug "AppStoreReceiptCheck::constructor (#{if @purchaseInfo? then @purchaseInfo else "?"})"
  
    @receiptRequest = null
    @receiptResponse = null
    @receiptIdentifier = null

    super

  # ----------------------------------------------------------------------------------------------------------------
  @shouldVerifyReceipt: ()->

    Hy.Update.FlagUpdate.checkBooleanFlag("flag2", Hy.Config.Commerce.StoreKit.kVerifyReceipt)

  # ----------------------------------------------------------------------------------------------------------------
  # For StoreKit version 1.5
  send15: ()->

    useSandbox = AppStorePurchase.checkSandboxFlag()

    Hy.Trace.debug "AppStoreReceiptCheck::send15 (sandbox=#{useSandbox})"

    state = Hy.Network.NetworkServiceEventState.SendError

    # Takes one argument, a dictionary with the following values:
    #   receipt[blob]:                    A receipt retrieved from a call to Ti.Storekit.purchase's 
    #                                     callback evt.receipt.
    #   callback[function]:               A function to be called when the verification request completes.
    #   sandbox[bool, defaults to false]: Whether or not to use Apple's Sandbox verification server.
    #   sharedSecret[string, optional]:   The shared secret for your app that you creates in iTunesConnect; 
    #                                     required for verifying auto-renewable subscriptions.

    r = 
      receipt: @purchaseInfo.receipt
      callback: (e)=>this.response(e)
      sandbox: useSandbox

#    signature changed after 1.0
#    @receiptRequest = Hy.IAP.storekit.verifyReceipt(@purchaseInfo, (e)=>this.response(e))

    @receiptRequest = Hy.IAP.storekit.verifyReceipt(r)

    if @receiptRequest?
      state = Hy.Network.NetworkServiceEventState.Sent

    this.setState(state)

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  # For StoreKit version 1.6.0
  #
  send: ()->

    useSandbox = AppStorePurchase.checkSandboxFlag()

    Hy.Trace.debug "AppStoreReceiptCheck::send16 (sandbox=#{useSandbox})"

    state = Hy.Network.NetworkServiceEventState.SendError

    # storekit 1.6:
    # Takes one argument, a dictionary with the following values:
    #   identifier[string]:               The transaction identifier
    #   receipt[blob]:                    A receipt retrieved from a call to Ti.Storekit.purchase's callback evt.receipt.
    #   quantity[int]:                    The number of items purchased
    #   productIdentifier[string]:        The product's identifier in the in-app store
    #
    #  Setting the callback in the argument dictionary has been DEPRECATED. Pass the callback as the 2nd parameter to verifyReceipt.
    #  Setting the sandbox property in the argument dictionary has been DEPRECATED. Use the 'receiptVerificationSandbox' property for the module.
    #

    Hy.Trace.debug "AppStoreReceiptCheck::send (purchaseInfo: #{JSON.stringify(@purchaseInfo)})"
    Hy.Trace.debug "AppStoreReceiptCheck::send (Sandbox: #{Hy.IAP.storekit.receiptVerificationSandbox})"

    purchaseInfo = 
      identifier:        @purchaseInfo.identifier
      receipt:           @purchaseInfo.receipt
      quantity:          @purchaseInfo.quantity
      productIdentifier: @purchaseInfo.productIdentifier

    @receiptRequest = Hy.IAP.storekit.verifyReceipt(purchaseInfo, (e)=>this.response(e))

    if @receiptRequest?
      state = Hy.Network.NetworkServiceEventState.Sent

    this.setState(state)

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  response: (e)->

    # success[boolean]: Whether or not the request succeeded
    # valid[boolean]: Whether or not the receipt is valid
    # receipt[string]: The receipt identifier
    # message[string]: If success is false, the error message

    # StoreKit 2.1.1
    
    # success[boolean]: Whether or not the request succeeded
    # valid[boolean]: Whether or not the receipt is valid
    # message[string]: If success or valid is false, the error message
    # identifier[string]: The transaction identifier
    # receipt[object]: A blob of type "text/json" which contains the receipt information for the purchase.
    # quantity[int]: The number of items purchased
    # productIdentifier[string]: The product's identifier in the in-app store.

    @receiptResponse = e

    Hy.Trace.debug "AppStoreReceiptCheck::response (success=#{e.success})"

    state = Hy.Network.NetworkServiceEventState.CompletedSuccess

    if e.success
      if e.valid
        s = "Receipt verified: quantity=#{e.receipt.quantity} productId=#{e.receipt.product_id}"
        Hy.Trace.debug "Receipt::response (#{s})"
        @receiptIdentifier = e.receipt
      
      else
        this.setErrorMessage("Sorry - Couldn\'t verify purchase. Please contact #{Hy.Config.Support.email}")
    else
      this.setErrorMessage(e.message)

    if not @receiptIdentifier?
      state = Hy.Network.NetworkServiceEventState.CompletedError

    ## TESTING - REMOVE LINE BELOW WHEN DONE
    #state = Hy.Network.NetworkServiceEventState.CompletedError

    this.setState(state)

    super

    this.doFnPost()

    null

  # ----------------------------------------------------------------------------------------------------------------
  timedout: ()->
    this.setErrorMessage("No response from AppStore while validating purchase Receipt. Please try again.")
    super
    this

# ==================================================================================================================
# 
class AppStoreRestoreTransactions extends AppStoreEvent

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    Hy.Trace.debug "AppStoreRestoreTransactions::constructor"

    @listener = null
    @restoreRequest = null
    @transactions = null

    super

  # ----------------------------------------------------------------------------------------------------------------
  send: ()->

    Hy.Trace.debug "AppStoreRestoreTransactions::send"

    state = Hy.Network.NetworkServiceEventState.SendError

    @listener = (e)=>this.response(e)
    Hy.IAP.storekit.addEventListener('restoredCompletedTransactions', @listener)

    @restoreRequest = Hy.IAP.storekit.restoreCompletedTransactions()

    state = Hy.Network.NetworkServiceEventState.Sent

    this.setState(state)

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  response: (e)->

    Hy.Trace.debug "AppStoreRestoreTransactions::response (success=#{e.error})"

    if @listener?
      Hy.IAP.storekit.removeEventListener('restoredCompletedTransactions', @listener)
      @listener = null

    # OLD
    # error[string]: An error message, if one was encountered.
    # transactions[array]: If no errors were encountered, all of the transactions that were restored.
    #  Each transaction can contain the following properties:
    #   state[int]: The current state of the transaction; most likely To.Storekit.RESTORED.
    #   identifier[string]: A string that uniquely identifies a successful payment transaction.
    #   productIdentifier[string]: A string used to identify a product that can be purchased from within your application.
    #   quantity[int]: The number of items the user wants to purchase.
    #   date[date]: The date the transaction was added to the App Store's payment queue.
    
    # NEW (storekit 1.2)
    #
    # The following event information will be provided:
    #
    # error[string]:       An error message, if one was encountered.
    # transactions[array]: If no errors were encountered, all of the transactions that were restored.
    #
    # Each transaction can contain the following properties:
    #
    #   state[int]:                The current state of the transaction; most likely To.Storekit.RESTORED.
    #   identifier[string]:        A string that uniquely identifies a successful payment transaction.
    #   productIdentifier[string]: A string used to identify a product that can be purchased 
    #                              from within your application.
    #   quantity[int]:             The number of items the user wants to purchase.
    #   date[date]:                The date the transaction was added to the App Store's payment queue.
    #   receipt[object]:           A blob of type "text/json" which contains the receipt information 
    #                              for the purchase.
    #  We add "success" for abstraction purposes

    state = Hy.Network.NetworkServiceEventState.CompletedSuccess
    @results = []

    if e.error?
      this.setErrorMessage(e.error)
      state = Hy.Network.NetworkServiceEventState.CompletedError
    else
      @transactions = e.transactions

      if @transactions?
        for t in @transactions
          t.success = t.state is Hy.IAP.storekit.RESTORED
          @results.push t
          Hy.Trace.debug "AppStoreRestoreTransactions::response (success=#{t.success} #{t.identifier} #{t.productIdentifier})"
          Hy.Trace.debug "AppStoreRestoreTransactions::response (state=#{t.state} identifier=#{t.identifier} productIdentifier=#{t.productIdentifier} quantity=#{t.quantity} date=#{t.date})"

    this.setState(state)

    super

    this.doFnPost()

    null

  # ----------------------------------------------------------------------------------------------------------------
  timedout: ()->
    this.setErrorMessage("No response from AppStore while restoring purchases. Please try again.")
    super
    this

  # ----------------------------------------------------------------------------------------------------------------
  getLog: ()->

   log = {}
   log.errorMessage= this.getErrorMessage()
   log.transactions = []

   if @transactions?
     for t in @transactions
       l = {}
       l[field] = value for field, value of t
       log.transactions.push l

   return log

#
# ==================================================================================================================
# 
class AppStoreProduct

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@reference, @priceFormatted, @identifier, @title)->
    Hy.Trace.debug "AppStoreProduct::constructor (#{this.dumpStr()})"
    this

  # ----------------------------------------------------------------------------------------------------------------
  getReference: ()-> @reference

  # ----------------------------------------------------------------------------------------------------------------
  getPrice: ()-> @priceFormatted

  # ----------------------------------------------------------------------------------------------------------------
  getIdentifier: ()-> @identifier

  # ----------------------------------------------------------------------------------------------------------------
  getTitle: ()-> @title

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    "AppStoreProduct: identifier=#{this.getIdentifier()} title=#{this.getTitle()} price=#{this.getPrice()}"

# ==================================================================================================================
# 
class ReceiptService

  # ----------------------------------------------------------------------------------------------------------------
  @create: (fnPost, reference, purchaseInfo)->

    r = new ReceiptService(fnPost, reference, purchaseInfo)

    if not r.verify()
      r = null

    return r    

  # ----------------------------------------------------------------------------------------------------------------
  @shouldVerifyReceipt: ()->

    AppStoreReceiptCheck.shouldVerifyReceipt()

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@fnPost, @reference, @purchaseInfo)->

    @receiptIdentifier = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  verify: ()->

    status = true

    fPost = (event, status)=>this.verifyPostCallback(event, status)

    @event = new AppStoreReceiptCheck(@purchaseInfo)
    @event.setFnPost(fPost)

    @event.setInitialDelay(0)
    @event.setTimeout(Hy.Config.Commerce.kReceiptTimeout)

    if not @event.enqueue()
      Hy.Trace.debug "ReceiptService::verify (COULD NOT ENQUEUE EVENT)"
      status = false

    return status

  # ----------------------------------------------------------------------------------------------------------------
  verifyPostCallback: (event, success)->

    Hy.Trace.debug "ReceiptService::verifyPostCallback (#{success})"

    if success
      @receiptIdentifier = event.receiptIdentifier

    f = ()=>@fnPost(event.getErrorMessage(), @reference, @receiptIdentifier)

    if @fnPost?
      Hy.Utils.PersistentDeferral.create 0, f
    
    null

  # ----------------------------------------------------------------------------------------------------------------
  getLog: ()->
    Hy.Trace.debug "ReceiptService::getLog"

    log = {}
#    log.reference = @reference
    log.puchaseInfo = @purchaseInfo

    if @receiptIdentifier?
      log.receiptQuantity = @receiptIdentifier.quantity
      log.receiptProduct_id = @receiptIdentifier.product_id
    
    return log

# ==================================================================================================================
# 
class InventoryService

  # ----------------------------------------------------------------------------------------------------------------
  # fnPre is a supplied callback which should return an array product ids to inventory.
  # fnPost is a callback which will be passed: 
  #   boolean (true if successful)
  #   string (error message if non-null)
  #   array (of successfully inventoried product ids)

  @create: (fnPre, fnPost)->

    t = new InventoryService(fnPre, fnPost)
    if not t.schedule()
      t = null

    return t
  
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@fnPre, @fnPost)->

    Hy.Trace.debug "InventoryService::constructor"
  
    InventoryService.gInstance = this

    @event = null

    this   

  # ----------------------------------------------------------------------------------------------------------------  
  schedule: ()->
    Hy.Trace.debug "InventoryService::schedule"
  
    status = true

    fPre = (event, status)=>this.requestProductsPreCallback(event, status)
    fPost = (event, status)=>this.requestProductsPostCallback(event, status)

    @event = new AppStoreInventoryCheck()
    @event.setFnPre(fPre)
    @event.setFnPost(fPost)

    @event.setInitialDelay(0)
    @event.setRecurringDelay(Hy.Config.Content.kInventoryInterval)
    @event.setSendLimit(-1)
    @event.setTimeout(Hy.Config.Content.kInventoryTimeout)

    if not @event.enqueue()
      Hy.Trace.debug "InventoryService::scheduleInventoryCheck (COULD NOT ENQUEUE EVENT)"
      status = false

    return status

  # ----------------------------------------------------------------------------------------------------------------
  doImmediate: ()->

    @event?.setImmediate()

  # ----------------------------------------------------------------------------------------------------------------
  requestProductsPreCallback: (event, status)->
    Hy.Trace.debug "InventoryService::requestProductsPreCallback"

    stat = false

    if @fnPre?
      products = @fnPre()
      if _.size(products)>0
        event.setRequestedProducts(products)
        stat = true

    return stat

  # ----------------------------------------------------------------------------------------------------------------
  requestProductsPostCallback: (event, success)->

    # event.validProducts: products which checked out valid in the app store
    # event.getErrorMessage: error message if failed

    requestedProducts = event.getRequestedProducts()

    Hy.Trace.debug "InventoryService::requestProductsPostCallback (status=#{success} valid products=#{_.size(event.getValidProducts())} requested products=#{_.size(requestedProducts)})"
  
    results = []

    if success
      for p in event.getValidProducts()
        Hy.Trace.debug "InventoryService::requestProductsPostCallback (product=#{p.title}/#{p.identifier})"

        if _.indexOf(requestedProducts, p.identifier) isnt -1
          results.push new AppStoreProduct(p, p.formattedPrice, p.identifier, p.title)

    else
      Hy.Trace.debug "Transaction::requestProductsPostCallback (ERROR #{event.getErrorMessage()})"

    f = ()=>@fnPost(success, event.getErrorMessage(), results)

    if @fnPost?
      Hy.Utils.PersistentDeferral.create 0, f

    null

# ==================================================================================================================
# 
class PurchaseService

  # ----------------------------------------------------------------------------------------------------------------
  @canMakePayments: ()->
    return Hy.IAP.storekit.canMakePayments

  # ----------------------------------------------------------------------------------------------------------------
  #
  @create: (fnPost, product, reference)->

    t = null

    if PurchaseService.canMakePayments()
      t = new PurchaseService(fnPost, product, reference)
    else
      Hy.Trace.debug "PurchaseService::create (ERROR CAN\'T MAKE PAYMENTS)"

    return t
  
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@fnPost, @product, @reference)->

    Hy.Trace.debug "PurchaseService::constructor (#{@product.dumpStr()})"
  
    @receipt = null
    @purchaseInfo = null

    this   

  # ----------------------------------------------------------------------------------------------------------------
  purchase: ()->

    Hy.Trace.debug "PurchaseService::purchase"

    status = true

    fPost = (event, status)=>this.purchaseCallback(event, status)

    @event = new AppStorePurchase(@product)
    @event.setFnPost(fPost)
    @event.setInitialDelay(0)
    @event.setTimeout(Hy.Config.Commerce.kPurchaseTimeout)

    if @event.enqueue()
      Hy.Trace.debug "PurchaseService::purchase (event enqueued)"
    else
      Hy.Trace.debug "PurchaseService::purchase (COULD NOT ENQUEUE EVENT)"
      status = false

    status

  # ----------------------------------------------------------------------------------------------------------------
  purchaseCallback: (event, success)->

    Hy.Trace.debug "PurchaseService::purchaseCallback (#{success})"

    if success
      @purchaseInfo = event.purchaseInfo

    f = ()=>@fnPost(event.getErrorMessage(), @reference, @purchaseInfo)

    if @fnPost?
      Hy.Utils.PersistentDeferral.create 0, f
    
    null

  # ----------------------------------------------------------------------------------------------------------------
  getLog: ()->

   log = {}
   log.product = @product.getIdentifier()
   log.identifier = @purchaseInfo?.identifier
   log.date = @purchaseInfo?.date
   log.receipt = @purchaseInfo?.receipt

   return log

# ==================================================================================================================
# 
class RestoreTransactionsService

  # ----------------------------------------------------------------------------------------------------------------
  @create: (fnPost)->

    t = new RestoreTransactionsService(fnPost)

    return t
  
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@fnPost)->

    Hy.Trace.debug "RestoreTransactionsService::constructor"
  
    this   

  # ----------------------------------------------------------------------------------------------------------------
  restore: ()->

    status = true

    fPost = (event, status)=>this.restorePostCallback(event, status)

    @event = new AppStoreRestoreTransactions()
    @event.setFnPost(fPost)

    @event.setInitialDelay(0)
    @event.setTimeout(Hy.Config.Commerce.kRestoreTimeout)

    if not @event.enqueue()
      Hy.Trace.debug "RestoreTransactionsService::restore (COULD NOT ENQUEUE EVENT)"
      status = false

    return status

  # ----------------------------------------------------------------------------------------------------------------
  restorePostCallback:(event, status)->
    Hy.Trace.debug "RestoreTransactionsService::completedCallback (#{status})"

    f = ()=>@fnPost(event.getErrorMessage(), event.results)
            
    if @fnPost?
      Hy.Utils.PersistentDeferral.create 0, f
  
    null

  # ----------------------------------------------------------------------------------------------------------------
  getLog: ()->

    @event?.getLog()

# ==================================================================================================================
# 
# assign to global namespace:
Hy.IAP =
  InventoryService: InventoryService
  ReceiptService: ReceiptService
  PurchaseService: PurchaseService
  RestoreTransactionsService: RestoreTransactionsService
  storekit : null #require('ti.storekit') 1.4.0


