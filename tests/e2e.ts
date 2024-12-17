import { expect } from 'chai';
import * as sinon from 'sinon';
import * as fsPromise from 'fs/promises';
import * as fs from 'fs';
import path from 'path';
import * as util from 'node:util';
import wary from 'wary';

import * as settings from 'balena-settings-client';
import * as etcherSdk from 'etcher-sdk';
import getSdk from 'balena-sdk';
const sdk = getSdk({
	apiUrl: settings.get('apiUrl'),
});

import * as imagefs from 'balena-image-fs';
import * as init from '../src/init';

const RASPBERRYPI_OS1 = path.join(__dirname, 'images', 'raspberrypi-os1.img');
const RASPBERRYPI_OS2 = path.join(__dirname, 'images', 'raspberrypi-os2.img');
const RASPBERRYPI_WITH_DEVICE_TYPE = path.join(
	__dirname,
	'images',
	'raspberrypi-with-device-type.img',
);
const EDISON = path.join(__dirname, 'images', 'edison');
const RANDOM = path.join(__dirname, 'images', 'device.random');
let DEVICES: Record<string, Awaited<ReturnType<typeof prepareDevice>>> = {};

const prepareDevice = function (deviceType: string) {
	const applicationName = `DeviceInitE2E_${deviceType.replace(/[- ]/, '_')}`;
	console.log(`Creating ${applicationName}`);
	return sdk.models.application
		.has(applicationName)
		.then(function (hasApplication) {
			if (hasApplication) {
				return;
			}
			return sdk.models.application.create({
				name: applicationName,
				deviceType,
			});
		})
		.then(sdk.models.device.generateUniqueKey)
		.then((uuid) => sdk.models.device.register(applicationName, uuid));
};

const waitStream = (stream: init.InitializeEmitter) =>
	new Promise(function (resolve, reject) {
		stream.on('error', reject);
		stream.on('close', resolve);
		stream.on('end', resolve);
	});

const getManifest = (slug: string) => sdk.models.device.getManifestBySlug(slug);

// #######################################################################
// Raspberry Pi
// #######################################################################
wary.it(
	'should add a config.json correctly to a raspberry pi',
	{ raspberrypi: RASPBERRYPI_OS1 },
	function (images) {
		const config = { isTestConfig: true };

		return sdk.models.device
			.get(DEVICES.raspberrypi.id)
			.then((device) =>
				getManifest(device.device_type).then((manifest) =>
					init.configure(images.raspberrypi, manifest, config),
				),
			)
			.then(waitStream)
			.then(() =>
				imagefs.interact(images.raspberrypi, 1, function (_fs) {
					const readFileAsync = util.promisify(_fs.readFile);
					return readFileAsync('/config.json', { encoding: 'utf8' });
				}),
			)
			.then(JSON.parse)
			.then((parsedConfig) => expect(parsedConfig.isTestConfig).to.equal(true));
	},
);

wary.it(
	'should add a correct config.json to a raspberry pi containing a device-type.json',
	{ raspberrypi: RASPBERRYPI_WITH_DEVICE_TYPE },
	function (images) {
		const config = { isTestConfig: true };

		return sdk.models.device
			.get(DEVICES.raspberrypi.id)
			.then(() =>
				// make sure the device-type.json file is read from the image
				init
					.getImageManifest(images.raspberrypi)
					.then((manifest) =>
						init.configure(images.raspberrypi, manifest!, config),
					),
			)
			.then(waitStream)
			.then(() =>
				imagefs.interact(images.raspberrypi, 5, function (_fs) {
					const readFileAsync = util.promisify(_fs.readFile);
					return readFileAsync('/config.json', { encoding: 'utf8' });
				}),
			)
			.then(JSON.parse)
			.then((parsedConfig) => expect(parsedConfig.isTestConfig).to.equal(true));
	},
);

wary.it(
	'should add network correctly to a 1.x raspberry pi',
	{ raspberrypi: RASPBERRYPI_OS1 },
	function (images) {
		const options = {
			network: 'wifi',
			wifiSsid: 'testWifiSsid',
			wifiKey: 'testWifiKey',
		};

		return sdk.models.device
			.get(DEVICES.raspberrypi.id)
			.then((device) =>
				getManifest(device.device_type).then((manifest) =>
					init.configure(images.raspberrypi, manifest, {}, options),
				),
			)
			.then(waitStream)
			.then(() =>
				imagefs.interact(images.raspberrypi, 1, function (_fs) {
					const readFileAsync = util.promisify(_fs.readFile);
					return readFileAsync('/config.json', { encoding: 'utf8' });
				}),
			)
			.then(JSON.parse)
			.then(function (config) {
				expect(config.wifiSsid).to.equal('testWifiSsid');
				expect(config.wifiKey).to.equal('testWifiKey');

				expect(config.files['network/network.config']).to.include(
					'Name=testWifiSsid',
				);
				return expect(config.files['network/network.config']).to.include(
					'Passphrase=testWifiKey',
				);
			});
	},
);

