# ==================================================================================================================
class Contest
  gInstanceCount = 0
  
  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    @instance = ++gInstanceCount
    @contestQuestions = []

    this

  # ----------------------------------------------------------------------------------------------------------------
  addQuestions: (contentPack, numQuestionsNeeded)->
    q = _.min(contentPack.getContent(), (q)->Hy.Content.Questions.getUsageCount(q))

    minDisplayCount = Hy.Content.Questions.getUsageCount(q)

    numQuestionsAdded = if (numRecords = contentPack.getNumRecords()) < numQuestionsNeeded
      numRecords
    else
      numQuestionsNeeded

    # Returns actual number added
    this.addQuestions_(contentPack, minDisplayCount, numQuestionsAdded)

  # ----------------------------------------------------------------------------------------------------------------
  addQuestions_: (contentPack, minDisplayCount, nNeeded)->

    numAdded = 0
    isOrderRandom = contentPack.isOrderRandom()

    questions = contentPack.getContent()

    fnPickQuestions = (qs, numQ = qs.length)=>
      for i in [0..(numQ-1)]
        q = if isOrderRandom
          ind = Hy.Utils.Math.random(_.size(qs))
          qt = qs[ind]
          qs.splice(ind, 1)
          qt
        else
          qs[i]

        @contestQuestions.push(new ContestQuestion(this, contentPack, q))
      null

    qs = if isOrderRandom # v1.1.0
      _.select(questions, (q)->Hy.Content.Questions.getUsageCount(q) is minDisplayCount)
    else
      _.select(questions, (q)->true)

    # Check for duplicates
    currentQuestions = _.map(@contestQuestions, (contestQuestion)=>contestQuestion.getQuestion())
    qs = _.without(qs, currentQuestions)

    if qs.length is 0
      null # huh
    else
      numAdded = nNeeded

      if qs.length > nNeeded
        # more eligible questions than we need, so pull a subset
        fnPickQuestions(qs, nNeeded)
      else
        remainingNeeded = nNeeded - qs.length
        # first include all the questions we currently have
        fnPickQuestions(qs)

        # now fill up remainder with next set:
        if remainingNeeded > 0
          this.addQuestions_(contentPack, ++minDisplayCount, remainingNeeded)

    numAdded

  # ----------------------------------------------------------------------------------------------------------------
  getQuestions: ()-> @contestQuestions

# ==================================================================================================================
class ContestQuestion
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@contest, @contentPack, @question)->
    @questionText = @question.question

    indeces = Hy.Utils.Array.shuffle([0,1,2,3])
    @answers = (@question["answer#{index+1}"] for index in indeces)

#    as = @question.answers
#    @answers = (as[index] for index in indeces)

    i = 0
    i++ while (indeces[i] != 0 and i < indeces.length)
    @indexCorrectAnswer = i

    @used = false

    gInstances.push this

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Class Methods:
  # ----------------------------------------------------------------------------------------------------------------
  gInstances = []

  # ----------------------------------------------------------------------------------------------------------------
  # TODO: is this ever used??
  @collection: ()->gInstances
  
  # ----------------------------------------------------------------------------------------------------------------
  @findByQuestionID: (contestQuestions, questionID)->
    for cq in contestQuestions
      return cq if cq.question.id is questionID
    null
    
  # ----------------------------------------------------------------------------------------------------------------
  # Instance Methods:
  # ----------------------------------------------------------------------------------------------------------------
  getContentPack: ()-> @contentPack
  # ----------------------------------------------------------------------------------------------------------------
  getQuestionID: ()-> @question.id

  # ----------------------------------------------------------------------------------------------------------------
  getQuestionText: ()-> @questionText

  # ----------------------------------------------------------------------------------------------------------------
  getAnswerText: (index)-> @answers[index]

  # ----------------------------------------------------------------------------------------------------------------
  getQuestion: ()-> @question
  
  # ----------------------------------------------------------------------------------------------------------------
  setUsed: ()->
    @used = true
    Hy.Content.Questions.incrementUsageCount(@question)
    this

  # ----------------------------------------------------------------------------------------------------------------
  wasUsed: ()-> @used

# ==================================================================================================================
class ContestResponse

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@player, @contestQuestion, @answerIndex, @startTime, @answerTime)->

    gInstances.push this
    @instance = ++gInstanceCount

    @correct = (@answerIndex is @contestQuestion.indexCorrectAnswer)
    @score = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Class Methods:
  # ----------------------------------------------------------------------------------------------------------------
  gInstances = []
  gInstanceCount = 0

  # ----------------------------------------------------------------------------------------------------------------
  @collection: ()->gInstances
  
  # ----------------------------------------------------------------------------------------------------------------
  # Returns responses for the CURRENT contest
  @selectByQuestionID: (questionID)->

    fnFilter = (response)->
      cq = response.contestQuestion
      (cq.getQuestionID() is questionID) and (cq.contest is Hy.ConsoleApp.get().getContest())

    filteredResponses = _.select gInstances, fnFilter

    fnSortBy = (r)->
      r.instance
    sortedResponses = _.sortBy filteredResponses, fnSortBy

  # ----------------------------------------------------------------------------------------------------------------
  # Returns responses for the CURRENT contest
  @selectByQuestionIDAndPlayer: (questionID, player)->

    responses = ContestResponse.selectByQuestionID(questionID)
    for r in responses
      if r.player.index is player.index
        return r

    return null

  # ----------------------------------------------------------------------------------------------------------------
  # Returns responses for the CURRENT contest
  @selectByPlayer: (player)->

    responses = []

    for r in gInstances
      if (r.player.index is player.index) and (r.contestQuestion.contest is Hy.ConsoleApp.get().getContest())
        responses.push r

    responses

  # ----------------------------------------------------------------------------------------------------------------
  # Instance Methods:
  # ----------------------------------------------------------------------------------------------------------------
  contest: ()->@contestQuestion.contest

  # ----------------------------------------------------------------------------------------------------------------
  getPlayer: ()-> @player
  # ----------------------------------------------------------------------------------------------------------------
  getCorrect: ()-> @correct

  # ----------------------------------------------------------------------------------------------------------------
  getStartTime: ()-> @startTime

  # ----------------------------------------------------------------------------------------------------------------
  getAnswerTime: ()-> @answerTime

  # ----------------------------------------------------------------------------------------------------------------
  getScore: ()->

    if not @score?
      @score = this.computeScore()

    @score

  # ----------------------------------------------------------------------------------------------------------------
  computeScore: ()->

    score = 0

    if this.getCorrect()
      switch this.getStartTime() - this.getAnswerTime()
        when 0, 1, 2, 3
          score = 3
        when 4, 5, 6
          score = 2
        else
          score = 1

    score

# ==================================================================================================================
# assign to global namespace:
Hy.Contest =
  Contest:         Contest
  ContestQuestion: ContestQuestion
  ContestResponse: ContestResponse

