
declare module 'wary' {
	function it<T>(title: string, parameter: T, fn: (parameter: T) => void | Promise<void>): void;
	function run(): Promise<void>;
	export = {
		it,
		run,
	};
};
