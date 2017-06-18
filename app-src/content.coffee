class ContentIcon

  kContentPackIconFilenameSuffix = ".png"

  gInstances = []

  # ----------------------------------------------------------------------------------------------------------------
  @getDefaultIconSpec: ()->  "general"

  # ----------------------------------------------------------------------------------------------------------------
  @findByIconSpec: (iconSpec, directory = null)->

    if not (icon = _.detect(gInstances, (i)=>i.iconSpec is iconSpec))?
      icon = ContentIcon.findInDirectory(iconSpec, directory)

    icon

  # ----------------------------------------------------------------------------------------------------------------
  @findInDirectory: (iconSpec, directory = null)->

    filename = ContentIcon.getFilename(iconSpec)

    for dir in [directory, Hy.Config.Content.kDefaultIconDirectory]
      if dir?
        if ContentIcon.checkForIconFile(dir, filename)
          icon = new ContentIcon(iconSpec, dir, filename)

    icon

  # ----------------------------------------------------------------------------------------------------------------
  @find: (contentPack)->

    ContentIcon.findByIconSpec(contentPack.getIconSpec(), contentPack.getDirectory())
  
  # ----------------------------------------------------------------------------------------------------------------
  @writeFile: (contentPack, bits)->

    iconSpec = contentPack.getIconSpec()
    filename = ContentIcon.getFilename(iconSpec)
    directory = contentPack.getDirectory()

    Hy.Trace.debug "ContentIcon::writeFile (#{contentPack.getProductID()} #{bits?} #{directory}/#{filename})"

    f = Ti.Filesystem.getFile(directory, filename)

    if f.exists()
      Hy.Trace.debug "ContentIcon::writeFile (ALREADY EXISTS #{filename})"
#      f.deleteFile()
    else
      f.write(bits)
      f.setRemoteBackup(false) # Don't need to backup downloaded content icon files

    new ContentIcon(iconSpec, directory, filename)

  # ----------------------------------------------------------------------------------------------------------------
  @checkForIconFile: (directory, filename)->
    f = Ti.Filesystem.getFile(directory, filename)

    return f.exists()

  # ----------------------------------------------------------------------------------------------------------------
  @getFilename: (iconSpec)->

    density = switch Hy.UI.Device.getDensity()
      when "high"
        "@2x"
      else
        ""  
    name = iconSpec + density + ContentIcon.getFilenameSuffix()

    return name

  # ----------------------------------------------------------------------------------------------------------------
  @getFilenameSuffix: ()-> kContentPackIconFilenameSuffix

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@iconSpec, @directory, @filename)->

    gInstances.push this
    this

  # ----------------------------------------------------------------------------------------------------------------
  getPathname: ()->
    "#{@directory}/#{@filename}"

# ==================================================================================================================
class ContentPackPurchaseItem extends Hy.Commerce.UnmanagedPurchaseItem

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@contentPack)->

    super @contentPack.getProductID(), @contentPack, @contentPack.getProductID()

    this


# ==================================================================================================================
# 
# Some definitions:
#   "acquisition method": describes the relationship between this content and the user. Does not describe
#                         how the content ends up on the device.
#
#        Source:          content manifest
#        Mutability:      doesn't change
#        Values:          (props on class ContentAcquisitionMethod)
#             Included:   made available as part of the app purchase or offered later as part of an update
#             AppStore:   available for acquisition from an App Store
#             ThirdParty: made available through a 3rd-party
#
#   "Entitlement":        is this user entitled to this content? For instance, if the user has purchased 
#                         this content pack, then the user is entitled to it. Doesn't describe the 
#                         download state of the content, etc.
#        Source:          Not persistently stored. Set at runtime during a purchase. Determined at startup, etc
#                         if the content is local. We rely on the AppStore to keep us honest here if we 
#                         lose track of this.
#        Mutability:      changes when the user buys the content pack     
#        Values:          (props on class ContentEntitlement)
#            DontKnow:    we don't know at this time. See above notes re: not persistently stored.
#            Entitled:    the user has a "right" to this content (i.e., has bought it, or it's part of the app)
#            NotEntitled: the user doesn't have a right to it, but can take steps to get a 
#                         right to it (i.e., buy it)
#
#   "local":              is the content local on this device? (true or false)
#
#   "loaded":             is the content loaded from the filesystem and ready to be played? (true or false)
#
#   "selected" :          true if the user has selected this content for inclusion in the next contest. This 
#                         value is saved across sessions via Hy.Options.contentPacks.
#
#  Higher-level predicates
#
#   "isOKToDisplay":       true if we should show this content to the user... either because it's local or because
#                          it can be acquired.
#
#   "showPurchaseOption":  n/a for content other than AppStore content. 
#                          true for AppStore content that should be offered to the user for purchase
#
#   "isReadyForPurchase":  n/a for content other than AppStore content. 
#                          true for AppStore content if the content has been "inventoried" against the Store.
#                          (This inventory step is performed each time the app is started up.)
#   "isReadyForPlay":      true if the content is ready to play. This means, more or less, 
#                          that the content is local

class ContentAcquisitionMethod
  @Included    = 1
  @AppStore    = 2
  @ThirdParty  = 3

class ContentEntitlement
  @DontKnow    = -1
  @NotEntitled =  0
  @Entitled    =  1

