const m = require('mochainon');
const _ = require('lodash');
const os = require('os');
const path = require('path');
const Promise = require('bluebird');
const fs = Promise.promisifyAll(require('fs'));
const wary = require('wary');

const settings = require('balena-settings-client');
const etcherSdk = require('etcher-sdk');
const sdk = require('balena-sdk')({
	apiUrl: settings.get('apiUrl')
});

const imagefs = require('balena-image-fs');
const init = require('../lib/init');

const RASPBERRYPI_OS1 = path.join(__dirname, 'images', 'raspberrypi-os1.img');
const RASPBERRYPI_OS2 = path.join(__dirname, 'images', 'raspberrypi-os2.img');
const RASPBERRYPI_WITH_DEVICE_TYPE = path.join(__dirname, 'images', 'raspberrypi-with-device-type.img');
const EDISON = path.join(__dirname, 'images', 'edison');
const RANDOM = path.join(__dirname, 'images', 'device.random');
let DEVICES = {};

const prepareDevice = function(deviceType) {
	const applicationName = `DeviceInitE2E_${deviceType.replace(/[- ]/, '_')}`;
	console.log(`Creating ${applicationName}`);
	return sdk.models.application.has(applicationName).then(function(hasApplication) {
		if (hasApplication) { return; }
		return sdk.models.application.create({
			name: applicationName,
			deviceType
		});}).then(sdk.models.device.generateUniqueKey)
	.then(uuid => sdk.models.device.register(applicationName, uuid));
};

const extract = stream => new Promise(function(resolve, reject) {
	let result = '';
	stream.on('error', reject);
	stream.on('data', chunk => result += chunk);
	return stream.on('end', () => resolve(result));
});

const waitStream = stream => new Promise(function(resolve, reject) {
	stream.on('error', reject);
	stream.on('close', resolve);
	return stream.on('end', resolve);
});

const getManifest = slug => sdk.models.device.getManifestBySlug(slug);

//#######################################################################
// Raspberry Pi
//#######################################################################
wary.it('should add a config.json correctly to a raspberry pi',
	{raspberrypi: RASPBERRYPI_OS1}
, function(images) {

	const config =
		{isTestConfig: true};

	return sdk.models.device.get(DEVICES.raspberrypi.id).then(device => getManifest(device.device_type).then(manifest => init.configure(images.raspberrypi, manifest, config))).then(waitStream)
	.then(() => imagefs.interact(
		images.raspberrypi,
		1,
		function(_fs) { 
			const readFileAsync = Promise.promisify(_fs.readFile);
			return readFileAsync('/config.json', { encoding: 'utf8' });
	})).then(JSON.parse)
	.then(config => m.chai.expect(config.isTestConfig).to.equal(true));
});

wary.it('should add a correct config.json to a raspberry pi containing a device-type.json',
	{raspberrypi: RASPBERRYPI_WITH_DEVICE_TYPE}
, function(images) {

	const config =
		{isTestConfig: true};

	return sdk.models.device.get(DEVICES.raspberrypi.id).then(device => // make sure the device-type.json file is read from the image
	init.getImageManifest(images.raspberrypi).then(manifest => init.configure(images.raspberrypi, manifest, config))).then(waitStream)
	.then(() => imagefs.interact(
		images.raspberrypi,
		5,
		function(_fs) { 
			const readFileAsync = Promise.promisify(_fs.readFile);
			return readFileAsync('/config.json', { encoding: 'utf8' });
	})).then(JSON.parse)
	.then(config => m.chai.expect(config.isTestConfig).to.equal(true));
});

wary.it('should add network correctly to a 1.x raspberry pi',
	{raspberrypi: RASPBERRYPI_OS1}
, function(images) {

	const options = {
		network: 'wifi',
		wifiSsid: 'testWifiSsid',
		wifiKey: 'testWifiKey'
	};

	return sdk.models.device.get(DEVICES.raspberrypi.id).then(device => getManifest(device.device_type).then(manifest => init.configure(images.raspberrypi, manifest, {}, options))).then(waitStream)
	.then(() => imagefs.interact(
		images.raspberrypi,
		1,
		function(fs) { 
			const readFileAsync = Promise.promisify(fs.readFile);
			return readFileAsync('/config.json', { encoding: 'utf8' });
	})).then(JSON.parse)
	.then(function(config) {
		m.chai.expect(config.wifiSsid).to.equal('testWifiSsid');
		m.chai.expect(config.wifiKey).to.equal('testWifiKey');

		m.chai.expect(config.files['network/network.config']).to.include('Name=testWifiSsid');
		return m.chai.expect(config.files['network/network.config']).to.include('Passphrase=testWifiKey');
	});
});

