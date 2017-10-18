m = require('mochainon')
_ = require('lodash')
os = require('os')
path = require('path')
Promise = require('bluebird')
fs = Promise.promisifyAll(require('fs'))
wary = require('wary')
resin = require('resin-sdk-preconfigured')
imagefs = require('resin-image-fs')
init = require('../lib/init')

RASPBERRYPI = path.join(__dirname, 'images', 'raspberrypi.img')
RASPBERRYPI_WITH_DEVICE_TYPE = path.join(__dirname, 'images', 'raspberrypi-with-device-type.img')
EDISON = path.join(__dirname, 'images', 'edison')
RANDOM = path.join(__dirname, 'images', 'device.random')
DEVICES = {}

prepareDevice = (deviceType) ->
	applicationName = "DeviceInitE2E_#{deviceType.replace(/[- ]/, '_')}"
	console.log("Creating #{applicationName}")
	resin.models.application.has(applicationName).then (hasApplication) ->
		return if hasApplication
		resin.models.application.create(applicationName, deviceType)
	.then(resin.models.device.generateUniqueKey)
	.then (uuid) ->
		resin.models.device.register(applicationName, uuid)

extract = (stream) ->
	return new Promise (resolve, reject) ->
		result = ''
		stream.on('error', reject)
		stream.on 'data', (chunk) ->
			result += chunk
		stream.on 'end', ->
			resolve(result)

waitStream = (stream) ->
	return new Promise (resolve, reject) ->
		stream.on('error', reject)
		stream.on('close', resolve)
		stream.on('end', resolve)

########################################################################
# Raspberry Pi
########################################################################

wary.it 'should add a config.json correctly to a raspberry pi',
	raspberrypi: RASPBERRYPI
, (images) ->

	config =
		isTestConfig: true

	resin.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		init.configure(images.raspberrypi, device.device_type, config)
	.then(waitStream)
	.then ->
		Promise.using imagefs.read(
			partition: 1
			path: '/config.json'
			image: images.raspberrypi
		), extract
	.then(JSON.parse)
	.then (config) ->
		m.chai.expect(config.isTestConfig).to.equal(true)

wary.it 'should add a correct config.json to a raspberry pi containing a device-type.json',
	raspberrypi: RASPBERRYPI_WITH_DEVICE_TYPE
, (images) ->

	config =
		isTestConfig: true

	resin.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		init.configure(images.raspberrypi, device.device_type, config)
	.then(waitStream)
	.then ->
		Promise.using imagefs.read(
			partition: 5
			path: '/config.json'
			image: images.raspberrypi
		), extract
	.then(JSON.parse)
	.then (config) ->
		m.chai.expect(config.isTestConfig).to.equal(true)

wary.it 'should not trigger a state event when configuring a raspberry pi',
	raspberrypi: RASPBERRYPI
, (images) ->
	spy = m.sinon.spy()

	resin.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		init.configure(images.raspberrypi, device.device_type, {})
	.then (configuration) ->
		configuration.on('state', spy)
		return waitStream(configuration)
	.then ->
		m.chai.expect(spy).to.not.have.been.called

wary.it 'should initialize a raspberry pi image',
	raspberrypi: RASPBERRYPI
	random: RANDOM
, (images) ->

	drive =
		raw: images.random
		size: fs.statSync(images.random).size

	resin.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		init.configure(images.raspberrypi, device.device_type, {})
	.then(waitStream).then ->
		init.initialize(images.raspberrypi, 'raspberry-pi', { drive })
	.then(waitStream).then ->
		Promise.props
			raspberrypi: fs.readFileAsync(images.raspberrypi)
			random: fs.readFileAsync(images.random)
		.then (results) ->
			m.chai.expect(results.random).to.deep.equal(results.raspberrypi)

wary.it 'should initialize a raspberry pi image containing a device type',
	raspberrypi: RASPBERRYPI_WITH_DEVICE_TYPE
	random: RANDOM