# ==================================================================================================================
#
#  "id" must be globally unique (i.e., across all content packs)
# 
class ContentPack
 
  gCount = 0

  @kRequiredFields = ["kind", "filename", "directory", "contentFileKind", "productID", "version", "method", "numRecords", "longDescription", "displayName", "difficulty", "iconSpec", "order"]

  @kOptionalFields = ["sort", "description", "contentFile", "authorContactInfo", "authorVersionInfo", "formatting"]

  # ----------------------------------------------------------------------------------------------------------------
  @checkFields: (c, fieldList)->

    for field in fieldList
      if not c[field]?
        return field

    return null

  # ----------------------------------------------------------------------------------------------------------------
  @addHeaderProp: (header, kind, name, value)->
    switch kind
      when "content"
        header[name] = value
      when "customization"
        if not header._customizations?
          header._customizations = []
        header._customizations.push value

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Returns the content prop in object "header" that has "name". 
  #If "name" isnt specified, then returns an array of all content props
  #
  @getHeaderContentProp: (header, name = null)->

    value = if name?
      header[name]
    else
      arr = []
      for name, value of header
        if name isnt "_customizations"
          arr.push {name: name, value: value}
      arr

    value

  # ----------------------------------------------------------------------------------------------------------------
  @getHeaderCustomizationProps: (header)->
    props = if (c = header._customizations)?
      c
    else
      []

    props

  # ----------------------------------------------------------------------------------------------------------------
  @compareVersions: (a, b)->
    ContentPack.compareVersionNumbers(a.getVersion(), b.getVersion())

  # ----------------------------------------------------------------------------------------------------------------
  @compareVersionNumbers: (a, b)->
    result = 0

    if a > b
      result = 1
    else
      if a < b
        result = -1

    return result

  # ----------------------------------------------------------------------------------------------------------------
  @find: (productID, contentPacks=ContentManager.get().getContentPacks())->

    _.select(contentPacks, (c)=>c.getProductID() is productID)

  # ----------------------------------------------------------------------------------------------------------------
  @findByIndex: (index, contentPacks=ContentManager.get().getContentPacks())->

    _.detect(contentPacks, (c)=>c.getIndex() is index)

  # ----------------------------------------------------------------------------------------------------------------
  @findLatestVersionOKToDisplay: (productID)->

    ContentPack.findLatestVersion(productID, (c)=>c.isOKToDisplay())

  # ----------------------------------------------------------------------------------------------------------------
  @findLatestVersion: (productID, filterFn = null)->

    ContentPack.findLatestVersion_(ContentPack.find(productID), filterFn)

  # ----------------------------------------------------------------------------------------------------------------
  @findLatestVersion_: (versions, filterFn = null)->

    highestV = -1
    highestVcontentPack = null

    if filterFn?
      versions = _.select(versions, (c)=>filterFn(c))

    for c in versions
      v = parseInt c.version

      highestV = Math.max(v, highestV)

      if highestV is v
        highestVContentPack = c

    return highestVContentPack

  # ----------------------------------------------------------------------------------------------------------------
  @getUnpurchasedAppStoreContentPacks: (contentPacks=ContentManager.get().getLatestContentPacks())->

    _.select(contentPacks, ((c)=>c.isAppStoreContent() and not c.isEntitled()))

  # ----------------------------------------------------------------------------------------------------------------
  @getPurchasedAppStoreContentPacks: (contentPacks=ContentManager.get().getLatestContentPacks())->

    _.select(contentPacks, (c)=>c.isAppStoreContent() and (c.isEntitled()))

  # ----------------------------------------------------------------------------------------------------------------
  @findPurchasedAppStoreContentPack: (productID)->

    s = ContentPack.find(productID, ContentPack.getPurchasedAppStoreContentPacks(ContentManager.get().getContentPacks()))

    return s

  # ----------------------------------------------------------------------------------------------------------------
  # We inventory any AppStore content that hasn't been purchased and hasn't yet been inventoried
  #
  @getAppStoreContentPacksNeedingInventory: (contentPacks=ContentManager.get().getLatestContentPacks())->
    
    _.select(contentPacks, ((c)=>c.isAppStoreContent() and not c.isEntitled() and not c.hasAppStoreInventoryInfo()))

  # ----------------------------------------------------------------------------------------------------------------
  @getMaxContentFileSize: ()->

    Hy.Config.Content.kContentPackMaxBytes

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Currently only support deleting third-party content. Purchased Content isn't designed to be deleted
  # (due to logging in "initPurchaseState")
  #
  # Rely on caller to clean up the UI, etc
  #
  @delete: (contentPack)->

    status = false

    if contentPack? and contentPack.isThirdParty()
      # unselect
      contentPack.setSelected(false)

      # delete content file
      if (contentFile = contentPack.getContentFile())?
        ContentFile.delete(contentFile)

      # remove from manifest
      contentPack.getManifest().removeContentPack(contentPack)

    status

  # ----------------------------------------------------------------------------------------------------------------
  @deleteByProductID: (productID, filterFn = null)->

    contentPacks = _.select(ContentPack.find(productID), (c)=>if filterFn? then filterFn(c) else true)

    for contentPack in contentPacks
      ContentPack.delete(contentPack)

    null
    
  # ----------------------------------------------------------------------------------------------------------------
  @create: (manifest, contentPackSpec)->

    contentPack = null

    kind = contentPackSpec.kind

    if (error = ContentPack.checkFields(contentPackSpec, kind.kRequiredFields))?
      s = "ERROR missing field \"#{error}\" in (#{manifest.getDisplayName()})"
      new Hy.Utils.ErrorMessage("fatal", "Content Manifest", s) #will display popup dialog
    else
      contentPack = new kind(manifest, contentPackSpec)

    contentPack   

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@manifest, spec)->

    this.initializeFromSpec(spec)

    @index = ++gCount

    # True if an update is available for downloading
    @updateAvailable = false

    this.addIcon()

    this.setAcquisitionMethod(this.getAcquisitionMethod())

    # Is the file representing this content on this device?
    this.setLocal(this.checkForContentFile())

    # Has this content pack been loaded from its file representation?
    this.setLoaded(false)

    # Initialize purchase state
    this.initPurchaseState()

    # Initialize entitlement state
    this.initEntitlementState()

    # Did the user previously select this content pack for the next contest?
    this.loadSelectedFromAppOptions()

    this.resetContent()

    this    

  # ----------------------------------------------------------------------------------------------------------------
  initializeFromSpec: (spec)->

    # Initialize content-related properties
    for t in ["required", "optional"]
      for field in this.getFields(t)
        this[field] = ContentPack.getHeaderContentProp(spec, field)

    # Now look for customizations
    if (customizationSpecs = ContentPack.getHeaderCustomizationProps(spec)).length > 0
      @customization = new Hy.Customize(this, customizationSpecs)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getCustomization: ()-> @customization

  # ----------------------------------------------------------------------------------------------------------------
  hasCustomization: ()-> this.getCustomization()?

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> @kind

  # ----------------------------------------------------------------------------------------------------------------
  getManifest: ()-> @manifest

  # ----------------------------------------------------------------------------------------------------------------
  # Must be implemented by children
  #
  getSourceURL: ()-> null

  # ----------------------------------------------------------------------------------------------------------------
  getFields: (kind)->

    fields = switch kind
      when "required"
        ContentPack.kRequiredFields      
      when "optional"
        ContentPack.kOptionalFields      
      else
        null

    fields

  # ----------------------------------------------------------------------------------------------------------------
  getContentFileKind: ()-> @contentFileKind

  # ----------------------------------------------------------------------------------------------------------------
  getContentFile: ()-> 

    if not @contentFile?
      @contentFile = new (this.getContentFileKind())(this.getDirectory(), this.getFilename())

    @contentFile
    
  # ----------------------------------------------------------------------------------------------------------------
  addIcon: (icon = ContentIcon.find(this))-> # Might return null if no icon

    @icon = icon

  # ----------------------------------------------------------------------------------------------------------------
  getSort: ()-> if @sort? then @sort else -1

  # ----------------------------------------------------------------------------------------------------------------
  getProductID: ()-> @productID

  # ----------------------------------------------------------------------------------------------------------------
  getDescription: ()-> @description

  # ----------------------------------------------------------------------------------------------------------------
  getLongDescription: ()-> @longDescription

  # ----------------------------------------------------------------------------------------------------------------
  getLongDescriptionDisplay: ()->

    Hy.Utils.String.trimWithElipsis(this.getLongDescription(), Hy.Config.Content.kContentPackMaxLongDescriptionLength)

  # ----------------------------------------------------------------------------------------------------------------
  getIconSpec: ()-> @iconSpec

  # ----------------------------------------------------------------------------------------------------------------
  getIcon: ()-> @icon

  # ----------------------------------------------------------------------------------------------------------------
  getOrder: ()-> @order

  # ----------------------------------------------------------------------------------------------------------------
  isOrderRandom: ()-> this.getOrder() is "random"

  # ----------------------------------------------------------------------------------------------------------------
  isOrderSequential: ()-> this.getOrder() is "sequential"

  # ----------------------------------------------------------------------------------------------------------------
  getVersion: ()-> @version

  # ----------------------------------------------------------------------------------------------------------------
  getDirectory: ()-> @directory

  # ----------------------------------------------------------------------------------------------------------------
  getFilename: ()-> @filename

  # ----------------------------------------------------------------------------------------------------------------
  getIndex: ()-> @index

  # ----------------------------------------------------------------------------------------------------------------
  getDisplayName: ()-> @displayName

  # ----------------------------------------------------------------------------------------------------------------
  getAuthorContactInfo: ()-> @authorContactInfo

  # ----------------------------------------------------------------------------------------------------------------
  getAuthorVersionInfo: ()-> @authorVersionInfo

  # ----------------------------------------------------------------------------------------------------------------
  setAcquisitionMethod: (methodString)->

    @method = switch methodString
      when "included"
        ContentAcquisitionMethod.Included
      when "AppStore"
        ContentAcquisitionMethod.AppStore
      when "ThirdParty"
        ContentAcquisitionMethod.ThirdParty
      else
        null

    if not @method?
      s = "Unexpected content acquisition method: #{methodString}"
      new Hy.Utils.ErrorMessage("fatal", "ContentPack", s) #will display popup dialog

    this      

  # ----------------------------------------------------------------------------------------------------------------
  getAcquisitionMethod: ()-> @method

  # ----------------------------------------------------------------------------------------------------------------
  isAcquisitionMethod: (method)->

    method is this.getAcquisitionMethod()

  # ----------------------------------------------------------------------------------------------------------------
  isThirdParty: ()->

    this.isAcquisitionMethod(ContentAcquisitionMethod.ThirdParty)

  # ----------------------------------------------------------------------------------------------------------------
  isAppStoreContent: ()->

    this.isAcquisitionMethod(ContentAcquisitionMethod.AppStore)

  # ----------------------------------------------------------------------------------------------------------------
  # Should we show this content to the player?
  # - Does it have an icon?
  # - If included content, is it local?
  #
  isOKToDisplay: ()->

    ok = this.getIcon()? 

    ok = ok and switch this.getAcquisitionMethod()
      when ContentAcquisitionMethod.Included, ContentAcquisitionMethod.ThirdParty
        this.isLocal() # screw case: listed in a manifest that was successfully downloaded, but download of pack failed
      when ContentAcquisitionMethod.AppStore
        true # always show it    
      else
        false

    ok

  # ----------------------------------------------------------------------------------------------------------------
  isReadyForPlay: ()->

    this.isLocal()

  # ----------------------------------------------------------------------------------------------------------------
  showPurchaseOption: ()-> 

    Hy.Trace.debug "ContentPack::showPurchaseOption (#{this.dumpStr()})"

    ok = switch this.getAcquisitionMethod()
      when ContentAcquisitionMethod.AppStore
        if this.isEntitled() # Already purchased!?
          if this.isLocal()
            false
          else
            true # Screw case: for some reason, content isn't local but it should be.
        else
          true # We show even if it hasn't been inventoried yet. We'll check that at buy time
      else
        false

    ok

  # ----------------------------------------------------------------------------------------------------------------
  isReadyForPurchase: ()-> 

    ok = switch this.getAcquisitionMethod()
      when ContentAcquisitionMethod.AppStore
        if this.isEntitled() # Already purchased!?
          false
        else
          # yes if we have fresh inventory data
          this.hasAppStoreInventoryInfo()
      else
        false

    ok

  # ----------------------------------------------------------------------------------------------------------------
  initPurchaseState: ()->

    appStoreProductInfo = null

    # look in other versions of this content pack for clues as to its state
    purchasedPacks = ContentPack.findPurchasedAppStoreContentPack(@productID)
 
    if _.size(purchasedPacks)>0
      previousPurchase = _.first(purchasedPacks)
      appStoreProductInfo = previousPurchase.getAppStoreProductInfo()
    else
      appStoreProductInfo = new ContentPackPurchaseItem(this)
      
    this.setAppStoreProductInfo(appStoreProductInfo)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initEntitlementState: ()->

    @previousVersionWasPurchased = false

    if this.isAppStoreContent()

      # Look for other manifests for other versions of this contentPack which are entitled
      for contentPack in ContentPack.find(this.getProductID())
        if contentPack isnt this and contentPack.isEntitled()
          @previousVersionWasPurchased = true
          break

      # There's an edge case that we could recognize here:

      # Is there a version local on the device, perhaps due to this scenario: 
      # A new version of the app was installed with a ShippedManifest which specifies a newer version of AppStore content, 
      # which happened to already be owned by the user? 
      # In this case, it's possible that that older version isn't mentioned in any UpdateManifest. So it's 
      # just sitting there... a version not mentioned in the (updated) ShippedManifest or in any UpdateManifests. But the
      # user is still entitled to it.
      #

      # We try to catch this in ContentManager.doRequiredUpdate.

    this

  # ----------------------------------------------------------------------------------------------------------------
  getPreviousVersionWasPurchased: ()->

    @previousVersionWasPurchased

  # ----------------------------------------------------------------------------------------------------------------
  getEntitlement: ()->

    entitlement = switch this.getAcquisitionMethod()

      when ContentAcquisitionMethod.Included
         ContentEntitlement.Entitled

      when ContentAcquisitionMethod.AppStore
        # Since we don't directly persist this info, look for clues
        # -- if the content is local, that's a pretty clear sign
        # -- if there's an App Store receipt
        # -- if there's a previous version that was purchased
        #
        if this.isLocal() or this.hasAppStoreReceipt() or this.getPreviousVersionWasPurchased()
          ContentEntitlement.Entitled
        else
          ContentEntitlement.NotEntitled

      when ContentAcquisitionMethod.ThirdParty
        if this.isLocal()
          ContentEntitlement.Entitled
        else
          ContentEntitlement.NotEntitled

      else
        ContentEntitlement.DontKnow

    entitlement

  # ----------------------------------------------------------------------------------------------------------------
  isEntitled: ()->

    this.getEntitlement() is ContentEntitlement.Entitled

  # ----------------------------------------------------------------------------------------------------------------
  # This is set with info obtained via an Inventory, which we do every time the app starts up
  #
  setAppStoreProductInfo: (appStoreProductInfo)->

    @appStoreProductInfo = appStoreProductInfo

  # ----------------------------------------------------------------------------------------------------------------
  getAppStoreProductInfo: ()-> @appStoreProductInfo

  # ----------------------------------------------------------------------------------------------------------------
  hasAppStoreProductInfo: ()-> this.getAppStoreProductInfo()?

  # ----------------------------------------------------------------------------------------------------------------
  hasAppStoreInventoryInfo: ()->

    this.hasAppStoreProductInfo()? and this.getAppStoreProductInfo().hasAppStoreInventoryInfo()

  # ----------------------------------------------------------------------------------------------------------------
  getAppStoreReceipt: ()-> 

    if this.hasAppStoreProductInfo()?
      this.getAppStoreProductInfo().getAppStoreReceipt()
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  hasAppStoreReceipt: ()-> 

    this.getAppStoreReceipt()?

  # ----------------------------------------------------------------------------------------------------------------
  clearAppStoreReceipt: ()->

    if this.hasAppStoreProductInfo()?
      this.getAppStoreProductInfo().clearAppStoreReceipt()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDisplayPrice: ()->

    if this.hasAppStoreProductInfo()
      this.getAppStoreProductInfo().getDisplayPrice()
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  setLocal: (local)->
 
    @local = local

  # ----------------------------------------------------------------------------------------------------------------
  isLocal: ()-> @local

  # ----------------------------------------------------------------------------------------------------------------
  resetContent: ()->
    @content = {}

  # ----------------------------------------------------------------------------------------------------------------
  # Called only when we notice a discrepancy
  #
  setActualNumRecords: (numRecords)->

    @numRecords = numRecords

  # ----------------------------------------------------------------------------------------------------------------
  getDifficulty: ()-> @difficulty

  # ----------------------------------------------------------------------------------------------------------------
  getDifficultyDisplay: (longForm = false)->

    text = switch this.getDifficulty()
      when 1
        "Easy"
      when 2
        if longForm then "Medium" else "Med."
      when 3
        "Hard"
      else
        "Easy"
 
    text

  # ----------------------------------------------------------------------------------------------------------------
  getNumRecords: ()-> @numRecords

  # ----------------------------------------------------------------------------------------------------------------
  getUsage: ()-> 

    used = 0

    if (numRecords = this.getNumRecords()) isnt 0

      usage = Questions.getContentPackUsage(this.getProductID())

      # Edge case: lots of questions have been removed from this content pack...
      used = Math.min(1, usage/numRecords)

    used

  # ----------------------------------------------------------------------------------------------------------------
  resetUsage: ()->

    Questions.resetContentPackUsage(this.getProductID())

  # ----------------------------------------------------------------------------------------------------------------
  getContent: ()-> @content

  # ----------------------------------------------------------------------------------------------------------------
  addContent: (content)->

    @content[content.id] = content

  # ----------------------------------------------------------------------------------------------------------------
  findContentByID: (id)->

    @content[id]

  # ----------------------------------------------------------------------------------------------------------------
  updateContent: (contentInfo)->

    if (content = this.findContentByID(contentInfo.id))?
      for prop, value of contentInfo
        content[prop] = value

    this

  # ----------------------------------------------------------------------------------------------------------------
  updateInfo: (info)->

    for prop, value of info
      this[prop] = value

    this
  # ----------------------------------------------------------------------------------------------------------------
  isSelected: ()-> @selected

  # ----------------------------------------------------------------------------------------------------------------
  setSelected: (selected)->
    @selected = selected

    option = Hy.Options.contentPacks

    if @selected
      option.addOption(this.getProductID())
    else
      option.removeOption(this.getProductID())

    this

  # ----------------------------------------------------------------------------------------------------------------
  loadSelectedFromAppOptions: ()->

    selected = Hy.Options.contentPacks.getOption(this.getProductID())

    # Let's do a little sanity checking here: If it's been selected but not purchased, something is wrong.
    if selected and not this.isEntitled()
      selected = false
      
    this.setSelected(selected)

    return this.isSelected()

  # ----------------------------------------------------------------------------------------------------------------
  toggleSelected: ()->
    this.setSelected(not this.isSelected())

    return this.isSelected()

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    "#{this.constructor.name}: #{@index} #{@productID}/#{@displayName}/#{@version} #{@filename} local=#{this.isLocal()} loaded=#{this.isLoaded()} selected=#{this.isSelected()} entitlement=#{this.getEntitlement()} icon=#{@icon?}"

  # ----------------------------------------------------------------------------------------------------------------
  checkForContentFile: ()->

    this.getContentFile().exists()

  # ----------------------------------------------------------------------------------------------------------------
  writeFile: (text, requiresRemoteBackup = false)->

    if (status = this.getContentFile().writeFile(text, requiresRemoteBackup))
      this.setLocal(true)

    return status

  # ----------------------------------------------------------------------------------------------------------------
  writeIcon: (bits)->

    if (icon = ContentIcon.writeFile(this, bits))?
      this.addIcon(icon)

    return icon?

  # ----------------------------------------------------------------------------------------------------------------
  setLoaded: (loaded)->

    @loaded = loaded

  # ----------------------------------------------------------------------------------------------------------------
  isLoaded: ()-> @loaded

  # ----------------------------------------------------------------------------------------------------------------
  load: ()->

    if (f = (this.isLocal() and not this.isLoaded()))

      t = new Hy.Utils.TimedOperation("CONTENT FILE LOAD #{this.getProductID()}")

      this.resetContent()

      if (numRecordsLoaded = this.getContentFile().load(this)) is 0
        s = "ERROR: Problem reading content pack (#{@filename})"
        new Hy.Utils.ErrorMessage("fatal", "ContentPack", s) #will display popup dialog
      else
        if this.getNumRecords() isnt numRecordsLoaded
          Hy.Trace.debug "ContentPack::load (DIDN\'T READ EXPECTED NUMBER OF RECORDS content pack=#{this.getProductID()} Processed expected=#{this.getNumRecords()} actual=#{numRecordsLoaded})"
          this.setActualNumRecords(numRecordsLoaded)

      t.mark("done")

      this.setLoaded(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # True if an update for this content pack is ready for download
  #
  isUpdateAvailable: ()-> @updateAvailable

  # ----------------------------------------------------------------------------------------------------------------
  setUpdateAvailable: (flag)-> @updateAvailable = flag

# ==================================================================================================================
# 
# Google Docs-based content packs are represented locally as files with names based on the Google ID of the
# corresponding cloud-based instance of the pack, along with a version #.
#
# TODO: are Google doc IDs considered PII? Can an ID be shared safely?
# TODO: how long are doc IDs, and can they be safely used in an iOS filename?
#
# We can handle several forms of URLs to "published" Google Docs spreadsheets:
#
#   "public" form:
#
#    https://docs.google.com/spreadsheet/pub?key=0AvVyfy1LBTe3dEVHWk9GbTdWSWkyZFBJRldaMDJQVmc&single=true&gid=0&output=csv
#
#   "domain" form:
#
#    https://docs.google.com/a/hyperbotic.com/spreadsheet/pub?key=0AvVyfy1LBTe3dEVHWk9GbTdWSWkyZFBJRldaMDJQVmc&output=html
#
#   or
#
#    https://docs.google.com/a/hyperbotic.com/spreadsheet/ccc?key=0AvVyfy1LBTe3dEVHWk9GbTdWSWkyZFBJRldaMDJQVmc&output=html
#
#   For all of the above, we convert to a format based on kBaseURL:
#
#   https://docs.google.com/spreadsheet/pub?key=KEY&single=true&gid=0&output=csv
#
# All that's important is (i) we can extract the key and (ii) it's been published. 
# With the key, we'll can create a "public" URL and attempt to access it.
#
# If not published publicly, the user (or this code) may see a login page; we don't support that yet.
#

class GDocsContentPack extends ContentPack

  @kRequiredFields = ContentPack.kRequiredFields
  @kOptionalFields = []
  kBaseURL = "https://docs.google.com/spreadsheet/pub"

  # ----------------------------------------------------------------------------------------------------------------
  #
  # https://docs.google.com/spreadsheet/pub?key=0AvVyfy1LBTe3dEVHWk9GbTdWSWkyZFBJRldaMDJQVmc&single=true&gid=0&output=csv
  # https://docs.google.com/a/hyperbotic.com/spreadsheet/pub?key=0AvVyfy1LBTe3dEVHWk9GbTdWSWkyZFBJRldaMDJQVmc&output=html
  #
  # https://docs.google.com/a/hyperbotic.com/spreadsheet/ccc?key=0AvVyfy1LBTe3dEVHWk9GbTdWSWkyZFBJRldaMDJQVmc&output=html
  #
  # Mobile version?
  # https://docs.google.com/a/hyperbotic.com/spreadsheet/lv?key=0AvVyfy1LBTe3dGV4SWJ0b3hWSGdrRHFVcllvRXRZdGc&usp=drive_web
  #
  #

  @matchURL: (url)->
    url.match(/^https:\/\/docs.google.com\/(.)*spreadsheet\/ccc/gi)? or url.match(/^https:\/\/docs.google.com\/(.)*spreadsheet\/pub/gi)? or url.match(/^https:\/\/docs.google.com\/(.)*spreadsheet\/lv/gi)

  # ----------------------------------------------------------------------------------------------------------------
  @matchAuthChallengeURLBase: (url)-> # 2.6.2

    # https://accounts.google.com/ServiceLogin?...
    # https://www.google.com/a/hyperbotic.com/ServiceLogin?...
    # https://accounts.google.com/AccountChooser?hd=foo.org...

    url.match(/^https:\/\/(.)+google.com(.)*\/ServiceLogin/gi)? or url.match(/^https:\/\/(.)+google.com(.)*\/AccountChooser/gi)?

  # ----------------------------------------------------------------------------------------------------------------
  @matchAuthChallengeURL: (url)->

    # https://docs.google.com/a/hyperbotic.com/spreadsheet/pub?key=... #? 
    # "https://accounts.google.com/ServiceLogin?service=wise&passive=1209600&continue=https%3A%2F%2Fdocs.google.com%2Fspreadsheet%2Fpub%3Fkey%3D0AvVyfy1LBTe3dGV4SWJ0b3hWSGdrRHFVcllvRXRZdGc%26single%3Dtrue%26gid%3D0%26output%3Dcsv&followup=https%3A%2F%2Fdocs.google.com%2Fspreadsheet%2Fpub%3Fkey%3D0AvVyfy1LBTe3dGV4SWJ0b3hWSGdrRHFVcllvRXRZdGc%26single%3Dtrue%26gid%3D0%26output%3Dcsv&ltmpl=sheets"

    GDocsContentPack.matchAuthChallengeURLBase(url) and (url.match(/spreadsheet\/pub/gi)? or url.match(/spreadsheet\/ccc/gi)? or url.match(/spreadsheet%2Fpub/gi)? or url.match(/spreadsheet%2Fccc/gi)? or url.match(/spreadsheet%252Fpub/gi)? or url.match(/spreadsheet%252Fpub/gi)?)

  # ----------------------------------------------------------------------------------------------------------------
  @diagnoseURLIssues: (url)->

    # https://accounts.google.com/ServiceLogin?...
    # https://www.google.com/a/hyperbotic.com/ServiceLogin?...
    # https://docs.google.com/a/hyperbotic.com/spreadsheet/pub?key=...

    diagnosis = if GDocsContentPack.matchAuthChallengeURL(url)
      GDocsContentPack.diagnoseURLMessage(url)
    else
      null

    diagnosis

  # ----------------------------------------------------------------------------------------------------------------
  @diagnoseURLMessage: (url)->

    "Content is not public - use Google \"publish\" option & don't select \"Require viewers to sign in\""

  # ----------------------------------------------------------------------------------------------------------------
  # Attempt to correct minor error where output format isn't the kind we want (csv)
  #
  @rewritePublicURLOutputFormatArg: (url)->

    url.replace(/&output=(html|txt|pdf|csv|ods|xls)/gi,"&output=csv")

  # ----------------------------------------------------------------------------------------------------------------
  @extractGDocsIDFromURL: (url)->

    id = null

    # Encode "=" and you get "%3D". Then encode that and you get: %253D
    # Encode "&" and you get %26. Encode that and you get: %2526

    # Order is important

    for spec in [ {start:"key=", end:"&"}, {start:"key%3D", end:"&"}, {start:"key%3D", end:"%26"}, {start: "key%253D", end: "%2526"}]
      if (i = url.indexOf(spec.start)) > -1
        s = url.substr(i + spec.start.length)
        if ((i = s.indexOf(spec.end)) > -1) or ((i = s.indexOf("#")) > -1) 
          id = s.substr(0, i)
        else
          id = s

        return id

    id

  # ----------------------------------------------------------------------------------------------------------------
  @makeURL: (id)->

    url = kBaseURL + "?" + "key=#{id}"
    url = url + "&" + "single=true&gid=0&output=csv"

    url

  # ----------------------------------------------------------------------------------------------------------------
  @makeFilename: (id, version)->
    "_gdocs--v#{version}--id--#{id}.csv"

  # ----------------------------------------------------------------------------------------------------------------
  @matchFilename: (filename)->
    filename.match(/^_gdocs--v[0-9]+--id--(.)+.csv$/g)?

  # ----------------------------------------------------------------------------------------------------------------
  @extractVersionInfoFromFilename: (filename)->

    version = null

    pre = "_gdocs--v"
    if filename.indexOf(pre) is 0
      v = filename.substr(pre.length)
      if (i = v.indexOf("--")) > -1
        version = v.substr(0, i)

    parseInt(version)

  # ----------------------------------------------------------------------------------------------------------------
  @extractGDocsIDFromFilename: (filename, idString = "--id--", suffix = ".csv")->

    id = null

    if (i = filename.indexOf(idString)) > -1
      s = filename.substr(i + idString.length)
      if (i = s.indexOf(suffix)) > -1
        id = s.substr(0, i)

    id

  # ----------------------------------------------------------------------------------------------------------------
  @matchByFilename: (directory, filename, kind = GDocsContentPack, contentFileKind = CSVContentFile)->

    contentPackSpec = null

    if kind.matchFilename(filename)
      contentPackSpec = {}
      contentPackSpec.filename = filename
      contentPackSpec.directory = directory
      contentPackSpec.version = kind.extractVersionInfoFromFilename(filename)
      contentPackSpec.productID = kind.extractGDocsIDFromFilename(filename)
      contentPackSpec.kind = kind
      contentPackSpec.contentFileKind = contentFileKind

      # Now read the header of the file for more info about this content pack
      contentPackSpec.contentFile = new contentFileKind(contentPackSpec.directory, contentPackSpec.filename)

      if (header = contentPackSpec.contentFile.getHeader())?
        for prop, value of header
          contentPackSpec[prop] = value
      else # No header means error
        contentPackSpec = null
      
    contentPackSpec

  # ----------------------------------------------------------------------------------------------------------------
  @writeNewContentFile: (directory, productID, version, rawContent, kind = GDocsContentPack, contentFileKind = CSVContentFile)->
    
    c = new contentFileKind(directory, kind.makeFilename(productID, version))
    status = c.writeFile(rawContent, false) # Don't backup downloaded content

    if status then c else null

  # ----------------------------------------------------------------------------------------------------------------
  @getMaxContentFileSize: ()->

      Hy.Config.Content.kThirdPartyContentPackMaxBytes

  # ----------------------------------------------------------------------------------------------------------------
  @checkTypeViaPeek: (rawText)->

    CSVContentFile.checkTypeViaPeek(rawText)

  # ----------------------------------------------------------------------------------------------------------------
  getSourceURL: ()->

    GDocsContentPack.makeURL(this.getProductID())

# ==================================================================================================================
#   Subclass to handle new Google docs format:
#
#     https://docs.google.com/spreadsheets/d/1nwdArvqCLzofg2R8oSRPX2VqW9nc2BDgDoflLc4tEGY/pubhtml
#
#   We switch to this:
#
#     https://docs.google.com/spreadsheets/d/1nwdArvqCLzofg2R8oSRPX2VqW9nc2BDgDoflLc4tEGY/export?format=csv
#
#

class GDocsContentPack2 extends GDocsContentPack #2.6.2

  @kRequiredFields = GDocsContentPack.kRequiredFields
  @kOptionalFields = GDocsContentPack.kOptionalFields
  kBaseURL = "https://spreadsheets.google.com/feeds/cells"

  # ----------------------------------------------------------------------------------------------------------------
  # 2.6.2 New format
  #
  #
  # No warning, no documentation, nothing. Thanks, Google!
  #
  # https://support.google.com/docs/answer/3544847?hl=en
  # http://stackoverflow.com/questions/21189665/new-google-spreadsheets-publish-limitation
  # https://productforums.google.com/forum/#!topic/docs/An-nZtjaupU
  # https://docs.google.com/spreadsheets/d/1nwdArvqCLzofg2R8oSRPX2VqW9nc2BDgDoflLc4tEGY/pubhtml
  # https://docs.google.com/presentation/d/1V06mpJxZwOd6Dso6bri7Dh41O1PlsoaaZG3ki2KuCiE/present?slide=id.i209
  # https://developers.google.com/google-apps/spreadsheets/#working_with_worksheets
  # http://stackoverflow.com/questions/11290337/how-to-convert-google-spreadsheets-worksheet-string-id-to-integer-index-gid
  #
  # Sheets v3 API: not dead yet!
  # https://code.google.com/a/google.com/p/apps-api-issues/issues/detail?id=3709
  #
  #
  @matchBase: (url)->

    # "https://accounts.google.com/ServiceLogin?service=wise&passive=1209600&continue=https%3A%2F%2Fspreadsheets.google.com%2Ffeeds%2Fcells%2F1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs%2Fod6%2Fpublic%2Fbasic%3Falt%3Djson&followup=https%3A%2F%2Fspreadsheets.google.com%2Ffeeds%2Fcells%2F1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs%2Fod6%2Fpublic%2Fbasic%3Falt%3Djson&ltmpl=sheets"
    #
    url.match(/google.com\/(.)*spreadsheets\/d/gi)? or url.match(/google.com%2F(.)*spreadsheets%2Fd/gi)? or url.match(/google.com\/(.)*cells\//gi)? or url.match(/google.com%2F(.)*cells%2F/gi)?

  # ----------------------------------------------------------------------------------------------------------------
  @matchURL: (url)->

    # https://docs.google.com/spreadsheets/d/1TY_6-cH4tdFKCGG9DmHg908jNuUTljBTYFMA8XQmpFI/pubhtml
    # https://docs.google.com/a/hyperbotic.com/spreadsheets/d/1TY_6-cH4tdFKCGG9DmHg908jNuUTljBTYFMA8XQmpFI/edit#gid=0
    # https://spreadsheets.google.com/feeds/cells/1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs/od6/public/basic?alt=json

    url.match(/^https:\/\/docs.google.com\/(.)*spreadsheets\/d/gi)? or url.match(/^https:\/\/spreadsheets.google.com\/feeds\/cells/gi)? 

  # ----------------------------------------------------------------------------------------------------------------
  #
  # "https://www.google.com/a/foo.org/ServiceLogin?service=wise&passive=1209600&continue=https://docs.google.com/a/foo.org/spreadsheets/d/1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs/edit&followup=https://docs.google.com/a/foo.org/spreadsheets/d/1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs/edit&ltmpl=sheets"
  #

  @matchAuthChallengeURL: (url)-> GDocsContentPack.matchAuthChallengeURLBase(url) and GDocsContentPack2.matchBase(url)

  # ----------------------------------------------------------------------------------------------------------------
  @diagnoseURLIssues: (url)->

    diagnosis = if GDocsContentPack2.matchAuthChallengeURL(url)
      GDocsContentPack.diagnoseURLMessage(url)
    else
      null

    diagnosis

  # ----------------------------------------------------------------------------------------------------------------
  @extractGDocsIDFromURL: (url)->

    # https://docs.google.com/spreadsheets/d/1TY_6-cH4tdFKCGG9DmHg908jNuUTljBTYFMA8XQmpFI/pubhtml
    # https://docs.google.com/a/hyperbotic.com/spreadsheets/d/1TY_6-cH4tdFKCGG9DmHg908jNuUTljBTYFMA8XQmpFI/edit#gid=0
    # "https://www.google.com/a/foo.org/ServiceLogin?service=wise&passive=1209600&continue=https://docs.google.com/a/foo.org/spreadsheets/d/1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs/edit&followup=https://docs.google.com/a/foo.org/spreadsheets/d/1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs/edit&ltmpl=sheets"
    # https://accounts.google.com/AccountChooser?hd=foo.org&continue=https%3A%2F%2Fdocs.google.com%2Fa%2Ffoo.org%2Fspreadsheets%2Fd%2F1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs%2Fpubhtml&followup=https%3A%2F%2Fdocs.google.com%2Fa%2Ffoo.org%2Fspreadsheets%2Fd%2F1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs%2Fpubhtml&service=wise&ltmpl=sheets
    # https://spreadsheets.google.com/feeds/cells/1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs/od6/public/basic?alt=json

    id = null

    for spec in [ {start:"/d/", end:"/"}, {start:"%2Fd%2F", end: "%2F"}, {start:"%252Fd%252F", end: "%252F"}, {start:"/cells/", end:"/"}, {start:"%2Fcells%2F", end:"%2F"}, {start:"%252Fcells%252F", end: "%252F"}]
      if (i = url.indexOf(spec.start)) > -1
        s = url.substr(i + spec.start.length)
        if ((i = s.indexOf(spec.end)) > -1)
          id = s.substr(0, i)
        else
          id = s

        return id

    id 

  # ----------------------------------------------------------------------------------------------------------------
  @extractGDocsIDFromDataURL: (url)->

    # https://spreadsheets.google.com/feeds/cells/1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs/od6/public/basic?alt=json

    id = null

    for spec in [ {start:"/cells/", end:"/"} ]
      if (i = url.indexOf(spec.start)) > -1
        s = url.substr(i + spec.start.length)
        if ((i = s.indexOf(spec.end)) > -1)
          id = s.substr(0, i)
        else
          id = s

        return id

    id 

  # ----------------------------------------------------------------------------------------------------------------
  @makeURL: (id)->

    # od6 is the first worksheet in the spreadsheet
    # http://stackoverflow.com/questions/11290337/how-to-convert-google-spreadsheets-worksheet-string-id-to-integer-index-gi

    url = "#{kBaseURL}/#{id}/od6/public/basic?alt=json"

    url
    
  # ----------------------------------------------------------------------------------------------------------------
  # Note the "id2"
  #
  @makeFilename: (id, version)->
    "_gdocs--v#{version}--id2--#{id}.json"

  # ----------------------------------------------------------------------------------------------------------------
  @matchFilename: (filename)->
    filename.match(/^_gdocs--v[0-9]+--id2--(.)+.json$/g)?

  # ----------------------------------------------------------------------------------------------------------------
  @extractVersionInfoFromFilename: (filename)-> GDocsContentPack.extractVersionInfoFromFilename(filename)

  # ----------------------------------------------------------------------------------------------------------------
  @extractGDocsIDFromFilename: (filename)-> GDocsContentPack.extractGDocsIDFromFilename(filename, "--id2--", ".json")

  # ----------------------------------------------------------------------------------------------------------------
  @matchByFilename: (directory, filename)-> GDocsContentPack.matchByFilename(directory, filename, GDocsContentPack2, GDocsJSON)

  # ----------------------------------------------------------------------------------------------------------------
  @writeNewContentFile: (directory, productID, version, rawContent)-> 
    GDocsContentPack.writeNewContentFile(directory, productID, version, rawContent, GDocsContentPack2, GDocsJSON)
    
  # ----------------------------------------------------------------------------------------------------------------
  @getMaxContentFileSize: ()-> GDocsContentPack.getMaxContentFileSize()

  # ----------------------------------------------------------------------------------------------------------------
  @checkTypeViaPeek: (rawText)-> 

    GDocsJSON.checkTypeViaPeek(rawText)

  # ----------------------------------------------------------------------------------------------------------------
  getSourceURL: ()->

    GDocsContentPack2.makeURL(this.getProductID())
  
  
# ==================================================================================================================
#
# An abstraction of the actual file containing trivia content
#
class ContentFile

  kFieldSpec = [
    {fieldName: "question", displayName: "Question"},
    {fieldName: "answer1",  displayName: "Answer #1"},
    {fieldName: "answer2",  displayName: "Answer #2"},
    {fieldName: "answer3",  displayName: "Answer #3"},
    {fieldName: "answer4",  displayName: "Answer #4"}
  ]

  # ----------------------------------------------------------------------------------------------------------------
  @delete: (contentFile)->

    ContentFile.deleteFile(contentFile.getDirectory(), contentFile.getFilename())

  # ----------------------------------------------------------------------------------------------------------------
  @deleteFile: (directory, filename)->

    f = Ti.Filesystem.getFile(directory, filename)

    if (exists = f.exists())
      Hy.Trace.debug "ContentFile::deleteFile (exists: #{directory} / #{filename})"
      f.deleteFile()

    exists

  # ----------------------------------------------------------------------------------------------------------------
  # Must be implemented by children
  @checkTypeViaPeek: (rawText)->

    false

  # ----------------------------------------------------------------------------------------------------------------
  # We don't allow "<", to keep html tags out
  #
  @checkIllegalChars: (text)->

    replacementText = text.replace(/</g, "?")

    replacementText

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@directory, @filename)->

    @rawContent = null # raw text contained in the file

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDirectory: ()-> @directory

  # ----------------------------------------------------------------------------------------------------------------
  getFilename: ()-> @filename

  # ----------------------------------------------------------------------------------------------------------------
  exists: ()->

    f = Ti.Filesystem.getFile(this.getDirectory(), this.getFilename())

    Hy.Trace.debug("ContentFile::exists (#{this.getDirectory()}/#{this.getFilename()} exists: #{f.exists()}")
    
    return f.exists()

  # ----------------------------------------------------------------------------------------------------------------
  getTriviaContentStartLineNum: ()-> 1

  # ----------------------------------------------------------------------------------------------------------------
  checkTriviaContent: (contentPack, content = [])->

    lineNum = this.getTriviaContentStartLineNum()

    numMessages = 0
    maxNumMessages = 5

    fnMessage = (kind, s, line = lineNum)=>
      if ++numMessages <= maxNumMessages
        ContentManager.addMessage(kind, line, s)
      null

    fnIllegalCharsCheck = (name, value)=>
      return value # Now handled in html page
      if (newValue = ContentFile.checkIllegalChars(value)) isnt value
        fnMessage("warning", "#{name} contains illegal char \"<\" (replaced with \"?\")")
      newValue
    
    fnStringEmptyCheck = (name, value, action, fix)=>
      if not value? or value.length is 0
        fnMessage("warning", "#{name} must not be blank#{if action? then " " + action else ""}")
        return fix
      return value

    fnStringTooLongCheck = (name, value, max)=>
      if value? and value.length > max
        value = value.substr(0, max)
        fnMessage("warning", "#{name} too long (trimmed)")
      return value

    fnCheckDirectives = (name, value)=>
      [mess, messType, newValue] = this.processDirectives(name, value)
      if mess?
        fnMessage(messType, "Problem with \"#{name}\": #{mess}")
      if newValue?
        return newValue
      else
        return value

    if (content.length > 0)

      # Check for max number of questions
      if contentPack.isThirdParty() and content.length > Hy.Config.Content.kThirdPartyContentPackMaxNumRecords
        # Attempt to get the line number right
        l = lineNum + Hy.Config.Content.kThirdPartyContentPackMaxNumRecords
        fnMessage("warning", "Too many question rows (max is #{Hy.Config.Content.kThirdPartyContentPackMaxNumRecords} - excess ignored)", l)
        content.slice(0, Hy.Config.Content.kThirdPartyContentPackMaxNumRecords)     

      # Check that each question has 4 answers, and text lengths
      for questionSet in content

        # Check for lines that are all blanks
        l = 0
        for fieldName in ["question", "answer1", "answer2", "answer3", "answer4"]
          l += if not questionSet[fieldName]? or questionSet[fieldName].length is 0 then 0 else 1
        if l is 0
          fnMessage("error", "Line does not contain a question or any answers")
          for fieldName in ["question", "answer1", "answer2", "answer3", "answer4"]
            questionSet[fieldName] = "(Line #{lineNum} in content file is blank - please correct!)"

        for fieldSpec in kFieldSpec
          fieldName = fieldSpec.fieldName
          displayName = fieldSpec.displayName

          max = if fieldName is "question" then Hy.Config.Content.kContentPackMaxQuestionLength else Hy.Config.Content.kContentPackMaxAnswerLength
          if not (fieldValue = questionSet[fieldName])?
            fieldValue = "" # make it look like a zero-length string

          fieldValue = fnStringEmptyCheck(displayName, fieldValue, null, "(Please enter a value for this field!)")
          fieldValue = fnStringTooLongCheck(displayName, fieldValue, max)
          fieldValue = fnIllegalCharsCheck(displayName, fieldValue)
          fieldValue = fnCheckDirectives(fieldName, fieldValue)

          if fieldValue isnt questionSet[fieldName]
            questionSet[fieldName] = fieldValue

        lineNum++

    content

  # ----------------------------------------------------------------------------------------------------------------
  processDirectives: (name, value)->

    newValue = null
    messType = null
    mess = null

    # Look for [img ...] directive
    if false #value.match(/^\[img (.)*\]$/gi)
      newValue = value.replace(/^\[img/gi, "<img").replace(/\]$/gi, ">")
      messType = "warning"
      mess = "[img] is not yet supported"

    [mess, messType, newValue]

  # ----------------------------------------------------------------------------------------------------------------
  setRawContent: (rawContent)->

    @rawContent = rawContent

  # ----------------------------------------------------------------------------------------------------------------
  # This is cached, but we'll throw it away later if we remember
  #
  getRawContent: ()->

    if not @rawContent?
      file = Ti.Filesystem.getFile(this.getDirectory(), this.getFilename())
      if file.exists()
        @rawContent = file.read().toString()

    @rawContent
  # ----------------------------------------------------------------------------------------------------------------
  processQuestion: (contentPack, question)->

    @numRecordsLoaded++

    if (result = Questions.loadQuestion(contentPack, question))?
      contentPack.addContent(result)

    this

  # ----------------------------------------------------------------------------------------------------------------
  load: (contentPack)->
    Hy.Trace.debug "ContentFile::load (#{contentPack.getProductID()} file=#{this.getFilename()} version=#{contentPack.getVersion()})"

    @numRecordsLoaded = 0

    # We throw away "data" as soon as we're done with it
    # All of the contained data are elements that will be copied on assignment
    if (data = this.getTriviaContent(contentPack))?

      # If third-party content, check validity of data
      if contentPack.isThirdParty()
        data = this.checkTriviaContent(contentPack, data)

      for d in data
        this.processQuestion(contentPack, d)

    Hy.Trace.debug "ContentFile::load (#{contentPack.getProductID()} Processed #{@numRecordsLoaded})"

    # And now throw away the raw content as well
    this.setRawContent(null)

    @numRecordsLoaded

  # ----------------------------------------------------------------------------------------------------------------
  onParseError: (report = null)->

    s = "ERROR parsing content file #{if report? then report else ""} (#{this.getDirectory()}/#{this.getFilename()})"
    new Hy.Utils.ErrorMessage("fatal", "ContentFile", s) #will display popup dialog

    file = Ti.Filesystem.getFile(this.getDirectory(), this.getFilename())

    try
      if file.exists()
        file.deleteFile()
    catch e
      Hy.Trace.debug "ContentFile::onParseError (Failed deleting file #{e})"

    null

  # ----------------------------------------------------------------------------------------------------------------
  writeFile: (text, requiresRemoteBackup = false)->

    status = true

    filename = this.getFilename()

    f = Ti.Filesystem.getFile(this.getDirectory(), filename)

    exists = f.exists()

    if exists
      Hy.Trace.debug "ContentFile::writeFile (ALREADY EXISTS #{filename})"

    Hy.Trace.debug "ContentFile::writefile (writing file #{this.getDirectory()}/#{filename})"
#    Hy.Trace.debug "ContentFile::writefile (CONTENTS #{text})"

    f.write(text)

    # This is an "Offline Data" file, by Apple's definition:
    # http://developer.apple.com/library/ios/#qa/qa1719/_index.html
    #
    # "Offline Data"
    # This is data that can be downloaded or otherwise recreated, but that the user expects
    # to be reliably available when offline. Offline data should be put in the
    # <Application_Home>/Documents directory or in the <Application_Home>/Library/Private Documents 
    # directory (see QA1699 for details) and marked with the "do not backup" attribute. Data stored 
    # in either location will persist in low-storage situations and the "do not backup" attribute will prevent
    # iTunes or iCloud backing up the data. Offline data files should be removed as soon as they are 
    # no longer needed to avoid using unnecessary storage space on the user's device."
    #
    # We place this downloaded content in  Ti.Filesystem.applicationDataDirectory, which maps to
    # "../Documents"
    # http://jira.appcelerator.org/browse/TIMOB-6286

    f.setRemoteBackup(requiresRemoteBackup) 

    # If we have cached the raw contents, replace 'em
    if status and this.getRawContent()?
      this.setRawContent(text)

    status

# ==================================================================================================================
#
#
class JSONContentFile extends ContentFile

  # ----------------------------------------------------------------------------------------------------------------
  # We don't cache the results of this, and hope the caller throws it away
  #
  getTriviaContent: (contentPack)->

    results = null

    if (contents = this.getRawContent())?
      try
        results = JSON.parse(contents)
      catch e
        this.onParseError()
        results = null

    results

# ==================================================================================================================
#
#
class ContentFileWithHeader extends ContentFile

  # "schemaName" is here for documentation purposes only at this point... the actual mapping to schemaName is hard-wired
  #  at this point.
  #
  kRequiredHeaderProperties = [
    {schemaName: "longDescription",     displayName: "description"},
    {schemaName: "displayName",         displayName: "name"},
    {schemaName: "difficulty",          displayName: "difficulty"},
    {schemaName: "iconSpec",            displayName: "icon"}
    {schemaName: "authorContactInfo",   displayName: "contact"}  
    {schemaName: "authorVersionInfo",   displayName: "version"}  
    {schemaName: "order",               displayName: "order"}  #v1.1.0
  ]

  @kFileTag = "##TriviaPro" 
  @kCommentTag = "#!"

  # ----------------------------------------------------------------------------------------------------------------
  @checkTypeViaPeek: (rawText)->

    t = rawText.substr(0, ContentFileWithHeader.kFileTag.length)

    t.toLowerCase() is ContentFileWithHeader.kFileTag.slice(0).toLowerCase()
    
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directory, filename)->
 
    @triviaContentStartLineNum = null

    super directory, filename

    this

  # ----------------------------------------------------------------------------------------------------------------
  getCommentTag: ()-> ContentFileWithHeader.kCommentTag

  # ----------------------------------------------------------------------------------------------------------------
  getFileTag: ()-> ContentFileWithHeader.kFileTag

  # ----------------------------------------------------------------------------------------------------------------
  # The first line of content. Skips over #Trivia, header props, and blank line separator
  #
  getTriviaContentStartLineNum: ()-> @triviaContentStartLineNum

  # ----------------------------------------------------------------------------------------------------------------
  # We presume that a child implementation has extracted the actual header from a file somehow and has
  # super'd up to this implementation for semantic checking:
  #
  #  - Make sure that all of the required fields are there
  #  - Make sure that text values aren't too long
  #
  getHeader: (headerContent = null)->

    header = if headerContent?
      # may return null if user error
      this.checkHeaderPropConstraints(headerContent)
    else
      # Some error with the input... presume that an error has already been generated
      null

    header

  # ----------------------------------------------------------------------------------------------------------------
  # Returns a header, or null if user error
  #
  checkHeaderPropConstraints: (headerContent)->

    lineNum = 0

    fnAddWarning = (s, l = lineNum)=>
      ContentManager.addMessage("warning", l, s)

    fnAddError = (s, l = lineNum)=>
      ContentManager.addMessage("error", l, s)
      status = false

    status = true

    defaultedProps = []

    #
    #
    header = {} 
    for c in headerContent
      name = c.name
      value = c.value
      lineNum = c.lineNum

      switch name
        # We added this one programmatically
        when "numRecords"          
          if value < (min = Hy.Config.Content.kThirdPartyContentPackMinNumRecords)
            fnAddError("Minimum number of questions is #{min}. Please add more and try again")
          else
            ContentPack.addHeaderProp(header, "content", "numRecords", value)

        else
          [found, newStatus] = this.checkHeaderProp(name, value, lineNum, header, defaultedProps)

          status = status and newStatus

