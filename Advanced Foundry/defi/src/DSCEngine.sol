// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Mike Chabanovskyi
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg.
 * This stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by wETH and wBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of all collateral be <= the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the DSC System. It handles all the logic for minting and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice This contract is very loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__NumOfTokenAddressesAndNumOfPriceFeedAddressesShouldBeEqual();
    error DSCEngine__CollateralTokenNotAllowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintingFailed();
    error DSCEngine__HealthFactorOK();
    error DSCEngine__HealthFactorNotImproved();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amountOfCollateralDeposit)) private s_collateralDeposited;
    mapping(address user => uint256 amountDSCMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_DSC;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedCollateralToken(address requestedCollateralTokenAddress) {
        if (s_priceFeeds[requestedCollateralTokenAddress] == address(0)) {
            revert DSCEngine__CollateralTokenNotAllowed();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address DSCAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__NumOfTokenAddressesAndNumOfPriceFeedAddressesShouldBeEqual();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_DSC = DecentralizedStableCoin(DSCAddress);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDSCToMint The amount of DSC to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDSCToMint) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDSCToMint);
    }

    /**
     * @notice Follows CEI
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        isAllowedCollateralToken(tokenCollateralAddress)
        moreThanZero(amountCollateral)
        nonReentrant // <- whenever working with external contracts, consider making functions nonReentrant
    /* payable */
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're withdrawing
     * @param amountCollateral: The amount of collateral you're withdrawing
     * @param amountDSCToBurn: The amount of DSC you want to burn
     * @notice This function will withdraw your collateral and burn DSC in one transaction
     */
    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDSCToBurn) external moreThanZero(amountCollateral) {
        _burnDSC(amountDSCToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have DSC minted, you will not be able to redeem until you burn your DSC
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) external moreThanZero(amountCollateral) nonReentrant {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice follows CEI
     * @param amountDSCToMint The amount of DSC to mint
     * @notice The user must have more collateral value than the minimum threshold
     */
    function mintDSC(uint256 amountDSCToMint) public moreThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;
        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_DSC.mint(msg.sender, amountDSCToMint);

        if (!minted) {
            revert DSCEngine__MintingFailed();
        }
    }

    function burnDSC(uint256 amount) public moreThanZero(amount) {
        _burnDSC(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @param collateral The ERC20 collateral address to liquidate from the user
     * @param user The user who has broken the health factor. Their _healthFactor should be below MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC you want to burn to improve the user's health factor
     * @notice You can partially liquidate a user.
     * @notice You will get a liquidation bonus for taking the user's funds
     * @notice This function working assumes the protocol will be roughly 200% overcollateralized in order for this to work
     * @notice A known bug would be if the protocol were 100% or less collateralized, then we wouldn't be able to incentivize the liquidators
     */
    function liquidate(address collateral, address user, uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOK();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUSD(collateral, debtToCover);

        // And give them a 10% bonus
        // 0.05 * 0.1 = 0.005. Getting 0.055 ETH
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);

        _burnDSC(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    /*//////////////////////////////////////////////////////////////
                     PRIVATE & INTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Low-level internal function. Do not call unless the function calling it is checking for health factors being broken
     */
    function _burnDSC(uint256 amountDSCToBurn, address onBehalfOf, address DSCFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDSCToBurn;
        bool success = i_DSC.transferFrom(DSCFrom, address(this), amountDSCToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_DSC.burn(amountDSCToBurn);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user) private view returns (uint256 totalDSCMinted, uint256 collateralValueInUSD) {
        totalDSCMinted = s_DSCMinted[user];

        collateralValueInUSD = getAccountCollateralValue(user);
    }

    /**
     * Returns how close to liquidation a user is
     * If a user goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) /* The underscore means it's an internal function */ {
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);

        // To avoid division by 0:
        if (totalDSCMinted == 0) {
            return type(uint256).max; // Return the maximum value if no DSC is minted
        }

        uint256 collateralAdjustedForThreshold = (collateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    /*//////////////////////////////////////////////////////////////
                   PUBLIC & EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getTokenAmountFromUSD(address token, uint256 USDAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();

        return (USDAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUSD) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUSD += getUSDValue(token, amount);
        }
        return totalCollateralValueInUSD;
    }

    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getAccountInformation(address user) external view returns (uint256 totalDSCMinted, uint256 collateralValueInUSD) {
        (totalDSCMinted, collateralValueInUSD) = _getAccountInformation(user);
    }
}
