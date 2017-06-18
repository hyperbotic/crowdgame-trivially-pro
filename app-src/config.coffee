# ==================================================================================================================
Hy.Config =

  AppId: "an id"

  platformAndroid: false

  Production: false

  DisplayName: "Trivially Pro"

  kMaxRemotePlayers : 35

  kMaxPlayerNameLength: 8

  kHelpPage  : "??"
  
  PlayerStage:
    kMaxNumPlayers : 36 # kMaxRemotePlayers + 1 (for Console Player)
    kPadding       :  5

  Dynamics:
    panicAnswerTime: 3
    revealAnswerTime: 5
    maxNumQuestions: 50 # Max number of questions that can be played at a time

  Version:

    copyright: "Copyright© 2017"
    copyright1: "Copyright© 2017"
    copyright2: ""

    Console:
      kConsoleMajorVersion  : 1
      kConsoleMinorVersion  : 4
      kConsoleMinor2Version : 0
      kVersionMoniker       : ""

    Remote:
      kMinRemoteMajorVersion    : 1
      kMinRemoteMinorVersion    : 0

    isiOS4Plus: ()->
      result = false
      # add iphone specific tests
      if Ti.Platform.name is 'iPhone OS'
        version = Ti.Platform.version.split "."
        major = parseInt(version[0])
        # can only test this support on a 3.2+ device
        result = major >= 4
      result

  Commerce:
    kReceiptDirectory    : Ti.Filesystem.applicationDataDirectory + "/receipts"
    kPurchaseLogFile     : Ti.Filesystem.applicationDataDirectory + "/purchases.txt"
    kReceiptTimeout      : 60 * 1000
    kPurchaseTimeout     : 2 * 60 * 1000
    kRestoreTimeout      : 30 * 1000

    kPurchaseTEST_isPurchased: false # Set to true to short-circuit "buy" options
    kPurchaseTEST_dontShowBuy: false # Set to true to short-circuit "buy" options

    StoreKit:
      kUseSandbox :  false
      kVerifyReceipt: true

  PlayerNetwork:
    kSingleUserModeOverride: true # Set true to force app into single user mode
    kMaxNumInitializationAttempts : 5
    kTimeBetweenInitializationAttempts: 5 * 1000

    # We present a fatal error if the player network hasnt hit the ready state in time
    kServiceStartupTimeout: 20 * 1000

    kHelpPage  : "http:??"

    kFirebaseRootURL: "??"
    kFirebaseAppRootURL: "??"

    registerAPI      : "??"

    ActivityMonitor:
      kRemotePingInterval: 30 * 1000       # This is here just for reference. See main.coffee.
      kCheckInterval   : (60*1000) + 10    # How often we check the status of connections. 
      kThresholdActive : (60*1000) + 10    # A client is "active" if we hear from it at least this often. 
                                           #  This is set to a value that's more than
                                           #  double the interval that clients are actually sending pings at, so that a client can
                                           #  miss a ping but still be counted as "active"
                                           #  
      kThresholdAlive  :  120*1000 + 10    # A client is dead if we don't hear from it within this timeframe.
                                           # We set it to greater than 4 ping cycles.
                                           #

  NetworkService:
    kQueueImmediateInterval   :  1 * 1000
    kQueueBackgroundInterval  : 10 * 1000
    kDefaultEventTimeout      : 25 * 1000 # v1.0.7

  Rendezvous:
    URL                      : "??"
    URLDisplayName           : "??" 

    API                      : "??"
    MinConsoleUpdateInterval : 5 * 60 * 1000 # 5 minutes

  Update:
    kUpdateBaseURL       : "??"

    # Changed protocol for naming the update manifest, as of 2.3: 
    # Now there's one manifest per shipped version of the app
    #
    kUpdateCheckInterval : 20*60*1000 # 20 minutes - changed for Pro v1.0.1

    kRateAppReminderFileName : Titanium.Filesystem.applicationDataDirectory + "/AppReminderLog"

  DownloadManager:
    kCacheDirectoryPath  : Ti.Filesystem.applicationDataDirectory + "/downloadCache"
    kCacheDirectoryName  : "Documents/downloadCache"
    kMaxSimultaneousDownloads: 1

  Trace:
    messagesOn       : false
    memoryLogging    : false
    uiTrace          : false
    # HACK, as "applicationDirectory" seems to be returning a path with "Applications" at the end
    LogFileDirectory : Titanium.Filesystem.applicationDataDirectory + "../tmp" 
    MarkerFilename: Titanium.Filesystem.applicationDataDirectory + "../tmp" + "/MARKER.txt"

  Content:
    kContentMajorVersionSupported  : "001"
    kUsageDatabaseName             : "CrowdGame_Trivially_Usage_database"
    kUsageDatabaseVersion          : "001"
                                     # This is the "documents" directory
    kUpdateDirectory               : Ti.Filesystem.applicationDataDirectory
    kThirdPartyContentDirectory    : Ti.Filesystem.applicationDataDirectory + "/third-party"
    kShippedDirectory              : Ti.Filesystem.resourcesDirectory + "/data"
    kDefaultIconDirectory          : Ti.Filesystem.resourcesDirectory + "/data"
    kInventoryInterval             : 60 * 1000
    kInventoryTimeout              : 30 * 1000

    kContentPackMaxNameLength               :  50
    kContentPackMaxLongDescriptionLength    : 175
    kContentPackMaxIconSpecLength           :  30
    kContentPackMaxQuestionLength           : 120
    kContentPackMaxAnswerLength             :  55
    kContentPackMaxAuthorVersionInfoLength  :  10
    kContentPackMaxAuthorContactInfoLength  :  (64 + 1 + 255) #http://askville.amazon.com/maximum-length-allowed-email-address/AnswerViewer.do?requestId=1166932
    kContentPackWithHeaderMaxNumHeaderProps :  150

    kThirdPartyContentPackMinNumRecords     :   5
    kThirdPartyContentPackMaxNumRecords     : 200

    kAppStoreProductInfo_CustomTriviaPackFeature_1: "custom_trivia_pack_feature_1"

    kHelpPage    : "??"
    kSamplesPage : "??"

    kContentPackMaxBytes                    : -1
    kThirdPartyContentPackMaxBytes          : 1024 * 1024 # 1MB

    kThirdPartyContentBuyText: "buy"
    kThirdPartyContentNewText: "new"
    kThirdPartyContentInfoText: "info"

    kSampleCustomContestsDefault : [
      {name: "Simple Gray Template", url: "a url here"},
      {name: "Gamer Template",       url: "another here"}
    ]

  Analytics: 
    
    active                        : true
    Namespace                     : "Hy.Analytics.TriviallyPro"
    Version                       : "Pro-v1.1.0"
    Google:
      accountID                   : "your-id-here"

  Support:
    email                         : "??"
    contactUs                     : "??"

  UI:
    kTouchAndHoldDuration: 900
    kTouchAndHoldDurationStarting : 300
    kTouchAndHoldDismissDuration: 2000 # Amount of time the menu stays up after touch event has fired

Hy.Config.Update.kUpdateFilename = "trivially-pro-update-manifest--v-#{Hy.Config.Version.Console.kConsoleMajorVersion}-#{Hy.Config.Version.Console.kConsoleMinorVersion}-#{Hy.Config.Version.Console.kConsoleMinor2Version}.json"

if not Hy.Config.Production
  Hy.Config.Trace.messagesOn                      = true
  Hy.Config.Trace.memoryLogging                   = true
  Hy.Config.Trace.uiTrace                         = true

  Hy.Config.Commerce.StoreKit.kUseSandbox         = true

  Hy.Config.Update.kUpdateCheckInterval           = 1 * 60 * 1000

  Hy.Config.PlayerNetwork.kServiceStartupTimeout  = 60 * 1000

  Hy.Config.PlayerNetwork.registerAPI = "a url"

Hy.Config.Commerce.kPurchaseTEST_isPurchased = true # HACK
Hy.Config.Commerce.kPurchaseTEST_dontShowBuy = true # HACK

