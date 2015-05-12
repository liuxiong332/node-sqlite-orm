Cache = require '../lib/cache'

describe 'Cache', ->
  it 'set and get', ->
    cache = new Cache({maxSize: 10})
    for i in [1..10]
      cache.set(i, i)
    for i in [1..10]
      cache.get(i).should.equal(i)
    cache.list.getList().should.eql (i for i in [10..1])

    for i in [11..20]
      cache.set(i, i)
    cache.list.getList().should.eql (i for i in [20..11])

    for i in [20..11]
      cache.get(i)
    cache.list.getList().should.eql (i for i in [11..20])