wary.it(
	'should add network correctly to a 2.x raspberry pi',
	{ raspberrypi: RASPBERRYPI_OS2 },
	function (images) {
		const options = {
			network: 'wifi',
			wifiSsid: 'testWifiSsid',
			wifiKey: 'testWifiKey',
		};

		return sdk.models.device
			.get(DEVICES.raspberrypi.id)
			.then((device) =>
				getManifest(device.device_type).then((manifest) =>
					init.configure(images.raspberrypi, manifest, {}, options),
				),
			)
			.then(waitStream)
			.then(() =>
				imagefs.interact(images.raspberrypi, 1, function (_fs) {
					const readFileAsync = util.promisify(_fs.readFile);
					return readFileAsync('/system-connections/resin-wifi', {
						encoding: 'utf8',
					});
				}),
			)
			.then(function (wifiConfig) {
				expect(wifiConfig).to.include('ssid=testWifiSsid');
				return expect(wifiConfig).to.include('psk=testWifiKey');
			});
	},
);

wary.it(
	'should not trigger a state event when configuring a raspberry pi',
	{ raspberrypi: RASPBERRYPI_OS1 },
	function (images) {
		const spy = sinon.spy();

		return sdk.models.device
			.get(DEVICES.raspberrypi.id)
			.then((device) =>
				getManifest(device.device_type).then((manifest) =>
					init.configure(images.raspberrypi, manifest, {}),
				),
			)
			.then(function (configuration) {
				configuration.on('state', spy);
				return waitStream(configuration);
			})
			.then(() => expect(spy).to.have.property('called', false));
	},
);

