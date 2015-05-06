###
 sqlite-orm
 https://github.com/liuxiong332/sqlite-orm

 Copyright (c) 2015 liuxiong
 Licensed under the MIT license.
###
Q = require 'q'
sqlite3 = require('sqlite3').verbose()

module.exports =
class Mapper
  constructor: (@fileName) ->
    @db = null

  newDB: ->
    defer = Q.defer()
    db = new sqlite3.Database @fileName, (err) ->
      if err then defer.reject(err) else defer.reject(db)

  define: (modelName, attributes, options) ->
    # for attr, val of attributes

  sync: ->
    Q.async ->
      @db ?= yield @newDB()


