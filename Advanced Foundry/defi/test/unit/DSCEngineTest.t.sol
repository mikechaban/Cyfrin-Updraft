// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    uint256 AMOUNT_TO_MINT = 100 ether;
    address public USER = makeAddr("user");

    // Liquidation
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public COLLATERAL_TO_COVER = 20 ether;

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant DEBT_TO_COVER = 15 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, , ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__NumOfTokenAddressesAndNumOfPriceFeedAddressesShouldBeEqual.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /*//////////////////////////////////////////////////////////////
                              PRICE TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18
        uint256 expectedUsdValue = 30000e18;
        uint256 actualUsdValue = dsce.getUSDValue(weth, ethAmount);
        assertEq(expectedUsdValue, actualUsdValue);
    }

    function testGetTokenAmountFromUSD() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWETH = 0.05 ether;
        uint256 actualWETH = dsce.getTokenAmountFromUSD(weth, usdAmount);
        assertEq(expectedWETH, actualWETH);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT COLLATERAL TEST
    //////////////////////////////////////////////////////////////*/
    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock sillyToken = new ERC20Mock("SILLY", "SILLY", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralTokenNotAllowed.selector);
        dsce.depositCollateral(address(sillyToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDSCMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUSD(weth, collateralValueInUSD);
        assertEq(totalDSCMinted, expectedTotalDSCMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testRedeemCollateralForDSCFixed() public {
        // Arrange
        uint256 expectedWETHBalance = AMOUNT_COLLATERAL;

        uint256 userDSCBalance = dsc.balanceOf(USER);
        uint256 userWETHBalance = ERC20Mock(weth).balanceOf(USER);

        // Act
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        dsce.redeemCollateralForDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();

        // Assert
        assertEq(userDSCBalance, 0);
        assertEq(expectedWETHBalance, userWETHBalance);
    }

    function testCantLiquidateGoodHealthFactor() public depositedCollateral {
        ERC20Mock(weth).mint(LIQUIDATOR, COLLATERAL_TO_COVER);

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_TO_MINT);
        dsce.mintDSC(AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 initialUserHealthFactor = dsce.getHealthFactor(USER);
        emit log_named_uint("Initial Health Factor", initialUserHealthFactor);

        assertGt(initialUserHealthFactor, 1e18, "Initial health factor should be above the minimum threshold");

        uint256 initialUserDSCBalance = dsc.balanceOf(USER);
        uint256 initialUserWETHBalance = ERC20Mock(weth).balanceOf(USER);

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), COLLATERAL_TO_COVER);
        dsce.depositCollateralAndMintDSC(weth, COLLATERAL_TO_COVER, AMOUNT_TO_MINT);

        uint256 initialLiquidatorDSCBalance = dsc.balanceOf(LIQUIDATOR);
        uint256 initialLiquidatorWETHBalance = ERC20Mock(weth).balanceOf(LIQUIDATOR);

        dsc.approve(address(dsce), AMOUNT_TO_MINT);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOK.selector);
        dsce.liquidate(weth, USER, AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 finalUserDSCBalance = dsc.balanceOf(USER);
        uint256 finalUserWETHBalance = ERC20Mock(weth).balanceOf(USER);

        uint256 finalLiquidatorDSCBalance = dsc.balanceOf(LIQUIDATOR);
        uint256 finalLiquidatorWETHBalance = ERC20Mock(weth).balanceOf(LIQUIDATOR);

        assertEq(initialUserDSCBalance, finalUserDSCBalance);
        assertEq(initialUserWETHBalance, finalUserWETHBalance);

        assertEq(initialLiquidatorDSCBalance, finalLiquidatorDSCBalance);
        assertEq(initialLiquidatorWETHBalance, finalLiquidatorWETHBalance);
    }
}
