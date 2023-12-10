//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg.
// This stablecoin has the properties:
// - Exogenous Collateral
// - Dollar pegged
// - Algoritmically Stable

// It is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and WBTC.
// Our DSC system should always be "overcollateralized". At no point, should the value of all collateral <= the $ backed value of all the DSC.

// This contract is the core of DSC System. It handles all the logic for mining and redeeming DSC, as well as depositing & withdrawing collateral
// This contract is VERY loosely based on the MakerDAO DSS system.
contract DSCEngine is ReentrancyGuard{
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngnie_TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeed; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_priceFeed[tokenAddress] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();

            for (uint256 i = 0; i < tokenAddresses.length; i++) {
                s_priceFeed[tokenAddresses[i]] = priceFeedAddresses[i];
                s_collateralTokens.push(tokenAddresses[i]);
            }
            i_dsc = DecentralizedStableCoin(dscAddress);
        }
    }

    function depositCollateralAndMintDsc() external {}
    /**
     *
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender,tokenCollateralAddress,amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender,address(this),amountCollateral);
        if(!success){
            revert DSCEngnie_TransferFailed();

        }
    }

    function redeemCollateralForDsc() external {}
    function redeemCollateral() external {}

    /**
     * 
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @notice they must have more collateral value than the minimum threshold
     */
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant{
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they minted too much ($150 DSC, $100 ETH)
        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if(!minted){
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc() external {}
    function liquidate() external {}

    function getHealthFactor() external view {}


    function _getAccountInformation(address user) private view returns (uint256 totalDscMinted,uint256 collateralValueInUsd){
        
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }
    /**
     * 
     * Returns how close to liquidation a user is
     * If a user goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256){
        // total DSC minted
        // total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

     // 1. Check health factor (do they have enough collateral?)
     // 2. Revert if they don't
    function _revertIfHealthFactorIsBroken(address user) internal view {
       uint256 userHealthFactor = _healthFactor(user);   
       if(userHealthFactor < MIN_HEALTH_FACTOR) {
          revert DSCEngine__BreaksHealthFactor(userHealthFactor);

       }
    }


    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUsd){
        // loop through each collateral token, get the amount they have deposited, and map it to 
        // the price , to get the USD value
        for(uint256 i=0; i < s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 tokenAmount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token,tokenAmount);
        }
        return totalCollateralValueInUsd;
    }
    function getUsdValue(address token, uint256 amount) public view returns (uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[token]);
        (,int256 price,,,) = priceFeed.latestRoundData(); 
        // 1 ETH = $1000
        // The returned value from CL will be 1000 * 1e8;
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