#          if not found # V1.0.1
#            fnAddWarning("Unexpected field \"#{name}\" (ignored)")

    # Do post-processing customization checks
    if header._customizations?
      status = status and Hy.Customize.validateSettings(header._customizations, fnAddWarning, fnAddError)

    # Check for missing required properties
    for propSpec in kRequiredHeaderProperties
      if not _.detect(headerContent, (c)=>c.name is propSpec.displayName)?
        [found, newStatus] = this.checkHeaderProp(propSpec.displayName, null, lineNum, header, defaultedProps)

        status = status and newStatus

    # Summarize info regarding properties that were defaulted
    if (numDefaulted = _.size(defaultedProps)) > 0
      report = "Default values provided for:\n"
      f = false
      for prop in defaultedProps
        report += "#{if f then ", " else ""}#{prop}"
        f = true
      lineNum = null
      fnAddWarning(report)
        
    if status then header else null

  # ----------------------------------------------------------------------------------------------------------------
  checkHeaderProp: (name, value, lineNum, header, defaultProps)->

    warnOnMissingProps = false

    fnIllegalCharsCheck = (name, value)=>
      if value? and ((newValue = ContentFile.checkIllegalChars(value)) isnt value)
        fnAddWarning("\"#{name}\" contains illegal char \"<\" (replaced with \"?\")")
      newValue

    fnStringEmptyCheck = (name, value, action, fix)=>
      if not value? 
        if warnOnMissingProps
          fnAddWarning("\"#{name}\" not specified #{if action? then "(" + action + ")" else ""}")
        defaultProps.push name
        return fix
      else if value.length is 0
        fnAddWarning("\"#{name}\" requires a value #{if action? then "(" + action + ")" else ""}")
        defaultProps.push name
        return fix
      else
        return value

    fnStringTooLongCheck = (name, value, max)=>
       if value? and value.length > max
         value = value.substr(0, max)
         fnAddWarning("\"#{name}\" longer than #{max} char (trimmed)")
       return value

    fnAddWarning = (s)=>
      ContentManager.addMessage("warning", lineNum, s)

    fnAddError = (s)=>
      ContentManager.addMessage("error", lineNum, s)
      status = false

    status = true
    found = true

    switch name
      when "contact"
        if value?
          value = fnStringTooLongCheck(name, value, Hy.Config.Content.kContentPackMaxAuthorContactInfoLength)
          value = fnIllegalCharsCheck(name, value)
          ContentPack.addHeaderProp(header, "content", "authorContactInfo", value)

      when "version"
        if value?
          value = fnStringTooLongCheck(name, value, Hy.Config.Content.kContentPackMaxAuthorVersionInfoLength)
          value = fnIllegalCharsCheck(name, value)
          ContentPack.addHeaderProp(header, "content", "authorVersionInfo", value)

      when "name"
        defaultValue = "My Custom Trivia Pack"
        value = fnStringTooLongCheck(name, value, Hy.Config.Content.kContentPackMaxNameLength)
        value = fnStringEmptyCheck(name, value, "defaulted to \"#{defaultValue}\"", defaultValue)
        value = fnIllegalCharsCheck(name, value)
        ContentPack.addHeaderProp(header, "content", "displayName", value)

      when "description" # This will be mapped into "longDescription"
        defaultValue = "Description of my Custom Trivia Pack"
        value = fnStringTooLongCheck(name, value, Hy.Config.Content.kContentPackMaxLongDescriptionLength)
        value = fnStringEmptyCheck(name, value, "default value provided", defaultValue)
        value = fnIllegalCharsCheck(name, value)
        ContentPack.addHeaderProp(header, "content", "longDescription", value)

      when "difficulty"
        defaultValue = "easy"
        value = fnStringEmptyCheck(name, value, "defaulted to \"#{defaultValue}\"", defaultValue)

        difficulty = switch value.toLowerCase()
          when "easy"
            1
          when "medium"
            2
          when "difficult", "hard"
            3
          else
            display = value.substr(0, 10) + if value.length > 0 then "..." else ""
            fnAddWarning("Invalid \"#{name}\" (\"#{display}\" - set to \"easy\")")
            1
        ContentPack.addHeaderProp(header, "content", "difficulty", difficulty)

      when "icon"
        defaultValue = ContentIcon.getDefaultIconSpec()

        value = fnStringEmptyCheck(name, value, "defaulted to \"#{defaultValue}\"", defaultValue)

        if value.length > Hy.Config.Content.kContentPackMaxIconSpecLength
          fnAddWarning("Value for \"#{name}\" longer than #{Hy.Config.Content.kContentPackMaxIconSpecLength} chars (using \"#{defaultValue}\")")
          value = defaultValue

          if not warn?
            if not ContentIcon.findByIconSpec(value.toLowerCase())?
              fnAddWarning("Invalid \"#{name}\" (\"#{value}\" - using \"#{defaultValue}\")")
              value = defaultValue
        ContentPack.addHeaderProp(header, "content", "iconSpec", value.toLowerCase())

      when "order" # v1.1.0
        defaultValue = "random"
        value = fnStringEmptyCheck(name, value, "defaulted to \"#{defaultValue}\"", defaultValue)

        order = switch (v = value.toLowerCase())
          when "random", "sequential"
            v
          else
            display = value.substr(0, 10) + if value.length > 0 then "..." else ""
            fnAddWarning("Invalid \"#{name}\" (\"#{display}\" - set to \"#{defaultValue}\")")
            defaultValue
        ContentPack.addHeaderProp(header, "content", "order", order)

      else
        # Check for customizations

        [found, status, message, output] = Hy.Customize.checkProp(name, value)

        # For better error messages later
        if output?
          output.lineNum = lineNum

        if status
          if message?
            fnAddWarning(message)
          if found
            ContentPack.addHeaderProp(header, "customization", name, output)
        else
          # We present any error as a warning and ignore the line
          fnAddWarning(if message? then message else "Couldn\'t understand \"#{name}\"")
          status = true

        if not found
          # Here for completeness: property not found
          null

    [found, status]

# ==================================================================================================================
#
# Sample:
# https://spreadsheets.google.com/feeds/download/spreadsheets/Export?key=0AvVyfy1LBTe3dEVHWk9GbTdWSWkyZFBJRldaMDJQVmc&exportFormat=tsv
#
class ExcelContentFile extends ContentFileWithHeader

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directory, filename)->
 
    @tokens = null

    super directory, filename

    this

  # ----------------------------------------------------------------------------------------------------------------
  # If setting to null, a signal that we can clear our cached stuff also
  #
  setRawContent: (rawContent)->

    if not rawContent?
      @tokens = null

    super rawContent

  # ----------------------------------------------------------------------------------------------------------------
  # We cache the results of this operation
  tokenize: ()->

    if not @tokens?
      @tokens = this.parse()

    @tokens

  # ----------------------------------------------------------------------------------------------------------------
  # Must be implement by children
  #
  parse: ()->

    null

  # ----------------------------------------------------------------------------------------------------------------
  getTriviaContent: (contentPack)->

    results = null

    if (lines = this.tokenize())?

      for i in [this.getTriviaContentStartLineNum()-1..lines.length-1]

        results ||= []
     
        d = lines[i]

        question = {}
        question.question = d[0]
        question.answer1 = d[1]
        question.answer2 = d[2]
        question.answer3 = d[3]
        question.answer4 = d[4]
        question.topic = contentPack.getProductID()

        # The use of a GUID means that the user may see the same question more than once, across updates
        question.id = Hy.Utils.UUID.generate() 

        results.push question
    
    results

  # ----------------------------------------------------------------------------------------------------------------
  # Just extract the header and send it up for input validation, returning an object (hash).
  #
  # We expect the top few lines to contain header info, with a blank line to separate the header from 
  # questions / answers. If not, return null header and set error message accordingly.
  #
  # Input param is an array of {name:, value:} pairs. We do it this way so that we can detect
  # the difference between a header setting that's missing, and one that has no value associated with it.
  #   
  # We bail at the first unrecoverable error
  #
  getHeader: (headerContent = null)->

    headerContent = []
    error = false

    fnClearMessages = ()=>
      ContentManager.clearMessages()
      null

    fnMessage = (kind, s)=>
      if kind is "error"
        error = true
        # Display only this error message
        fnClearMessages()
      ContentManager.addMessage(kind, lineNum, s)
      null

    fnAddHeader = (name, value, l = lineNum)=>
      numHeaderRecords++
      headerContent.push {name: name, value: value, lineNum: lineNum}
      null      

    fnIsComment = (prop)=>
      prop.substr(0,2) is this.getCommentTag() 

    lines = this.tokenize()

    sawFileTag = false # ##Trivia

    lineNum = 0                     # Current line number, for error reporting
    numHeaderRecords = 0            # Number of actual header properties encountered. 
    triviaContentLineNumber = null  # Line number of first trivia content line

    mode = "header" # Either "header" or "trivia"

    while (lineNum < lines.length) and (not error)

      lineNum++

      line = lines[lineNum-1]
      prop = line[0].toLowerCase()
      propDisplay = line[0] # For messages to the user, don't lowercase
      value = line[1]

      if fnIsComment(prop)
        switch mode
          when "header"
            # Comment line in header. Nothing to do
            null
          when "trivia"
            fnMessage("error", "Comment tag \"#{this.getCommentTag()}\" can\'t appear in trivia section")
            break
      else
        switch prop
          when ""  # Check: Are we at the separator?
            switch mode
              when "header"
                mode = "trivia"
              when "trivia"
               fnMessage("error", "There must be only one blank line, separating settings from question/answer lines")
               break
          when this.getFileTag().slice().toLowerCase() # #Trivia tag?
            if sawFileTag
              fnMessage("error", "\"#{this.getFileTag()}\" must appear only once, in the first cell of the first row")
              break
            else
              sawFileTag = true
              switch mode
                when "header"
                  if lineNum isnt 1
                    fnMessage("error", "\"#{this.getFileTag()}\" must appear in the first cell of the first row")
                    break
                when "trivia"
                  fnMessage("error", "\#{this.getFileTag()}\" must appear only once, in the first cell of the first row")
                  break
          else # Something else
            switch mode
              when "header"
                # Check: too many header rows?
                if numHeaderRecords >= (max = Hy.Config.Content.kContentPackWithHeaderMaxNumHeaderProps)
                  fnMessage("error", "Too many settings (max is #{max})")
                  break
                else
                  # Have we seen this property before?
                  if _.size(_.select(headerContent, (r)=>r.name is prop)) > 0
                    fnMessage("warning", "Ignoring duplicate setting \"#{propDisplay}\"")
                  else
                    fnAddHeader(prop, value)
              when "trivia"
                if not triviaContentLineNumber?
                  triviaContentLineNumber = lineNum

    if not error and mode is "header"
      lineNum = 1
      fnMessage("error", "A blank separator line is required between settings and question/answer rows")

    if not error and not sawFileTag
      lineNum = 1
      fnMessage("error", "\"#{this.getFileTag()}\" must appear in the first cell of the first row")
    if error
      headerContent = null
    else
      @triviaContentStartLineNum = triviaContentLineNumber
      fnAddHeader("numRecords", (lines.length - triviaContentLineNumber + 1), null)

    super headerContent

# ==================================================================================================================
class TSVContentFile extends ExcelContentFile
  # ----------------------------------------------------------------------------------------------------------------
  parse: ()->

    try
      results = Hy.Utils.TSVParser.parse(this.getRawContent())
    catch e
      this.onParseError()
      results = null
  
    results    

# ==================================================================================================================
# Sample:
# https://docs.google.com/spreadsheet/pub?key=0AvVyfy1LBTe3dEVHWk9GbTdWSWkyZFBJRldaMDJQVmc&single=true&gid=0&output=csv
#
class CSVContentFile extends ExcelContentFile

  # ----------------------------------------------------------------------------------------------------------------
  @checkTypeViaPeek: (rawText)-> ContentFileWithHeader.checkTypeViaPeek(rawText)

  # ----------------------------------------------------------------------------------------------------------------
  parse: ()->

    try
      results = Hy.Utils.CSVParser.parse(this.getRawContent())
    catch e
      this.onParseError()
      results = null
    
    results

