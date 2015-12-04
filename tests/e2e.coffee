m = require('mochainon')
_ = require('lodash')
os = require('os')
path = require('path')
Promise = require('bluebird')
fs = Promise.promisifyAll(require('fs'))
wary = require('wary')
resin = require('resin-sdk')
imagefs = require('resin-image-fs')
init = require('../lib/init')

RASPBERRYPI = path.join(__dirname, 'images', 'raspberrypi.img')
EDISON = path.join(__dirname, 'images', 'edison')
RANDOM = path.join(__dirname, 'images', 'device.random')
UUIDS = {}

prepareDevice = (deviceType) ->
	applicationName = "DeviceInitE2E_#{deviceType.replace(/[- ]/, '_')}"
	console.log("Creating #{applicationName}")
	resin.models.application.has(applicationName).then (hasApplication) ->
		return if hasApplication
		resin.models.application.create(applicationName, deviceType)
	.then(resin.models.device.generateUUID)
	.then (uuid) ->
		resin.models.device.register(applicationName, uuid)
	.get('uuid')

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

wary.it 'should add a correct config.json to a raspberry pi',
	raspberrypi: RASPBERRYPI
, (images) ->

	options =
		network: 'ethernet'

	resin.models.device.get(UUIDS.raspberrypi).then (device) ->
		init.configure(images.raspberrypi, UUIDS.raspberrypi, options)
		.then(waitStream)
		.then _.partial imagefs.read,
			partition:
				primary: 4
				logical: 1
			path: '/config.json'
			image: images.raspberrypi
		.then(extract)
		.then(JSON.parse)
		.then (config) ->
			m.chai.expect(config.deviceType).to.equal('raspberry-pi')
			m.chai.expect(config.applicationId).to.equal(device.application[0].id)
			m.chai.expect(config.deviceId).to.equal(device.id)
			m.chai.expect(config.uuid).to.equal(UUIDS.raspberrypi)

wary.it 'should configure a raspberry pi with ethernet',
	raspberrypi: RASPBERRYPI
, (images) ->

	options =
		network: 'ethernet'

	init.configure(images.raspberrypi, UUIDS.raspberrypi, options)
	.then(waitStream)
	.then _.partial imagefs.read,
		partition:
			primary: 4
			logical: 1
		path: '/config.json'
		image: images.raspberrypi
	.then(extract)
	.then(JSON.parse)
	.then (config) ->
		networkConfig = config.files['network/network.config']
		m.chai.expect(networkConfig).to.not.include('wifi')
		m.chai.expect(networkConfig).to.include('ethernet')

wary.it 'should configure a raspberry pi with wifi',
	raspberrypi: RASPBERRYPI
, (images) ->

	options =
		network: 'wifi'
		wifiSsid: 'mywifissid'
		wifiKey: 'mywifikey'

	init.configure(images.raspberrypi, UUIDS.raspberrypi, options)
	.then(waitStream)
	.then _.partial imagefs.read,
		partition:
			primary: 4
			logical: 1
		path: '/config.json'
		image: images.raspberrypi
	.then(extract)
	.then(JSON.parse)
	.then (config) ->
		networkConfig = config.files['network/network.config']
		m.chai.expect(networkConfig).to.include('wifi')
		m.chai.expect(networkConfig).to.include("Name = #{options.wifiSsid}")
		m.chai.expect(networkConfig).to.include("Passphrase = #{options.wifiKey}")

wary.it 'should not trigger a stat event when configuring a rasperry pi',
	raspberrypi: RASPBERRYPI
, (images) ->

	options =
		network: 'ethernet'

	spy = m.sinon.spy()

	init.configure(images.raspberrypi, UUIDS.raspberrypi, options)
	.then (configuration) ->
		configuration.on('state', spy)
		return waitStream(configuration)
	.then ->
		m.chai.expect(spy).to.not.have.been.called

wary.it 'should initialize a raspberry pi image',
	raspberrypi: RASPBERRYPI
	random: RANDOM
, (images) ->

	options =
		network: 'ethernet'

	init.configure(images.raspberrypi, UUIDS.raspberrypi, options)
	.then(waitStream).then ->
		init.initialize(images.raspberrypi, 'raspberry-pi', drive: images.random)
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

	options =
		network: 'ethernet'

	spy = m.sinon.spy()

	init.configure(images.raspberrypi, UUIDS.raspberrypi, options)
	.then(waitStream).then ->
		init.initialize(images.raspberrypi, 'raspberry-pi', drive: images.random)
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
	options =
		network: 'ethernet'

	spy = m.sinon.spy()

	init.configure(images.raspberrypi, UUIDS.raspberrypi, options)
	.then(waitStream).then ->
		init.initialize(images.raspberrypi, 'raspberry-pi', drive: images.random)
	.then (initialization) ->
		initialization.on('burn', spy)
		return waitStream(initialization)
	.then ->
		m.chai.expect(spy).to.have.been.called
		args = spy.lastCall.args
		m.chai.expect(args[0].percentage).to.equal(100)
		m.chai.expect(args[0].eta).to.equal(0)

