module.exports =
class ObserverArray
  constructor: (@observeFunc) ->
    @list = []
    @inObserve = true
    @observers = []

  _scopeUnobserve: (callback) ->
    origin = @inObserve
    @inObserve = false
    callback()
    @inObserve = origin

  observe: (func) ->
    @observers.push func

  unobserve: (func) ->
    @observers.splice(@observers.indexOf(func), 1)

  set: (index, value) ->
    list = @list
    oldValue = list[index]
    list[index] = value
    if @inObserve or @observers.length > 0
      change = {name: index, type: 'update', oldValue}
      @observeFunc [change] if @inObserve
      obs(change) for obs in @observers

  get: (index) -> @list[index]

  splice: (start, removeCount, insertItems...) ->
    removed = @list.splice(start, removeCount, insertItems...)

    if @inObserve or @observers.length > 0
      change =
        type: 'splice', index: start, removed: removed
        addedCount: insertItems.length
      @observeFunc([change]) if @inObserve
      obs(change) for obs in @observers
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
