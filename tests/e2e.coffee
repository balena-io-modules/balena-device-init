m = require('mochainon')
_ = require('lodash')
os = require('os')
path = require('path')
Promise = require('bluebird')
fs = Promise.promisifyAll(require('fs'))
wary = require('wary')

settings = require('balena-settings-client')
sdk = require('balena-sdk')({
	apiUrl: settings.get('apiUrl')
})

imagefs = require('resin-image-fs')
init = require('../lib/init')

RASPBERRYPI_OS1 = path.join(__dirname, 'images', 'raspberrypi-os1.img')
RASPBERRYPI_OS2 = path.join(__dirname, 'images', 'raspberrypi-os2.img')
RASPBERRYPI_WITH_DEVICE_TYPE = path.join(__dirname, 'images', 'raspberrypi-with-device-type.img')
EDISON = path.join(__dirname, 'images', 'edison')
RANDOM = path.join(__dirname, 'images', 'device.random')
DEVICES = {}

prepareDevice = (deviceType) ->
	applicationName = "DeviceInitE2E_#{deviceType.replace(/[- ]/, '_')}"
	console.log("Creating #{applicationName}")
	sdk.models.application.has(applicationName).then (hasApplication) ->
		return if hasApplication
		sdk.models.application.create({
			name: applicationName
			deviceType
		})
	.then(sdk.models.device.generateUniqueKey)
	.then (uuid) ->
		sdk.models.device.register(applicationName, uuid)

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

getManifest = (slug) ->
	sdk.models.device.getManifestBySlug(slug)

########################################################################
# Raspberry Pi
########################################################################

wary.it 'should add a config.json correctly to a raspberry pi',
	raspberrypi: RASPBERRYPI_OS1
, (images) ->

	config =
		isTestConfig: true

	sdk.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		getManifest(device.device_type).then (manifest) ->
			init.configure(images.raspberrypi, manifest, config)
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

	sdk.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		# make sure the device-type.json file is read from the image
		init.getImageManifest(images.raspberrypi).then (manifest) ->
			init.configure(images.raspberrypi, manifest, config)
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

wary.it 'should add network correctly to a 1.x raspberry pi',
	raspberrypi: RASPBERRYPI_OS1
, (images) ->

	options =
		network: 'wifi'
		wifiSsid: 'testWifiSsid'
		wifiKey: 'testWifiKey'

	sdk.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		getManifest(device.device_type).then (manifest) ->
			init.configure(images.raspberrypi, manifest, {}, options)
	.then(waitStream)
	.then ->
		Promise.using imagefs.read(
			partition: 1
			path: '/config.json'
			image: images.raspberrypi
		), extract
	.then(JSON.parse)
	.then (config) ->
		m.chai.expect(config.wifiSsid).to.equal('testWifiSsid')
		m.chai.expect(config.wifiKey).to.equal('testWifiKey')

		m.chai.expect(config.files['network/network.config']).to.include('Name=testWifiSsid')
		m.chai.expect(config.files['network/network.config']).to.include('Passphrase=testWifiKey')

wary.it 'should add network correctly to a 2.x raspberry pi',
	raspberrypi: RASPBERRYPI_OS2
, (images) ->

	options =
		network: 'wifi'
		wifiSsid: 'testWifiSsid'
		wifiKey: 'testWifiKey'

	sdk.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		getManifest(device.device_type).then (manifest) ->
			init.configure(images.raspberrypi, manifest, {}, options)
	.then(waitStream)
	.then ->
		Promise.using imagefs.read(
			partition: 1
			path: '/system-connections/resin-wifi'
			image: images.raspberrypi
		), extract
	.then (wifiConfig) ->
		m.chai.expect(wifiConfig).to.include('ssid=testWifiSsid')
		m.chai.expect(wifiConfig).to.include('psk=testWifiKey')

wary.it 'should not trigger a state event when configuring a raspberry pi',
	raspberrypi: RASPBERRYPI_OS1
, (images) ->
	spy = m.sinon.spy()

	sdk.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		getManifest(device.device_type).then (manifest) ->
			init.configure(images.raspberrypi, manifest, {})
	.then (configuration) ->
		configuration.on('state', spy)
		return waitStream(configuration)
	.then ->
		m.chai.expect(spy).to.not.have.been.called

wary.it 'should initialize a raspberry pi image',
	raspberrypi: RASPBERRYPI_OS1
	random: RANDOM
, (images) ->

	drive =
		raw: images.random
		size: fs.statSync(images.random).size

	sdk.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		getManifest(device.device_type).then (manifest) ->
			init.configure(images.raspberrypi, manifest, {})
			.then(waitStream).then ->
				init.initialize(images.raspberrypi, manifest, { drive })
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

	sdk.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		# make sure the device-type.json file is read from the image
		init.getImageManifest(images.raspberrypi).then (manifest) ->
			init.configure(images.raspberrypi, manifest, {})
			.then(waitStream).then ->
				init.initialize(images.raspberrypi, manifest, { drive })
	.then(waitStream).then ->
		Promise.props
			raspberrypi: fs.readFileAsync(images.raspberrypi)
			random: fs.readFileAsync(images.random)
		.then (results) ->
			m.chai.expect(results.random).to.deep.equal(results.raspberrypi)

wary.it 'should emit state events when initializing a raspberry pi',
	raspberrypi: RASPBERRYPI_OS1
	random: RANDOM
, (images) ->

	drive =
		raw: images.random
		size: fs.statSync(images.random).size

	spy = m.sinon.spy()

	sdk.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		getManifest(device.device_type).then (manifest) ->
			init.configure(images.raspberrypi, manifest, {})
			.then(waitStream).then ->
				init.initialize(images.raspberrypi, manifest, { drive })
	.then (initialization) ->
		initialization.on('state', spy)
		return waitStream(initialization)
	.then ->
		m.chai.expect(spy).to.have.been.calledOnce
		args = spy.firstCall.args
		m.chai.expect(args[0].operation.command).to.equal('burn')
		m.chai.expect(args[0].percentage).to.equal(100)

wary.it 'should emit burn events when initializing a raspberry pi',
	raspberrypi: RASPBERRYPI_OS1
	random: RANDOM
, (images) ->

	drive =
		raw: images.random
		size: fs.statSync(images.random).size

	spy = m.sinon.spy()

	sdk.models.device.get(DEVICES.raspberrypi.id).then (device) ->
		getManifest(device.device_type).then (manifest) ->
			init.configure(images.raspberrypi, manifest, {})
			.then(waitStream).then ->
				init.initialize(images.raspberrypi, manifest, { drive })
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

	sdk.models.device.get(DEVICES.edison.id).then (device) ->
		getManifest(device.device_type).then (manifest) ->
			init.configure(images.edison, manifest, config)
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

	sdk.models.device.get(DEVICES.edison.id).then (device) ->
		getManifest(device.device_type).then (manifest) ->
			init.configure(images.edison, manifest, {})
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

	sdk.models.device.get(DEVICES.edison.id).then (device) ->
		getManifest(device.device_type).then (manifest) ->
			init.configure(images.edison, manifest, {})
			.then(waitStream).then ->
				init.initialize(images.edison, manifest, {})
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
	sdk.auth.login
		email: process.env.TEST_EMAIL
		password: process.env.TEST_PASSWORD
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
