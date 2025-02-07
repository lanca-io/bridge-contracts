// Purpose: To have a single source of truth for networks across the project
import { type CNetwork, CNetworkNames, NetworkType } from "../types/CNetwork";
import { HardhatNetworkUserConfig } from "hardhat/src/types/config";
import {
	arbitrum,
	arbitrumSepolia,
	avalanche,
	avalancheFuji,
	base,
	baseSepolia,
	mainnet,
	optimism,
	optimismSepolia,
	polygon,
	polygonAmoy,
	sepolia,
} from "viem/chains";
import { urls } from "./rpcUrls";

const DEFAULT_BLOCK_CONFIRMATIONS = 2;
const deployerPK = process.env.DEPLOYER_PRIVATE_KEY;
const proxyDeployerPK = process.env.PROXY_DEPLOYER_PRIVATE_KEY;
const saveDeployments = false;

export const networkTypes: Record<NetworkType, string> = {
	mainnet: "mainnet",
	testnet: "testnet",
};

export const networkEnvKeys: Record<string, string> = {
	// mainnets
	ethereum: "ETHEREUM",
	arbitrum: "ARBITRUM",
	optimism: "OPTIMISM",
	polygon: "POLYGON",
	polygonZkEvm: "POLYGON_ZKEVM",
	avalanche: "AVALANCHE",
	base: "BASE",
	// testnets
	sepolia: "SEPOLIA",
	optimismSepolia: "OPTIMISM_SEPOLIA",
	arbitrumSepolia: "ARBITRUM_SEPOLIA",
	avalancheFuji: "FUJI",
	baseSepolia: "BASE_SEPOLIA",
	polygonAmoy: "POLYGON_AMOY",
};

export const functionsGatewayUrls = {
	mainnet: ["https://01.functions-gateway.chain.link/", "https://02.functions-gateway.chain.link/"],
	localhost: ["https://01.functions-gateway.chain.link/", "https://02.functions-gateway.chain.link/"],
	testnet: ["https://01.functions-gateway.testnet.chain.link/", "https://02.functions-gateway.testnet.chain.link/"],
};

