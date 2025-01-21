// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaParentPoolStorage} from "../storages/LancaParentPoolStorage.sol";
import {ILancaParentPool} from "../interfaces/pools/ILancaParentPool.sol";
import {LancaOwnable} from "../LancaOwnable.sol";
import {ZERO_ADDRESS} from "../Constants.sol";

abstract contract LancaParentPoolStorageSetters is
    LancaParentPoolStorage,
    LancaOwnable,
    ILancaParentPool
{
    constructor(address owner) LancaOwnable(owner) {}

    /**
     * @notice Function to set the Ethers JS code for Chainlink Functions
     * @param ethersHashSum the JsCode
     * @dev this functions was used inside of ConceroFunctions
     */
    function setEthersHashSum(bytes32 ethersHashSum) external payable onlyOwner {
        s_ethersHashSum = ethersHashSum;
    }

    function setGetBalanceJsCodeHashSum(bytes32 hashSum) external payable onlyOwner {
        s_getChildPoolsLiquidityJsCodeHashSum = hashSum;
    }

    /**
     * @notice function to manage the Cross-chains Concero contracts
     * @param chainSelector chain identifications
     * @param contractAddress address of the Cross-chains Concero contracts
     * @param isAllowed bool to allow or disallow the contract
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     * @dev this functions is used in ConceroPool.sol
     */
    function setConceroContractSender(
        uint64 chainSelector,
        address contractAddress,
        bool isAllowed
    ) external payable onlyOwner {
        require(contractAddress != ZERO_ADDRESS, InvalidAddress());
        s_isSenderContractAllowed[chainSelector][contractAddress] = isAllowed;
    }

    /**
     * @notice Function to set the Cap of the Master pool.
     * @param newCap The new Cap of the pool
     */
    function setPoolCap(uint256 newCap) external payable onlyOwner {
        s_liquidityCap = newCap;
    }

    /**
     * @notice function to manage the Cross-chain ConceroPool contracts
     * @param chainSelector chain identifications
     * @param pool address of the Cross-chain ConceroPool contract
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     * @dev this functions is used on ConceroPool.sol
     */
    function setPools(
        uint64 chainSelector,
        address pool,
        bool isRebalancingNeeded
    ) external payable onlyOwner {
        require(s_childPools[chainSelector] != pool && pool != ZERO_ADDRESS, InvalidAddress());

        spoolChainSelectors.push(chainSelector);
        s_childPools[chainSelector] = pool;

        if (isRebalancingNeeded) {
            bytes32 distributeLiquidityRequestId = keccak256(
                abi.encodePacked(pool, chainSelector, RedistributeLiquidityType.addPool)
            );

            bytes[] memory args = new bytes[](7);
            args[0] = abi.encodePacked(s_distributeLiquidityJsCodeHashSum);
            args[1] = abi.encodePacked(s_ethersHashSum);
            args[2] = abi.encodePacked(CLFRequestType.liquidityRedistribution);
            args[3] = abi.encodePacked(chainSelector);
            args[4] = abi.encodePacked(distributeLiquidityRequestId);
            args[5] = abi.encodePacked(RedistributeLiquidityType.addPool);
            args[6] = abi.encodePacked(block.chainid);

            bytes memory delegateCallArgs = abi.encodeWithSelector(
                IParentPoolCLFCLA.sendCLFRequest.selector,
                args
            );
            LancaLib.safeDelegateCall(address(i_parentPoolCLFCLA), delegateCallArgs);
        }
    }
}
