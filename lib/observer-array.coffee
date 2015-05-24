module.exports =
class ObserverArray
  constructor: (@observeFunc) ->
    @list = []
    @inObserve = false

  observe: -> @inObserve = true

  unobserve: -> @inObserve = false

  scopeUnobserve: (callback) ->
    origin = @inObserve
    @inObserve = false
    callback()
    @inObserve = origin

  set: (index, value) ->
    list = @list
    oldValue = list[index]
    list[index] = value
    if @inObserve
      @observeFunc [{name: index, type: 'update', oldValue}]

  get: (index) -> @list[index]

  splice: (start, removeCount, insertItems...) ->
    removed = @list.splice(start, removeCount, insertItems...)

    if @inObserve
      change =
        type: 'splice', index: start, removed: removed
        addedCount: insertItems.length
      @observeFunc [change]
    removed

  clear: ->
    @splice(0, @list.length)

  push: (elements...) ->
    @splice(@list.length, 0, elements...)

  pop: ->
    if @list.length > 0
      @splice(@list.length - 1, 1)[0]

  slice: (start, end) ->
    @list.slice(start, end)

  indexOf: (index) ->
    @list.indexOf index

  Object.defineProperty @prototype, 'length',
    get: -> @list.length
