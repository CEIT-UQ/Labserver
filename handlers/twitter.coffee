{Experiment} = require '../experiment'
{Handler} = require '../handler'
errors = require '../error'
util = require 'util'
http = require 'http'

class TwitterExp extends Handler
    constructor: () -> 
        @queue = []
        @experiments = []
        @running = false
        @template = {type: 'Twitter', user: null}

        @on 'experimentAdded', (id) ->
            util.log "Experiment added: #{util.inspect @experiments[id].experiment}"
            util.log "Are we running? #{if @running then 'yes' else 'no'}"
            if not @running
                @running = true
                @_runHead()

        @on 'experimentCompleted', (id) ->
            @queue = @queue[1..@queue.length]
            if @queue.length is 0
                @running = false
            else
                @_runHead()

    createExperiment: (desc, cb) ->
        if not @validate desc
            new errors.BadExperimentDescription()
        else
            exp = new Experiment desc
            @_addExperiment exp
            cb exp


    getExperiment: (id, cb) ->
        exp = @_getExperiment(id)
        cb exp

    getResult: (id, cb) ->
        res = @_getResult(id)
        cb res

    cancelExperiment: (id, cb) ->
        res = @_cancelExp(id)
        cb res

    validate: (desc) ->
        for own k, v of @template
            # Desc must include all of template's fields
            if k not of desc
                return false
            # And if the template has a defined value for a given field,
            # desc's value for that field must match it.
            else
                if v? and desc[k] isnt v
                    return false

        return true

    _addExperiment: (exp) ->
        @queue.push exp
        exp.id = @experiments.length
        @experiments.push {experiment: exp, result: null}
        @emit 'experimentAdded', exp.id

    _setResult: (id, res) ->
        result = ({text: y.text, created_at: new Date(y.created_at)} for y in res)
        #util.log util.inspect result
        @experiments[id].result = result

    _runHead: () ->
        head = @queue[0]
        head.run()
        @emit 'experimentStarted', head.id
        options = 
            host: 'api.twitter.com'
            port: 80
            path:"/1/statuses/user_timeline.json?screen_name=#{head.description.user}&include_entities=false&trim_user=true"

        req = http.get options
        req.on 'response', (response) =>
            req.buf = ''
            response.on 'data', (chunk) =>
                req.buf += chunk

            response.on 'end', () =>
                @_setResult head.id, JSON.parse req.buf
                #util.log util.inspect JSON.parse req.buf
                head.complete()
                @emit 'experimentCompleted', head.id
                
exports.TwitterExp = TwitterExp