# ==================================================================================================================
#
# Sample:
# https://spreadsheets.google.com/feeds/cells/1vwiFpn-tQi4zoMOk9JBfjGnFaa9sQd2_Ovwc8G4KpBs/od6/public/basic?alt=json
#
class GDocsJSON extends ExcelContentFile

  # ----------------------------------------------------------------------------------------------------------------
  @checkTypeViaPeek: (rawText)-> 
    rawText.match(/{"version":"1.0",/gi)?

  # ----------------------------------------------------------------------------------------------------------------
  parse: ()->
  
    results = null

    try
      results = this.processGDocsJSON(JSON.parse(this.getRawContent()))
    catch e
      this.onParseError()
      results = null

    results

  # ----------------------------------------------------------------------------------------------------------------
  # Traverse the GDocs JSON and return an array of arrays
  #
  processGDocsJSON: (gDocsJSON) ->
    results = []
    maxNumColumns = 5

    # "A2" - column is "A", row is "2"
    fnGetEntryRowNum = (entry)=>
      if (arr = entry.title.$t.match(/[0-9]+/))?
        Number(arr[0])
      else
        0

    # "A2" - column is "A", row is "2"
    fnGetEntryColumnNum = (entry)=>
      if (arr = entry.title.$t.match(/[a-zA-Z]+/))?
        (arr[0].toUpperCase().charCodeAt(0) - "A".charCodeAt(0)) # We expect at most 5 columns
      else
        0

    fnGetEntryValue       = (entry)=> entry.content.$t

    fnGetEntry = ()=>
      entry = if index < gDocsJSON.feed.entry.length
        gDocsJSON.feed.entry[index++]
      else
        null
      entry

    fnAddCellToRow = (entry) =>
      if (columnIndex = fnGetEntryColumnNum(entry)) <= maxNumColumns
        # Pad out cells that we're skipping
        while row.length < columnIndex
          row.push ""
        row.push fnGetEntryValue(entry)
      null

    fnPushRow = (row = null)=>
      if row?
        results.push row
        row = null
      null

    rowNum = 0
    index = 0
    row = null
    entry = null

    while (entry = fnGetEntry())?

      switch rowNum

        # First time through
        when 0
          row = []
          fnAddCellToRow(entry)

        # Another cell for the same row
        when fnGetEntryRowNum(entry)
          fnAddCellToRow(entry)

        # Next row
        when fnGetEntryRowNum(entry)-1
          fnPushRow(row) # Push old row
          row = []       # Start a new one
          fnAddCellToRow(entry)

        # One or more rows skipped
        else
          fnPushRow(row)  # Push old row
          fnPushRow([""]) # Push a blank one
          row = []       # Start a new one
          fnAddCellToRow(entry)

      rowNum = fnGetEntryRowNum(entry)

    fnPushRow(row) # Last one

    results

# ==================================================================================================================
# A single instance of this class keeps track of the usage database, which contains a single table containing a 
# row for each question that's been displayed since installation. 
# The row tracks the question ID and the display count. If a question has not been displayed, it is not represented
# in the table. 
# If the database is deleted (by, say, a reinstallation of the app), then we presume that no questions have yet been 
# seen by the user.
#
class QuestionUsage
  kDBName = "#{Hy.Config.Content.kUsageDatabaseName}_#{Hy.Config.Content.kUsageDatabaseVersion}"

  constructor: ()->

    @counts = null
    @connection = null

    if this.connect()
      this.installSchema()

    this

  # ----------------------------------------------------------------------------------------------------------------
  connect: ()->
    Hy.Trace.debug "QuestionUsage::@connect (Opening DB name=#{kDBName})"
    @connection = Ti.Database.open(kDBName)

    # According to Apple, this database is an example of "Critical Data"
    #
    # "This is user-created data or other data that cannot be recreated. It should be placed in 
    # the <Application_Home>/Documents directory and should not be marked with the "do not backup" 
    # attribute. Critical data will persist in low-storage situations and will be backed up by iTunes or iCloud."
    #
    # Recent versions of Appcelerator place this db file here: 
    #  "Library/Private Documents"
    f = @connection.file

    if f?
      f.setRemoteBackup(true) # Usage database should be backed up

    if @connection is null
      Hy.Trace.debug "QuestionUsage::@connect (DB Open Error: name=#{kDBName})"
      new Hy.Utils.ErrorMessage("fatal", "QuestionUsage::@connect", "DB Open Error: (name=#{kDBName})") #will display popup dialog
      return null
 
    this
  # ----------------------------------------------------------------------------------------------------------------
  execute: (sql)->

    @connection.execute sql

  # ----------------------------------------------------------------------------------------------------------------
  installSchema: ()->
  
    @connection.execute "create table if not exists QUESTIONUSAGE (ID text, USAGECOUNT integer, TOPIC text)"

  # ----------------------------------------------------------------------------------------------------------------
  load: ()->
    dbCursor = @connection.execute "select * from QUESTIONUSAGE"

    @counts = {}

    while dbCursor.isValidRow()
      this.add(dbCursor.field(0), dbCursor.field(1), dbCursor.field(2))
      dbCursor.next()

    dbCursor.close()

    this
    
  # ----------------------------------------------------------------------------------------------------------------
  add: (id, displayCount, topic)->
#    Hy.Trace.debug "QuestionUsage::load (id=#{id} displayCount=#{displayCount} topic=#{topic})"
    @counts[id] = {topic: topic}
    this.setUsageCountByID(id, displayCount)
    @counts

  # ----------------------------------------------------------------------------------------------------------------
  findByID: (id)->

    @counts[id]

  # ----------------------------------------------------------------------------------------------------------------
  getUsageCountByID: (id)->

    if (c = this.findByID(id))?
      c.usage_count
    else
      0

  # ----------------------------------------------------------------------------------------------------------------
  setUsageCountByID: (id, count)->

    if (c = this.findByID(id))?
      c.usage_count = count

    this

  # ----------------------------------------------------------------------------------------------------------------
  dumpCounts: ()->

    for prop, value of @counts
      Hy.Trace.debug "QuestionUsage::dumpCounts (id=#{prop} usage_count=#{value.usage_count} topic=#{value.topic})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  incrementUsageCount: (id, topic)->

    # We mirror the usage count in @counts and in the database

    count = this.getUsageCountByID(id) + 1
    
    if count > 1
      this.setUsageCountByID(id, count)
      @connection.execute "update QUESTIONUSAGE set USAGECOUNT=#{count} where ID = \'#{id}\'"
    else
      this.add(id, 1, topic)
      @connection.execute "insert into QUESTIONUSAGE (ID, USAGECOUNT, TOPIC) values (\'#{id}\', 1, \"#{topic}\")"

    this.updateContentPackUsage(topic, count)

    this

  # ----------------------------------------------------------------------------------------------------------------
  resetUsageCount: (topic)->

    this.writeDBLog()
    this.dumpCounts()

#    @connection.execute "update QUESTIONUSAGE set USAGECOUNT=0 where TOPIC = \'#{topic}\'"
    @connection.execute "delete from QUESTIONUSAGE where TOPIC = \'#{topic}\'"

    idsToDelete = []
    for prop, value of @counts
      if value.topic is topic
        idsToDelete.push prop

    for i in idsToDelete
      delete @counts[i]

    this.writeDBLog()
    this.dumpCounts()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # The result is an object with a property for each content pack that's had at least one question displayed.
  # The name of the property is the content pack product id, and the value of the property is the number 
  # of questions that have been displayed at least once.
  # This method is typically called once, when the usage database is loaded. We update the counters during
  # the game via "incrementUsageCount".
  #
  # EDGE CASE THAT WE DON'T HANDLE: if a content pack is updated, and the new version contains fewer questions
  # than the old version, and those removed questions have already been used, then this code will effectively
  # over-report the usage for that content pack. We should just avoid making massive changes to already-deployed
  # content packs. The most likely instance of this scenario is where a single question is removed for some
  # reason. We will try to deal with the massive change case in ContentPack.getUsage().
  #
  computeContentPackUsage: ()->

    @contentPackUsageInfo = {}

    if @counts?
      for id, props of @counts
        if props.usage_count > 0
          this.updateContentPackUsage(props.topic, 1)

    this

  # ----------------------------------------------------------------------------------------------------------------
  updateContentPackUsage: (topic, count)->

    if @contentPackUsageInfo?
      #
      # "Usage", in this context, means we are tracking how many questions have been used
      # at least once.
      #
      if count is 1
        if not @contentPackUsageInfo[topic]?
          @contentPackUsageInfo[topic] = 0
        @contentPackUsageInfo[topic]++

    this
        
  # ----------------------------------------------------------------------------------------------------------------
  # "topic" = content pack product id
  #
  getContentPackUsage: (topic)->

    usage = 0

    if not @contentPackUsageInfo?
      this.computeContentPackUsage()

    if not (usage = @contentPackUsageInfo[topic])?
      usage = 0

    usage

  # ----------------------------------------------------------------------------------------------------------------
  # "topic" = content pack product id
  #
  resetContentPackUsage: (topic)->

    # Clear counters in DB and in-memory cache
    this.resetUsageCount(topic)

    # Clear usage
    if @contentPackUsageInfo?
      @contentPackUsageInfo[topic] = 0
    
    null

  # ----------------------------------------------------------------------------------------------------------------
  writeDBLog: ()->

    Hy.Trace.debug "QuestionUsage::writeDBLog"

    dbCursor = @connection.execute "select * from QUESTIONUSAGE"

    while dbCursor.isValidRow()
      Hy.Trace.debug "QuestionUsage::writeDBLog (ID=#{dbCursor.field(0)} USAGECOUNT=#{dbCursor.field(1)} TOPIC=#{dbCursor.field(2)})"

      dbCursor.next()

    dbCursor.close()

# ==================================================================================================================
# A static wrapper class - no instance are created. Proxies access to the in-memory set of all questions.
#
class Questions

  @questionUsage = null

  kRequiredFileFields = ["question", "answer1", "answer2", "answer3", "answer4", "id", "topic"]

  # ----------------------------------------------------------------------------------------------------------------
  @init: ()->
    @questionUsage = new QuestionUsage()
    @questionUsage.load()

    Questions.computeContentPackUsage()

  # ----------------------------------------------------------------------------------------------------------------
  @checkRequiredFields: (q)->

    # We keep "topic" to help with analytics. We probably don't need "category"
    # "topic" = content pack product id
    for field in kRequiredFileFields
      if not q[field]?
        return field
     
    return null

  # ----------------------------------------------------------------------------------------------------------------
  # Working around various differences between object and file representations
  # 
  @copyToFileSchema: (source)->

    target = {}
    for field in kRequiredFileFields
      target[field] = source[field]

    return target

  # ----------------------------------------------------------------------------------------------------------------
  @loadQuestion: (contentPack, question)->

    result = null

    if (error = Questions.checkRequiredFields(question))?
      s = "ERROR missing question field \"#{error}\" (#{contentPack.getDisplayName()} #{question.id})"
      new Hy.Utils.ErrorMessage("fatal", "ContentManifest", s) #will display popup dialog
    else
#      question.answers = [question.answer1, question.answer2, question.answer3, question.answer4] #answer1 is the correct answer
      # If question id has already been seen, we ignore this one
      if not contentPack.findContentByID(question.id)?

        result = question

    result

  # ----------------------------------------------------------------------------------------------------------------
  @getUsageCount: (question)->
    @questionUsage.getUsageCountByID(question.id)

  # ----------------------------------------------------------------------------------------------------------------
  @incrementUsageCount: (question)->
    @questionUsage.incrementUsageCount(question.id, question.topic)

  # ----------------------------------------------------------------------------------------------------------------
  @computeContentPackUsage: ()->

    @questionUsage.computeContentPackUsage()

  # ----------------------------------------------------------------------------------------------------------------
  @getContentPackUsage: (contentPackID)->

    @questionUsage.getContentPackUsage(contentPackID)

  # ----------------------------------------------------------------------------------------------------------------
  @resetContentPackUsage: (contentPackID)->

    @questionUsage.resetContentPackUsage(contentPackID)

  # ----------------------------------------------------------------------------------------------------------------
  @writeDBLog: ()->
    Hy.Trace.debug "Question::@writeDBLog"
    
    if @questionUsage?
      @questionUsage.writeDBLog()
    else
      Hy.Trace.debug "Question::writeDBLog (NO DATABASE)"

# ==================================================================================================================
# 
# Operational limit: a manifest is assumed to list no more than one version of a content pack at a time
#
class ContentManifest

  # ----------------------------------------------------------------------------------------------------------------
  @findLatestVersion: ()->

    latestVersion = null
    for m in ContentManager.get().getManifests()
      if (not latestVersion?) or (ContentManifest.compareVersions2(m, latestVersion) > 0)
        latestVersion = m

    return latestVersion

  # ----------------------------------------------------------------------------------------------------------------
  # "a" and "b" are ContentManifests
  # Return 1 if "a" is more recent than "b", 0 if the same, and -1 if "a" is less recent than "b"
  @compareVersions2: (a, b)->
    ContentManifest.compareVersionNumbers(a.versionMajor, a.versionMinor, b.versionMajor, b.versionMinor)

  # ----------------------------------------------------------------------------------------------------------------
  # "a" is a ContentManifest, remaining params are version numbers
  @compareVersions3: (a, bMajor, bMinor)->
    ContentManifest.compareVersionNumbers(a.versionMajor, a.versionMinor, bMajor, bMinor)

  # ----------------------------------------------------------------------------------------------------------------
  # Four params represent version numbers for two different manifests, "a" and "b"
  # return 1 if "a" is more recent than "b", 0 if the same version, and -1 if a is less recent than b
  @compareVersionNumbers: (aMajor, aMinor, bMajor, bMinor)->

    result = 0

    if (aMajor > bMajor) or ((aMajor is bMajor) and (aMinor > bMinor))
      result = 1
    else
      if (aMajor < bMajor) or ((aMajor is bMajor) and (aMinor < bMinor))
        result = -1

    return result

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@contentManager, @contentPackSpecs, @versionMajor, @versionMinor)->

    # true if this manifest and all of its content has been successfully downloaded and processed
    # set true immediately for ShippedManifests. Set true for UpdateManifests after successful
    #  download and processing of the manifest and all of it's content
    @processedCompletely = false

    @contentPacks = []

#    this.processContentPacks()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getContentManager: ()-> @contentManager

  # ----------------------------------------------------------------------------------------------------------------
  isKind: (kind)->

    this.constructor.name is kind

  # ----------------------------------------------------------------------------------------------------------------
  # Must be implemented by subclasses
  getDirectory: ()-> null

  # ----------------------------------------------------------------------------------------------------------------
  setProcessedCompletely: ()->
    @processedCompletely = true

  # ----------------------------------------------------------------------------------------------------------------
  isProcessedCompletely: ()-> @processedCompletely

  # ----------------------------------------------------------------------------------------------------------------
  addContentPack: (contentPack)->
    @contentPacks.push contentPack
    return contentPack

  # ----------------------------------------------------------------------------------------------------------------
  removeContentPack: (contentPack)->

    @contentPacks = _.without(@contentPacks, contentPack)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getContentPacks: ()->
    @contentPacks

  # ----------------------------------------------------------------------------------------------------------------
  isShippedManifest: ()->

    this.constructor.name is "ShippedManifest"

  # ----------------------------------------------------------------------------------------------------------------
  # Return true if every content pack is ready for display... does it have an icon, etc
  checkProcessedCompletely: ()->

    ok = true

    ready = ""
    notReady = ""

    for c in this.getContentPacks()
      if c.isOKToDisplay()
        ready += "#{c.getDisplayName()} "
      else
        notReady += "#{c.getDisplayName()} "
        ok = false

    Hy.Trace.debug "ContentManifest::checkProcessedCompletely (#{this.constructor.name} #{ok} Ready = #{ready} Not Ready=#{notReady})"

    return ok

  # ----------------------------------------------------------------------------------------------------------------
  createContentPack: (contentPackSpec)->

    ContentPack.create(this, contentPackSpec)

  # ----------------------------------------------------------------------------------------------------------------
  processContentPacks: (contentPackSpecs = @contentPackSpecs)->

    newContentPacks = []

    for c in contentPackSpecs
      ok = true

      # May not find content packs in this manifest, since this manifest may not have been added to ContentManager's 
      # list of manifests
      if (latestVersion = ContentPack.findLatestVersion(c.productID))?  
        ok = (ContentPack.compareVersionNumbers(c.version, latestVersion.getVersion()) > 0)

      Hy.Trace.debug "ContentManifest::processContentPacks (#{c.productID} #{c.displayName} #{c.version} #{if ok then "PROCESSING" else "IGNORING"} #{if latestVersion? then latestVersion.version else ""})"

      if ok
        if (contentPack = this.createContentPack(c))?
          if (newContentPack = this.addContentPack(contentPack))?
            newContentPacks.push newContentPack
        else # Error - delete if possible
          this.cleanUpBadContentPackSpec(c)

    if this.checkProcessedCompletely()
      this.setProcessedCompletely()

    newContentPacks

  # ----------------------------------------------------------------------------------------------------------------
  # An attempt to clean up after problems have been detected with a contentPack / contentFile, so that we don't
  # constantly bug the user or leave the app in a wierd state.
  #
  #
  cleanUpBadContentPackSpec: (contentPackSpec)->

    # Try to delete the associated contentFile if possible
    # If a subclass doesn't want to delete, needs to refine this implementation

    if (contentFileKind = contentPackSpec.contentFileKind)? and (directory = contentPackSpec.directory)? and (filename = contentPackSpec.filename)?
      if ContentFile.deleteFile(directory, filename)
        null

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDisplayName: (contentPackSpec)->

    "#{this.constructor.name}"

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->

    "#{this.constructor.name} version=#{@versionMajor}.#{@versionMinor} Dir=#{this.getDirectory()} processedCompletely=#{this.isProcessedCompletely()}"

# ==================================================================================================================
# 
# For kinds of content where we don't have a separate, explicit manifest. So we have to derive key info, such as
# productID and version info, from various clues, in order to list instances of this kind of content for the user.
# 
class DerivedContentManifest extends ContentManifest

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (contentManager, contentPackSpecs, versionMajor, versionMinor)->

    super contentManager, contentPackSpecs, versionMajor, versionMinor

    this

  # ----------------------------------------------------------------------------------------------------------------
  deriveContentPackSpec: (filename)->

    Hy.Trace.debug "DirectoryDerivedContentManifest::deriveContentPackSpec (file=#{filename})"

    if (contentPackSpec = this.matchContentPackByFilename(this.getDirectory(), filename))?
      contentPackSpec
    else 
      null

  # ----------------------------------------------------------------------------------------------------------------
  #
  matchContentPackByFilename: (directory, filename)->

    null

# ==================================================================================================================
# Describes the situation where we derive a manifest by scanning a directory
#
class DirectoryDerivedContentManifest extends DerivedContentManifest

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (contentManager)->

    super contentManager, this.deriveContentPackSpecs(), 1, 0

    this

  # ----------------------------------------------------------------------------------------------------------------
  deriveContentPackSpecs: ()->

    d = Ti.Filesystem.getFile(this.getDirectory())

    if not d.exists()
      d.createDirectory()

    contentPackSpecs = []
    for filename in d.getDirectoryListing()
      if (contentPackSpec = this.deriveContentPackSpec(filename))?
        contentPackSpecs.push contentPackSpec

    contentPackSpecs


