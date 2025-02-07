import { task } from "hardhat/config";
import { compileContracts } from "../../utils/compileContracts";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CNetwork, CNetworkNames, NetworkType } from "../../types/CNetwork";
import { conceroNetworks } from "../../constants";
import { networkTypes } from "../../constants/conceroNetworks";
import { conceroChains } from "../../constants/liveChains";
import { verifyContractVariables } from "../verifyContractVariables.task";
import deployProxyAdmin from "../../deploy/TransparentProxyAdmin";
import deployTransparentProxy from "../../deploy/TransparentProxy";
import { ProxyEnum } from "../../constants/deploymentVariables";
import deployLancaBridgeImplementation from "../../deploy/LancaBridge";
import { upgradeProxyImplementation } from "../transparentProxy/upgradeProxyImplementation.task";

interface DeployInfraParams {
	hre: any;
	liveChains: CNetwork[];
	deployableChains: CNetwork[];
	networkType: NetworkType;
	deployProxy: boolean;
	deployImplementation: boolean;
	setVars: boolean;
	uploadSecrets: boolean;
	slotId: number;
}

async function deployConceroRouter(params: DeployInfraParams) {
	const { hre, deployableChains, deployProxy, deployImplementation, setVars } = params;
	const name = hre.network.name as CNetworkNames;
	const isTestnet = deployableChains[0].type === "testnet";

	if (deployProxy) {
		await deployProxyAdmin(hre, ProxyEnum.conceroRouterProxy);
		await deployTransparentProxy(hre, ProxyEnum.conceroRouterProxy);
	}

	if (deployImplementation) {
		await deployLancaBridgeImplementation(hre, params);
		await upgradeProxyImplementation(hre, false);
	}

	if (setVars) {
	}
}

task("deploy-lanca-bridge", "Deploy the Lanca Bridge")
	.addFlag("deployproxy", "Deploy the proxy")
	.addFlag("deployimplementation", "Deploy the implementation")
	.addFlag("setvars", "Set the contract variables")
	.setAction(async taskArgs => {
		compileContracts({ quiet: true });

		// eslint-disable-next-line @typescript-eslint/no-require-imports
		const hre: HardhatRuntimeEnvironment = require("hardhat");

		const { live } = hre.network;
		const name = hre.network.name as CNetworkNames;
		const networkType = conceroNetworks[name].type;
		let deployableChains: CNetwork[] = [];
		if (live) deployableChains = [conceroNetworks[name]];

		let liveChains: CNetwork[] = [];
		if (networkType == networkTypes.mainnet) {
			liveChains = conceroChains.mainnet.infra;
			await verifyContractVariables();
		} else {
			liveChains = conceroChains.testnet.infra;
		}

		await deployConceroRouter({
			hre,
			deployableChains,
			liveChains,
			networkType,
			deployProxy: taskArgs.deployproxy,
			deployImplementation: taskArgs.deployimplementation,
			setVars: taskArgs.setvars,
			uploadSecrets: taskArgs.uploadsecrets,
			slotId: parseInt(taskArgs.slotid),
		});
	});

export default {};
