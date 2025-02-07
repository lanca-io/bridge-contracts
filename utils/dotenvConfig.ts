import * as dotenv from "dotenv";
import * as envEnc from "@chainlink/env-enc";

const ENV_FILES = [
	".env",
	".env.clf",
	".env.clccip",
	".env.tokens",
	".env.deployments.mainnet",
	".env.deployments.testnet",
	".env.wallets",
];

/**
 * Configures the dotenv with paths relative to a base directory.
 * @param {string} [basePath='../../../'] - The base path where .env files are located. Defaults to '../../'.
 */
(function configureDotEnv(basePath: string = "./") {
	const normalizedBasePath = basePath.endsWith("/") ? basePath : `${basePath}/`;

	ENV_FILES.forEach(file => {
		dotenv.config({ path: `${normalizedBasePath}${file}` });
	});
	envEnc.config({ path: process.env.PATH_TO_ENC_FILE });
})();

export {};
