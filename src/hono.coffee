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

  forwardData: (queue, payload) ->
    @emit 'message',
      queue: queue
      payload: payload

  componentize: (deviceId, telemetry, lwm2m) ->
    deviceParts = deviceId.split '.'
    toSend = {}
    componentDef =
      id: deviceId
      role: deviceId
      component: "hono/#{deviceId}"
      icon: 'rss'
      description: "#{deviceParts[0]} device on Hono"
      inports: []
      outports: []
    componentDef.lwm2m = true if lwm2m
    for key, val of telemetry
      queue = "hono/#{@options.tenant}/#{deviceId}/#{key}"
      componentDef.outports.push
        id: key
        queue: queue
        type: @valueToPortType val
      toSend[queue] = val
    if @components[deviceId]
      # Skip update if we exist
      return if @components[deviceId].lwm2m
      updated = JSON.stringify componentDef
      existing = JSON.stringify @components[deviceId]
      if updated is existing
        # Just forward the data
        @forwardData key, val for key, val of toSend
        return
    @components[deviceId] = componentDef
    @emit 'component', componentDef
    # Forward after registering component
    @forwardData key, val for key, val of toSend

  componentizeWithPath: (deviceId, path, telemetry) ->
    # TODO: We could use _X suffix as addressable port index
    port = path.split('/').pop()
    queue = "hono/#{@options.tenant}/#{deviceId}/#{port}"
    unless @components[deviceId]
      # We can do initial simple registration
      simplified = {}
      simplified[port] = telemetry.value
      @componentize deviceId, simplified, true
    @components[deviceId].lwm2m = true
    componentDef = JSON.parse JSON.stringify @components[deviceId]
    # See if this particular path has already been registered as port
    matchingPort = componentDef.outports.filter (p) -> p.id is port
    if matchingPort.length
      # Just forward the data
      @forwardData queue, telemetry.value
      return
    componentDef.outports.push
      id: port
      queue: queue
      type: @valueToPortType telemetry.value
    @components[deviceId] = componentDef
    @emit 'component', componentDef
    # Forward after registering component
    @forwardData queue, telemetry.value

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

    # Device sending semantic telemetry, likely LWM2M
    @componentizeWithPath annotations.device_id, msg.path, msg

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
