
# ==================================================================================================================
class SoundManager

  gInstance = null

  soundsInfo = [
    {key: 'silence',   url: 'silence.wav'}
    {key: 'clock01sA', url: 'clock1.wav'}
    {key: 'clock01sB', url: 'clock2.wav'}
    {key: 'clock01sC', url: 'clock3.wav'}
    {key: 'clock01sD', url: 'clock4.wav'}
    {key: 'clock01sE', url: 'clock5.wav'}
    {key: 'bell',      url: '000597941-Bell.wav'}
    {key: 'plop1',     url: '000617670-Plop1.wav'}
    {key: 'plop2',     url: '000949675-Plop2.wav'}
    {key: 'plop3',     url: '000949683-Plop3.wav'}
    {key: 'test',      url: '1000Hz-5sec.mp3'}
    {key: 'flitter',   url: 'flitter.wav'}
  ]

  eventMap = [
    {eventName: "gameStart",          soundName: "plop3"}
    {eventName: "challengeCompleted", soundName: "bell"}
    {eventName: "remotePlayerJoined", soundName: "flitter"}
    {eventName: "countDown_0",        soundName: "clock01sA"}
    {eventName: "countDown_1",        soundName: "clock01sB"}
    {eventName: "countDown_2",        soundName: "clock01sC"}
    {eventName: "countDown_3",        soundName: "clock01sD"}
    {eventName: "countDown_4",        soundName: "clock01sE"}
    {eventName: "hiddenChord",        soundName: "bell"}
    {eventName: "test",               soundName: "test"}
  ]

  # ----------------------------------------------------------------------------------------------------------------
  @init: ()->
    if not gInstance?
      gInstance = new SoundManager()

    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    # http://developer.appcelerator.com/question/157210/local-sound-files-not-playing-on-ios-7device-sdk-313-but-works-fine-in-simulator
    #
    # Should be "Ambient"
    # (Apple guidlines:
    #  https://developer.apple.com/library/ios/documentation/userexperience/conceptual/mobilehig/TechnologyUsage/TechnologyUsage.html#//apple_ref/doc/uid/TP40006556-CH18-SW3
    #
#    Ti.Media.setAudioSessionMode(Ti.Media.AUDIO_SESSION_MODE_PLAYBACK);
    Ti.Media.setAudioSessionMode(Ti.Media.AUDIO_SESSION_MODE_AMBIENT);

    this.initSounds()
  
    this
  # ----------------------------------------------------------------------------------------------------------------
  initSounds: ()->

    @sounds = {}
    for soundInfo in soundsInfo
      @sounds[soundInfo.key] = Ti.Media.createSound({url: "assets/sound/#{soundInfo.url}"})

    @soundOption = Hy.Options.sound

    # try to deal with sound system delay in playing first sound
    Hy.Trace.debug "ConsoleApp::initSound (Playing blank sound)"
    sound = this.getSound('silence', false)
    sound?.play()
    sound?.stop()
    Hy.Trace.debug "ConsoleApp::initSound (Ending blank sound)"

    this
  # ----------------------------------------------------------------------------------------------------------------
  soundsOn: ()->
    @soundOption.getValue() is "on"

  # ----------------------------------------------------------------------------------------------------------------
  getSound: (key, check=true)->
    sound = if not check || this.soundsOn() then @sounds[key] else null
    sound

  # ----------------------------------------------------------------------------------------------------------------
  findEvent: (eventName)->
    _.detect(eventMap, (m)=>m.eventName is eventName)

  # ----------------------------------------------------------------------------------------------------------------
  playEvent: (eventName, check = true)->
    if (event = this.findEvent(eventName))?
      if (sound = this.getSound(event.soundName, check))?
        sound.play()
    else
      Hy.Trace.debug("SoundManager::playEvent (COULD NOT FIND SOUND FOR REQUESTED EVENT #{eventName})")
    this

# ==================================================================================================================
Hyperbotic.Media =
  SoundManager: SoundManager


