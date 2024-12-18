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

import _ from 'lodash';
import path from 'path';
import * as util from 'node:util';
import * as imagefs from 'balena-image-fs';
import type {
	DeviceTypeConfigurationConfig,
	DeviceTypeJson,
} from './device-type-json';

/**
 * @summary Get device type manifest of an image
 * @function
 *
 * @param {String} image - path to image
 * @returns {Promise<Object | null>} device type manifest or null
 *
 * @example
 * utils.getImageManifest('path/to/image.img', 'raspberry-pi').then (manifest) ->
 * 	console.log(manifest)
 */
export function getImageManifest(
	image: string,
): Promise<DeviceTypeJson | null> {
	// Attempt to read manifest from the first
	// partition, but fallback to the API if
	// we encounter any errors along the way.
	return Promise.resolve(
		imagefs.interact(image, 1, function (_fs) {
			const readFileAsync = util.promisify(_fs.readFile);
			return readFileAsync('/device-type.json', {
				encoding: 'utf8',
			});
		}),
	)
		.then(JSON.parse)
		.catch(() => null);
}

/**
 * @summary Convert a device type file definition to resin-image-fs v4 format
 * @function
 * @protected
 *
 * @param {Object} definition - write definition
 *
 * @returns {Object} a converted write definition
 *
 * @example
 * utils.convertFileDefinition
 * 	partition:
 * 		primary: 4
 * 		logical: 1
 * 	path: '/config.json'
 */
export function convertFilePathDefinition<
	T extends Pick<DeviceTypeConfigurationConfig, 'partition'>,
>(
	inputDefinition: T,
): Omit<T, 'partition'> & { partition: number | undefined } {
	const definition = _.cloneDeep(inputDefinition);

	return {
		...definition,
		partition: _.isObject(definition.partition)
			? // Partition numbering is now numerical, following the linux
				// conventions in 5.95 of the TLDP's system admin guide:
				// http://www.tldp.org/LDP/sag/html/partitions.html#DEV-FILES-PARTS
				definition.partition.logical != null
				? definition.partition.logical + 4
				: (definition.partition = definition.partition.primary)
			: definition.partition,
	};
}

/**
 * @summary Add image info to a device type config definition
 * @function
 * @protected
 *
 * @param {String} image - image path
 * @param {Object} definition - write definition
 *
 * @returns {Object} a write definition
 *
 * @example
 * utils.definitionForImage 'my/rpi.img',
 * 	partition:
 * 		primary: 4
 * 		logical: 1
 * 	path: '/config.json'
 */
export function definitionForImage<
	T extends Pick<DeviceTypeConfigurationConfig, 'image' | 'partition'>,
>(image: string, configDefinition: T): T & { image: string } {
	configDefinition = _.cloneDeep(configDefinition);

	return {
		...configDefinition,
		image:
			configDefinition.image != null
				? // Sometimes (e.g. edison) our 'image' is a folder of images, and the
					// config specifies which one within that we should be using
					path.join(image, configDefinition.image)
				: image,
	};
}

/**
 * @summary Get image OS version
 * @function
 *
 * @param {String} image - path to image
 * @param {Object} manifest - device type manifest
 * @returns {Promise<string|null>} ResinOS version, or null if it could not be determined
 *
 * @example
 * utils.getImageOsVersion('path/to/image.img', manifest).then (version) ->
 * 	console.log(version)
 */
export function getImageOsVersion(
	image: string,
	manifest: DeviceTypeJson | undefined,
): Promise<string | null> {
	// Try to determine the location where os-release is stored. This is always
	// stored alongside "config.json" so look into the manifest if given, and
	// fallback to a sensible default if not. This should be able to handle a
	// wide range of regular images with several partitions as well as cases like
	// with Edison where "image" points to a folder structure.

	const definition = {
		...convertFilePathDefinition(
			definitionForImage(
				image,
				manifest?.configuration?.config ?? { partition: 1 },
			),
		),
		path: '/os-release',
	};

	return Promise.resolve(
		imagefs.interact(definition.image, definition.partition, function (_fs) {
			const readFileAsync = util.promisify(_fs.readFile);
			return readFileAsync(definition.path, { encoding: 'utf8' });
		}),
	)
		.then(function (osReleaseString) {
			const parsedOsRelease = _(osReleaseString)
				.split('\n')
				.map(function (line) {
					const match = line.match(/(.*)=(.*)/);
					if (match) {
						return [
							match[1],
							match[2].replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1'),
						];
					} else {
						return false;
					}
				})
				.filter()
				.fromPairs()
				.value();

			if (
				parsedOsRelease.NAME !== 'Resin OS' &&
				parsedOsRelease.NAME !== 'balenaOS'
			) {
				return null;
			} else {
				return parsedOsRelease.VERSION || null;
			}
		})
		.catch(() => null);
}

/**
 * @summary Write config.json to image
 * @function
 * @protected
 *
 * @param {String} image - image path
 * @param {Object} config - config.json object
 * @param {Object} definitionWithImage - write definition
 *
 * @returns {Promise}
 *
 * @example
 * utils.writeConfigJSON 'my/rpi.img',
 * 	hello: 'world'
 * ,
 * 	partition:
 * 		primary: 4
 * 		logical: 1
 * 	path: '/config.json'
 */
export const writeConfigJSON = function (
	image: string,
	config: Record<string, any>,
	definition: { partition: number | undefined; path: string },
) {
	const serializedConfig = JSON.stringify(config);

	const definitionWithImage = definitionForImage(image, definition);

	return imagefs.interact(
		definitionWithImage.image,
		definitionWithImage.partition,
		function (_fs) {
			const writeFileAsync = util.promisify(_fs.writeFile);
			return writeFileAsync(definitionWithImage.path, serializedConfig);
		},
	);
};
