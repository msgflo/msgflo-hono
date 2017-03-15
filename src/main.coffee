program = require 'commander'
Hono = require './hono'
MsgFlo = require './msgflo'

normalizeOptions = (options) ->
  options.msgflo = process.env['MSGFLO_BROKER'] if not options.msgflo
  options.msgflo = process.env['CLOUDAMQP_URL'] if not options.msgflo
  unless options.hono
    console.error "Hono address required. Please provide via --hono"
    process.exit 1
  unless options.tenant
    console.error "Hono tenant ID. Please provide via --tenant"
    process.exit 1
  unless options.msgflo
    console.error "MsgFlo broker address required. Please provide via --msgflo"
    process.exit 1
  return options

exports.main = main = ->
  program
  .option('--hono <uri>', 'Hono address', String, '')
  .option('--tenant <id>', 'Hono tenant identifier', String, '')
  .option('--msgflo <uri>', 'MsgFlo broker address', String, '')
  .option('--filter <device_id>', 'Device ID regexp to filter with', String, '')
  .parse(process.argv)

  options = normalizeOptions program

  msgflo = new MsgFlo
    url: options.msgflo
  msgflo.on 'connected', ->
    console.log 'Connected to MsgFlo'
  msgflo.on 'disconnected', ->
    console.log 'Disconnected from MsgFlo'
  msgflo.on 'error', (err) ->
    console.error err
    process.exit 1
  msgflo.connect()
  hono = new Hono
    url: options.hono
    tenant: options.tenant
  hono.on 'connected', ->
    console.log 'Connected to Hono'
  hono.on 'disconnected', ->
    console.log 'Disconnected from Hono'
  hono.on 'error', (err) ->
    console.error err
    process.exit 1
  hono.on 'component', (def) ->
    msgflo.registerComponent def
    .catch (err) ->
      console.error err
      process.exit 1
    .then ->
      console.log "Registered component #{def.component}"
  hono.on 'message', (msg) ->
    msgflo.send msg.queue, msg.payload
    .catch (err) ->
      console.error err
      process.exit 1
  hono.connect()