, (images) ->

	drive =
		raw: images.random
		size: fs.statSync(images.random).size

	resin.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		init.configure(images.raspberrypi, device.device_type, {})
	.then(waitStream).then ->

		# We use a nonsense device type name here to make
		# sure the device-type.json file is read from the device
		init.initialize(images.raspberrypi, 'foobar', { drive })

	.then(waitStream).then ->
		Promise.props
			raspberrypi: fs.readFileAsync(images.raspberrypi)
			random: fs.readFileAsync(images.random)
		.then (results) ->
			m.chai.expect(results.random).to.deep.equal(results.raspberrypi)

wary.it 'should emit state events when initializing a raspberry pi',
	raspberrypi: RASPBERRYPI
	random: RANDOM
, (images) ->

	drive =
		raw: images.random
		size: fs.statSync(images.random).size

	spy = m.sinon.spy()

	resin.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		init.configure(images.raspberrypi, device.device_type, {})
	.then(waitStream).then ->
		init.initialize(images.raspberrypi, 'raspberry-pi', { drive })
	.then (initialization) ->
		initialization.on('state', spy)
		return waitStream(initialization)
	.then ->
		m.chai.expect(spy).to.have.been.calledOnce
		args = spy.firstCall.args
		m.chai.expect(args[0].operation.command).to.equal('burn')
		m.chai.expect(args[0].percentage).to.equal(100)

wary.it 'should emit burn events when initializing a raspberry pi',
	raspberrypi: RASPBERRYPI
	random: RANDOM
, (images) ->

	drive =
		raw: images.random
		size: fs.statSync(images.random).size

	spy = m.sinon.spy()

	resin.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		init.configure(images.raspberrypi, device.device_type, {})
	.then(waitStream).then ->
		init.initialize(images.raspberrypi, 'raspberry-pi', { drive })
	.then (initialization) ->
		initialization.on('burn', spy)
		return waitStream(initialization)
	.then ->
		m.chai.expect(spy).to.have.been.called
		args = spy.lastCall.args
		m.chai.expect(args[0].percentage).to.equal(100)
		m.chai.expect(args[0].eta).to.equal(0)

########################################################################
# Intel Edison
########################################################################

wary.it 'should add a config.json to an intel edison',
	edison: EDISON
, (images) ->

	config =
		isTestConfig: true

	resin.models.device.get(DEVICES.edison.id).then (device) ->
		init.configure(images.edison, device.device_type, config)
	.then(waitStream)
	.then ->
		Promise.using imagefs.read(
			path: '/config.json'
			image: path.join(images.edison, 'resin-image-edison.hddimg')
		), extract
	.then(JSON.parse)
	.then (config) ->
		m.chai.expect(config.isTestConfig).to.equal(true)

wary.it 'should not trigger a state event when configuring an intel edison',
	edison: EDISON
, (images) ->

	spy = m.sinon.spy()

	resin.models.device.get(DEVICES.edison.id).then (device) ->
		init.configure(images.edison, device.device_type, {})
	.then (configuration) ->
		configuration.on('state', spy)
		return waitStream(configuration)
	.then ->
		m.chai.expect(spy).to.not.have.been.called

wary.it 'should be able to initialize an intel edison with a script',
	edison: EDISON
, (images) ->

	stdout = ''
	stderr = ''

	resin.models.device.get(DEVICES.edison.id).then (device) ->
		init.configure(images.edison, device.device_type, {})
	.then(waitStream)
	.then ->
		init.initialize(images.edison, 'intel-edison', {})
	.then (initialization) ->

		initialization.on 'stdout', (data) ->
			stdout += data

		initialization.on 'stderr', (data) ->
			stderr += data

		return waitStream(initialization)
	.then ->
		m.chai.expect(stdout.replace(/[\n\r]/g, '')).to.equal('Hello World')
		m.chai.expect(stderr).to.equal('')

Promise.try ->
	require('dotenv').config(silent: true)
.then ->
	resin.auth.login
		email: process.env.RESIN_E2E_EMAIL
		password: process.env.RESIN_E2E_PASSWORD
.then ->
	console.log('Logged in')
	Promise.props
		raspberrypi: prepareDevice('raspberry-pi')
		edison: prepareDevice('intel-edison')
.then (devices) ->
	DEVICES = devices
	wary.run()
.catch (error) ->
	console.error(error, error.stack)
	process.exit(1)
