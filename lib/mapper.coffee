###
 sqlite-orm
 https://github.com/liuxiong332/sqlite-orm

 Copyright (c) 2015 liuxiong
 Licensed under the MIT license.
###
Q = require 'q'
sqlite3 = require('sqlite3').verbose()
_ = require 'underscore'

module.exports =
class Mapper
  constructor: (@fileName) ->
    @db = null

  getDB: ->
    defer = Q.defer()
    if @db
      defer.resolve(@db)
    else
      @db = new sqlite3.Database @fileName, (err) ->
        if err then defer.reject(err) else defer.resolve(@db)
    defer.promise

  sync: ->
