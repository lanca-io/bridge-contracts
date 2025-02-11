// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {ConceroRouterMock} from "../mocks/ConceroRouterMock.sol";
import {CcipRouterMock} from "../mocks/CcipRouterMock.sol";

contract DeployHelper is Script {
    function getClfRouter() public view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            return vm.envAddress("CLF_ROUTER_ETHEREUM");
        }

        return vm.envAddress("CLF_ROUTER_BASE");
    }

    function getCLfSubId() public view returns (uint64) {
        uint256 chainId = block.chainid;
        uint256 res = vm.envUint("CLF_SUBID_BASE");

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            res = vm.envUint("CLF_SUBID_ETHEREUM");
        }

        return uint64(res);
    }

    function getClfDonId() public view returns (bytes32) {
        uint256 chainId = block.chainid;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            return vm.envBytes32("CLF_DONID_ETHEREUM");
        }

        return vm.envBytes32("CLF_DONID_BASE");
    }

    function getChainSelector() public view returns (uint64) {
        uint256 chainId = block.chainid;
        uint256 res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE");

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            res = vm.envUint("CL_CCIP_CHAIN_SELECTOR_ETHEREUM");
        }

        return uint64(res);
    }

    function getChainIndex() public view returns (uint8) {
        uint256 chainId = block.chainid;
        uint256 res = 1;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            res = 1;
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            res = 0;
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            res = 3;
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            res = 4;
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            res = 2;
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            res = 5;
        }

        return uint8(res);
    }

    function getLinkAddress() public view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            return vm.envAddress("LINK_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            return vm.envAddress("LINK_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            return vm.envAddress("LINK_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            return vm.envAddress("LINK_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            return vm.envAddress("LINK_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            return vm.envAddress("LINK_ETHEREUM");
        }

        return vm.envAddress("LINK_BASE");
    }

    function getUsdcAddress() public view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
            return vm.envAddress("USDC_BASE");
        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
            return vm.envAddress("USDC_ARBITRUM");
        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
            return vm.envAddress("USDC_POLYGON");
        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
            return vm.envAddress("USDC_AVALANCHE");
        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
            return vm.envAddress("USDC_OPTIMISM");
        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
            return vm.envAddress("USDC_ETHEREUM");
        }

        return vm.envAddress("USDC_BASE");
    }

    function getCcipRouter() public returns (address) {
        // @dev commented cuz for some reason ccip router fails in fork tests

        //        uint256 chainId = block.chainid;
        //        if (chainId == vm.envUint("BASE_CHAIN_ID")) {
        //            return vm.envAddress("CL_CCIP_ROUTER_BASE");
        //        } else if (chainId == vm.envUint("ARBITRUM_CHAIN_ID")) {
        //            return vm.envAddress("CL_CCIP_ROUTER_ARBITRUM");
        //        } else if (chainId == vm.envUint("POLYGON_CHAIN_ID")) {
        //            return vm.envAddress("CL_CCIP_ROUTER_POLYGON");
        //        } else if (chainId == vm.envUint("AVALANCHE_CHAIN_ID")) {
        //            return vm.envAddress("CL_CCIP_ROUTER_AVALANCHE");
        //        } else if (chainId == vm.envUint("OPTIMISM_CHAIN_ID")) {
        //            return vm.envAddress("CL_CCIP_ROUTER_OPTIMISM");
        //        } else if (chainId == vm.envUint("ETHEREUM_CHAIN_ID")) {
        //            return vm.envAddress("CL_CCIP_ROUTER_ETHEREUM");
        //        }
        //        return vm.envAddress("CL_CCIP_ROUTER_BASE");

        return address(new CcipRouterMock(getLinkAddress()));
    }

    function getConceroRouterMock() public returns (address) {
        return address(new ConceroRouterMock());
    }

    function getClfSecretsSlotId() public pure returns (uint8) {
        // @dev doesn't matter for forge tests
        return uint8(0);
    }

    function getClfSecretsVersion() public pure returns (uint64) {
        // @dev doesn't matter for forge tests
        return uint64(0);
    }

    function getClfSrcJsHash() public pure returns (bytes32) {
        // @dev doesn't matter for forge tests
        return bytes32(0);
    }

    function getClfDstJsHash() public pure returns (bytes32) {
        // @dev doesn't matter for forge tests
        return bytes32(0);
    }

    function getClfEthersJsHash() public pure returns (bytes32) {
        // @dev doesn't matter for forge tests
        return bytes32(0);
    }

    function getMessengers() public view returns (address[] memory) {
        address[] memory messengers = new address[](3);
        messengers[0] = vm.envAddress("MESSENGER_0_ADDRESS");
        messengers[1] = vm.envAddress("MESSENGER_1_ADDRESS");
        messengers[2] = vm.envAddress("MESSENGER_2_ADDRESS");
        return messengers;
    }

    function getMinDepositAmount() public view returns (uint256) {
        uint256 chainId = block.chainid;

        if (
            chainId == vm.envUint("BASE_CHAIN_ID") ||
            chainId == vm.envUint("ARBITRUM_CHAIN_ID") ||
            chainId == vm.envUint("POLYGON_CHAIN_ID") ||
            chainId == vm.envUint("AVALANCHE_CHAIN_ID") ||
            chainId == vm.envUint("OPTIMISM_CHAIN_ID") ||
            chainId == vm.envUint("ETHEREUM_CHAIN_ID")
        ) {
            return 250e6;
        }

        return 1e6;
    }

    function getDepositFeeAmount() public view returns (uint256) {
        uint256 chainId = block.chainid;

        if (
            chainId == vm.envUint("BASE_CHAIN_ID") ||
            chainId == vm.envUint("ARBITRUM_CHAIN_ID") ||
            chainId == vm.envUint("POLYGON_CHAIN_ID") ||
            chainId == vm.envUint("AVALANCHE_CHAIN_ID") ||
            chainId == vm.envUint("OPTIMISM_CHAIN_ID") ||
            chainId == vm.envUint("ETHEREUM_CHAIN_ID")
        ) {
            return 3e6;
        }

        return 0;
    }

    function getWithdrawalCooldownSeconds() public view returns (uint256) {
        uint256 chainId = block.chainid;

        if (
            chainId == vm.envUint("BASE_CHAIN_ID") ||
            chainId == vm.envUint("ARBITRUM_CHAIN_ID") ||
            chainId == vm.envUint("POLYGON_CHAIN_ID") ||
            chainId == vm.envUint("AVALANCHE_CHAIN_ID") ||
            chainId == vm.envUint("OPTIMISM_CHAIN_ID") ||
            chainId == vm.envUint("ETHEREUM_CHAIN_ID")
        ) {
            return 7 days;
        }

        return 1 seconds;
    }
}