# ==================================================================================================================
# 
# We arbitrarily presume that all third-party content is "derived".
#
class ThirdPartyContentManifest extends DirectoryDerivedContentManifest

  kSupportedThirdPartyContentPackKinds = [GDocsContentPack, GDocsContentPack2 ]

  # ----------------------------------------------------------------------------------------------------------------
  @create: (contentManager)->

    new ThirdPartyContentManifest(contentManager)

  # ----------------------------------------------------------------------------------------------------------------
  getDirectory: ()-> Hy.Config.Content.kThirdPartyContentDirectory

  # ----------------------------------------------------------------------------------------------------------------
  # We currently look for: GDocs-based content packs, each of which resides in its own local directory
  #
  matchContentPackByFilename: (directory, filename)->

    for kind in kSupportedThirdPartyContentPackKinds
      if (contentPackSpec = kind.matchByFilename(directory, filename))?
        contentPackSpec.method = "ThirdParty"
        return contentPackSpec

    return null

  # ----------------------------------------------------------------------------------------------------------------
  #
  deriveContentPackInfo: (eventSpec)->

    contentPackSpec = if eventSpec.kind? and eventSpec.id?
      {productID: eventSpec.id, kind: eventSpec.kind}
    else
        null

    contentPackSpec
  # ----------------------------------------------------------------------------------------------------------------
  # See if the url almost matches a supported kind of URL, correcting problems if possible, before we
  # attempt a download
  #
  coerceURL: (url)->

    for kind in kSupportedThirdPartyContentPackKinds
      if kind.matchURL(url) or kind.matchAuthChallengeURL(url)
        if (id = kind.extractGDocsIDFromURL(url))?
          return [kind, id, kind.makeURL(id)]

    return [null, null, null]

  # ----------------------------------------------------------------------------------------------------------------
  matchAuthChallengeURL: (url)->

    for kind in kSupportedThirdPartyContentPackKinds
      if kind.matchAuthChallengeURL(url)
          return true

    return false

  # ----------------------------------------------------------------------------------------------------------------
  diagnoseURLIssues: (eventSpec)->

    if eventSpec.kind? then kind.diagnoseURLIssues(eventSpec.URL) else null

  # ----------------------------------------------------------------------------------------------------------------
  # Called when user wants to import a content pack
  #
  addContent: (url, fnRefreshProgressReport = null, fnRefreshDone = null)->

    @fnRefreshDone = fnRefreshDone
    @fnRefreshProgressReport = fnRefreshProgressReport

    eventSpecs = []

    if url?

      # We don't parse the URL first, etc, since it might be shortened, etc. We really have no choice
      # except to retrieve it, allowing the HTTPClient to deal with various redirects, etc.
      eventSpecs.push {
        callback: ((cm, event, eventSpec)=>return(cm.refreshContentDownloaded(event, eventSpec))), 
        URL: url,
        display: "ThirdPartyContentManifest::addContent (#{url})",
        operation: "add"
        mode: "downloadingContentPack"
        }

      result = this.refreshContentInitialize(eventSpecs)
    else
      result = false

    result

  # ----------------------------------------------------------------------------------------------------------------
  # Called when the user wishes to refresh the specified contentPack
  #
  refreshContent: (contentPack, fnRefreshProgressReport = null, fnRefreshDone = null)->

    result = true

    @fnRefreshDone = fnRefreshDone
    @fnRefreshProgressReport = fnRefreshProgressReport

    if contentPack? and contentPack.isThirdParty()
      eventSpecs = []
      eventSpecs.push {
        callback: ((cm, event, eventSpec)=>return(cm.refreshContentDownloaded(event, eventSpec))), 
        URL: contentPack.getSourceURL(),
        display: "ThirdPartyContentManifest::refreshContentStart (#{contentPack.dumpStr()})",
        operation: "refresh",
        mode: "downloadingContentPack"
        contentPackInfo: {
          contentPack: contentPack,
          displayName: contentPack.getDisplayName(),
          kind:        contentPack.getKind(),
          directory:   contentPack.getDirectory(),
          productID:   contentPack.getProductID(),
          newVersion:  contentPack.getVersion() + 1 }
        }

      result = this.refreshContentInitialize(eventSpecs)

    result

  # ----------------------------------------------------------------------------------------------------------------
  refreshContentInitialize: (eventSpecs)->

    downloadManager = new Hy.Network.DownloadManager(this, 
                                                     ((cm)=>cm.refreshContentStart(eventSpecs)), 
                                                     ((cm, status)=>cm.refreshContentLoop((s = status[0]).status, s.object)),
                                                     "ThirdPartyContentManifest::refreshContent")

    true

  # ----------------------------------------------------------------------------------------------------------------
  refreshContentStart: (eventSpecs)->

    Hy.Trace.debug "ThirdPartyContentManifest::refreshContentStart"

    return eventSpecs

  # ----------------------------------------------------------------------------------------------------------------
  refreshContentDownloaded: (event, eventSpec)->

    contentPackInfo = eventSpec.contentPackInfo
    locationURL = event.getLocationURL()

    fnDone = ()=>
      # Are we at an authentication challenge?
      status = if this.matchAuthChallengeURL(locationURL)
        false
      else
        eventSpec.locationURL = locationURL
        eventSpec.rawText = event.responseText
        eventSpec.mode = "downloadedContentPack"
        true
      status

    Hy.Trace.debug "ThirdPartyContentManifest::refreshContentDownloaded (#{eventSpec.URL} size=#{(event.responseText).length})"

    # GREAT PLACE FOR A BRREAKPOINT

    # See if we can/need to coerce this URL into something we can process
    status = false

    if not eventSpec.isCoerced? 

      [kind, id, coercedURL] = this.coerceURL(locationURL)

      if coercedURL?
        newEventSpec = _.clone(eventSpec)

        newEventSpec.kind = kind
        newEventSpec.id = id
        newEventSpec.URL = coercedURL
        newEventSpec.isCoerced = true # Don't coerce more than once
        eventSpec.mode = "redirecting" # Will be the signal that we are still chasing this content

        @fnRefreshProgressReport?("Found content, redirecting to preferred format...")

        Hy.Trace.debug "ThirdPartyContentManifest::refreshContentDownloaded (COERCED #{coercedURL})"

        this.refreshContentInitialize([newEventSpec])
        status = true

      else
        status = fnDone()
    else
      status = fnDone()

    status


  # ----------------------------------------------------------------------------------------------------------------
  refreshContentLoop: (status, eventSpec)=>

    fn_unexpectedMode = (mode, context = null)=>
      s = "ERROR: unexpected mode (#{mode} #{if context? then context else ""})"
      new Hy.Utils.ErrorMessage("fatal", "refreshContentLoop", s) #will display popup dialog
      null

    fn_downloadFailure = ()=>
      @refreshState.numFail++
      ContentManager.addMessage("error", null, "Download Failed. Check URL and republish with Google \"publish\" option. Make sure to NOT select \"Require viewers to sign in\"")
      null

    # We use this object to keep track of stats across invocations of this function.
    # We might find ourselves here more than once if we coerced a URL and subsequently chased the new URL
    #
    if not @refreshState?
      # Set up for warn/error messages
      ContentManager.clearMessages()

      @refreshState =
        numSuccess: 0
        numFail: 0
        numAdded: 0
        numUpdated: 0
        messages: []
        contentPackSpec: null
        contentPack: null

    # This code assumes that we're processing one contact pack at a time.

    Hy.Trace.debug "ThirdPartyContentManifest::refreshContentLoop (mode=#{eventSpec.mode} status=#{eventSpec.display} #{status})"

    if not (nextMode = eventSpec.mode)?
      fn_unexpectedMode(nextMode)         

    while nextMode?
      nextMode = switch nextMode
        when "downloadingContentPack", "downloadingCustomizationAssets"
          if status
            # Shoudn't get here
            fn_unexpectedMode(nextMode, "status=#{status}")         
          else
            fn_downloadFailure()
          "done"

        when "redirecting"
          # Just keep waiting...
          null

        when "downloadedContentPack"
          if status
            if this.refreshContentProcess(eventSpec)?
              "downloadCustomizationAssets"
            else
              "done"
          else
            fn_downloadFailure()
            "done"

        when "downloadCustomizationAssets"
          if this.refreshContentDownloadCustomizationAssets(eventSpec)
            eventSpec.mode = "downloadingCustomizationAssets"
            null
          else
            "done"

        when "downloadedCustomizationAssets"
          "done"

        when "done"
          if ContentManager.haveErrorMessage()
            if @refreshState.contentPackSpec?
              ContentFile.delete(@refreshState.contentPackSpec.contentFile)
          @refreshState.messages = this.refreshContentProcessMessages(@refreshState.messages, eventSpec)
          this.refreshContentReport(eventSpec)
          null

        else
          fn_unexpectedMode(eventSpec.mode)         

    this

  # ----------------------------------------------------------------------------------------------------------------
  refreshContentProcess: (eventSpec)->

    if (newContentPackSpec = this.refreshContentPreprocess(eventSpec))?
      @refreshState.contentPackSpec = newContentPackSpec
      for newContentPack in this.processContentPacks([newContentPackSpec])
        @refreshState.contentPack = newContentPack

        newContentPack.load()

        # Make it appear selected # Nope - V1.0.2
        newContentPack.setSelected(false) 

        if newContentPack.getVersion() is 1
          @refreshState.numAdded++
        else
          @refreshState.numUpdated++

        # Delete previous version to avoid cluttering up the user's storage
        ContentPack.deleteByProductID(newContentPack.getProductID(), (c)=>c.getVersion() < newContentPack.getVersion())

    newContentPackSpec

  # ----------------------------------------------------------------------------------------------------------------
  refreshContentDownloadCustomizationAssets: (eventSpec)->

    cust = null

    fn_addMessage = (kind, line, message)=>ContentManager.addMessage(kind, line, message)

    fn_done = (status)=>
      for s in status
        if not s.status
          # Should have already prepared an error message and cleared the failure
           null
#          c = s.object.customization
#          ContentManager.addMessage("warning", c.lineNum, "Couldn\'t download \"#{c.propName}\", please try again")
#          cust.clearAssetDownloadFailure(c)          

      # TODO: Check status
      eventSpec.mode = "downloadedCustomizationAssets"
      this.refreshContentLoop(true, eventSpec)
      this

    f = false
    if (cust = @refreshState?.contentPack?.getCustomization())?
      if (assetEventSpecs = cust.prepareAssetDownloadEventSpecs(@fnRefreshProgressReport, fn_addMessage))?
        @fnRefreshProgressReport("Downloading customization assets...")

        new Hy.Network.DownloadManager(cust, 
                                       ((c)=>assetEventSpecs),
                                       ((cm, status)=>fn_done(status)),
                                       "refreshContentDownloadCustomizationAssets")
        f = true
    
     f

  # ----------------------------------------------------------------------------------------------------------------
  refreshContentPreprocess: (eventSpec)->

    newContentPackSpec = null

    contentPackInfo = switch eventSpec.operation
      when "add"
        # eventSpec should had the ID of the content pack
        if (contentPackInfo = this.deriveContentPackInfo(eventSpec))?
          contentPackInfo.displayName = null
          contentPackInfo.directory = this.getDirectory()

          # Check to see if this content pack doesn't already exist. 
          contentPackInfo.newVersion = if (existingContentPack = ContentPack.findLatestVersion(contentPackInfo.productID))?
            # If so, treat this like a refresh
            existingContentPack.getVersion() + 1
          else
            1
        else
          report = if (diagnosis = this.diagnoseURLIssues(eventSpec))?
            diagnosis
          else if eventSpec.locationURL isnt eventSpec.URL
            "URL redirects to content which does not appear valid:\n#{Hy.Utils.String.trimWithElipsis(eventSpec.locationURL, 3 * Hy.UI.NavGroup.getExplainMaxCharsPerLine())}"
          else
            "URL does not appear to reference valid content:\n#{Hy.Utils.String.trimWithElipsis(eventSpec.URL, 3 * Hy.UI.NavGroup.getExplainMaxCharsPerLine())}"

          ContentManager.addMessage("error", null, report)
 
        contentPackInfo

      when "refresh"
        eventSpec.contentPackInfo

      else
        Hy.Trace.debug "ThirdPartyContentManifest::refreshContentPreprocess (NO CONTACT PACK INFO)"
        null

    if contentPackInfo?
      displayName = if contentPackInfo.displayName? then "\"#{contentPackInfo.displayName}\" " else ""

      # Check size
      if eventSpec.rawText.length > (maxSize = contentPackInfo.kind.getMaxContentFileSize())
        ContentManager.addMessage("error", null, "Content must be smaller than #{(maxSize/1024)} KB)")
      else
        # Check header for hints that it's the right kind of file
        if contentPackInfo.kind.checkTypeViaPeek(eventSpec.rawText)
          # Write file
          if (newContentFile = contentPackInfo.kind.writeNewContentFile(contentPackInfo.directory, contentPackInfo.productID, contentPackInfo.newVersion, eventSpec.rawText))?
            # Update user
            if contentPackInfo.displayName? and contentPackInfo.newVersion?
              @fnRefreshProgressReport?("Updated \"#{contentPackInfo.displayName}\" (update ##{contentPackInfo.newVersion})")
            # Create a "spec" for this new contentPack, to be used to create/load it
            if (newContentPackSpec = this.deriveContentPackSpec(newContentFile.getFilename()))?
              null
            else
              if newContentFile? # Clean up
#                ContentFile.delete(newContentFile) # Move this to main loop? ??
                newContentFile = null

          else
            ContentManager.addMessage("error", null, "INTERNAL ERROR: Couldn\'t store topic (please report)")
            @fnRefreshProgressReport?("Sorry, couldn\'t store \"#{contentPackInfo.displayName}\" (v#{contentPackInfo.newVersion})")
            Hy.Trace.debug "ThirdPartyContentManifest::refreshContentDownloaded (COULD NOT WRITE CONTENT FILE #{contentPackInfo.kind} #{contentPackInfo.productID})"
        else
          report = "First cell of first row must contain \"#{ContentFileWithHeader.kFileTag}\""
          if eventSpec.operation is "refresh" # let's add a little more info
            report += "\nAlso: be sure to use Google \"publish\" option & don't select \"Require viewers to sign in\""
       
          ContentManager.addMessage("error", null, report)

    newContentPackSpec

  # ----------------------------------------------------------------------------------------------------------------
  refreshContentProcessMessages: (messages, eventSpec)->

    newMessages = []

    fnAddMessage = (kind, line, m)=>
      newMessages.push {kind: kind, line: line, message: m}

    # Message errors first and then warnings
    # Add in any context as necessary
    # NOTE: WE DON'T DO THAT HERE SINCE WE PRESUME WE'RE PROCESSING ONE CONTENT PACK AT A TIME
    #
    for k in ["error", "warning"]
      if (messes = ContentManager.getMessages(k)).length > 0

        intro = switch k
          when "error"
            "Correct these issues and try again:"
          when "warning"
            "These minor issues were ignored:"
          else
            null

        if intro?
          fnAddMessage("header", null, intro)


        for m in messes
          fnAddMessage(m.kind, m.line, m.message)

    messages.concat(newMessages)

  # ----------------------------------------------------------------------------------------------------------------
  refreshContentRenderMessages: (messages)->

    maxNumMessages = 3

    fnAddPadded = (s, append)=>
      if s isnt ""
        s += " "
      s += append
      s

    fnFormatMessage = (m)=>
      s = ""
      if m.line?
        s = fnAddPadded(s, "Line #{m.line}: ")
      if m.message?
        s = fnAddPadded(s, m.message)
      s

    report = ""
    numMessages = 0
    tooMany = false
    successFlag = true

    # Show errors first
    sortedMessages = _.sortBy(messages, (m)=>m.kind is "error")

    for message in messages
      if not tooMany
        m = null
        switch message.kind
          when "warning", "error"
            numMessages++
            if numMessages > maxNumMessages # Don't want to overwhelm the user
              m = "(Too many more messages to display) "
              tooMany = true
            else
              m = fnFormatMessage(message)

            if message.kind is "error"
              successFlag = false

          when "header"
            m = fnFormatMessage(message)

        if m?
          if report isnt ""
            report += "\n"
          report += m

    [successFlag, report]

  # ----------------------------------------------------------------------------------------------------------------
  refreshContentReport: (eventSpec)->
    @refreshState.numSuccess = @refreshState.numAdded + @refreshState.numUpdated

    if @fnRefreshDone?
      changes = @refreshState.numUpdated isnt 0 or @refreshState.numAdded isnt 0

      [successFlag, messages] = this.refreshContentRenderMessages(@refreshState.messages)

      contentPack = if successFlag then @refreshState.contentPack else null
      context = if contentPack? then " \"#{contentPack.getDisplayName()}\"" else ""

      # Work up a nice 1-line summary for the marquee.
      summary = ""

      # Add'l intro info for the NavGroup, if needed
      introMessage = null

      switch eventSpec.operation
        when "add"
          if successFlag
            summary += "Trivia Pack added successfully!"
            introMessage = "Trivia Pack#{context} added successfully"
            Hy.ConsoleApp.get().analytics?.logUCCAddSuccess()
          else
            summary += "Trivia Pack not added"
            introMessage = "Could not add Trivia Pack due to problems encountered during download and processing. Please check the URL and try again."
            Hy.ConsoleApp.get().analytics?.logUCCAddFailure()
        when "refresh"
          if successFlag
            summary += "Trivia Pack updated successfully!"
            introMessage = "Trivia Pack#{context} updated successfully"
            Hy.ConsoleApp.get().analytics?.logUCCRefreshSuccess()
          else
            summary += "Trivia Pack not updated"
            introMessage = "Trivia Pack could not be updated due to problems encountered during download and processing. Please try again later. If problem persists, delete and then re-add the contest"
            Hy.ConsoleApp.get().analytics?.logUCCRefreshFailure()

      # In case we have nothing to say, make something up, for the NavGroup
      if messages.length is 0 and introMessage?
        messages= introMessage

      @fnRefreshDone(successFlag, changes, summary,  messages)

    @refreshState = null

    this

# ==================================================================================================================
# 
class FileBasedManifest extends ContentManifest

  # ----------------------------------------------------------------------------------------------------------------
  @matchFilename: (filename)->
    return filename.match(/^trivially-content-manifest--[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9].json$/g)?

  # ----------------------------------------------------------------------------------------------------------------
  @getFilenameFromVersion: (versionMajor, versionMinor)->
    return "trivially-content-manifest--#{versionMajor}-#{versionMinor}.json"

  # ----------------------------------------------------------------------------------------------------------------
  # When will we ever return more than one?
  #
  @findByFilename: (filename)->

    result = []

    for m in ContentManager.get().getManifests()
      if (m.filename is filename)
        result.push m

    return result

  # ----------------------------------------------------------------------------------------------------------------
  @extractVersionInfo: (filename)->

    i = filename.indexOf "--"
    if i > -1
      major = filename.substr(i+2, 3)
      minor = filename.substr(i+6, 4)
     
      return {major: major, minor: minor}

    return null

  # ----------------------------------------------------------------------------------------------------------------
  # Return true if the new manifest with versionMajor/versionMinor should be downloaded and processed
  @checkManifestUpdate: (versionMajor, versionMinor)->

    Hy.Trace.debug "FileBasedManifest::checkManifestUpdate (ENTER version=#{versionMajor}.#{versionMinor})"

    # Check:
    # - Is it already local?
    # - Is it more recent than what we already have, or if the same but incomplete?

    filename = FileBasedManifest.getFilenameFromVersion(versionMajor, versionMinor)

    isLocal = _.size(FileBasedManifest.findByFilename(filename))> 0

    if isLocal
      Hy.Trace.debug "FileBasedManifest::checkManifestUpdate (already local - #{filename})"

    better = true

    latest = ContentManifest.findLatestVersion()

    if latest?
      switch ContentManifest.compareVersions3(latest, versionMajor, versionMinor)
        when -1
          Hy.Trace.debug "FileBasedManifest::checkManifestUpdate (more recent)"
        when 0
          if latest.isProcessedCompletely()
            better = false
          else
            Hy.Trace.debug "FileBasedManifest::checkManifestUpdate (same version, but not processed completely)"
        when 1
          better = false
          Hy.Trace.debug "FileBasedManifest::checkManifestUpdate (less recent)"

    status = (not isLocal) or better

    Hy.Trace.debug "FileBasedManifest::checkManifestUpdate (EXIT #{status})"

    return status
    
  # ----------------------------------------------------------------------------------------------------------------
  @readFile: (directory, filename)->
    contents = null

    file = Ti.Filesystem.getFile(directory, filename)

    if file.exists()
      contents = file.read().toString()

    if not contents?
      s = "ERROR: manifest file appears empty (#{filename})"
      new Hy.Utils.ErrorMessage("fatal", "FileBasedManifest", s) #will display popup dialog

    return contents

  # ----------------------------------------------------------------------------------------------------------------
  @parseText: (text, url, onFailureFn = null)->

    m = null
    try
      m = JSON.parse(text)
      Hy.Trace.debug "FileBasedManifest::parseText (length=#{_.size m})"
    catch e
      s = "ERROR parsing manifest file (#{url})"
      new Hy.Utils.ErrorMessage("fatal", "FileBasedManifest", s) #will display popup dialog

      onFailureFn?()

    return m

  # ----------------------------------------------------------------------------------------------------------------
  @create: (contentManager, kind)->

    manifest = null

    if (filename = kind.getFilename())?
      if (text = kind.readFile(filename))?
        if (m = kind.parseText(text, filename))?
          manifest = new kind(contentManager, m, filename)

    manifest

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (contentManager, contentPackSpecs, @filename)->

    if not (version = FileBasedManifest.extractVersionInfo(@filename))?
      version = {}
      version.major = 0
      version.minor = 0

    super contentManager, contentPackSpecs, version.major, version.minor

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDisplayName: ()->

    "#{this.constructor.name} #{@filename}"

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->

    super + " #{@filename}"

# ==================================================================================================================
# 
# Models our own content, with its various idiosyncracies

class LegacyContentManifest extends FileBasedManifest

  # ----------------------------------------------------------------------------------------------------------------
  @matchContentPackFilename: (filename, productID)->

    regex = new RegExp("Trivially--#{productID}--[0-9][0-9][0-9][0-9].trivia$", "g")

    regex.test(filename)

  # ----------------------------------------------------------------------------------------------------------------
  @extractVersionInfoFromContentPackFilename: (filename)->

    version = null

    if (i = filename.indexOf("--")) > -1
      rest = filename.substr(i + 2)
      if (j = rest.indexOf("--")) > -1
        version = rest.substr(j+2, 4)

    version

  # ----------------------------------------------------------------------------------------------------------------
  # Shipped and Update manifests manage content packs with filenames of this form
  #
  @findLocalContentPackVersionsByProductID: (contentPack)->

    d = Ti.Filesystem.getFile(contentPack.getDirectory())

    versions = []

    for file in d.getDirectoryListing()
      if LegacyContentManifest.matchContentPackFilename(file, contentPack.getProductID())
        versions.push LegacyContentManifest.extractVersionInfoFromContentPackFilename(file)

    versions

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (contentManager, contentPackSpecs, filename)->

    this.compatibility_1_3(contentPackSpecs)

    this.fixFileToObjectSchemaDifferences(contentPackSpecs)
    this.setContentPackInfo(contentPackSpecs)

    super contentManager, contentPackSpecs, filename

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Fix up legacy differences between various property names referenced in manifest files
  # "productId" -> "productID"
  # "icon" -> "iconSpec"
  #
  fixFileToObjectSchemaDifferences: (contentPackSpecs)->
 
    for contentPackSpec in contentPackSpecs
      if contentPackSpec.productId?
        contentPackSpec.productID = contentPackSpec.productId
      if contentPackSpec.icon?
        contentPackSpec.iconSpec = contentPackSpec.icon
      if contentPackSpec.numRecords?
        contentPackSpec.numRecords = parseInt(contentPackSpec.numRecords)
      if contentPackSpec.difficulty?
        contentPackSpec.difficulty = parseInt(contentPackSpec.difficulty)

    this

  # ----------------------------------------------------------------------------------------------------------------
  compatibility_1_3: (contentPackSpecs)->

    for contentPackSpec in contentPackSpecs
      # "longDescription": introduced in 1.3. Existing installations with update manifests will be missing it.
      if not contentPackSpec.longDescription?
        contentPackSpec.longDescription = contentPackSpec.description

    this

  # ----------------------------------------------------------------------------------------------------------------
  setContentPackInfo: (contentPackSpecs)->

    for contentPackSpec in contentPackSpecs
      contentPackSpec.filename = this.getContentPackFilename(contentPackSpec)
      contentPackSpec.directory = this.getContentPackDirectoryByMethod(contentPackSpec.method)
      contentPackSpec.contentFileKind = JSONContentFile
      contentPackSpec.kind = ContentPack
    this

  # ----------------------------------------------------------------------------------------------------------------
  # Shipped and Update manifests manage content packs with filenames of this form
  #
  getContentPackFilename: (contentPackSpec)->

    name = "Trivially--{productID}--{version}"
    name = name.replace(/{productID}/, contentPackSpec.productID)
    name = name.replace(/{version}/, contentPackSpec.version)
    name += ".trivia"

    name

  # ----------------------------------------------------------------------------------------------------------------
  # Content packs listed in a shipped manifest may refer to free content shipped with the app, or for-purchase
  # content available for download. On the other hand, all content listed in an update manifest is by definition
  # coming via download.
  #
  # Shipped content is found in the (read-only) Resources directory of the bundle, and any downloaded content 
  # is expected in the Documents directory.
  #
  getContentPackDirectory: (isAppStoreContent)->

    directory = if this.isShippedManifest()
      if isAppStoreContent
        Hy.Config.Content.kUpdateDirectory # Documents directory
      else
        Hy.Config.Content.kShippedDirectory # Resources directory
    else
      Hy.Config.Content.kUpdateDirectory # Documents directory

    directory

  # ----------------------------------------------------------------------------------------------------------------
  getContentPackDirectoryByMethod: (method)->
 
    this.getContentPackDirectory(method is "AppStore")

# ==================================================================================================================
# 