wary.it('should add network correctly to a 2.x raspberry pi',
	{raspberrypi: RASPBERRYPI_OS2}
, function(images) {

	const options = {
		network: 'wifi',
		wifiSsid: 'testWifiSsid',
		wifiKey: 'testWifiKey'
	};

	return sdk.models.device.get(DEVICES.raspberrypi.id).then(device => getManifest(device.device_type).then(manifest => init.configure(images.raspberrypi, manifest, {}, options))).then(waitStream)
	.then(() => imagefs.interact(
		images.raspberrypi,
		1,
		function(fs) { 
			const readFileAsync = Promise.promisify(fs.readFile);
			return readFileAsync('/system-connections/resin-wifi', { encoding: 'utf8' });
	})).then(function(wifiConfig) {
		m.chai.expect(wifiConfig).to.include('ssid=testWifiSsid');
		return m.chai.expect(wifiConfig).to.include('psk=testWifiKey');
	});
});

wary.it('should not trigger a state event when configuring a raspberry pi',
	{raspberrypi: RASPBERRYPI_OS1}
, function(images) {
	const spy = m.sinon.spy();

	return sdk.models.device.get(DEVICES.raspberrypi.id).then(device => getManifest(device.device_type).then(manifest => init.configure(images.raspberrypi, manifest, {}))).then(function(configuration) {
		configuration.on('state', spy);
		return waitStream(configuration);}).then(() => m.chai.expect(spy).to.not.have.been.called);
});

const mockBlockDeviceFromFile = function(path) {
	const drive = {
		raw: path,
		device: path,
		devicePath: path,
		displayName: path,
		icon: 'some icon',
		isSystem: false,
		description: 'some description',
		mountpoints: [],
		size: fs.statSync(path).size,
		isReadOnly: false,
		busType: 'UNKNOWN',
		error: null,
		blockSize: 512,
		busVersion: null,
		enumerator: 'fake',
		isCard: null,
		isRemovable: true,
		isSCSI: false,
		isUAS: null,
		isUSB: true,
		isVirtual: false,
		logicalBlockSize: 512,
		partitionTableType: null,
	};
	const device = new etcherSdk.sourceDestination.BlockDevice({
		drive,
		unmountOnSuccess: false,
		write: true,
		direct: false,
	});

	device._open = () => etcherSdk.sourceDestination.File.prototype._open.call(device);
	device._close = () => etcherSdk.sourceDestination.File.prototype._close.call(device);

	return device;
};

wary.it('should initialize a raspberry pi image', {
	raspberrypi: RASPBERRYPI_OS1,
	random: RANDOM
}
, function(images) {

	const drive = mockBlockDeviceFromFile(images.random);

	return sdk.models.device.get(DEVICES.raspberrypi.id).then(device => getManifest(device.device_type).then(manifest => init.configure(images.raspberrypi, manifest, {})
	.then(waitStream).then(() => init.initialize(images.raspberrypi, manifest, { drive })))).then(waitStream).then(() => Promise.props({
		raspberrypi: fs.readFileAsync(images.raspberrypi),
		random: fs.readFileAsync(images.random)}).then(results => m.chai.expect(results.random).to.deep.equal(results.raspberrypi)));
});

wary.it('should initialize a raspberry pi image containing a device type', {
	raspberrypi: RASPBERRYPI_WITH_DEVICE_TYPE,
	random: RANDOM
}
, function(images) {

	const drive = mockBlockDeviceFromFile(images.random);

	return sdk.models.device.get(DEVICES.raspberrypi.id).then(device => // make sure the device-type.json file is read from the image
	init.getImageManifest(images.raspberrypi).then(manifest => init.configure(images.raspberrypi, manifest, {})
	.then(waitStream).then(() => init.initialize(images.raspberrypi, manifest, { drive })))).then(waitStream).then(() => Promise.props({
		raspberrypi: fs.readFileAsync(images.raspberrypi),
		random: fs.readFileAsync(images.random)}).then(results => m.chai.expect(results.random).to.deep.equal(results.raspberrypi)));
});