const mockBlockDeviceFromFile = function (filepath: string) {
	const drive = {
		raw: filepath,
		device: filepath,
		devicePath: filepath,
		displayName: filepath,
		icon: 'some icon',
		isSystem: false,
		description: 'some description',
		mountpoints: [],
		size: fs.statSync(filepath).size,
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

	// @ts-expect-error mock this props for testing
	device._open = () =>
		// @ts-expect-error mock this props for testing
		etcherSdk.sourceDestination.File.prototype._open.call(device);
	// @ts-expect-error mock this props for testing
	device._close = () =>
		// @ts-expect-error mock this props for testing
		etcherSdk.sourceDestination.File.prototype._close.call(device);

	return device;
};

wary.it(
	'should initialize a raspberry pi image',
	{
		raspberrypi: RASPBERRYPI_OS1,
		random: RANDOM,
	},
	function (images) {
		const drive = mockBlockDeviceFromFile(images.random);

		return sdk.models.device
			.get(DEVICES.raspberrypi.id)
			.then((device) =>
				getManifest(device.device_type).then((manifest) =>
					init
						.configure(images.raspberrypi, manifest, {})
						.then(waitStream)
						.then(() =>
							init.initialize(images.raspberrypi, manifest, { drive }),
						),
				),
			)
			.then(waitStream)
			.then(async () => {
				const [raspberrypi, random] = await Promise.all([
					fsPromise.readFile(images.raspberrypi),
					fsPromise.readFile(images.random),
				]);
				expect(random).to.deep.equal(raspberrypi);
			});
	},
);

wary.it(
	'should initialize a raspberry pi image containing a device type',
	{
		raspberrypi: RASPBERRYPI_WITH_DEVICE_TYPE,
		random: RANDOM,
	},
	function (images) {
		const drive = mockBlockDeviceFromFile(images.random);

		return sdk.models.device
			.get(DEVICES.raspberrypi.id)
			.then(() =>
				// make sure the device-type.json file is read from the image
				init.getImageManifest(images.raspberrypi).then((manifest) =>
					init
						.configure(images.raspberrypi, manifest!, {})
						.then(waitStream)
						.then(() =>
							init.initialize(images.raspberrypi, manifest!, { drive }),
						),
				),
			)
			.then(waitStream)
			.then(async () => {
				const [raspberrypi, random] = await Promise.all([
					fsPromise.readFile(images.raspberrypi),
					fsPromise.readFile(images.random),
				]);
				expect(random).to.deep.equal(raspberrypi);
			});
	},
);

wary.it(
	'should emit state events when initializing a raspberry pi',
	{
		raspberrypi: RASPBERRYPI_OS1,
		random: RANDOM,
	},
	function (images) {
		const drive = mockBlockDeviceFromFile(images.random);

		const spy = sinon.spy();

		return sdk.models.device
			.get(DEVICES.raspberrypi.id)
			.then((device) =>
				getManifest(device.device_type).then((manifest) =>
					init
						.configure(images.raspberrypi, manifest, {})
						.then(waitStream)
						.then(() =>
							init.initialize(images.raspberrypi, manifest, { drive }),
						),
				),
			)
			.then(function (initialization) {
				initialization.on('state', spy);
				return waitStream(initialization);
			})
			.then(function () {
				expect(spy).to.have.property('calledOnce', true);
				const { args } = spy.firstCall;
				expect(args[0].operation.command).to.equal('burn');
				return expect(args[0].percentage).to.equal(100);
			});
	},
);

wary.it(
	'should emit burn events when initializing a raspberry pi',
	{
		raspberrypi: RASPBERRYPI_OS1,
		random: RANDOM,
	},
	function (images) {
		const drive = mockBlockDeviceFromFile(images.random);

		const spy = sinon.spy();

		return sdk.models.device
			.get(DEVICES.raspberrypi.id)
			.then((device) =>
				getManifest(device.device_type).then((manifest) =>
					init
						.configure(images.raspberrypi, manifest, {})
						.then(waitStream)
						.then(() =>
							init.initialize(images.raspberrypi, manifest, { drive }),
						),
				),
			)
			.then(function (initialization) {
				initialization.on('burn', spy);
				return waitStream(initialization);
			})
			.then(function () {
				expect(spy).to.have.property('called', true);
				const { args } = spy.lastCall;
				expect(args[0].percentage).to.equal(100);
				return expect(args[0].eta).to.equal(0);
			});
	},
);

// #######################################################################
// Intel Edison
// #######################################################################

wary.it(
	'should add a config.json to an intel edison',
	{ edison: EDISON },
	function (images) {
		const config = { isTestConfig: true };

		return sdk.models.device
			.get(DEVICES.edison.id)
			.then((device) =>
				getManifest(device.device_type).then((manifest) =>
					init.configure(images.edison, manifest, config),
				),
			)
			.then(waitStream)
			.then(() =>
				imagefs.interact(
					path.join(images.edison, 'resin-image-edison.hddimg'),
					undefined,
					function (_fs) {
						const readFileAsync = util.promisify(_fs.readFile);
						return readFileAsync('/config.json', { encoding: 'utf8' });
					},
				),
			)
			.then(JSON.parse)
			.then((parsedConfig) => expect(parsedConfig.isTestConfig).to.equal(true));
	},
);

wary.it(
	'should not trigger a state event when configuring an intel edison',
	{ edison: EDISON },
	function (images) {
		const spy = sinon.spy();

		return sdk.models.device
			.get(DEVICES.edison.id)
			.then((device) =>
				getManifest(device.device_type).then((manifest) =>
					init.configure(images.edison, manifest, {}),
				),
			)
			.then(function (configuration) {
				configuration.on('state', spy);
				return waitStream(configuration);
			})
			.then(() => expect(spy).to.have.property('called', false));
	},
);

wary.it(
	'should be able to initialize an intel edison with a script',
	{ edison: EDISON },
	function (images) {
		let stdout = '';
		let stderr = '';

		return sdk.models.device
			.get(DEVICES.edison.id)
			.then((device) =>
				getManifest(device.device_type).then((manifest) =>
					init
						.configure(images.edison, manifest, {})
						.then(waitStream)
						.then(() => init.initialize(images.edison, manifest, {})),
				),
			)
			.then(function (initialization) {
				initialization.on('stdout', (data) => (stdout += data));

				initialization.on('stderr', (data) => (stderr += data));

				return waitStream(initialization);
			})
			.then(function () {
				expect(stdout.replace(/[\n\r]/g, '')).to.equal('Hello World');
				return expect(stderr).to.equal('');
			});
	},
);

void (async () => {
	try {
		(await import('dotenv')).config({ silent: true });
		await sdk.auth.login({
			email: process.env.TEST_EMAIL!,
			password: process.env.TEST_PASSWORD!,
		});
		console.log('Logged in');
		const [raspberrypi, edison] = await Promise.all([
			prepareDevice('raspberry-pi'),
			prepareDevice('intel-edison'),
		]);
		DEVICES = { raspberrypi, edison };
		await wary.run();
	} catch (error) {
		console.error(error, error.stack);
		return process.exit(1);
	}
})();
