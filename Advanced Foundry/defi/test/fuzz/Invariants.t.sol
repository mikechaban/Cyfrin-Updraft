// SPDX-License-Identifier: MIT

// Have our invariant aka properties

// What are our invariants?
// 1. The total supply of DSC should be less than the total value of collateral
// 2. Getter view functions should never revert <- evergreen invariant (all protocols should prolly have it)

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    // For getter function Invariants
    address token;
    uint256 USDAmountInWei;
    address user;
    uint256 amount;
    uint256 totalDscMinted;
    uint256 collateralValueInUsd;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (, , weth, wbtc, ) = config.activeNetworkConfig();
        // targetContract(address(dsce));
        handler = new Handler(dsce, dsc);
        targetContract(address(handler));

        // For getter function Invariants
        token = weth; // or any appropriate token address
        USDAmountInWei = 1e18; // example value
        user = address(0x123); // example user address
        amount = 1e18; // example amount
        totalDscMinted = 1e18; // example total DSC minted
        collateralValueInUsd = 1e18; // example collateral value in USD
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it to all the debt (DSC)

        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWETHDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalWBTCDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUSDValue(weth, totalWETHDeposited);
        uint256 wbtcValue = dsce.getUSDValue(wbtc, totalWBTCDeposited);

        console.log("weth value:", wethValue);
        console.log("wbtc value:", wbtcValue);
        console.log("Total Supply:", totalSupply);
        console.log("Times mint called: ", handler.timesMintIsCalled());

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public view {
        dsce.getTokenAmountFromUSD(token, USDAmountInWei);
        dsce.getAccountCollateralValue(user);
        dsce.getUSDValue(token, amount);
        dsce.calculateHealthFactor(totalDscMinted, collateralValueInUsd);
        dsce.getAccountInformation(user);
        dsce.getCollateralTokens();
        dsce.getCollateralBalanceOfUser(user, token);
        dsce.getPrecision();
        dsce.getAdditionalFeedPrecision();
        dsce.getLiquidationThreshold();
        dsce.getLiquidationBonus();
        dsce.getLiquidationPrecision();
        dsce.getMinHealthFactor();
        dsce.getDSC();
        dsce.getCollateralTokenPriceFeed(token);
        dsce.getHealthFactor(user);
    }
}
