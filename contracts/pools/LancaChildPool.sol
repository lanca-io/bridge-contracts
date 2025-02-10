// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILancaChildPool} from "./interfaces/ILancaChildPool.sol";
import {ICcip} from "../common/interfaces/ICcip.sol";
import {LancaPoolCommon} from "./LancaPoolCommon.sol";
import {ZERO_ADDRESS} from "../common/Constants.sol";
import {LancaChildPoolStorageSetters} from "./storages/LancaChildPoolStorageSetters.sol";
import {LibErrors} from "../common/libraries/LibErrors.sol";
import {ILancaPoolCcip} from "./interfaces/ILancaPoolCcip.sol";

contract LancaChildPool is
    LancaChildPoolStorageSetters,
    CCIPReceiver,
    ILancaChildPool,
    ILancaPoolCcip
{
    using SafeERC20 for IERC20;

    /* CONSTANT VARIABLES */
    uint32 public constant CLF_CALLBACK_GAS_LIMIT = 300_000;
    uint32 private constant CCIP_SEND_GAS_LIMIT = 300_000;

    /* IMMUTABLE VARIABLES */
    LinkTokenInterface private immutable i_linkToken;

    /* CONSTRUCTOR */
    constructor(
        address link,
        address owner,
        address ccipRouter,
        address usdc,
        address lancaBridge
    )
        CCIPReceiver(ccipRouter)
        LancaPoolCommon(usdc, lancaBridge)
        LancaChildPoolStorageSetters(owner)
    {
        i_linkToken = LinkTokenInterface(link);
    }

    /* EXTERNAL FUNCTIONS */
    receive() external payable {}

    function removePools(uint64 chainSelector) external payable onlyOwner {
        uint256 poolChainSelectorsLen = s_poolChainSelectors.length;
        uint256 poolChainSelectorsLast = poolChainSelectorsLen - 1;
        for (uint256 i; i < poolChainSelectorsLen; ++i) {
            if (s_poolChainSelectors[i] == chainSelector) {
                s_poolChainSelectors[i] = s_poolChainSelectors[poolChainSelectorsLast];
                s_poolChainSelectors.pop();
                delete s_dstPoolByChainSelector[chainSelector];
            }
        }
    }

    function distributeLiquidity(
        uint64 chainSelector,
        uint256 amountToSend,
        bytes32 distributeLiquidityRequestId
    ) external onlyMessenger {
        require(
            s_dstPoolByChainSelector[chainSelector] != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        require(
            !s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId],
            DistributeLiquidityRequestAlreadyProceeded()
        );

        s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId] = true;

        ICcip.CcipSettleMessage memory ccipTxData = ICcip.CcipSettleMessage({
            ccipTxType: ICcip.CcipTxType.liquidityRebalancing,
            data: bytes("")
        });

        _ccipSend(chainSelector, amountToSend, ccipTxData);
    }

    function ccipSendToPool(
        uint64 chainSelector,
        uint256 amountToSend,
        bytes32 withdrawalId
    ) external onlyMessenger {
        require(
            s_dstPoolByChainSelector[chainSelector] != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        require(!s_isWithdrawalRequestTriggered[withdrawalId], WithdrawalAlreadyTriggered());

        s_isWithdrawalRequestTriggered[withdrawalId] = true;

        ICcip.CcipSettleMessage memory ccipTxData = ICcip.CcipSettleMessage({
            ccipTxType: ICcip.CcipTxType.withdrawal,
            data: abi.encode(withdrawalId)
        });

        _ccipSend(chainSelector, amountToSend, ccipTxData);
    }

    function liquidatePool(bytes32 distributeLiquidityRequestId) external onlyMessenger {
        require(
            !s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId],
            DistributeLiquidityRequestAlreadyProceeded()
        );

        s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId] = true;

        uint256 poolsCount = s_poolChainSelectors.length;
        require(poolsCount != 0, NoPoolsToDistribute());

        uint256 amountToSendPerPool = (i_usdc.balanceOf(address(this)) / poolsCount) - 1;
        ICcip.CcipSettleMessage memory ccipTxData = ICcip.CcipSettleMessage({
            ccipTxType: ICcip.CcipTxType.liquidityRebalancing,
            data: bytes("")
        });

        for (uint256 i; i < poolsCount; ++i) {
            //This is a function to deal with adding&removing pools. So, the second param will always be address(0)
            _ccipSend(s_poolChainSelectors[i], amountToSendPerPool, ccipTxData);
        }
    }

    /* INTERNAL FUNCTIONS */
    /**
     * @notice CCIP function to receive bridged values
     * @param any2EvmMessage the CCIP message
     * @dev only allowed chains and sender must be able to deliver a message in this function.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAllowListedSenderOfChainSelector(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        uint256 ccipReceivedAmount = any2EvmMessage.destTokenAmounts[0].amount;
        address ccipReceivedToken = any2EvmMessage.destTokenAmounts[0].token;

        require(
            ccipReceivedToken == address(i_usdc),
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.notUsdcToken)
        );

        emit CCIPReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            ccipReceivedToken,
            ccipReceivedAmount
        );
    }

    /**
     * @notice Function to Distribute Liquidity across Concero Pools and process withdrawals
     * @param chainSelector the chainSelector of the pool to send the USDC
     * @param amount amount of the token to be sent
     * @param ccipTxData the data to be sent to the pool
     * @dev This function will sent the address of the user as data. This address will be used to update the mapping on ParentPool.
     * @dev when processing withdrawals, the chainSelector will always be the index 0 of s_poolChainSelectors
     */
    function _ccipSend(
        uint64 chainSelector,
        uint256 amount,
        ICcip.CcipSettleMessage memory ccipTxData
    ) internal returns (bytes32) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(i_usdc), amount: amount});
        address destinationPool = s_dstPoolByChainSelector[chainSelector];

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(destinationPool),
            data: abi.encode(ccipTxData),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: CCIP_SEND_GAS_LIMIT})),
            feeToken: address(i_linkToken)
        });

        uint256 ccipFeeAmount = IRouterClient(i_ccipRouter).getFee(chainSelector, evm2AnyMessage);

        i_usdc.approve(i_ccipRouter, amount);
        i_linkToken.approve(i_ccipRouter, ccipFeeAmount);

        return IRouterClient(i_ccipRouter).ccipSend(chainSelector, evm2AnyMessage);
    }
}
