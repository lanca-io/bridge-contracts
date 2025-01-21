// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract LancaParentPoolStorageSetters is LancaParentPoolStorage, LancaOwnable {
    constructor(address owner) LancaOwnable(owner) {}

    function setDonHostedSecretsSlotId(uint8 slotId) external payable onlyOwner {
        s_donHostedSecretsSlotId = slotId;
    }

    /**
     * @notice Function to set the Don Secrets Version from Chainlink Functions
     * @param _version the version
     * @dev this functions was used inside of ConceroFunctions
     */
    function setDonHostedSecretsVersion(uint64 version) external payable onlyOwner {
        s_donHostedSecretsVersion = version;
    }

    /**
     * @notice Function to set the Source JS code for Chainlink Functions
     * @param _hashSum  the JsCode
     * @dev this functions was used inside of ConceroFunctions
     */
    function setCollectLiquidityJsCodeHashSum(bytes32 hashSum) external payable onlyOwner {
        s_collectLiquidityJsCodeHashSum = hashSum;
    }

    function setRedistributeLiquidityJsCodeHashSum(bytes32 hashSum) external payable onlyOwner {
        s_distributeLiquidityJsCodeHashSum = hashSum;
    }

    /**
     * @notice Function to set the Ethers JS code for Chainlink Functions
     * @param _ethersHashSum the JsCode
     * @dev this functions was used inside of ConceroFunctions
     */
    function setEthersHashSum(bytes32 ethersHashSum) external payable onlyOwner {
        s_ethersHashSum = ethersHashSum;
    }

    function setGetBalanceJsCodeHashSum(bytes32 hashSum) external payable onlyOwner {
        s_getChildPoolsLiquidityJsCodeHashSum = hashSum;
    }
}
