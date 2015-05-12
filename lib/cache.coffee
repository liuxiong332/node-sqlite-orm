
class List
  constructor: ->
    @head = {}
    @tail = {}
    @head.next = @tail
    @tail.prev = @head

  insertBefore: (refNode, newNode) ->
    prevNode = refNode.prev
    prevNode.next = newNode
    newNode.prev = prevNode
    newNode.next = refNode
    refNode.prev = newNode

  insertAfter: (refNode, newNode) ->
    nextNode = refNode.next
    refNode.next = newNode
    newNode.prev = refNode
    newNode.next = nextNode
    nextNode.prev = newNode

  detach: (node) ->
    nextNode = node.next
    prevNode = node.prev
    node.next = node.prev = null
    nextNode.prev = prevNode
    prevNode.next = nextNode

  forward: (node) ->
    if node isnt @head.next
      @detach(node)
      @insertAfter(@head, node)

  getList: ->
    iter = @head
    while (iter = iter.next) isnt @tail
      iter.value

module.exports =
class Cache
  constructor: (options) ->
    @maxSize = options.maxSize ? Infinity
    @curSize = 0
    @cache = new Map
    @list = new List

  get: (key) ->
    node = @cache.get(key)
    if node
      @list.forward(node)
      node.value

  set: (key, value) ->
    list = @list
    node = @cache.get(key)
    if node
      node.value = value
      list.forward(node)
    else
      node = {key, value}
      list.insertAfter(list.head, node)
      @cache.set(key, node)
      if ++ @curSize > @maxSize
        @_removeNode list.tail.prev
        -- @curSize

  _removeNode: (node) ->
    @list.detach node
    @cache.delete(node.key)
