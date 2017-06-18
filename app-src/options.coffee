# ==================================================================================================================
class ApplicationOption
  _.extend ApplicationOption::, Hy.Utils.Eventable

  # ----------------------------------------------------------------------------------------------------------------
  propKey: ()->
    "Hy.#{if @namespace? then @namespace + '.' else ''}#{@key}"


# ==================================================================================================================
class ChoicesOption extends ApplicationOption
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@key, @choices, @namespace = null)->
#    Hy.Trace.debug "ChoicesOption::constructor(key => #{key})"
    propKey = this.propKey()
    Ti.App.Properties.setInt(propKey, 0) unless Ti.App.Properties.hasProperty(propKey)
    @index = Ti.App.Properties.getInt(propKey)
    this

  # ----------------------------------------------------------------------------------------------------------------
  numOptions: ()-> _.size(@choices)

  # ----------------------------------------------------------------------------------------------------------------
  setValue: (newValue)->
#    Hy.Trace.debug "ChoicesOption<#{@key}>::setValue(newValue => #{newValue})"
    this.setIndex @choices.indexOf(newValue)
    this

  # ----------------------------------------------------------------------------------------------------------------
  setIndex: (newIndex)->
#    Hy.Trace.debug "ChoicesOption<#{@key}>::setIndex(newIndex => #{newIndex})"
    Ti.App.Properties.setInt(this.propKey(), newIndex)
    @index = newIndex
    this.fireEvent 'change', {source:this}
    this

  # ----------------------------------------------------------------------------------------------------------------
  getValue: ()->
    @choices[@index]

  # ----------------------------------------------------------------------------------------------------------------
  getChoices: ()-> @choices

  # ----------------------------------------------------------------------------------------------------------------
  isValidValue: (value)->
    @choices.indexOf(value) isnt -1

# ==================================================================================================================
class ToggleOption extends ApplicationOption
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@key, @namespace = null)->
    propKey = this.propKey()
    Ti.App.Properties.setBool(propKey, true) unless Ti.App.Properties.hasProperty(propKey)
    @value = Ti.App.Properties.getBool(propKey)
    this

  # ----------------------------------------------------------------------------------------------------------------
  setValue: (newValue)->
    Ti.App.Properties.setBool(this.propKey(), newValue)
    @value = newValue
    this.fireEvent 'change', {source:this}
    this

  # ----------------------------------------------------------------------------------------------------------------
  toggle: ()->
    this.setValue !@value


# ==================================================================================================================
class ToggleOptionSet
  _.extend ToggleOptionSet::, Hy.Utils.Eventable

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@namespace, @keys)->
#    Hy.Trace.debug "ToggleOptionSet::constructor"
    @toggleOptions = {}
    for key in keys
      toggleOption = new ToggleOption(key, @namespace)
      toggleOption.addEventListener 'change', (evt)=>this.toggleOptionChanged(evt)
      @toggleOptions[key] = toggleOption
      
    this

  # ----------------------------------------------------------------------------------------------------------------
  enabledOptions: ()->
#    Hy.Trace.debug "ToggleOptionSet::enabledOptions<#{@namespace}>"
    options = for key, toggleOption of @toggleOptions
      if toggleOption.value then toggleOption else null
    _.compact options

  # ----------------------------------------------------------------------------------------------------------------
  enabledOptionKeys: ()->
#    Hy.Trace.debug "ToggleOptionSet::enabledOptionKeys"
    _.pluck this.enabledOptions(), 'key'

  # ----------------------------------------------------------------------------------------------------------------
  toggleOptionChanged: (evt)->
#    Hy.Trace.debug "ToggleOptionSet::toggleOptionChanged"
    this.fireEvent 'change', {source:evt.source, owner:this}

# ==================================================================================================================
class ListOption extends ApplicationOption
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@key, @namespace = null)->
    propKey = this.propKey()
    @list = []
    Ti.App.Properties.setList(propKey, @list) unless Ti.App.Properties.hasProperty(propKey)
    @list = Ti.App.Properties.getList(propKey)
#    Hy.Trace.debug "OpenChoiceOption::constructor (key=#{key} namespace=#{namespace} list=#{_.size(@list)})"
    this

  # ----------------------------------------------------------------------------------------------------------------
  addOption: (value)->
#    Hy.Trace.debug "ListOption:<#{@key}>::addOption(new option => #{value} list=#{_.size(@list)})"

    if _.indexOf(@list, value) is -1
      @list.push(value)
      Ti.App.Properties.setList(this.propKey(), @list)

    this.fireEvent 'change', {source:this, action:"add", value:value}
    this

  # ----------------------------------------------------------------------------------------------------------------
  removeOption: (value)->
#    Hy.Trace.debug "ListOption:<#{@key}>::removeOption(removed option => #{value} list=#{_.size(@list)})"

    if _.indexOf(@list, value) isnt -1
      @list = _.without(@list, value)
      Ti.App.Properties.setList(this.propKey(), @list)

    this.fireEvent 'change', {source:this, action:"remove", value:value}
    this

  # ----------------------------------------------------------------------------------------------------------------
  getOption: (value)->
    option = _.indexOf(@list, value) isnt -1

#    Hy.Trace.debug "ListOption:<#{@key}>::getOption(option => #{value} value=#{option} list=#{_.size(@list)})"
 
    return option

  # ----------------------------------------------------------------------------------------------------------------
  getList: ()->
    return @list

# ==================================================================================================================
class Options
  @numQuestions = new ChoicesOption('numQuestions', [5, 10, 20, -1])
  @secondsPerQuestion = new ChoicesOption('secondsPerQuestion', [10, 15, 20, 30, 45, 60, 90, 120, 150, 180, 210, 240, 270, 300, 360, 420, 480, 540, 570])
  @firstCorrect = new ChoicesOption('firstCorrect', ['yes', 'no'])
  @sound = new ChoicesOption('sound', ['on', 'off'])

  @contentPacks = new ListOption('ContentPacks')

  props = Ti.App.Properties.listProperties()
  for prop in props
    Hy.Trace.info "#{prop} => #{Ti.App.Properties.getString(prop)}"

# ==================================================================================================================
# assign to global namespace:
Hy.Options = Options