wary.it('should emit state events when initializing a raspberry pi', {
	raspberrypi: RASPBERRYPI_OS1,
	random: RANDOM
}
, function(images) {

	const drive = mockBlockDeviceFromFile(images.random);

	const spy = m.sinon.spy();

	return sdk.models.device.get(DEVICES.raspberrypi.id).then(device => getManifest(device.device_type).then(manifest => init.configure(images.raspberrypi, manifest, {})
	.then(waitStream).then(() => init.initialize(images.raspberrypi, manifest, { drive })))).then(function(initialization) {
		initialization.on('state', spy);
		return waitStream(initialization);}).then(function() {
		m.chai.expect(spy).to.have.been.calledOnce;
		const {
			args
		} = spy.firstCall;
		m.chai.expect(args[0].operation.command).to.equal('burn');
		return m.chai.expect(args[0].percentage).to.equal(100);
	});
});

wary.it('should emit burn events when initializing a raspberry pi', {
	raspberrypi: RASPBERRYPI_OS1,
	random: RANDOM
}
, function(images) {

	const drive = mockBlockDeviceFromFile(images.random);

	const spy = m.sinon.spy();

	return sdk.models.device.get(DEVICES.raspberrypi.id).then(device => getManifest(device.device_type).then(manifest => init.configure(images.raspberrypi, manifest, {})
	.then(waitStream).then(() => init.initialize(images.raspberrypi, manifest, { drive })))).then(function(initialization) {
		initialization.on('burn', spy);
		return waitStream(initialization);}).then(function() {
		m.chai.expect(spy).to.have.been.called;
		const {
			args
		} = spy.lastCall;
		m.chai.expect(args[0].percentage).to.equal(100);
		return m.chai.expect(args[0].eta).to.equal(0);
	});
});

//#######################################################################
// Intel Edison
//#######################################################################

wary.it('should add a config.json to an intel edison',
	{edison: EDISON}
, function(images) {

	const config =
		{isTestConfig: true};

	return sdk.models.device.get(DEVICES.edison.id).then(device => getManifest(device.device_type).then(manifest => init.configure(images.edison, manifest, config))).then(waitStream)
	.then(() => imagefs.interact(
		path.join(images.edison, 'resin-image-edison.hddimg'),
		undefined,
		function(fs) { 
			const readFileAsync = Promise.promisify(fs.readFile);
			return readFileAsync('/config.json', { encoding: 'utf8' });
	})).then(JSON.parse)
	.then(config => m.chai.expect(config.isTestConfig).to.equal(true));
});

wary.it('should not trigger a state event when configuring an intel edison',
	{edison: EDISON}
, function(images) {

	const spy = m.sinon.spy();

	return sdk.models.device.get(DEVICES.edison.id).then(device => getManifest(device.device_type).then(manifest => init.configure(images.edison, manifest, {}))).then(function(configuration) {
		configuration.on('state', spy);
		return waitStream(configuration);}).then(() => m.chai.expect(spy).to.not.have.been.called);
});

wary.it('should be able to initialize an intel edison with a script',
	{edison: EDISON}
, function(images) {

	let stdout = '';
	let stderr = '';

	return sdk.models.device.get(DEVICES.edison.id).then(device => getManifest(device.device_type).then(manifest => init.configure(images.edison, manifest, {})
	.then(waitStream).then(() => init.initialize(images.edison, manifest, {})))).then(function(initialization) {

		initialization.on('stdout', data => stdout += data);

		initialization.on('stderr', data => stderr += data);

		return waitStream(initialization);}).then(function() {
		m.chai.expect(stdout.replace(/[\n\r]/g, '')).to.equal('Hello World');
		return m.chai.expect(stderr).to.equal('');
	});
});

Promise.try(() => require('dotenv').config({silent: true})).then(() => sdk.auth.login({
	email: process.env.TEST_EMAIL,
	password: process.env.TEST_PASSWORD
})).then(function() {
	console.log('Logged in');
	return Promise.props({
		raspberrypi: prepareDevice('raspberry-pi'),
		edison: prepareDevice('intel-edison')
	});}).then(function(devices) {
	DEVICES = devices;
	return wary.run();}).catch(function(error) {
	console.error(error, error.stack);
	return process.exit(1);
});
