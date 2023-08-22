//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//1.Deploy mocks when we are on a local anvil chain (SEPOLIA,MAINNET...)
//2.Keep track of contract address across different chains (Anvil)
//Sepolioa ETH/USD different address
//Mainnet ETH/USD differet address

import {Script} from "lib/forge-std/src/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Test,console} from "lib/forge-std/src/Test.sol";


contract HelperConfig is Script{
    // If we are on a local anvil, we deploy mocks
    // Otherwise, grab the existing address from this live network

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8;

    struct NetworkConfig{
        address priceFeed; // ETH/USD price feed address
    }
    NetworkConfig public activeNetworkConfig;

    constructor(){
        if(block.chainid == 11155111){
            activeNetworkConfig = getSepoliaEthConfig();
            
        }
        else if(block.chainid == 1){
            activeNetworkConfig = getMainnetEthConfig();
            
        }
        else if(block.chainid == 42161){
            activeNetworkConfig = getArbutrumMainnetConfig();
        }
        else{
            activeNetworkConfig = getOrCreateAnvilConfig();
           
        }
        
    }
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory){
        //price feed address
        NetworkConfig memory sepoliaConfig = NetworkConfig({priceFeed : 0x694AA1769357215DE4FAC081bf1f309aDC325306});

        return sepoliaConfig;
    }
    function getMainnetEthConfig() public pure returns (NetworkConfig memory){
        //price feed address
        NetworkConfig memory mainnetConfig = NetworkConfig({priceFeed : 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419});

        return mainnetConfig;
    }
    function getArbutrumMainnetConfig() public pure returns (NetworkConfig memory){
        //price feed address
        NetworkConfig memory arbitrumConfig = NetworkConfig({priceFeed : 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612});

        return arbitrumConfig;
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory){
        if(activeNetworkConfig.priceFeed != address(0)){
            return activeNetworkConfig;
        }
         
        //price feed address
        
        // 1. Deploy the mocks
        // 2. Return the mock address

        vm.startBroadcast();
    
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS,INITIAL_PRICE);
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({priceFeed : address(mockPriceFeed)});
        return anvilConfig;
    }
}