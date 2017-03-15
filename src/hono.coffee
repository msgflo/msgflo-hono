container = require 'rhea'
url = require 'url'
{EventEmitter} = require 'events'

prepareConnectionOptions = (honoUrl) ->
  parsed = url.parse honoUrl
  [username, password] = parsed.auth.split ':'
  options =
    host: parsed.hostname
    port: parsed.port
    container_id: container.generate_uuid()
    username: username
    password: password

parseMessage = (msg) ->
  try
    return JSON.parse msg
  return msg

class HonoConnector extends EventEmitter
  components: {}
  connection: null
  constructor: (@options) ->
    @connectionOptions = prepareConnectionOptions @options.url
    @filter = new RegExp @options.filter or '.*'

  connect: ->
    return if @connection?.is_open()
    connection = container.connect @connectionOptions
    connection.on 'connection_open', (ctx) =>
      @connection = ctx.connection
      @emit 'connected', ctx.connection
      do @subscribeTelemetry
      #do @subscribeEvents
    connection.on 'disconnected', (ctx) =>
      @connection = null
      @emit 'disconnected', ctx.connection
    connection.on 'connection_error', (ctx) =>
      @connection = null
      err = ctx.connection.get_error()
      @emit 'error', err
    connection.on 'message', (ctx) =>
      return if @isIgnored ctx.message.message_annotations
      msg = parseMessage ctx.message.body.content.toString()
      @handleTelemetry msg, ctx.message.message_annotations

  disconnect: ->
    return unless @connection?.is_open()
    connection.close()
    return

  isIgnored: (annotations) ->
    return false if @filter.test annotations.device_id
    true

  valueToPortType: (val) ->
    if typeof val is 'string'
      return 'string'
    if typeof val is 'boolean'
      return 'boolean'
    if typeof val is 'number'
      return 'number'
    if typeof val is 'object'
      if Array.isArray val
        return 'array'
      return 'object'
    return 'all'

  componentize: (deviceId, telemetry) ->
    deviceParts = deviceId.split '.'
    componentDef =
      id: deviceId
      role: deviceId
      component: "hono/#{deviceId}"
      icon: 'rss'
      description: "#{deviceParts[0]} device on Hono"
      inports: []
      outports: []
    for key, val of telemetry
      componentDef.outports.push
        id: key
        queue: "hono/#{@options.tenant}/#{deviceId}/#{key}"
        type: @valueToPortType val
    if @components[deviceId]
      # Skip update if we exist
      updated = JSON.stringify componentDef
      existing = JSON.stringify @components[deviceId]
      return if updated is existing
    @components[deviceId] = componentDef
    @emit 'component', componentDef

  handleTelemetry: (msg, annotations) ->
    unless typeof msg is 'object'
      # Device that sends broken JSON or maybe raw telemetry
      @componentize annotations.device_id,
        telemetry: msg
      return

    unless msg.path
      # Device that sends plain JSON without semantics
      @componentize annotations.device_id, msg
      return
    return
    # Device sending semantic telemetry, likely LWM2M
    console.log annotations, JSON.stringify msg

  subscribeTelemetry: ->
    options =
      source:
        address: "telemetry/#{@options.tenant}"
        dynamic: 0
        expiry_policy: 'session-end'
      credit_window: 100
      autoaccept: true
      snd_settle_mode: 1
      rcv_settle_mode: 0
    @connection.open_receiver options

  subscribeEvents: ->
    options =
      source:
        address: "event/#{@options.tenant}"
        dynamic: 0
        expiry_policy: 'session-end'
      credit_window: 100
      autoaccept: true
      snd_settle_mode: 1
      rcv_settle_mode: 0
    @connection.open_receiver options

module.exports = HonoConnector
