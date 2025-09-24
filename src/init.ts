/*
Copyright 2016 Balena

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
 * @module init
 */

import _ from 'lodash';
import * as operations from 'resin-device-operations';
import * as balenaSemver from 'balena-semver';
import * as utils from './utils';
import * as network from './network';
import type { DeviceTypeJson } from './device-type-json';

export { getImageManifest, getImageOsVersion } from './utils';

export interface OperationState {
	operation:
		| CopyOperation
		| ReplaceOperation
		| RunScriptOperation
		| BurnOperation;
	percentage: number;
}

export interface Operation {
	command: string;
}

export interface CopyOperation extends Operation {
	command: 'copy';
	from: { path: string };
	to: { path: string };
}

export interface ReplaceOperation extends Operation {
	command: 'replace';
	copy: string;
	replace: string;
	file: {
		path: string;
	};
}

export interface RunScriptOperation extends Operation {
	command: 'run-script';
	script: string;
	arguments?: string[];
}

export interface BurnOperation extends Operation {
	command: 'burn';
	image?: string;
}

export interface BurnProgress {
	type: 'write' | 'check';
	percentage: number;
	transferred: number;
	length: number;
	remaining: number;
	eta: number;
	runtime: number;
	delta: number;
	speed: number;
}

export interface InitializeEmitter {
	on(event: 'stdout' | 'stderr', callback: (msg: string) => void): void;
	on(event: 'state', callback: (state: OperationState) => void): void;
	on(event: 'burn', callback: (state: BurnProgress) => void): void;
	on(event: 'end', callback: () => void): void;
	on(event: 'close', callback: () => void): void;
	on(event: 'error', callback: (error: Error) => void): void;
}

/**
 * @summary Configure an image with an application
 * @function
 * @public
 *
 * @description
 * This function injects `config.json` and network settings into the image.
 *
 * @param {String} image - path to image
 * @param {Object} manifest - device type manifest
 * @param {Object} config - a fully populated config object
 * @param {Object} [options] - configuration options
 *
 * @returns {Promise<EventEmitter>} configuration event emitter
 *
 * @example
 * init.configure('my/rpi.img', manifest, config).then (configuration) ->
 *
 * 	configuration.on('stdout', process.stdout.write)
 * 	configuration.on('stderr', process.stderr.write)
 *
 * 	configuration.on 'state', (state) ->
 * 		console.log(state.operation.command)
 * 		console.log(state.percentage)
 *
 * 	configuration.on 'error', (error) ->
 * 		throw error
 *
 * 	configuration.on 'end', ->
 * 		console.log('Configuration finished')
 */
export async function configure(
	image: string,
	manifest: DeviceTypeJson,
	config: Record<string, any>,
	options: object = {},
): Promise<InitializeEmitter> {
	// We only know how to find /etc/os-release on specific types of OS image. In future, we'd like to be able
	// to do this for any image, but for now we'll just treat others as unknowable (which means below we'll
	// configure the network to work for _either_ OS version.
	let osVersion: string | null = null;
	if (
		manifest.yocto?.image === 'resin-image' &&
		_.includes(['resinos-img', 'resin-sdcard'], manifest.yocto?.fstype)
	) {
		osVersion = await utils.getImageOsVersion(image, manifest);
	}

	if (manifest.configuration == null) {
		throw new Error(
			'Unsupported device type: Manifest missing configuration parameters',
		);
	}

	const { configuration } = manifest;
	// TS should be able to detect this on its own and we shoulnd't have to do it manually
	const manifestWithConfiguration = manifest as typeof manifest & {
		configuration: object;
	};

	const majorVersion = balenaSemver.major(osVersion);

	const configPathDefinition = utils.convertFilePathDefinition(
		configuration.config,
	);
	await utils.writeConfigJSON(image, config, configPathDefinition);

	// Configure for OS2 if it is OS2, or if we're just not sure
	if (majorVersion == null || majorVersion === 2) {
		await network.configureOS2Network(
			image,
			manifestWithConfiguration,
			options,
		);
	}

	// Configure for OS1 if it is OS1, or if we're just not sure
	if (majorVersion == null || majorVersion === 1) {
		await network.configureOS1Network(
			image,
			manifestWithConfiguration,
			options,
		);
	}

	return operations.execute(
		image,
		// @ts-expect-error TODO: Check whether this should be `manifest.initialization.operations` ?
		configuration.operations,
		options,
	);
}

/**
 * @summary Initialize an image
 * @function
 * @public
 *
 * @param {String} image - path to image
 * @param {Object} manifest - device type manifest
 * @param {Object} options - configuration options
 *
 * @returns {Promise<EventEmitter>} initialization event emitter
 *
 * @example
 * init.initialize('my/rpi.img', manifest, network: 'ethernet').then (configuration) ->
 *
 * 	configuration.on('stdout', process.stdout.write)
 * 	configuration.on('stderr', process.stderr.write)
 *
 * 	configuration.on 'state', (state) ->
 * 		console.log(state.operation.command)
 * 		console.log(state.percentage)
 *
 * 	configuration.on 'burn', (state) ->
 * 		console.log(state)
 *
 * 	configuration.on 'error', (error) ->
 * 		throw error
 *
 * 	configuration.on 'end', ->
 * 		console.log('Configuration finished')
 */
// TODO; Change 'initialize' to no longer be an async function in the next major
// eslint-disable-next-line @typescript-eslint/require-await -- after the resin-device-operations conversion to TS we realized that we don't need to await 'operations.execute'
export async function initialize(
	image: string,
	manifest: DeviceTypeJson,
	options: object,
): Promise<InitializeEmitter> {
	if (manifest.initialization == null) {
		throw new Error(
			'Unsupported device type: Manifest missing initialization parameters',
		);
	}
	return operations.execute(image, manifest.initialization.operations, options);
}
