/*
Copyright 2017 Balena

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

/**
 * @module network
 */

import _ from 'lodash';
import path from 'path';
import * as imagefs from 'balena-image-fs';
import reconfix from 'reconfix';
import * as utils from './utils';
import type { DeviceTypeJsonWithConfiguration } from './device-type-json';

const CONNECTIONS_FOLDER = '/system-connections';

const getConfigPathDefinition = function <
	T extends DeviceTypeJsonWithConfiguration,
>(manifest: T, configPath: string) {
	const configPathDefinition = utils.convertFilePathDefinition(
		manifest.configuration.config,
	);

	// Config locations are assumed to be the same as config.json, except the path itself
	return {
		...configPathDefinition,
		path: configPath,
	};
};

const fileNotFoundError = (e: any): e is Error => e.code === 'ENOENT';

/**
 * @summary Configure network on an ResinOS 1.x image
 * @function
 * @public
 *
 * @description
 * This function injects network settings into the device.
 *
 * @param {String} image - path to image
 * @param {Object} config - a fully populated config object
 * @param {Object} [answers] - configuration options
 *
 * @returns {Promise<void>}
 */
export const configureOS1Network = (
	image: string,
	manifest: DeviceTypeJsonWithConfiguration,
	answers: Record<string, any>,
) =>
	prepareImageOS1NetworkConfig(image, manifest).then(function () {
		const schema = getOS1ConfigurationSchema(manifest, answers);

		if (manifest.configuration.config.image) {
			image = path.join(image, manifest.configuration.config.image);
		}

		return reconfix.writeConfiguration(schema, answers, image);
	});

/**
 * @summary Configure network on an ResinOS 2.x image
 * @function
 * @public
 *
 * @description
 * This function injects network settings into the device.
 *
 * @param {String} image - path to image
 * @param {Object} config - a fully populated config object
 * @param {Object} [answers] - configuration options
 *
 * @returns {Promise<void>}
 */
export const configureOS2Network = function (
	image: string,
	manifest: DeviceTypeJsonWithConfiguration,
	answers: Record<string, any>,
) {
	if (answers.network !== 'wifi') {
		// For ethernet, we don't need to do anything
		// For anything else, we don't know what to do
		return;
	}

	return prepareImageOS2WifiConfig(image, manifest).then(function () {
		const schema = getOS2WifiConfigurationSchema(manifest);
		if (manifest.configuration.config.image) {
			image = path.join(image, manifest.configuration.config.image);
		}
		return reconfix.writeConfiguration(schema, answers, image);
	});
};

const prepareImageOS1NetworkConfig = function (
	target: string,
	manifest: DeviceTypeJsonWithConfiguration,
) {
	// This is required because reconfix borks if the child files specified are
	// completely undefined when it tries to read (before writing) the config
	const configFilePath = utils.definitionForImage(
		target,
		utils.convertFilePathDefinition(manifest.configuration.config),
	);
	return imagefs.interact(
		configFilePath.image,
		configFilePath.partition,
		function (_fs) {
			return _fs.promises
				.readFile(configFilePath.path, {
					encoding: 'utf8',
				})
				.catch((e) => {
					if (fileNotFoundError(e)) {
						return '{}';
					}
					throw e;
				})
				.then(JSON.parse)
				.then(function (contents) {
					contents.files ??= {};
					contents.files['network/network.config'] ??= '';
					return _fs.promises.writeFile(
						configFilePath.path,
						JSON.stringify(contents),
					);
				});
		},
	);
};

/**
 * @summary Prepare the image to ensure the wifi reconfix schema is applyable
 * @function
 * @private
 *
 * @description
 * Ensure the image has a resin-wifi file ready to configure, based
 * on the existing resin-sample.ignore or resin-sample files, if present.
 *
 * @param {String} target - path to the target image
 * @param {Object} manifest - the device type manifest for the image
 *
 * @returns {Promise<void>}
 */