wary.it 'should accept an appUpdatePollInterval setting',
	raspberrypi: RASPBERRYPI
, (images) ->

	options =
		network: 'ethernet'
		appUpdatePollInterval: 2

	resin.models.device.get(UUIDS.raspberrypi).then (device) ->
		init.configure(images.raspberrypi, UUIDS.raspberrypi, options)
		.then(waitStream)
		.then _.partial imagefs.read,
			partition:
				primary: 4
				logical: 1
			path: '/config.json'
			image: images.raspberrypi
		.then(extract)
		.then(JSON.parse)
		.then (config) ->
			m.chai.expect(config.appUpdatePollInterval).to.equal('120000')

wary.it 'should default appUpdatePollInterval to 1 second',
	raspberrypi: RASPBERRYPI
, (images) ->

	options =
		network: 'ethernet'

	resin.models.device.get(UUIDS.raspberrypi).then (device) ->
		init.configure(images.raspberrypi, UUIDS.raspberrypi, options)
		.then(waitStream)
		.then _.partial imagefs.read,
			partition:
				primary: 4
				logical: 1
			path: '/config.json'
			image: images.raspberrypi
		.then(extract)
		.then(JSON.parse)
		.then (config) ->
			m.chai.expect(config.appUpdatePollInterval).to.equal(60000)

########################################################################
# Intel Edison
########################################################################

wary.it 'should add a correct config.json to an intel edison',
	edison: EDISON
, (images) ->

	options =
		network: 'wifi'
		wifiSsid: 'mywifissid'
		wifiKey: 'mywifikey'

	resin.models.device.get(UUIDS.edison).then (device) ->
		init.configure(images.edison, UUIDS.edison, options)
		.then(waitStream)
		.then _.partial imagefs.read,
			image: path.join(images.edison, 'config.img')
			path: '/config.json'
		.then(extract)
		.then(JSON.parse)
		.then (config) ->
			m.chai.expect(config.deviceType).to.equal('intel-edison')
			m.chai.expect(config.applicationId).to.equal(device.application[0].id)
			m.chai.expect(config.deviceId).to.equal(device.id)
			m.chai.expect(config.uuid).to.equal(UUIDS.edison)

			networkConfig = config.files['network/network.config']
			m.chai.expect(networkConfig).to.include('wifi')
			m.chai.expect(networkConfig).to.include("Name = #{options.wifiSsid}")
			m.chai.expect(networkConfig).to.include("Passphrase = #{options.wifiKey}")

wary.it 'should not trigger a stat event when configuring an intel edison',
	edison: EDISON
, (images) ->

	options =
		network: 'wifi'
		wifiSsid: 'mywifissid'
		wifiKey: 'mywifikey'

	spy = m.sinon.spy()

	init.configure(images.edison, UUIDS.edison, options)
	.then (configuration) ->
		configuration.on('state', spy)
		return waitStream(configuration)
	.then ->
		m.chai.expect(spy).to.not.have.been.called

wary.it 'should be able to initialize an intel edison with a script',
	edison: EDISON
, (images) ->

	options =
		network: 'wifi'
		wifiSsid: 'mywifissid'
		wifiKey: 'mywifikey'

	stdout = ''
	stderr = ''

	resin.models.device.get(UUIDS.edison).then (device) ->
		init.configure(images.edison, UUIDS.edison, options)
		.then(waitStream)
		.then ->
			init.initialize(images.edison, 'intel-edison', options)
		.then (initialization) ->

			initialization.on 'stdout', (data) ->
				stdout += data

			initialization.on 'stderr', (data) ->
				stderr += data

			return waitStream(initialization)
		.then ->
			m.chai.expect(stdout.replace(/[\n\r]/g, '')).to.equal('Hello World')
			m.chai.expect(stderr).to.equal('')

resin.auth.login
	email: process.env.RESIN_E2E_USERNAME
	password: process.env.RESIN_E2E_PASSWORD
.then ->
	console.log('Logged in')
	Promise.props
		raspberrypi: prepareDevice('Raspberry Pi')
		edison: prepareDevice('Intel Edison')
.then (uuids) ->
	UUIDS = uuids
	wary.run().catch (error) ->
		console.error(error, error.stack)
		process.exit(1)