class ShippedManifest extends LegacyContentManifest

  # ----------------------------------------------------------------------------------------------------------------
  @getDirectory: ()->Hy.Config.Content.kShippedDirectory

  # ----------------------------------------------------------------------------------------------------------------
  # There should be exactly one manifest file in this directory - pick the first one we find

  @findFile: ()->
    directory = ShippedManifest.getDirectory()

    d = Ti.Filesystem.getFile(directory)
    dirList = d.getDirectoryListing()

    for f in dirList
      if FileBasedManifest.matchFilename(f)
        Hy.Trace.debug "ShippedManifest::findFile (file=#{f})"

        if (version = FileBasedManifest.extractVersionInfo(f))?
          if version.major is Hy.Config.Content.kContentMajorVersionSupported
            Hy.Trace.debug "ShippedManifest::findFile (USING #{f} corresponds to required major version #{Hy.Config.Content.kContentMajorVersionSupported})"
            return f

    Hy.Trace.debug "ShippedManifest::findFile (COULD NOT FIND major version #{Hy.Config.Content.kContentMajorVersionSupported})"
    
    return null    

  # ----------------------------------------------------------------------------------------------------------------  
  @getFilename: ()->

    filename = ShippedManifest.findFile()

    if not filename?
      s = "ERROR couldn\'t find shipped content manifest (#{ShippedManifest.getDirectory()})"
      new Hy.Utils.ErrorMessage("fatal", "ShippedManifest", s) #will display popup dialog

    return filename

  # ----------------------------------------------------------------------------------------------------------------
  @readFile: (filename)->  
    FileBasedManifest.readFile(ShippedManifest.getDirectory(), filename)

  # ----------------------------------------------------------------------------------------------------------------
  @onParseError: (filename)->
    # attempt to set up for future success
    try
      f = Ti.Filesystem.getFile(ShippedManifest.getDirectory(), filename)
      if f.exists()
        f.deleteFile()
    catch e
      Hy.Trace.debug "ShippedManifest::onParseError (Delete Failed)"

    null

  # ----------------------------------------------------------------------------------------------------------------
  @parseText: (text, filename)->
    FileBasedManifest.parseText(text, filename, ()=>ShippedManifest.onParseError(filename))

  # ----------------------------------------------------------------------------------------------------------------
  @create: (contentManager)->

    FileBasedManifest.create(contentManager, ShippedManifest)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (contentManager, contentPackSpecs, filename)->
    super contentManager, contentPackSpecs, filename

    this.setProcessedCompletely()
    this

  # ----------------------------------------------------------------------------------------------------------------
  getDirectory: ()->ShippedManifest.getDirectory()

  # ----------------------------------------------------------------------------------------------------------------
  #
  cleanUpBadContentPackSpec: (contentPackSpec)->

    this # Can't delete shipped content files

# ==================================================================================================================
# 
class UpdateManifest extends LegacyContentManifest

  # ----------------------------------------------------------------------------------------------------------------
  @getDirectory: ()-> Hy.Config.Content.kUpdateDirectory

  # ----------------------------------------------------------------------------------------------------------------
  @findFile: ()->

    filename = null

    directory = UpdateManifest.getDirectory()

    d = Ti.Filesystem.getFile(directory)

    dirList = d.getDirectoryListing()

    valid = []
    for file in dirList
      Hy.Trace.debug "UpdateManifest::findFile (file=#{file})"
      if FileBasedManifest.matchFilename(file)
        version = FileBasedManifest.extractVersionInfo file
        if version?      
          major = version.major
          minor = version.minor

          if major is Hy.Config.Content.kContentMajorVersionSupported
            Hy.Trace.debug "UpdateManifest::findFile (MATCH file=#{file} major=#{major} minor=#{minor})"
            valid.push {major:major, minor:minor, file:file}

    if _.size(valid) isnt 0
      valid = _.sortBy valid, (v)=>v.minor
      filename =  _.last(valid).file

    return filename

  # ----------------------------------------------------------------------------------------------------------------  
  @getFilename: ()->
    UpdateManifest.findFile()

  # ----------------------------------------------------------------------------------------------------------------  
  @readFile: (filename)->
    FileBasedManifest.readFile(UpdateManifest.getDirectory(), filename)

  # ----------------------------------------------------------------------------------------------------------------
  @parseText: (text, url)->
    FileBasedManifest.parseText(text, url)
  
  # ----------------------------------------------------------------------------------------------------------------
  @create: (contentManager)->

    if (manifest = FileBasedManifest.create(contentManager, UpdateManifest))?
      manifest.setWritten()

    manifest

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (contentManager, contentPackSpecs, filename)->
    super contentManager, contentPackSpecs, filename

    @written = false
    @text = null
    this

  # ----------------------------------------------------------------------------------------------------------------
  getDirectory: ()->UpdateManifest.getDirectory()

  # ----------------------------------------------------------------------------------------------------------------
  setWritten: ()->
    @written = true

  # ----------------------------------------------------------------------------------------------------------------
  setText: (text)->
    @text = text

  # ----------------------------------------------------------------------------------------------------------------
  writeFile: ()->

    ok = false

    if @written
      Hy.Trace.debug "UpdateManifest::writeManifest (ALREADY WRITTEN #{@filename})"
    else
      if @text?
        f = Ti.Filesystem.getFile(this.getDirectory(), @filename)

        if f.exists()
          Hy.Trace.debug "UpdateManifest::writeManifest (ALREADY EXISTS #{@filename} (DELETING))"
          f.deleteFile()

        Hy.Trace.debug "UpdateManifest::writeManifest (writing file #{@filename})"
        f.write @text
        f.setRemoteBackup(false) # Don't need to backup downloaded update manifest files
        this.setWritten()
        ok = true
      else
        Hy.Trace.debug "UpdateManifest::writeManifest (NO TEXT #{@filename})"

    return ok

# ==================================================================================================================
# Intended to be the main interface for content
#
# Offers these observer messages
#
#   userCreatedContentSessionProgressReport
#   userCreatedContentSessionStarted
#   userCreatedContentSessionCompleted
#
#   inventoryInitiated
#   inventoryUpdate
#   inventoryCompleted
#
#   purchaseInitiated
#   purchaseProgressReport
#   purchaseCompleted
#
#   restoreInitiated
#   restoreProgressReport
#   restoreCompleted

#   contentUpdateSessionStarted
#   contentUpdateSessionProgressReport
#   contentUpdateSessionCompleted
#
class ContentManager

  _.extend ContentManager, Hy.Utils.Observable

  kUpdateStatusUnknown     = 0
  kUpdateStatusSoFarSoGood = 1
  kUpdateStatusSortaOK     = 2
  kUpdateStatusFailed      = 3

  gInstance = null

  gMessages = null

  # ----------------------------------------------------------------------------------------------------------------
  @clearMessages: ()->
    
    gMessages = null

  # ----------------------------------------------------------------------------------------------------------------
  @addMessage: (kind, line, message)->

    gMessages ||= []

    gMessages.push {kind: kind, line: line, message: message}

  # ----------------------------------------------------------------------------------------------------------------
  @haveErrorMessage: ()->
    ContentManager.getMessages("error").length > 0

  # ----------------------------------------------------------------------------------------------------------------
  @getMessages: (kind = null)-> 

    if kind? 
      _.select(gMessages, (m)=>m.kind is kind)
    else
      gMessages

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Returns current customization, if any
  #
  @getCurrentCustomization: ()->

    selectedContentPacks = _.select(ContentManager.get().getLatestContentPacksOKToDisplay(), (c)=>c.isSelected())

    # We expect only one...
    customization = if (selectedCustomizedPack = _.find(selectedContentPacks, (c)=>c.hasCustomization()))?
      selectedCustomizedPack.getCustomization()
    else
      null

    customization

  # ----------------------------------------------------------------------------------------------------------------    
  # Returns a string if we're in the middle of, say, a content pack purchase or upgrade, or a feature buy, etc
  # Returns null otherwise
  #
  @isBusy: ()->

    reason = if (contentManager = ContentManager.get())?
      contentManager.isBusy()
    else
      null

  # ----------------------------------------------------------------------------------------------------------------    
  @init: ()->
    if not gInstance?
      new ContentManager()

    gInstance

  # ----------------------------------------------------------------------------------------------------------------    
  constructor: ()->

    gInstance = this
    @manifests = []

    @iapInventory = null

    @contentPackBuyActivity = false
    @contentManifestUpdateActivity = false
    @UCC_Activity = false
    @restoreActivity = false

    Questions.init()
    this.loadManifests()

    this.scheduleInventory()

    @uccPurchaseItem = UserCreatedContentPurchaseItem.create(this)

    this

  # ----------------------------------------------------------------------------------------------------------------
  isBusy: ()->

    reason = null

    if this.isContentManifestUpdateActivityInProgress()
      reason = "Update in progress"

    if this.isContentPackBuyActivityInProgress()
      reason = "Purchase in progress"

    if this.isRestoreActivityInProgress()
      reason = "Purchase restore in progress"

    if this.isUCC_ActivityInProgress()
      reason = "Custom Trivia Pack activity in progress"

    reason    

  # ----------------------------------------------------------------------------------------------------------------
  # Returns true if not busy. If "busy", puts up ErrorMessage dialog
  #
  ensureNotBusy: (activity)->

    if (reason = this.isBusy())?
      s = "ContentManager unexpectedly busy (#{reason}) while attempting \"#{activity}\""
      new Hy.Utils.ErrorMessage("fatal", "ContentManager", s) #will display popup dialog
      
    reason is null

  # ----------------------------------------------------------------------------------------------------------------
  getUCCPurchaseItem: ()-> @uccPurchaseItem

  # ----------------------------------------------------------------------------------------------------------------
  removeManifest: (manifest)->

    @manifests = _.without(@manifests, manifest)

  # ----------------------------------------------------------------------------------------------------------------
  addManifest: (manifest)->

    # First remove any existing manifests of the same version
    newManifests = _.reject(@manifests, (m)=>ContentManifest.compareVersions2(m, manifest) is 0)
    newManifests.push(manifest)

    Hy.Trace.debug "ContentManager::addManifest (#{manifest.constructor.name} before=#{_.size(@manifests)} after=#{_.size(newManifests)})"

    @manifests = newManifests

  # ----------------------------------------------------------------------------------------------------------------
  getManifests: ()-> @manifests

  # ----------------------------------------------------------------------------------------------------------------
  getManifestByKind: (kind)-> 

    _.detect(this.getManifests(), (m)=>m.isKind(kind))

  # ----------------------------------------------------------------------------------------------------------------
  getContentPacks: (filterFn = null)->
    contentPacks = []
    for manifest in this.getManifests()
      for contentPack in manifest.getContentPacks()
        if (not filterFn?) or filterFn?(contentPack)
          contentPacks.push(contentPack)

    contentPacks

  # ----------------------------------------------------------------------------------------------------------------
  getLatestContentPacksOKToDisplay: ()->

    this.getLatestContentPacks((c)=>c.isOKToDisplay())

  # ----------------------------------------------------------------------------------------------------------------
  getLatestContentPacks: (filterFn = null)->
    contentPacks = []

    for contentPack in this.getContentPacks()
      latest = ContentPack.findLatestVersion(contentPack.getProductID(), filterFn)

      if latest? and not _.detect(contentPacks, (c)=>c is latest)
        contentPacks.push latest

    contentPacks

  # ----------------------------------------------------------------------------------------------------------------
  loadManifests: ()->

    for t in [ShippedManifest, UpdateManifest, ThirdPartyContentManifest]
      if (manifest = t.create(this))?
        this.addManifest(manifest)
        manifest.processContentPacks()

    this.dump()
    this

  # ----------------------------------------------------------------------------------------------------------------    
  # Check if there's a required or strongly-urged update pending
  #
  doUpdateChecks: ()->

    reasons = ""
    required = false

    fnAddReason = (reason)=>
      if reasons isnt ""
        reasons += "\n"
      reasons += reason
      null

    # Make sure ContentManager isn't already doing something, and that the page isn't going to be busy also
    if not this.isBusy() 

      # Scenario #0: Update manifest told us to... but only for popovers (otherwise, handled via marquee)
      if (update = ContentManifestUpdate.getUpdate())? and update.isPopover()
        if (r = update.isRequired()) or update.shouldRemind()
          update.resetReminderTimer()
          fnAddReason(update.getPopover())
          required = required or r
    
      # Scenario #1: old versions of purchased content are local, but ShippingManifest and UpdateManifest don't refer to 'em.
      flag = false
      for c in this.findUnmanifestedEligibleContentPacks()

        Hy.Trace.debug "ContentManager::doUpdateChecks (SCENARIO #1: #{c.dumpStr()})"

        c.setUpdateAvailable(true)

        if not flag # Only message once
          fnAddReason("New versions of purchased content\npacks are available")
          flag = true

        required = required or true # Force these updates

      if reasons isnt ""
        this.updateManifests(reasons, required)        

    reasons isnt ""

  # ----------------------------------------------------------------------------------------------------------------
  #
  # Scenario: an updated version of the app has been installed, and its ShippedManifest includes a version of an IAP
  # item that is more recent than an IAP item that's already been purchased and is on the device. We will have missed
  # noticing that during the "loadManifests" pass... the item will just look like it wasn't purchased, even through it's
  # on the device, albeit as an older version.
  #
  # Update: this is now handled in "ContentPack.initEntitlement"
  #
  findUnmanifestedEligibleContentPacks: ()->

    contentPacks = []

    for c in this.getLatestContentPacks()
      if c.isAppStoreContent() and not c.isEntitled()
        if not c.isLocal()
          versions = LegacyContentManifest.findLocalContentPackVersionsByProductID(c)

          if _.size(versions) > 0
            Hy.Trace.debug "ContentManager::findUnmanifestedEligibleContentPacks (content pack: #{c.dumpStr()} version: #{c.getVersion()} #versions: #{_.size(versions)})"
            contentPacks.push c

    contentPacks

  # ----------------------------------------------------------------------------------------------------------------
  dump: ()->

    Hy.Trace.debug "ContentManager.dump (ALL MANIFESTS)"
    for manifest in this.getManifests()
      Hy.Trace.debug manifest.dumpStr()

    Hy.Trace.debug "ContentManager.dump (ALL CONTENT PACKS)"
    for contentPack in this.getContentPacks()
      Hy.Trace.debug contentPack.dumpStr()

    Hy.Trace.debug "ContentManager.dump (LATEST CONTENT PACKS)"
    for contentPack in this.getLatestContentPacks()
      Hy.Trace.debug contentPack.dumpStr()

    this    

  # ----------------------------------------------------------------------------------------------------------------
  # INVENTORY
  # ----------------------------------------------------------------------------------------------------------------
  
  # ----------------------------------------------------------------------------------------------------------------
  scheduleInventory: ()->

    fnPre = ()=>_.map(ContentPack.getAppStoreContentPacksNeedingInventory(), (c)=>c.getAppStoreProductInfo())

    fnPost = (status, errorMessage, products)=>this.inventoryCallback(status, errorMessage, products)

    if _.size(fnPre()) > 0
      ContentManager.notifyObservers (observer)=>observer.obs_inventoryInitiated?()

    @iapInventory = new Hy.Commerce.InventorySession(fnPre, fnPost)

  # ----------------------------------------------------------------------------------------------------------------
  doInventoryImmediate: ()->

    if not @iapInventory?
      this.scheduleInventory()

    @iapInventory?.doImmediate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  inventoryCallback: (status, errorMessage, purchaseItems)->

    ContentManager.notifyObservers (observer)=>observer.obs_inventoryCompleted?(status, errorMessage)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # USER CREATED CONTENT
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  setUCC_Activity: ()-> @UCC_Activity = true

  # ----------------------------------------------------------------------------------------------------------------
  clearUCC_Activity: ()-> @UCC_Activity = false

  # ----------------------------------------------------------------------------------------------------------------
  isUCC_ActivityInProgress: ()-> @UCC_Activity

  # ----------------------------------------------------------------------------------------------------------------
  createUCC_Activity: ()->

    this.setUCC_Activity()
    UCC_Activity.create()

  # ----------------------------------------------------------------------------------------------------------------
  userCreatedContentRefreshRequested: (context)->

    if this.ensureNotBusy("userCreatedContentRefreshRequested") and (contentPack = context.contentPack)? and contentPack.isThirdParty()
      if (activity = this.createUCC_Activity())?
        activity.doContestRefresh(context)

    this

  # ----------------------------------------------------------------------------------------------------------------
  userCreatedContentDeleteRequested: (context)->

    if this.ensureNotBusy("userCreatedContentDeleteRequested") and (contentPack = context.contentPack)? and contentPack.isThirdParty()

      if (activity = this.createUCC_Activity())?
        activity.doContestDelete(context)

    this

  # ----------------------------------------------------------------------------------------------------------------
  userCreatedContentAddRequested: (url = null)->

    if this.ensureNotBusy("userCreatedContentAddRequested")
      if (uccPurchaseItem = this.getUCCPurchaseItem())? and uccPurchaseItem.isPurchased()
        if (activity = this.createUCC_Activity())?
          activity.doAdd(url)
      else
        this.userCreatedContentUpsell()

    this

  # ----------------------------------------------------------------------------------------------------------------
  userCreatedContentLoadSamples: ()->

    if this.ensureNotBusy("userCreatedContentLoadSamples")
      if (uccPurchaseItem = this.getUCCPurchaseItem())? and uccPurchaseItem.isPurchased()
        if (s = Hy.Update.SamplesUpdate.getSamplesUpdate())?
          if (activity = this.createUCC_Activity())?
            activity.doLoadSamples(s)
      else
        this.userCreatedContentUpsell()

    this

  # ----------------------------------------------------------------------------------------------------------------
  userCreatedContentUpsell: ()->

    if this.ensureNotBusy("userCreatedContentUpsell") and (activity = this.createUCC_Activity())?
      activity.doUpsell()

    this

# ----------------------------------------------------------------------------------------------------------------
  userCreatedContentBuyFeature: ()->

    fnDone = (context, status, navSpec, changes)=>
      if status
        navSpec._title = "Purchase Successful"
        navSpec._explain = "thank you! - have fun creating!"

        navSpec._buttonSpecs = [
          {_value: "show me how to get started!", _dismiss: "_root", _fnCallback: (event, view)=>Hy.UI.Application.get().showContentOptionsPage()},
          {_value: "ok", _dismiss: "_root"}]

      context.navGroup.pushNavSpec(navSpec)
      null

    if this.ensureNotBusy("userCreatedContentBuyFeature") and (activity = this.createUCC_Activity())?
      context =
        fnDone: fnDone

      activity.doBuyFeature(context, true) # true: show an intro message for a few seconds

    this

  # ----------------------------------------------------------------------------------------------------------------
  # CONTENT PACK PURCHASE
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  isContentPackBuyActivityInProgress: ()->
    @contentPackBuyActivity

  # ----------------------------------------------------------------------------------------------------------------
  setContentPackBuyActivity: ()-> @contentPackBuyActivity = true

  # ----------------------------------------------------------------------------------------------------------------
  clearContentPackBuyActivity: ()-> @contentPackBuyActivity = false

  # ----------------------------------------------------------------------------------------------------------------
  createContentPackBuyActivity: ()->

    this.setContentPackBuyActivity()
    ContentPackBuyActivity.create()

  # ----------------------------------------------------------------------------------------------------------------
  buyContentPack: (context)->

    status = if this.ensureNotBusy("buyContentPack") and (activity = this.createContentPackBuyActivity())?
      activity.doBuyContentPack(context)
    else
      false

    status

  # ----------------------------------------------------------------------------------------------------------------
  # MANIFEST UPDATE
  # ----------------------------------------------------------------------------------------------------------------
 
  # ----------------------------------------------------------------------------------------------------------------
  isContentManifestUpdateActivityInProgress: ()->
    @contentManifestUpdateActivity

  # ----------------------------------------------------------------------------------------------------------------
  setContentManifestUpdateActivity: ()-> @contentManifestUpdateActivity = true

  # ----------------------------------------------------------------------------------------------------------------
  clearContentManifestUpdateActivity: ()-> @contentManifestUpdateActivity = false

  # ----------------------------------------------------------------------------------------------------------------
  createContentManifestUpdateActivity: ()->

    this.setContentManifestUpdateActivity()
    ContentManifestUpdateActivity.create()

  # ----------------------------------------------------------------------------------------------------------------
  updateManifests: (reason = null, required = false)-> 

    status = if this.ensureNotBusy("ContentUpdate") and (activity = this.createContentManifestUpdateActivity())?
      activity.doUpdateManifests(reason, required)
    else
      false

    status

  # ----------------------------------------------------------------------------------------------------------------
  # RESTORE
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  setRestoreActivity: ()-> @restoreActivity = true

  # ----------------------------------------------------------------------------------------------------------------
  clearRestoreActivity: ()-> @restoreActivity = false

  # ----------------------------------------------------------------------------------------------------------------
  isRestoreActivityInProgress: ()->
    @restoreActivity

  # ----------------------------------------------------------------------------------------------------------------
  createRestoreActivity: ()->

    this.setRestoreActivity()
    RestoreActivity.create()


# ----------------------------------------------------------------------------------------------------------------
  restore: ()->

    fnDone = (context, status, navSpec, changes)=>
      if status
#        navSpec._title = "Restore Successful"
#        navSpec._explain = "thank you!"

        navSpec._buttonSpecs = [
          {_value: "ok", _dismiss: "_root"}]

      context.navGroup.pushNavSpec(navSpec)
      null

    if this.ensureNotBusy("restore") and (activity = this.createRestoreActivity())?
      context =
        fnDone: fnDone

      activity.doRestore(context, true) # true: show an intro message for a few seconds

    this


# ==================================================================================================================
#
# An "Activity" represents a user-level scenario, such as buying a content pack.
# An Activity may wrap one or more "transaction", serially - only one transaction at a time.
# By default, when a transaction ends, so does the associated Activity, unless "isTerminal" is set to false
#

