// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaOrchestratorStorage} from "./storages/LancaOrchestratorStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILancaBridge} from "./interfaces/ILancaBridge.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LancaOrchestrator is LancaOrchestratorStorage {
    using SafeERC20 for IERC20;

    /* TYPES */

    struct Integration {
        address integrator;
        uint256 feeBps;
    }

    /* ERRORS */

    error InvalidIntegratorFeeBps();
    error InvalidBridgeToken();

    /* CONSTANTS */
    uint16 internal constant MAX_INTEGRATOR_FEE_BPS = 1000;
    uint16 internal constant BPS_DIVISOR = 10000;
    uint24 internal constant DST_CHAIN_GAS_LIMIT = 1_000_000;

    /* IMMUTABLES */
    address internal immutable i_usdc;
    address internal immutable i_lancaBridge;

    /* EVENTS */
    event IntegratorFeesCollected(address integrator, address token, uint256 amount);

    constructor(address usdc, address lancaBridge) {
        i_usdc = usdc;
        i_lancaBridge = lancaBridge;
    }

    /* FUNCTIONS */

    function bridge(
        address token,
        uint256 amount,
        address receiver,
        uint64 dstChainSelector,
        bytes memory compressedDstSwapData,
        Integration memory integration
    ) external {
        if (token != i_usdc) revert InvalidBridgeToken();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        amount -= _collectIntegratorFee(token, amount, integration);

        address dstLancaContract = s_lancaOrchestratorDstByChainSelector[dstChainSelector];
        bytes memory message = abi.encode(receiver, compressedDstSwapData);

        ILancaBridge.BridgeData memory bridgeData = ILancaBridge.BridgeData({
            amount: amount,
            token: token,
            feeToken: i_usdc,
            receiver: dstLancaContract,
            dstChainSelector: dstChainSelector,
            dstChainGasLimit: DST_CHAIN_GAS_LIMIT,
            message: compressedDstSwapData
        });

        ILancaBridge(i_lancaBridge).bridge(bridgeData);
    }

    /* INTERNAL FUNCTIONS */

    function _collectIntegratorFee(
        address token,
        uint256 amount,
        Integration memory integration
    ) internal returns (uint256) {
        if (integration.integrator == address(0)) return 0;
        if (integration.feeBps > MAX_INTEGRATOR_FEE_BPS) revert InvalidIntegratorFeeBps();

        uint256 integratorFeeAmount = (amount * integration.feeBps) / BPS_DIVISOR;
        if (integratorFeeAmount == 0) return 0;

        s_integratorFeesAmountByToken[integration.integrator][token] += integratorFeeAmount;
        //        s_totalIntegratorFeesAmountByToken[token] += integratorFeeAmount;

        emit IntegratorFeesCollected(integration.integrator, token, integratorFeeAmount);
        return integratorFeeAmount;
    }
}