const prepareImageOS2WifiConfig = async function (
	target: string,
	manifest: DeviceTypeJsonWithConfiguration,
) {
	/*
	 * We need to ensure a template network settings file exists at resin-wifi. To do that:
	 * * if the `resin-wifi` file exists (previously configured image or downloaded from the UI) we're all good
	 * * if the `resin-sample` exists, it's copied to resin-sample.ignore
	 * * if the `resin-sample.ignore` exists, it's copied to `resin-wifi`
	 * * otherwise, the new file is created from a hardcoded template
	 */
	const inputDefinition = utils.definitionForImage(
		target,
		utils.convertFilePathDefinition(manifest.configuration.config),
	);

	const files = await imagefs.interact(
		inputDefinition.image,
		inputDefinition.partition,
		function (_fs) {
			return _fs.promises.readdir(CONNECTIONS_FOLDER);
		},
	);

	// The required file already exists
	if (_.includes(files, 'resin-wifi')) {
		return;
	}

	// Fresh image, new format, according to https://github.com/resin-os/meta-resin/pull/770/files
	if (_.includes(files, 'resin-sample.ignore')) {
		await imagefs.interact(
			inputDefinition.image,
			inputDefinition.partition,
			async function (_fs) {
				const contents = await _fs.promises.readFile(
					`${CONNECTIONS_FOLDER}/resin-sample.ignore`,
					{
						encoding: 'utf8',
					},
				);
				await _fs.promises.writeFile(
					`${CONNECTIONS_FOLDER}/resin-wifi`,
					contents,
				);
			},
		);
		return;
	}

	// Fresh image, old format
	if (_.includes(files, 'resin-sample')) {
		await imagefs.interact(
			inputDefinition.image,
			inputDefinition.partition,
			async function (_fs) {
				const contents = await _fs.promises.readFile(
					`${CONNECTIONS_FOLDER}/resin-sample`,
					{
						encoding: 'utf8',
					},
				);
				await _fs.promises.writeFile(
					`${CONNECTIONS_FOLDER}/resin-wifi`,
					contents,
				);
			},
		);
		return;
	}

	// In case there's no file at all (shouldn't happen normally, but the file might have been removed)
	await imagefs.interact(
		inputDefinition.image,
		inputDefinition.partition,
		async function (_fs) {
			await _fs.promises.writeFile(
				`${CONNECTIONS_FOLDER}/resin-wifi`,
				DEFAULT_CONNECTION_FILE,
			);
		},
	);
};

// Taken from https://goo.gl/kr1kCt
const DEFAULT_CONNECTION_FILE = `\
[connection]
id=resin-wifi
type=wifi

[wifi]
hidden=true
mode=infrastructure
ssid=My_Wifi_Ssid

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=super_secret_wifi_password

[ipv4]
method=auto

[ipv6]
addr-gen-mode=stable-privacy
method=auto\
`;

const getOS1ConfigurationSchema = function (
	manifest: DeviceTypeJsonWithConfiguration,
	answers: Record<string, any>,
) {
	// We could switch between schemas using `choice`, but right now that has different semantics, where
	// it wipes the whole of the rest of the file, whereas using a fixed schema does not. We should
	// handle this nicer when we move to rust reconfix.
	if (answers.network === 'wifi') {
		return getOS1WifiConfigurationSchema(manifest);
	} else {
		return getOS1EthernetConfiguration(manifest);
	}
};

const getOS1EthernetConfiguration = (
	manifest: DeviceTypeJsonWithConfiguration,
) => ({
	mapper: [
		{
			// This is a hack - if we don't specify any mapping for config.json, then
			// the next mapping wipes it completely, leaving only the `files` block.
			// `files` here is used just because it's safe - we're about to overwrite it.
			domain: [['config_json', 'files']],
			template: {
				files: {},
			},
		},
		{
			domain: [['network_config', 'service_home_ethernet']],
			template: {
				service_home_ethernet: {
					Type: 'ethernet',
					Nameservers: '8.8.8.8,8.8.4.4',
				},
			},
		},
	],

	files: {
		config_json: {
			type: 'json',
			location: getConfigPathDefinition(manifest, '/config.json'),
		},
		network_config: {
			type: 'ini',
			location: {
				parent: 'config_json',
				property: ['files', 'network/network.config'],
			},
		},
	},
});

const getOS1WifiConfigurationSchema = (
	manifest: DeviceTypeJsonWithConfiguration,
) => ({
	mapper: [
		{
			domain: [
				['config_json', 'wifiSsid'],
				['config_json', 'wifiKey'],
			],
			template: {
				wifiSsid: '{{wifiSsid}}',
				wifiKey: '{{wifiKey}}',
			},
		},
		{
			domain: [
				['network_config', 'service_home_ethernet'],
				['network_config', 'service_home_wifi'],
			],
			template: {
				service_home_ethernet: {
					Type: 'ethernet',
					Nameservers: '8.8.8.8,8.8.4.4',
				},
				service_home_wifi: {
					Hidden: true,
					Type: 'wifi',
					Name: '{{wifiSsid}}',
					Passphrase: '{{wifiKey}}',
					Nameservers: '8.8.8.8,8.8.4.4',
				},
			},
		},
	],

	files: {
		config_json: {
			type: 'json',
			location: getConfigPathDefinition(manifest, '/config.json'),
		},
		network_config: {
			type: 'ini',
			location: {
				parent: 'config_json',
				property: ['files', 'network/network.config'],
			},
		},
	},
});

const getOS2WifiConfigurationSchema = (
	manifest: DeviceTypeJsonWithConfiguration,
) => ({
	mapper: [
		{
			domain: [
				['system_connections', 'resin-wifi', 'wifi'],
				['system_connections', 'resin-wifi', 'wifi-security'],
			],
			template: {
				wifi: {
					ssid: '{{wifiSsid}}',
				},
				'wifi-security': {
					psk: '{{wifiKey}}',
				},
			},
		},
	],

	files: {
		system_connections: {
			fileset: true,
			type: 'ini',
			location: getConfigPathDefinition(manifest, CONNECTIONS_FOLDER),
		},
	},
});
