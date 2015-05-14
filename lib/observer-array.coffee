module.exports =
class ObserverArray extends Array
  constructor: (@observeFunc) ->
    super()

  observe: ->
    Array.observe this, @observeFunc

  unobserve: ->
    Array.unobserve this, @observeFunc

  scopeUnobserve: (callback) ->
    this.unobserve()
    callback()
    this.observe()
