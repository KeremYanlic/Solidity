//SPDX-License-Identifier: MIT
pragma solidity^0.8.20;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
contract DSCEngineTest is Test {
    
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address weth;


    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    function setUp() public {
        
        deployer = new DeployDSC();
        (dsc,dscEngine,helperConfig) = deployer.run();
        
        (ethUsdPriceFeed,, weth,,) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER,STARTING_ERC20_BALANCE);
    }
    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth,0);

        vm.stopPrank();
    }

}  