export const conceroNetworks: Record<CNetworkNames, CNetwork> = {
	localhost: {
		accounts: [deployerPK, proxyDeployerPK],
		// mock CLF data
		functionsDonId: process.env.CLF_DONID_SEPOLIA,
		functionsDonIdAlias: process.env.CLF_DONID_SEPOLIA_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_SEPOLIA,
		functionsCoordinator: process.env.CLF_COORDINATOR_SEPOLIA,
		functionsSubIds: [process.env.CLF_SUBID_SEPOLIA],
		functionsGatewayUrls: functionsGatewayUrls.testnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_SEPOLIA,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_SEPOLIA,
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_SEPOLIA,
		linkPriceFeed: process.env.LINK_PRICEFEED_SEPOLIA,
		ccipRouter: process.env.CL_CCIP_ROUTER_SEPOLIA,
	} as HardhatNetworkUserConfig,
	hardhat: {
		chainId: 31337,
		forking: {
			url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
			enabled: process.env.MAINNET_FORKING_ENABLED === "true",
			blockNumber: 9_675_000,
		},
		accounts: [
			{
				privateKey: deployerPK,
				balance: "10000000000000000000000",
			},
			{
				privateKey: deployerPK,
				balance: "10000000000000000000000",
			},
		],
		// mock CLF data
		functionsDonId: process.env.CLF_DONID_SEPOLIA,
		functionsDonIdAlias: process.env.CLF_DONID_SEPOLIA_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_SEPOLIA,
		functionsCoordinator: process.env.CLF_COORDINATOR_SEPOLIA,
		functionsSubIds: [process.env.CLF_SUBID_SEPOLIA],
		functionsGatewayUrls: functionsGatewayUrls.testnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_SEPOLIA,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_SEPOLIA,
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_SEPOLIA,
		linkPriceFeed: process.env.LINK_PRICEFEED_SEPOLIA,
		ccipBnmToken: process.env.CCIPBNM_SEPOLIA,
		ccipRouter: process.env.CL_CCIP_ROUTER_SEPOLIA,
	} as HardhatNetworkUserConfig,
	// TESTNETS
	sepolia: {
		type: networkTypes.testnet,
		saveDeployments,
		chainId: 11155111,
		rpcs: urls.sepolia,
		url: urls.sepolia[0],
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_SEPOLIA,
		functionsDonIdAlias: process.env.CLF_DONID_SEPOLIA_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_SEPOLIA,
		functionsCoordinator: process.env.CLF_COORDINATOR_SEPOLIA,
		functionsSubIds: [process.env.CLF_SUBID_SEPOLIA],
		functionsGatewayUrls: functionsGatewayUrls.testnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_SEPOLIA,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_SEPOLIA,
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_SEPOLIA,
		linkPriceFeed: process.env.LINK_PRICEFEED_SEPOLIA,
		ccipBnmToken: process.env.CCIPBNM_SEPOLIA,
		usdc: process.env.USDC_SEPOLIA,
		ccipRouter: process.env.CL_CCIP_ROUTER_SEPOLIA,
		viemChain: sepolia,
		name: "sepolia",
	},
	baseSepolia: {
		type: networkTypes.testnet,
		saveDeployments,
		chainId: 84532,
		url: urls.baseSepolia[0],
		rpcs: urls.baseSepolia,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_BASE_SEPOLIA,
		functionsDonIdAlias: process.env.CLF_DONID_BASE_SEPOLIA_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_BASE_SEPOLIA,
		functionsCoordinator: process.env.CLF_COORDINATOR_BASE_SEPOLIA,
		functionsSubIds: [process.env.CLF_SUBID_BASE_SEPOLIA],
		functionsGatewayUrls: functionsGatewayUrls.testnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_BASE_SEPOLIA,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA,
		conceroChainIndex: "1",
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_BASE_SEPOLIA,
		linkPriceFeed: process.env.LINK_PRICEFEED_BASE_SEPOLIA,
		ccipBnmToken: process.env.CCIPBNM_BASE_SEPOLIA,
		usdc: process.env.USDC_BASE_SEPOLIA,
		ccipRouter: process.env.CL_CCIP_ROUTER_BASE_SEPOLIA,
		viemChain: baseSepolia,
		name: "baseSepolia",
		priceFeed: {
			linkToUsdPriceFeeds: process.env.LINK_USD_PRICEFEED_BASE_SEPOLIA!,
			usdcToUsdPriceFeeds: process.env.USDC_USD_PRICEFEED_BASE_SEPOLIA!,
			nativeToUsdPriceFeeds: process.env.NATIVE_USD_PRICEFEED_BASE_SEPOLIA!,
			linkToNativePriceFeeds: process.env.LINK_NATIVE_PRICEFEED_BASE_SEPOLIA!,
		},
	},
	avalancheFuji: {
		type: networkTypes.testnet,
		saveDeployments,
		chainId: 43113,
		url: urls.avalancheFuji[0],
		rpcs: urls.avalancheFuji,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_FUJI,
		functionsDonIdAlias: process.env.CLF_DONID_FUJI_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_FUJI,
		functionsCoordinator: process.env.CLF_COORDINATOR_FUJI,
		functionsSubIds: [process.env.CLF_SUBID_FUJI],
		functionsGatewayUrls: functionsGatewayUrls.testnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_FUJI,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_FUJI,
		conceroChainIndex: "4",
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_FUJI,
		linkPriceFeed: process.env.LINK_PRICEFEED_FUJI,
		ccipBnmToken: process.env.CCIPBNM_FUJI,
		usdc: process.env.USDC_FUJI,
		ccipRouter: process.env.CL_CCIP_ROUTER_FUJI,
		viemChain: avalancheFuji,
		name: "avalancheFuji",
	},
	optimismSepolia: {
		type: networkTypes.testnet,
		saveDeployments,
		chainId: 11155420,
		url: urls.optimismSepolia[0],
		rpcs: urls.optimismSepolia,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_OPTIMISM_SEPOLIA,
		functionsDonIdAlias: process.env.CLF_DONID_OPTIMISM_SEPOLIA_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_OPTIMISM_SEPOLIA,
		functionsCoordinator: process.env.CLF_COORDINATOR_OPTIMISM_SEPOLIA,
		functionsSubIds: [process.env.CLF_SUBID_OPTIMISM_SEPOLIA],
		functionsGatewayUrls: functionsGatewayUrls.testnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_OPTIMISM_SEPOLIA,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA,
		conceroChainIndex: "2",
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_OPTIMISM_SEPOLIA,
		linkPriceFeed: process.env.LINK_PRICEFEED_OPTIMISM_SEPOLIA,
		ccipBnmToken: process.env.CCIPBNM_OPTIMISM_SEPOLIA,
		usdc: process.env.USDC_OPTIMISM_SEPOLIA,
		ccipRouter: process.env.CL_CCIP_ROUTER_OPTIMISM_SEPOLIA,
		viemChain: optimismSepolia,
		name: "optimismSepolia",
		priceFeed: {
			linkToUsdPriceFeeds: process.env.LINK_USD_PRICEFEED_OPTIMISM_SEPOLIA!,
			usdcToUsdPriceFeeds: process.env.USDC_USD_PRICEFEED_OPTIMISM_SEPOLIA!,
			nativeToUsdPriceFeeds: process.env.NATIVE_USD_PRICEFEED_OPTIMISM_SEPOLIA!,
			linkToNativePriceFeeds: process.env.LINK_NATIVE_PRICEFEED_OPTIMISM_SEPOLIA!,
		},
	},
	arbitrumSepolia: {
		type: networkTypes.testnet,
		saveDeployments,
		chainId: 421614,
		url: urls.arbitrumSepolia[0],
		rpcs: urls.arbitrumSepolia,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_ARBITRUM_SEPOLIA,
		functionsDonIdAlias: process.env.CLF_DONID_ARBITRUM_SEPOLIA_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_ARBITRUM_SEPOLIA,
		functionsCoordinator: process.env.CLF_COORDINATOR_ARBITRUM_SEPOLIA,
		functionsSubIds: [process.env.CLF_SUBID_ARBITRUM_SEPOLIA],
		functionsGatewayUrls: functionsGatewayUrls.testnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_ARBITRUM_SEPOLIA,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA,
		conceroChainIndex: "0",
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_ARBITRUM_SEPOLIA,
		linkPriceFeed: process.env.LINK_PRICEFEED_ARBITRUM_SEPOLIA,
		ccipBnmToken: process.env.CCIPBNM_ARBITRUM_SEPOLIA,
		usdc: process.env.USDC_ARBITRUM_SEPOLIA,
		ccipRouter: process.env.CL_CCIP_ROUTER_ARBITRUM_SEPOLIA,
		viemChain: arbitrumSepolia,
		name: "arbitrumSepolia",
		priceFeed: {
			linkToUsdPriceFeeds: process.env.LINK_USD_PRICEFEED_ARBITRUM_SEPOLIA!,
			usdcToUsdPriceFeeds: process.env.USDC_USD_PRICEFEED_ARBITRUM_SEPOLIA!,
			nativeToUsdPriceFeeds: process.env.NATIVE_USD_PRICEFEED_ARBITRUM_SEPOLIA!,
			linkToNativePriceFeeds: process.env.LINK_NATIVE_PRICEFEED_ARBITRUM_SEPOLIA!,
		},
	},
	polygonAmoy: {
		type: networkTypes.testnet,
		saveDeployments,
		chainId: 80002,
		url: urls.polygonAmoy[0],
		rpcs: urls.polygonAmoy,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_POLYGON_AMOY,
		functionsDonIdAlias: process.env.CLF_DONID_POLYGON_AMOY_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_POLYGON_AMOY,
		functionsCoordinator: process.env.CLF_COORDINATOR_POLYGON_AMOY,
		functionsSubIds: [process.env.CLF_SUBID_POLYGON_AMOY],
		functionsGatewayUrls: functionsGatewayUrls.testnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_POLYGON_AMOY,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_POLYGON_AMOY,
		conceroChainIndex: "3",
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_POLYGON_AMOY,
		linkPriceFeed: process.env.LINK_PRICEFEED_POLYGON_AMOY,
		ccipBnmToken: process.env.CCIPBNM_POLYGON_AMOY,
		ccipRouter: process.env.CL_CCIP_ROUTER_POLYGON_AMOY,
		viemChain: polygonAmoy,
		name: "polygonAmoy",
		priceFeed: {
			linkToUsdPriceFeeds: process.env.LINK_USD_PRICEFEED_POLYGON_AMOY!,
			usdcToUsdPriceFeeds: process.env.USDC_USD_PRICEFEED_POLYGON_AMOY!,
			nativeToUsdPriceFeeds: process.env.NATIVE_USD_PRICEFEED_POLYGON_AMOY!,
			linkToNativePriceFeeds: process.env.LINK_NATIVE_PRICEFEED_POLYGON_AMOY!,
		},
	},
	// MAINNETS
	ethereum: {
		type: networkTypes.mainnet,
		saveDeployments,
		chainId: 1,
		url: urls.ethereum[0],
		rpcs: urls.ethereum,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_ETHEREUM,
		functionsDonIdAlias: process.env.CLF_DONID_ETHEREUM_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_ETHEREUM,
		functionsCoordinator: process.env.CLF_COORDINATOR_ETHEREUM,
		functionsSubIds: [process.env.CLF_SUBID_ETHEREUM],
		conceroChainIndex: "5",
		functionsGatewayUrls: functionsGatewayUrls.mainnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_ETHEREUM,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_ETHEREUM,
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_ETHEREUM,
		linkPriceFeed: process.env.LINK_USD_PRICEFEED_ETHEREUM,
		ccipRouter: process.env.CL_CCIP_ROUTER_ETHEREUM,
		viemChain: mainnet,
		name: "ethereum",
	},
	base: {
		type: networkTypes.mainnet,
		saveDeployments,
		chainId: 8453,
		url: urls.arbitrum[0],
		rpcs: urls.base,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_BASE,
		functionsDonIdAlias: process.env.CLF_DONID_BASE_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_BASE,
		functionsCoordinator: process.env.CLF_COORDINATOR_BASE,
		functionsSubIds: [process.env.CLF_SUBID_BASE],
		functionsGatewayUrls: functionsGatewayUrls.mainnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_BASE,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_BASE,
		conceroChainIndex: "1",
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_BASE,
		linkPriceFeed: process.env.LINK_PRICEFEED_BASE,
		ccipBnmToken: process.env.CCIPBNM_BASE_SEPOLIA,
		ccipRouter: process.env.CL_CCIP_ROUTER_BASE,
		viemChain: base,
		name: "base",
		priceFeed: {
			linkToUsdPriceFeeds: process.env.LINK_USD_PRICEFEED_BASE!,
			usdcToUsdPriceFeeds: process.env.USDC_USD_PRICEFEED_BASE!,
			nativeToUsdPriceFeeds: process.env.NATIVE_USD_PRICEFEED_BASE!,
			linkToNativePriceFeeds: process.env.LINK_NATIVE_PRICEFEED_BASE!,
		},
	},
	arbitrum: {
		type: networkTypes.mainnet,
		saveDeployments,
		chainId: 42161,
		url: urls.arbitrum[0],
		rpcs: urls.arbitrum,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_ARBITRUM,
		functionsDonIdAlias: process.env.CLF_DONID_ARBITRUM_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_ARBITRUM,
		functionsCoordinator: process.env.CLF_COORDINATOR_ARBITRUM,
		functionsSubIds: [process.env.CLF_SUBID_ARBITRUM],
		functionsGatewayUrls: functionsGatewayUrls.mainnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_ARBITRUM,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM,
		conceroChainIndex: "0",
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_ARBITRUM,
		linkPriceFeed: process.env.LINK_PRICEFEED_ARBITRUM,
		ccipBnmToken: process.env.CCIPBNM_ARBITRUM,
		ccipRouter: process.env.CL_CCIP_ROUTER_ARBITRUM,
		viemChain: arbitrum,
		name: "arbitrum",
		priceFeed: {
			linkToUsdPriceFeeds: process.env.LINK_USD_PRICEFEED_ARBITRUM!,
			usdcToUsdPriceFeeds: process.env.USDC_USD_PRICEFEED_ARBITRUM!,
			nativeToUsdPriceFeeds: process.env.NATIVE_USD_PRICEFEED_ARBITRUM!,
			linkToNativePriceFeeds: process.env.LINK_NATIVE_PRICEFEED_ARBITRUM!,
		},
	},
	polygon: {
		type: networkTypes.mainnet,
		saveDeployments,
		chainId: 137,
		url: urls.polygon[0],
		rpcs: urls.polygon,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_POLYGON,
		functionsDonIdAlias: process.env.CLF_DONID_POLYGON_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_POLYGON,
		functionsCoordinator: process.env.CLF_COORDINATOR_POLYGON,
		functionsSubIds: [process.env.CLF_SUBID_POLYGON],
		functionsGatewayUrls: functionsGatewayUrls.mainnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_POLYGON,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_POLYGON,
		conceroChainIndex: "3",
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_POLYGON,
		linkPriceFeed: process.env.LINK_PRICEFEED_POLYGON,
		ccipBnmToken: process.env.CCIPBNM_POLYGON_AMOY,
		ccipRouter: process.env.CL_CCIP_ROUTER_POLYGON,
		viemChain: polygon,
		name: "polygon",
		priceFeed: {
			linkToUsdPriceFeeds: process.env.LINK_USD_PRICEFEED_POLYGON!,
			usdcToUsdPriceFeeds: process.env.USDC_USD_PRICEFEED_POLYGON_AMOY!,
			nativeToUsdPriceFeeds: process.env.NATIVE_USD_PRICEFEED_POLYGON_AMOY!,
			linkToNativePriceFeeds: process.env.LINK_NATIVE_PRICEFEED_POLYGON_AMOY!,
		},
	},
	avalanche: {
		type: networkTypes.mainnet,
		saveDeployments,
		chainId: 43114,
		url: urls.avalanche[0],
		rpcs: urls.avalanche,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_AVALANCHE,
		functionsDonIdAlias: process.env.CLF_DONID_AVALANCHE_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_AVALANCHE,
		functionsCoordinator: process.env.CLF_COORDINATOR_AVALANCHE,
		functionsSubIds: [process.env.CLF_SUBID_AVALANCHE],
		conceroChainIndex: "4",
		functionsGatewayUrls: functionsGatewayUrls.mainnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_AVALANCHE,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_AVALANCHE,
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_AVALANCHE,
		linkPriceFeed: process.env.LINK_PRICEFEED_AVALANCHE,
		ccipBnmToken: process.env.CCIPBNM_FUJI,
		ccipRouter: process.env.CL_CCIP_ROUTER_AVALANCHE,
		viemChain: avalanche,
		name: "avalanche",
	},
	optimism: {
		type: networkTypes.mainnet,
		saveDeployments,
		chainId: 10,
		url: urls.optimism[0],
		rpcs: urls.optimism,
		accounts: [deployerPK, proxyDeployerPK],
		functionsDonId: process.env.CLF_DONID_OPTIMISM,
		functionsDonIdAlias: process.env.CLF_DONID_OPTIMISM_ALIAS,
		functionsRouter: process.env.CLF_ROUTER_OPTIMISM,
		functionsCoordinator: process.env.CLF_COORDINATOR_OPTIMISM,
		functionsSubIds: [process.env.CLF_SUBID_OPTIMISM],
		conceroChainIndex: "2",
		functionsGatewayUrls: functionsGatewayUrls.mainnet,
		donHostedSecretsVersion: process.env.CLF_DON_SECRETS_VERSION_OPTIMISM,
		chainSelector: process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM,
		confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
		linkToken: process.env.LINK_OPTIMISM,
		linkPriceFeed: process.env.LINK_USD_PRICEFEED_OPTIMISM,
		ccipRouter: process.env.CL_CCIP_ROUTER_OPTIMISM,
		viemChain: optimism,
		name: "optimism",
	},
};
export default conceroNetworks;