class ContentManagerActivity

  _.extend ContentManagerActivity, Hy.Utils.Observable

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@label)->

    @active = true

    @endInProgress = false

    @contentManager = ContentManager.get()

    @transaction = null

    @navGroup = null

    @hidingNavGroup = false

    @changes = false

    this

  # ----------------------------------------------------------------------------------------------------------------
  error: (message)->
    new Hy.Utils.ErrorMessage("fatal", "ContentManagerActivity", message) #will display popup dialog

  # ----------------------------------------------------------------------------------------------------------------
  setLabel: (label)-> @label = label

  # ----------------------------------------------------------------------------------------------------------------
  defaultTitle: (navSpec)=>

    if navSpec? and not navSpec._title?
      navSpec._title = @label

    this

  # ----------------------------------------------------------------------------------------------------------------
  hasNavGroup: ()-> @navGroup?

  # ----------------------------------------------------------------------------------------------------------------
  getNavGroup: ()-> @navGroup
    
  # ----------------------------------------------------------------------------------------------------------------
  createNavGroup: (options, navSpec)->

    defaultNavGroupOptions = {}

    @navGroup = new Hy.UI.NavGroupPopover(Hy.UI.ViewProxy.mergeOptions(defaultNavGroupOptions, options), navSpec)

    this.addNavGroupFns()

    @navGroup

  # ----------------------------------------------------------------------------------------------------------------
  addNavGroupFns: ()->

    @navGroup?.pushFnGuard(this, "viewDismiss", ()=>this.doDismiss()) # to clean up stuff
    @navGroup?.pushFnGuard(this, "navGroupDismissCheck", ()=>this.isOKToDismiss()) # to check if it's OK to dismiss

    this

  # ----------------------------------------------------------------------------------------------------------------
  removeNavGroupFns: ()->

    @navGroup?.removeFnGuard(this, "viewDismiss")
    @navGroup?.removeFnGuard(this, "navGroupDismissCheck")

    this

  # ----------------------------------------------------------------------------------------------------------------
  addNavGroup: (navGroup)->

    @navGroup = navGroup

    this.addNavGroupFns()

    @navGroup

  # ----------------------------------------------------------------------------------------------------------------
  isHiding: ()-> @hidingNavGroup

  # ----------------------------------------------------------------------------------------------------------------
  setHiding: (hiding)-> @hidingNavGroup = hiding

  # ----------------------------------------------------------------------------------------------------------------
  hide: ()-> 

    if not this.isHiding()
      this.setHiding(true)

      if @navGroup? and @navGroup.isPopover()
        @navGroup.hide()

    this

  # ----------------------------------------------------------------------------------------------------------------
  show: ()-> 

    if this.isHiding()
      this.setHiding(false)

      if @navGroup? and @navGroup?.isPopover()
        @navGroup.show()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # We're being asked if it's OK to let the user dismiss this NavGroup. We might be in the 
  # middle of a transaction, etc...
  #
  isOKToDismiss: ()->

    @active and not @transaction?

  # ----------------------------------------------------------------------------------------------------------------
  doDismiss: (summary = null)->

    this.end(summary)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # If the current transaction is terminal, when it ends, we'll close out this activity also
  #
  transactionIsTerminal: ()->
  
    @transaction? and @transaction.isTerminal

  # ----------------------------------------------------------------------------------------------------------------
  transactionSetIsTerminal: (flag)->

    if @transaction?
      @transaction.isTerminal = flag

    this

  # ----------------------------------------------------------------------------------------------------------------
  transactionGetContext: ()-> @transaction?.context

  # ----------------------------------------------------------------------------------------------------------------
  pushNavSpec: (navSpec)->

    if @navGroup? and navSpec?
      @navGroup.pushNavSpec(navSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  progressReport: (summary, navSpec = {_explain: summary})->

    if navSpec?
      this.defaultTitle(navSpec)
      this.pushNavSpec(navSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  # A specific "transacted" event, such as a content pack purchase. The event is part of a larger "activity".
  # NavGroup is optional. Will create the required NavGroup, if none passed in and navGroupOptions and navSpec are supplied
  #
  # "context": we look for "fnDone" on it at transaction end
  #
  transactionStart: (context, summary, navSpec = {_explain: summary}, navGroupOptions = null)->

    if @transaction?
      this.error("Attempting to start a new transaction, but there\'s still one around")
    else
      this.defaultTitle(navSpec)
      if this.hasNavGroup() 
        this.pushNavSpec(navSpec)
      else
        if navSpec? and navGroupOptions?
          this.createNavGroup(navGroupOptions, navSpec)

      context.navGroup = this.getNavGroup()

      @transaction = {context: context, isTerminal: true}

    this

  # ----------------------------------------------------------------------------------------------------------------
  # If context.fnDone was passed into constructor, we call that, sending these args:
  #   context
  #   successFlag
  #   @navGroup
  #   navSpec
  #
  # If not: if no buttons or back button, display an update and add an "ok" button that dismisses to _root
  #
  transactionEnd: (statusFlag, summary, navSpec, changes)->

    Hy.Trace.debug "ContentManagerActivity.transactionEnd (statusFlag=#{statusFlag}, summary=#{summary} changes=#{changes})"

    if changes
      @changes = true

    if @transaction?
      this.defaultTitle(navSpec)

      f = @transaction.context.fnDone
      t = this.transactionIsTerminal()
      c = @transaction.context
      if not (d = @transaction.context._dismiss)? then d = "_root"

      @transaction = null

      if f?
        f(c, statusFlag, navSpec, changes)
      else
        if not navSpec._buttonSpecs? and not navSpec._backButton?
          navSpec._buttonSpecs = [ {_value: "ok", _dismiss: d} ]

        this.pushNavSpec(navSpec)

    if t
      this.end(summary)

    this

  # ----------------------------------------------------------------------------------------------------------------
  end: (summary = null)->

    if not @endInProgress
      @endInProgress = true

      if @active
        @active = false

      if @transaction?
        this.error("Trying to end Activity but transaction is still active")
    
    this.removeNavGroupFns()

    this

# ==================================================================================================================
class UCC_Activity extends ContentManagerActivity

  # There can be only one activity of this type around at a time

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @create: ()->

    activity = if gInstance?
      s = "UCC_Activity (ERROR ALREADY EXISTS)"
      new Hy.Utils.ErrorMessage("fatal", " UCC_Activity", s) #will display popup dialog
      null
    else
      new UCC_Activity()

    activity

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    gInstance = this

    super "Custom Trivia Pack"

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_userCreatedContentSessionStarted?(@label)

    this

  # ----------------------------------------------------------------------------------------------------------------
  transactionStart: (context, summary, navSpec = {_explain: summary}, navGroupOptions = null)->

    super context, summary, navSpec, navGroupOptions

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_userCreatedContentSessionProgressReport?(summary)

    this    

  # ----------------------------------------------------------------------------------------------------------------
  progressReport: (summary, navSpec = {_explain: summary})->

    super summary, navSpec

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_userCreatedContentSessionProgressReport?(summary)

    this

  # ----------------------------------------------------------------------------------------------------------------
  end: (summary = null)->

    gInstance = null

    @contentManager.clearUCC_Activity()

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_userCreatedContentSessionCompleted?(summary, @changes)
   
    super summary

    this

  # ----------------------------------------------------------------------------------------------------------------
  #  context:
  #    .fnDone
  #    .contentPack
  #    .navGroup
  #
  doContestRefresh: (context)->

    fnUpsellDone = (context, successFlag, navSpec, changes)=>
      context.fnDone = context.originalFnDone
      if successFlag and (uccPurchaseItem = @contentManager.getUCCPurchaseItem())? and uccPurchaseItem.isPurchased()
        this.doContestRefresh(context)
      else
        this.end() # End the activity
        context.fnDone?(context, successFlag, navSpec, changes)
      null

    this.addNavGroup(context.navGroup)

    if (uccPurchaseItem = @contentManager.getUCCPurchaseItem())? and uccPurchaseItem.isPurchased()

      this.setLabel("Updating Trivia Pack")
      summary = "Starting Update..."
      this.transactionStart(context, summary)

      m = @contentManager.getManifestByKind("ThirdPartyContentManifest")
      if not m.refreshContent(context.contentPack,
                          ((report)=>this.progressReport(report)),
                          ((successFlag, changes, summary, report)=>
                            this.transactionEnd(successFlag, summary, {_title: summary, _explain: report}, changes)))
        summary = "Sorry, couldn\'t refresh contest. Please try again later"
        this.transactionEnd(false, summary, {_title: "Update Failed", _explain: summary}, false)
    else
      # Work in an upsell transaction, and then try again
      context2 = _.clone(context)
      context2.fnDone = fnUpsellDone
      context2.originalFnDone = context.fnDone
      this.doUpsell(context2, false) # false: don't end the Activity when done

    null

  # ----------------------------------------------------------------------------------------------------------------
  doContestDelete: (context)->

    this.addNavGroup(context.navGroup)

    this.setLabel("Removing Trivia Pack...")
    this.transactionStart(context, "Removing...")

    ContentPack.deleteByProductID(context.contentPack.getProductID())

    summary = "\"#{context.contentPack.getDisplayName()}\" removed"
    this.transactionEnd(true, summary, {_title: "Trivia Pack removed successfully", _explain: summary}, true)

    null

  # ----------------------------------------------------------------------------------------------------------------
  #
  # If url is null, we check the clipboard
  #
  doAdd: (url = null)->

    fnDone = (context, statusFlag, navSpec, changes)=>
       newNavSpec = 
         _title: navSpec._title
         _explain: navSpec._explain
         _buttonSpecs: [ {_value: "ok", _dismiss: context._dismiss} ]

       context.navGroup.pushNavSpec(newNavSpec)
       null

    fnImport = (context)=>

      this.setLabel("Adding Custom Trivia Pack")
      summary = "Starting Import..."
      this.transactionStart(context, summary)

      m = @contentManager.getManifestByKind("ThirdPartyContentManifest")
      if not m.addContent(url, 
                         ((report)=>this.progressReport(report)),
                         ((successFlag, changes, summary, report)=>this.transactionEnd(successFlag, summary, {_title: summary, _explain: report}, changes)))
                                                                   
        summary = "Sorry, couldn\'t import contest"
        this.transactionEnd(false, summary, {_title: "Import Failed", _explain: summary}, false)

      null

    fnFixURL = (url)=>
      # trim leading and trailing spaces
      url = url.replace(/(^\s*)|(\s*$)/gi, "")
      # If no leading http://, add it
      if not url.match(/^http[s]?:\/\//gi)?
        url = "http://" + url
      url

    navSpec = null
    context = {}
    context.fnDone = fnDone
    context._dismiss = "_root"

    title = "New Custom Trivia Pack"

    if not url?
      if Ti.UI.Clipboard.hasText() and (url = Ti.UI.Clipboard.getText())?
        url = fnFixURL(url)
      else
        navSpec = 
          _title: title
          _explain: "Clipboard is empty!\nPlease copy to the clipboard the URL of the contest you would like to import, and try again"
          _buttonSpecs: [
            {_value: "ok", _dismiss: context._dismiss}
          ]

    if url?
      urlDisplay = Hy.Utils.String.trimWithElipsis(url, Hy.UI.NavGroup.getExplainMaxCharsPerLine())

      navSpec = 
        _title: title
        _explain: "Do you want to import this URL?\n#{urlDisplay}"
        _buttonSpecs: [
          {_value: "yes", _navSpecFnCallback: (event, view, navGroup)=>fnImport(context)},
          {_value: "cancel", _dismiss: context._dismiss, _cancel: true}
        ]

    context.navGroup = this.createNavGroup({}, navSpec)

    this


  # ----------------------------------------------------------------------------------------------------------------
  #
  #
  doLoadSamples: (samples)->

    sampleIndex = -1
    numLoaded = 0
    needsTransaction = true

    fnGetNextSampleContest = ()=>
      sampleContest = null
      if samples?
        if (l = samples.length) > 0
          sampleIndex++
          if sampleIndex < l
            if (sampleContest = samples[sampleIndex])?
              if sampleContest.name? and sampleContest.url?
                return sampleContest
      null

    fnDone = (context, statusFlag, navSpec, changes)=>
       newNavSpec = 
         _title: navSpec._title
         _explain: navSpec._explain
         _buttonSpecs: [ {_value: "ok", _dismiss: context._dismiss} ]

       context.navGroup.pushNavSpec(newNavSpec)
       null

    fnChain = (context, successFlag, changes, summary, report)=>
      if successFlag
        numLoaded++

      if (sampleContest = fnGetNextSampleContest())?
        fnImport(context, sampleContest)
      else
        summary = "Sample Contests"
        report = switch numLoaded
          when 0
            "Sorry, no Samples could be loaded"
          when 1
            "Loaded 1 Sample"
          else
            "Loaded #{numLoaded} Samples"
        this.transactionEnd(successFlag, summary, {_title: summary, _explain: report}, changes)
      null

    fnImport = (context, sampleContest)=>

#      this.setLabel("Loading Sample Contest")
      n = Hy.Utils.String.trimWithElipsis(sampleContest.name, Hy.UI.NavGroup.getExplainMaxCharsPerLine())
      this.setLabel("Loading #{n}")

      summary = "Loading Samples..."
      if needsTransaction
        needsTransaction = false
        this.transactionStart(context, summary)

      m = @contentManager.getManifestByKind("ThirdPartyContentManifest")

      if not m.addContent(sampleContest.url, 
                         ((report)=>this.progressReport(report)),
                         ((successFlag, changes, summary, report)=>fnChain(context, successFlag, changes, summary, report)))
                                                                   
        summary = "Sorry, couldn\'t load Sample Contest"
        this.transactionEnd(false, summary, {_title: "Import Failed", _explain: summary}, false)

      null

    navSpec = null
    context = {}
    context.fnDone = fnDone
    context._dismiss = "_root"

    if (sampleContest = fnGetNextSampleContest())?
      navSpec = 
        _title: "Loading Sample Contests"
        _explain: "Do you want to load Sample Contests?"
        _buttonSpecs: [
          {_value: "yes", _navSpecFnCallback: (event, view, navGroup)=>fnImport(context, sampleContest)},
          {_value: "cancel", _dismiss: context._dismiss, _cancel: true}
        ]

      context.navGroup = this.createNavGroup({}, navSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doUpsell: (context = {}, topLevelTransaction = true)->

    fnBuy = ()=>
      this.doBuyFeature(context, true, topLevelTransaction)
      null

    fnShowInfoPage = (report)=>
      Hy.UI.Application.get().showContentOptionsPage()
      null

    uccPurchaseItem = @contentManager.getUCCPurchaseItem()
    price = uccPurchaseItem.getDisplayPrice()

    dismiss = if context._dismiss? then context._dismiss else "root"

    title = "Custom Trivia Pack Feature"

    # First of several check/generate functions, to help us work up a NavSpec spec
    
    # Return null if online, otherwise a gentle warning
    fn_generalChecks = ()=>
      if (s = Hy.Commerce.PurchaseSession.isReady())?
        {
          _title: title
          _backButton: "_previous"
          _explain: s
          _buttonSpecs: [
            {_value: "ok", _dismiss: dismiss}
          ]
        }
      else
        null

    # Return null if not already purchased, otherwise a gentle reminder
    fn_checkIsPurchased = ()=>
      if uccPurchaseItem.isPurchased()
        {
          _title: title
          _backButton: "_previous"
          _explain: "You have already purchased this feature!"
          _buttonSpecs: [
            {_value: "ok", _dismiss: dismiss}
          ]
        }
      else
        null

    # Return null if ready for purchase, otherwise a gentle note
    fn_checkReadyForPurchase = ()=>
      if not uccPurchaseItem.isReadyForPurchase()
        {
          _title: title
          _backButton: "_previous"
          _explain: "Sorry, unable to purchase feature at this time. Please try again later"
          _buttonSpecs: [
            {_value: "ok", _dismiss: dismiss}
          ]
        }
      else
        null
   
    # Return a prompt for the purchase
    fn_promptForPurchase = ()=>
      {
        _title: title
        _backButton: "_previous"
        _explain: "Would you like to purchase this feature so you can create your own contests?"
        _buttonSpecs: [
          {_value: "yes, buy for #{price}", _navSpecFnCallback: (event, view, navGroup)=>fnBuy()},
          {_value: "more info...", _dismiss: dismiss, _fnCallback: (event, view)=>fnShowInfoPage("Showing more info...")},
          {_value: "cancel", _dismiss: dismiss, _cancel: true}
        ]
      }

    # Run through the check/generate functions. Order is important
    navSpec = null   
    for f in [fn_generalChecks, fn_checkIsPurchased, fn_checkReadyForPurchase, fn_promptForPurchase]
      if (navSpec = f())?
        break

    if not navSpec?
      new Hy.Utils.ErrorMessage("fatal", " ContentPackBuyActivity", "Null NavSpec") #will display popup dialog
      
    if context.navGroup?
      this.addNavGroup(context.navGroup)
      this.pushNavSpec(navSpec)
    else
      context.navGroup = this.createNavGroup({}, navSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doBuyFeature: (context, delay = false, topLevelTransaction = true)->

    if context.navGroup?
      this.addNavGroup(context.navGroup)

    this.setLabel("Custom Trivia Pack Feature")
    summary = "Purchasing Feature..."
    explain = "Purchasing Feature...\nYou may be asked to enter your iTunes password..."

    this.transactionStart(context, summary, {_explain: explain}, {}) # Will create the NavGroup if necessary
    this.transactionSetIsTerminal(topLevelTransaction)

    Hy.Utils.PersistentDeferral.create((if delay then 2000 else 0), ()=>this.doBuyFeature_())

    this

# ----------------------------------------------------------------------------------------------------------------
  doBuyFeature_: ()->

    Hy.Trace.debug "UCC_Activity.doBuyFeature_ (ENTER)"

    fn = (errorMessage, purchaseItem)=>this.doBuyFeatureEnd(errorMessage, purchaseItem)

    errorMessage = null

    if not (errorMessage = Hy.Commerce.PurchaseSession.isReady())?
      if (uccPurchaseItem = @contentManager.getUCCPurchaseItem())? and (purchaseSession = new Hy.Commerce.PurchaseSession(uccPurchaseItem, fn))?
        this.hide() # Hide navGroup, if a PopOver, in case iOS pops its own, asking for password
        if not (errorMessage = purchaseSession.purchase())?
          summary = "Buying \"#{uccPurchaseItem.getDisplayName()}\"..."
          this.progressReport(summary)
      else
        errorMessage = "Sorry - not available for purchase at this time. Please try again later."

    if errorMessage?
      Hy.Trace.debug "UCC_Activity.doBuyFeature_ (ERROR #{errorMessage})"
      fn(errorMessage, null)

    errorMessage

# ----------------------------------------------------------------------------------------------------------------
  doBuyFeatureEnd: (errorMessage, purchaseItem)->

    Hy.Trace.debug "UCC_Activity.doBuyFeatureEnd (errorMessage=#{errorMessage})"

    summary = null
    navSpec = null

    this.show()

    # Work up a navSpec in case there's no fnDone to take over

    if errorMessage?
      summary = "Purchase Did Not Complete" 
      navSpec = {_title: summary , _explain: errorMessage}
    else
      summary = "thank you! - have fun creating!"
      navSpec = {_title: "Purchase Successful", _explain: summary}

    if this.transactionIsTerminal()
      navSpec._buttonSpecs = [ {_value: "ok", _dismiss: if (d = this.transactionGetContext()?._dismiss)? then d else "root"} ]

    this.transactionEnd(not errorMessage?, summary, navSpec, false)

    this

# ==================================================================================================================
class ContentPackBuyActivity extends ContentManagerActivity

  # There can be only one activity of this type around at a time

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @create: ()->

    activity = if gInstance?
      s = "ContentPackBuyActivity (ERROR ALREADY EXISTS)"
      new Hy.Utils.ErrorMessage("fatal", " ContentPackBuyActivity", s) #will display popup dialog
      null
    else
      new ContentPackBuyActivity()

    activity

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    gInstance = this

    super "Trivia Purchase"

    @iapDownloadContentPackSize = null

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_purchaseInitiated?(@label)

    this

  # ----------------------------------------------------------------------------------------------------------------
  transactionStart: (context, summary, navSpec = {_explain: summary}, navGroupOptions = null)->

    super context, summary, navSpec, navGroupOptions

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_purchaseProgressReport?(summary)

    this

  # ----------------------------------------------------------------------------------------------------------------
  progressReport: (summary, navSpec = {_explain: summary})->

    super summary, navSpec

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_purchaseProgressReport?(summary)

    this

  # ----------------------------------------------------------------------------------------------------------------
  end: (summary = null)->

    gInstance = null

    @contentManager.clearContentPackBuyActivity()

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_purchaseCompleted?(summary, @changes)

    super summary    

  # ----------------------------------------------------------------------------------------------------------------
  doBuyContentPack: (context)->

    contentPack = context.contentPack

    Hy.Trace.debug "ContentPackBuyActivity::doBuy (#{contentPack.getProductID()})"

    this.addNavGroup(context.navGroup)

    errorMessage = null
    purchaseSession = null

    fnBuy = ()=>
      if (errorMessage = purchaseSession.purchase())?
        this.buyCompleted([], errorMessage)        
      null

    fnBuyCallback = (errorMessage, appStoreProductInfo)=>this.doBuyCallback(errorMessage, appStoreProductInfo)

    summary = "Purchasing \"#{contentPack.getDisplayName()}\"..."

    this.transactionStart(context, summary)

    if not (errorMessage = Hy.Commerce.PurchaseSession.isReady())?
      if contentPack.isReadyForPurchase()
        if (purchaseSession = new Hy.Commerce.PurchaseSession(contentPack.getAppStoreProductInfo(), fnBuyCallback))?
          Hy.Utils.PersistentDeferral.create(2000, fnBuy)
        else
          errorMessage = "Sorry - \"#{contentPack.getDisplayName()}\" isn\'t available for purchase at this time. Please try again later."
      else
        errorMessage = "Sorry - \"#{contentPack.getDisplayName()}\" isn\'t available for purchase at this time. Please try again later."

    status = if errorMessage?
      this.buyCompleted([], errorMessage)
    else
      true

    status

  # ----------------------------------------------------------------------------------------------------------------
  doBuyCallback: (errorMessage, appStoreProductInfo)->

    if not errorMessage?
      if (c = appStoreProductInfo.getReference())? and (contentPack = ContentPack.findLatestVersion(c.getProductID()))?
        Hy.Trace.debug "ContentPackBuyActivity.doBuyCallback (errorMessage=#{errorMessage} productID=#{c.getProductID()})"

        new Hy.Network.DownloadManager(this, 
                                       ((cm)=>cm.buyDownload(contentPack)), 
                                       ((cm, results)=>cm.buyCompleted(results)),
                                       "buyDownload")

        summary = if contentPack.hasAppStoreReceipt() 
          "App Store receipt confirmed, now downloading trivia..."
        else
          "Now downloading trivia..."

        this.progressReport(summary)
      else
        this.error("Unexpected product ID returned: #{if appStoreProductInfo? then appStoreProductInfo.getDisplayName() else "?"}")

    if errorMessage?
      this.buyCompleted([], errorMessage)

    errorMessage?

  # ----------------------------------------------------------------------------------------------------------------
  buyDownload: (contentPack)->

    Hy.Trace.debug "ContentPackBuyActivity::buyDownload (#{contentPack.dumpStr()})"

    eventSpecs = []

    eventSpecs.push {
      callback: ((cm, event, eventSpec)=>return(cm.buyDownloadCallback(event, eventSpec))), 
      URL: Hy.Config.Update.kUpdateBaseURL + "/" + contentPack.getFilename(),
      display: "Purchased Trivia Pack #{contentPack.dumpStr()}", 
      contentPack: contentPack}

    return eventSpecs

  # ----------------------------------------------------------------------------------------------------------------
  buyDownloadCallback: (event, eventSpec)->
    Hy.Trace.debug "ContentPackBuyActivity::buyDownloadCallback"

    ok = eventSpec.contentPack.writeFile(event.responseText)

    if ok
      @iapDownloadContentPackSize = event.responseText.length
      summary = "Downloaded \"#{eventSpec.contentPack.getDisplayName()}\" trivia..."
      this.progressReport(summary)

    # TESTING - REMOVE LINE BELOW WHEN DONE
    #ok = false

    return ok

  # ----------------------------------------------------------------------------------------------------------------
  buyCompleted: (results, errorMessage=null)->

    Hy.Trace.debug "ContentPackBuyActivity::buyCompleted (results=#{_.size(results)} errorMessage=#{errorMessage})"

    ok = false
    contentPack = null

    if not errorMessage?
      for s in results
        Hy.Trace.debug "ContentPackBuyActivity.buyCompleted (status=#{s.object.display} #{s.status})"

      # Expect exactly one
      download = _.first(results)

      displayName = "??"

      if download?
        contentPack = download.object.contentPack
        displayName = contentPack.getDisplayName()

        if download.status
          ok = true
          Hy.ConsoleApp.get().analytics?.logContentPackPurchaseDownloadCompleted()
        else
          Hy.ConsoleApp.get().analytics?.logContentPackPurchaseDownloadFailed()
#          this.error("There was a problem downloading \"#{displayName}\". Please try again.")
          contentPack.clearAppStoreReceipt()

      if not ok
        errorMessage = "There was a problem downloading\n\"#{displayName}\".\nPlease try again."

    Hy.Commerce.PurchaseSession.log(errorMessage, {contentPack: displayName, contentPackDownloadSize: @iapDownloadContentPackSize})

    if ok
      summary = "Download of\n\"#{contentPack.getDisplayName()}\" complete.\nThank You!"
      title = "Purchase Completed Successfully"
    else
      summary = errorMessage
      title = "Purchase did not complete"

    this.transactionEnd(ok, summary, {_title: title, _explain: summary}, ok) 

    ok

# ==================================================================================================================
class RestoreActivity extends ContentManagerActivity

  # There can be only one activity of this type around at a time

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @create: ()->

    activity = if gInstance?
      s = "RestoreActivity (ERROR ALREADY EXISTS)"
      new Hy.Utils.ErrorMessage("fatal", " RestoreActivity", s) #will display popup dialog
      null
    else
      new RestoreActivity()

    activity

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    gInstance = this

    super "Restore"

    @iapDownloadContentPackSize = null

    @hadResults = false
    @numRestored = 0

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_restoreInitiated?(@label)

    this

  # ----------------------------------------------------------------------------------------------------------------
  transactionStart: (context, summary, navSpec = {_explain: summary}, navGroupOptions = null)->

    super context, summary, navSpec, navGroupOptions

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_restoreProgressReport?(summary)

    this

  # ----------------------------------------------------------------------------------------------------------------
  progressReport: (summary, navSpec = {_explain: summary})->

    super summary, navSpec

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_restoreProgressReport?(summary)

    this

  # ----------------------------------------------------------------------------------------------------------------
  end: (summary = null)->

    gInstance = null

    @contentManager.clearRestoreActivity()

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_restoreCompleted?(summary, @changes)

    super summary    

  # ----------------------------------------------------------------------------------------------------------------
  doRestore: (context)->

    topLevelTransaction = true
    delay = true

    Hy.Trace.debug "RestoreActivity::doRestore"

    if context.navGroup?
      this.addNavGroup(context.navGroup)

    this.setLabel("Restoring Purchases")
    summary = "Restoring Purchases..."
    explain = "Restoring Purchases...\nYou may be asked to enter your iTunes password..."

    this.transactionStart(context, summary, {_explain: explain}, {}) # Will create the NavGroup if necessary
    this.transactionSetIsTerminal(true)

    Hy.Utils.PersistentDeferral.create((if delay then 2000 else 0), ()=>this.doRestore_())

    this

  # ----------------------------------------------------------------------------------------------------------------
  doRestore_ :()->

    Hy.Trace.debug "RestoreActivity.doRestore_ (ENTER)"

    fnRestoreCallback = (errorMessage, results)=>this.doRestoreCallback(errorMessage, results)

    errorMessage = null

    if not (errorMessage = Hy.Commerce.RestoreSession.isReady())?
      if (restoreSession = new Hy.Commerce.RestoreSession(fnRestoreCallback))?
        this.hide() # Hide navGroup, if a PopOver, in case iOS pops its own, asking for password

        if not (errorMessage = restoreSession.restore())?
          summary = "Restoring Purchases..."
          this.progressReport(summary)
      else
        errorMessage = "Sorry - can not restore purchases at this time. Please try again later."

    if errorMessage?
      Hy.Trace.debug "UCCRestoreActivity.doRestore_ (ERROR #{errorMessage})"
      this.restoreCompleted(errorMessage, [])        

    errorMessage

  # ----------------------------------------------------------------------------------------------------------------
  doRestoreCallback: (errorMessage, results)->

    Hy.Trace.debug "RestoreActivity.doRestoreCallback (errorMessage=#{errorMessage} # results=#{_.size(results)})"

    this.show()

    if not errorMessage?

      @hadResults = _.size(results) > 0

      # Look for a Custom Trivia Feature purchase
      if (uccPurchaseItem = @contentManager.getUCCPurchaseItem())?
        if r = _.find(results, (r)=>r.success is true and r.productId is uccPurchaseItem.getProductID())

          Hy.Trace.debug "RestoreActivity.doRestoreCallback (Custom Trivia Feature: Receipt=#{r.receipt})"

          if not uccPurchaseItem.hasAppStoreReceipt()
            Hy.Trace.debug "RestoreActivity.doRestoreCallback (Custom Trivia Feature: writing receipt)"
            uccPurchaseItem.setAppStoreReceipt(r.receipt, true)

            @numRestored++
            summary = "Restored Custom Trivia Pack feature..."
            this.progressReport(summary)

      # And then look for any content packs
      new Hy.Network.DownloadManager(this, 
                                     ((cm)=>cm.restoreDownload(results)), 
                                     ((cm, status)=>cm.restoreCompleted(null, status)),
                                     "restoreDownload")
 
      summary = "Analyzing content packs to download..."
      this.progressReport(summary)

    if errorMessage?
      this.restoreCompleted(errorMessage, [])

    errorMessage?

  # ----------------------------------------------------------------------------------------------------------------
  restoreDownload: (results)->

    eventSpecs = []

    # Seems that the list of restored items may contain duplicates

    # http://stackoverflow.com/questions/9923890/removing-duplicate-objects-with-underscore-for-javascript
    results2 = _.uniq(results, false, (item,key,a)=>item.productId)

    Hy.Trace.debug "RestoreActivity::restoreDownload (results=#{_.size(results)} results2=#{_.size(results2)})"

    for result in _.filter(results2, (r)=>r.success is true)

      if (c = ContentPack.findLatestVersion(result.productId))? and (not c.isEntitled())

        Hy.Trace.debug "RestoreActivity::restoreDownload (scheduling download of #{c.dumpStr()})"

        eventSpecs.push {
          callback: ((cm, event, eventSpec)=>return(cm.restoreDownloadCallback(event, eventSpec))), 
          URL: Hy.Config.Update.kUpdateBaseURL + "/" + c.getFilename(),
          display: "Downloading restored Trivia Pack #{c.dumpStr()}", 
          contentPack: c}

    return eventSpecs

  # ----------------------------------------------------------------------------------------------------------------
  restoreDownloadCallback: (event, eventSpec)->
    Hy.Trace.debug "RestoreActivity::restoreDownloadCallback"

    if (ok = eventSpec.contentPack.writeFile(event.responseText))
      summary = "Downloaded \"#{eventSpec.contentPack.getDisplayName()}\"..."
      this.progressReport(summary)

    ok

  # ----------------------------------------------------------------------------------------------------------------
  restoreCompleted: (errorMessage, status)->

    Hy.Trace.debug "RestoreActivity::restoreCompleted (status=#{_.size(status)} errorMessage=#{errorMessage})"

    summary = null
    navSpec = null

    this.show()

    @numRestored += _.size(status)
    changes = @numRestored > 0

    # Work up a navSpec in case there's no fnDone to take over

    if errorMessage?
      summary = "Restore did not complete" 
      navSpec = {_title: summary , _explain: errorMessage}
    else

      summary = (switch @numRestored
        when 0
          if @hadResults then "All purchases have already been restored" else "No purchases were restored"
        when 1
          "1 purchase restored"
        else
          "#{@numRestored} purchases restored"
      )

      navSpec = {_title: "Restoring Purchases", _explain: summary}

    if this.transactionIsTerminal()
      navSpec._buttonSpecs = [ {_value: "ok", _dismiss: if (d = this.transactionGetContext()?._dismiss)? then d else "root"} ]

    this.transactionEnd(not errorMessage?, summary, navSpec, changes)

    this

# ==================================================================================================================
class ContentManifestUpdateActivity extends ContentManagerActivity

  # There can be only one activity of this type around at a time

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @create: ()->

    activity = if gInstance?
      s = "ContentManifestUpdateActivity (ERROR ALREADY EXISTS)"
      new Hy.Utils.ErrorMessage("fatal", "ContentManifestUpdateActivity", s) #will display popup dialog
      null
    else
      new ContentManifestUpdateActivity()

    activity

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    gInstance = this

    super "Trivia Update"

    @required = false
    @recommended = false    

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_contentUpdateSessionStarted?(@label)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doDismiss: (summary = "Update Cancelled")->

    if @recommended
      Hy.ConsoleApp.get().analytics?.logContentUpdateSuggestedIgnored()

    super summary

    this

  # ----------------------------------------------------------------------------------------------------------------
  transactionStart: (context, summary, navSpec = {_explain: summary}, navGroupOptions = null)->

    super summary, context, navSpec, navGroupOptions

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_contentUpdateSessionProgressReport?(summary)

    this

  # ----------------------------------------------------------------------------------------------------------------
  progressReport: (summary, navSpec = {_explain: summary})->

    super summary, navSpec

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_contentUpdateSessionProgressReport?(summary)

    this

  # ----------------------------------------------------------------------------------------------------------------
  end: (summary = null)->

    gInstance = null

    @contentManager.clearContentManifestUpdateActivity()

    ContentManagerActivity.notifyObservers (observer)=>observer.obs_contentUpdateSessionCompleted?(summary, @changes)

    super summary

  # ----------------------------------------------------------------------------------------------------------------
  # We're being asked if it's OK to let the user dismiss this NavGroup. We might be in the 
  # middle of a transaction, etc...
  #
  isOKToDismiss: ()->

    not @required

  # ----------------------------------------------------------------------------------------------------------------
  # if "reason", we show that to the user and ask for ack, unless "required" is true
  #
  doUpdateManifests: (reason = null, required = false)->
    Hy.Trace.debug "ContentManifestUpdateActivity::doUpdateManifests (START)"

    @required = required
    @recommended = not @required and reason?

    @updateManifest = null
    @updateManifestSuccess = false

    fnUpdateManifests = (context)=>
      summary = "Starting Content Update..."
      this.transactionStart(context, summary, null, null)

      ok = false

      # We expect there to be exactly one updated manifest available at a time
      if (@updateInProgress = ContentManifestUpdate.getUpdate())?
        downloadManager = new Hy.Network.DownloadManager(this, 
                                                        ((cm)=>cm.updateManifestDownload()), 
                                                        ((cm, status)=>cm.updateManifestDownloadDone(status)),
                                                        "updateManifestDownload")
        ok = downloadManager?
      else
        ok = this.updateContentPackDownloadSetup()

      if not ok
        this.updateCompleted([])

      ok

    fnCreateNavSpec = (counter = null)=>
      navSpec = if @required
        {
          _title: "Required Trivia Update"
          _explain: "Trivially requires a trivia update\n#{if reason? then reason else ""}\n\n#{if counter? then "Starting update in " + counter + " second#{if counter > 1 then "s" else ""}" else ""}"
          _fnVisible: if counter isnt 1 then null else (navSpec)=>fnUpdateManifests(context)
        }
      else
        if @recommended
          {
            _title: "Trivia Update"
            _explain: "#{if reason? then reason else "A trivia update is available!"}\nWould you like to download it?"
            _buttonSpecs: [
              {_value: "yes", _navSpecFnCallback: (event, view, navGroup)=>fnUpdateManifests(context)},
              {_value: "cancel", _dismiss: "_root", _cancel: true}
            ]
          }
        else
          {
            _title: "Trivia Update"
            _explain: "Starting Trivia Update...\nThis won\'t take long..."
          }
      navSpec._id = "ManifestUpdate"
      navSpec

    fnCountdown = (counter)=>
      context.navGroup.replaceNavView(fnCreateNavSpec(counter))

      if counter > 1
        Hy.Utils.PersistentDeferral.create(1000, ()=>fnCountdown(counter-1))

      null

    counter = 6
    context = {}
    context.navGroup = this.createNavGroup({}, fnCreateNavSpec(null))
        
    if @required
      Hy.ConsoleApp.get().analytics?.logContentUpdateRequired()
    else
      if @suggested
        Hy.ConsoleApp.get().analytics?.logContentUpdateSuggested()

    # Kick it off
    if @required or not @recommended
      Hy.Utils.PersistentDeferral.create(2000, if @required then (()=>fnCountdown(counter)) else (()=>fnUpdateManifests(context)))

    this

  # ----------------------------------------------------------------------------------------------------------------
  updateManifestDownload: ()->

    Hy.Trace.debug "ContentManifestUpdateActivity::updateManifestDownload (PROCESSING manifest update #{@updateInProgress.versionMajor})"

    summary = "Downloading list of available updates..."
    this.progressReport(summary)

    eventSpecs = []

    eventSpecs.push {
      callback: ((cm, event, eventSpec)=>return(cm.updateManifestDownloadCallback(event, eventSpec))), 
      URL: Hy.Config.Update.kUpdateBaseURL + "/" + @updateInProgress.getFile(), 
      display: "Manifest Download #{@updateInProgress.versionMajor}.#{@updateInProgress.versionMinor}", 
      update: @updateInProgress}

    return eventSpecs

  # ----------------------------------------------------------------------------------------------------------------
  updateManifestDownloadCallback: (event, eventSpec)->

    Hy.Trace.debug "ContentManifestUpdateActivity::updateManifestDownloadCallback (ENTER)"

    status = false

    summary = "Analyzing list of available updates..."
    this.progressReport(summary)

    if (m = UpdateManifest.parseText(event.responseText, eventSpec.URL))?

      # if we're attempting to re-update an update manifest, remove the existing one first
      filename = eventSpec.update.getFile()

      if _.size(existingUpdateManifests = FileBasedManifest.findByFilename(filename)) > 0
        for existingUpdateManifest in existingUpdateManifests
          @contentManager.removeManifest(existingUpdateManifest)

      @updateManifest = new UpdateManifest(@contentManager, m, filename)
      @contentManager.addManifest(@updateManifest)
      @updateManifest.processContentPacks()
      @updateManifest.setText(event.responseText)
      @updateManifest.writeFile() # will overwrite any existing file

      status = true

    Hy.Trace.debug "ContentManifestUpdateActivity.updateManifestDownloadCallback (EXIT #{status})"

    status

  # ----------------------------------------------------------------------------------------------------------------
  updateManifestDownloadDone: (status)=>

    for s in status
      Hy.Trace.debug "ContentManifestUpdateActivity::updateManifestDownloadDone (status=#{s.object.display} #{s.status})"

    summary = "Completed analyzing list of available updates..."
    this.progressReport(summary)

    @updateManifestSuccess = _.size(_.select(status, (s)=>s.status is true)) > 0

    Hy.Trace.debug "ContentManifestUpdateActivity::updateManifestDownloadDone (ENTER status=#{@updateManifestSuccess})"

    # Now, check for content pack downloads

    this.updateContentPackDownloadSetup()

    null

  # ----------------------------------------------------------------------------------------------------------------
  updateContentPackDownloadSetup: ()->

    Hy.Trace.debug "ContentManifestUpdateActivity: updateContentPackDownloadSetup"

    downloadManager = new Hy.Network.DownloadManager(this, 
                                                     ((cm)=>cm.updateContentPackDownload()), 
                                                     ((cm, status)=>cm.updateCompleted(status)), 
                                                     "updateContentDownload")

    return downloadManager?

  # ----------------------------------------------------------------------------------------------------------------
  updateContentPackDownload: ()->

    eventSpecs = []

    # Schedule download of any icon and content files that are the latest. We assume that any
    # content packs that are missing icons or files are from the update manifest
    for c in @contentManager.getLatestContentPacks()
      Hy.Trace.debug "ContentManifestUpdateActivity::updateContentPackDownload (content pack: #{c.dumpStr()})"

      productID = c.getProductID()

      if not c.getIcon()?
        Hy.Trace.debug "ContentManifestUpdateActivity::updateContentPackDownload (Scheduling download of content icon: #{productID} (#{c.getIconSpec()}))"

        # Download the icon. ContentIcon class figures out whether we need high-density or low-density
        eventSpecs.push
          callback: ((cm, event, eventSpec)=>return(cm.updateContentIconDownloadCallback(event, eventSpec))),
          URL: Hy.Config.Update.kUpdateBaseURL + "/" + ContentIcon.getFilename(c.getIconSpec()),
          display: "Icon Download #{productID}",
          contentPack: c
          summary: "Downloaded \"#{c.getDisplayName()}\" Icon..."

      if (c.isEntitled() and not c.isLocal()) or c.isUpdateAvailable()
        Hy.Trace.debug "ContentManifestUpdateActivity::updateContentPackDownload (Scheduling download of content pack: #{productID})"

        eventSpecs.push
          callback: ((cm, event, eventSpec)=>return(cm.updateContentPackDownloadCallback(event, eventSpec))),
          URL: Hy.Config.Update.kUpdateBaseURL + "/" + c.getFilename(), 
          display: "Trivia Pack Download #{productID}", contentPack: c
          summary: "Downloaded \"#{c.getDisplayName()}\" trivia update..."
      else
        Hy.Trace.debug "ContentManifestUpdateActivity::updateContentPackDownload (SKIPPING content pack: #{productID})"

    numDownloads = _.size(eventSpecs)

    Hy.Trace.debug "ContentManifestUpdateActivity::updateContentPackDownload (updateContentPackDownloads=#{numDownloads})"

    if numDownloads > 0
      summary = "Downloading #{numDownloads} trivia update"
      summary += (if numDownloads is 1 then "" else "s")
      summary += "..."

      this.progressReport(summary)

    return eventSpecs

  # ----------------------------------------------------------------------------------------------------------------
  updateContentPackDownloadCallback: (event, eventSpec)->

    ok = eventSpec.contentPack.writeFile(event.responseText)

    if ok
      this.progressReport(eventSpec.summary)

      ok = true

    return ok

  # ----------------------------------------------------------------------------------------------------------------
  updateContentIconDownloadCallback: (event, eventSpec)->

    Hy.Trace.debug "ContentManifestUpdateActivity.updateContentIconDownloadCallback (state=#{event.responseStatus}, response=#{event.responseText?}/#{event.responseData?})"

    ok = eventSpec.contentPack.writeIcon(event.responseData)

    if ok
      this.progressReport(eventSpec.summary)

    return ok

  # ----------------------------------------------------------------------------------------------------------------
  updateCompleted: (status)->

    processedCompletely = false

    successful = _.select(status, (s)=>s.status is true)

    numRequested = _.size(status) + (if @updateInProgress? then 1 else 0)
    numSuccessful = _.size(successful) + (if @updateManifestSuccess then 1 else 0)

    Hy.Trace.debug "ContentManifestUpdateActivity::updateCompleted (ENTER status=#{numSuccessful}/#{numRequested})"

    report = "Update complete..."

    if numRequested is 0
      processedCompletely = true
    else
      if numSuccessful is 0
        report = "Sorry - couldn\'t process this update. Please try again later."
      else
        if numSuccessful < numRequested
          report = "Sorry - couldn\'t install all updates..."
          report += " Please try again later"
        else
          processedCompletely = true

          n = numSuccessful
          if (n>1) and @updateManifestSuccess
            n -= 1

          if n is 1
            report += " Trivia update installed"
          else
            report += " #{n} trivia update"
            if n > 1
              report += "s"

            report += " installed"
      
      @contentManager.doInventoryImmediate()

    if processedCompletely
      Hy.ConsoleApp.get().analytics?.logContentUpdate()

      if @updateInProgress?
        Hy.Update.Update.clear @updateInProgress.update

      if @updateManifest?
        if @updateManifest.checkProcessedCompletely()
          @updateManifest.setProcessedCompletely()

    else
      Hy.ConsoleApp.get().analytics?.logContentUpdateFailure()

    title = if processedCompletely then "Update Successful" else null

    this.transactionEnd(processedCompletely, report, {title: title, _explain: report}, processedCompletely)

    @contentManager.dump()

    return null

# ==================================================================================================================
#
# Represents the user-created contest purchase option
#
class UserCreatedContentPurchaseItem extends Hy.Commerce.ManagedPurchaseItem

  # ----------------------------------------------------------------------------------------------------------------
  @create: (reference)->
    displayName = "Custom Trivia Pack Feature"
    new UserCreatedContentPurchaseItem(Hy.Config.Content.kAppStoreProductInfo_CustomTriviaPackFeature_1, reference, displayName)

  # ----------------------------------------------------------------------------------------------------------------
  isPurchased: ()-> 
    super or Hy.Config.Commerce.kPurchaseTEST_isPurchased

# ==================================================================================================================
# Represents an available content manifest update
# As specified in the trivially console update manifest
#
class ContentManifestUpdate extends Hy.Update.Update

  # ----------------------------------------------------------------------------------------------------------------
  @create: (directive)->

    Hy.Trace.debug "ContentManifestUpdate::create (version=#{directive.version_major}/#{directive.version_minor})"

    m = null

    if FileBasedManifest.checkManifestUpdate(directive.version_major, directive.version_minor)
      m = new ContentManifestUpdate(directive)

    return m

  # ----------------------------------------------------------------------------------------------------------------
  @getUpdate: ()->

#    Hy.Trace.debug "ContentManifestUpdate::getUpdate (ENTER)"
    update = null

    updates = Hy.Update.Update.getUpdatesByType Hy.Update.Update.kContentManifestUpdateDirectiveName

    if updates?
      # We expect there to be exactly one updated manifest available a time
      update = _.first (updates)

      if not FileBasedManifest.checkManifestUpdate(update.versionMajor, update.versionMinor)
        update = null

#    Hy.Trace.debug "ContentManifestUpdate::getUpdate (EXIT)"
    
    return update

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (directive)->
    super

    @versionMajor = directive.version_major
    @versionMinor = directive.version_minor

    @file = FileBasedManifest.getFilenameFromVersion(@versionMajor, @versionMinor)

    Hy.Trace.debug "ContentManifestUpdate::constructor (version=#{@versionMajor}/#{@versionMinor} file=#{@file})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDumpString: ()->
    out = super
    out += " version=#{@versionMajor}.#{@versionMinor} file=#{@file}"

    out

  # ----------------------------------------------------------------------------------------------------------------
  getFile: ()->@file

# ==================================================================================================================
# assign to global namespace:
Hy.Content =
  ContentPack: ContentPack
  ContentManager: ContentManager
  ContentManagerActivity: ContentManagerActivity
  ContentManifestUpdate: ContentManifestUpdate
  Questions: Questions




