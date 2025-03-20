// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console, Test} from "forge-std/Test.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";

import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract CrossChainTest is Test {
    address owner = makeAddr("owner");
    address user = makeAddr("user");
    uint256 SEND_VALUE = 1e5;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    Vault vault;

    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("eth");
        arbSepoliaFork = vm.createFork("arb");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // Deploy and configure on Sepolia (Fork 0)
        vm.selectFork(sepoliaFork);
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(IERC20(address(sepoliaToken)), new address[](0), sepoliaNetworkDetails.rmnProxyAddress, sepoliaNetworkDetails.routerAddress);
        sepoliaToken.grantMintAndBurnRole(address(vault));
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(sepoliaToken), address(sepoliaPool));
        vm.stopPrank();

        console.log("Sepolia Pool Address:", address(sepoliaPool));
        console.log("Active Fork After Sepolia Deployment:", vm.activeFork());

        // Deploy on Arb Sepolia (Fork 1)
        vm.selectFork(arbSepoliaFork);
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        console.log("Deploying RebaseTokenPool on Arb Sepolia...");
        arbSepoliaPool = new RebaseTokenPool(IERC20(address(arbSepoliaToken)), new address[](0), arbSepoliaNetworkDetails.rmnProxyAddress, arbSepoliaNetworkDetails.routerAddress);
        console.log("Deployed Arb Sepolia Pool Address:", address(arbSepoliaPool));
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(arbSepoliaToken), address(arbSepoliaPool));
        vm.stopPrank();

        console.log("Arb Sepolia Pool Address:", address(arbSepoliaPool));
        console.log("Active Fork After Arb Sepolia Deployment:", vm.activeFork());

        // Ensure correct forks are selected before configuring
        vm.selectFork(sepoliaFork);
        configureTokenPool(sepoliaFork, sepoliaPool, arbSepoliaPool, IRebaseToken(address(arbSepoliaToken)), arbSepoliaNetworkDetails);

        vm.selectFork(arbSepoliaFork);
        configureTokenPool(arbSepoliaFork, arbSepoliaPool, sepoliaPool, IRebaseToken(address(sepoliaToken)), sepoliaNetworkDetails);
    }

    function configureTokenPool(uint256 fork, TokenPool localPool, TokenPool remotePool, IRebaseToken remoteToken, Register.NetworkDetails memory remoteNetworkDetails) public {
        vm.selectFork(fork);
        vm.startPrank(owner);
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);
        bytes memory remotePoolAddress = abi.encode(address(remotePool));
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteNetworkDetails.chainSelector,
            allowed: true,
            remotePoolAddress: remotePoolAddress,
            remoteTokenAddress: abi.encode(address(remoteToken)),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });
        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0);

        // Add logging to debug the issue
        console.log("Applying chain updates");
        console.log("Local Pool Address:", address(localPool));
        console.log("Remote Pool Address:", address(remotePool));
        console.log("Remote Token Address:", address(remoteToken));
        console.log("Remote Chain Selector:", remoteNetworkDetails.chainSelector);
        console.logBytes(remotePoolAddress);
        console.logBytes(abi.encode(address(remoteToken)));

        // Add assertions to check for zero addresses
        require(remotePoolAddress.length != 0, "Remote pool address is zero");
        require(abi.encode(address(remoteToken)).length != 0, "Remote token address is zero");

        console.log("Decoded Remote Pool Address:", address(bytes20(remotePoolAddress)));
        console.log("Decoded Remote Token Address:", address(bytes20(abi.encode(address(remoteToken)))));
        console.log("Chains Array Length:", chains.length);
        console.log("Allowed:", chains[0].allowed);
        console.log("Outbound Rate Limiter Enabled:", chains[0].outboundRateLimiterConfig.isEnabled);
        console.log("Inbound Rate Limiter Enabled:", chains[0].inboundRateLimiterConfig.isEnabled);
        console.log("TokenAdminRegistry address:", address(TokenAdminRegistry(remoteNetworkDetails.tokenAdminRegistryAddress)));
        console.log("Remote Token Address in Registry:", address(remoteToken));
        console.log("Active fork before applyChainUpdates:", vm.activeFork());
        console.log("Expected fork:", fork);

        //
        //
        //
        console.log("Chain selector exists before update:", localPool.isSupportedChain(16015286601757825753));

        console.log("Active fork before applyChainUpdates:", vm.activeFork());
        console.log("Expected fork:", fork);
        //
        //
        //

        // Try-catch block to capture the revert reason
        try localPool.applyChainUpdates(chains) {
            console.log("applyChainUpdates executed successfully");
        } catch Error(string memory reason) {
            console.log("applyChainUpdates failed with reason:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("applyChainUpdates failed with raw error:");
            console.logBytes(lowLevelData);
            revert("applyChainUpdates failed");
        }

        // Add logging after applyChainUpdates
        console.log("After applyChainUpdates");

        vm.stopPrank();
        console.log("After stopPrank");
        console.log("This function is done");
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);

        //         struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains
        //     bytes data; // Data payload
        //     EVMTokenAmount[] tokenAmounts; // Token transfers
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
        //   }

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: 100_000, allowOutOfOrderExecution: false}))
        });
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        vm.prank(user);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);
        uint256 localBalanceBefore = localToken.balanceOf(user);
        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
        uint256 localUserInterestRate = localToken.getUserInterestRate(user);

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);
        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
        uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);
        assertEq(remoteUserInterestRate, localUserInterestRate);
    }

    function testBridgeAllTokens() public {
        configureTokenPool(sepoliaFork, sepoliaPool, arbSepoliaPool, IRebaseToken(address(arbSepoliaToken)), arbSepoliaNetworkDetails);
        configureTokenPool(arbSepoliaFork, arbSepoliaPool, sepoliaPool, IRebaseToken(address(sepoliaToken)), sepoliaNetworkDetails);
        // We are working on the source chain (Sepolia)
        vm.selectFork(sepoliaFork);
        // Pretend a user is interacting with the protocol
        // Give the user some ETH
        vm.deal(user, SEND_VALUE);
        vm.startPrank(user);
        // Deposit to the vault and receive tokens
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        // bridge the tokens
        console.log("Bridging %d tokens", SEND_VALUE);
        uint256 startBalance = IERC20(address(sepoliaToken)).balanceOf(user);
        assertEq(startBalance, SEND_VALUE);
        vm.stopPrank();
        // bridge ALL TOKENS to the destination chain
        bridgeTokens(SEND_VALUE, sepoliaFork, arbSepoliaFork, sepoliaNetworkDetails, arbSepoliaNetworkDetails, sepoliaToken, arbSepoliaToken);
    }
}
