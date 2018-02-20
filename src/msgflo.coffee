msgflo = require 'msgflo-nodejs'
{EventEmitter} = require 'events'
Promise = require 'bluebird'

class MsgFloConnector extends EventEmitter
  participants: {}
  connection: null
  constructor: (options) ->
    super()
    @options = options

  connect: ->
    return if @connection
    connection = msgflo.transport.getClient @options.url
    connection.connect (err) =>
      if err
        @emit 'error', err
        return
      @connection = connection
      @emit 'connected', @connection

  disconnect: ->
    return unless @connection
    @connection.disconnect (err) =>
      if err
        @emit 'error', err
        return
      @emit 'disconnected', @connection
      @connection = null

  registerComponent: (definition) ->
    registerParticipant = Promise.promisify @connection.registerParticipant.bind @connection
    createQueue = Promise.promisify @connection.createQueue.bind @connection
    registerParticipant definition
    .then ->
      Promise.all definition.outports, (port) ->
        createQueue 'outqueue', port.queue, port.options

  send: (queue, payload) ->
    sendTo = Promise.promisify @connection.sendTo.bind @connection
    sendTo 'outqueue', queue, payload

module.exports = MsgFloConnector
