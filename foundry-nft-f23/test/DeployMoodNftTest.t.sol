//SPDX-License-Identifier: MIT
pragma solidity^0.8.18;

import {Test,console} from "lib/openzeppelin-contracts/lib/forge-std/src/Test.sol";
import {MoodNft} from "../src/MoodNft.sol";
import {DeployMoodNft} from "../script/DeployMoodNft.s.sol";
contract DeployMoodNftTest is Test {
   
  DeployMoodNft public deployMoodNft;

  function setUp() public {
    deployMoodNft = new DeployMoodNft();
  }

  function testConvertSvgToUri() public view {
    string memory expectedUri = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSAiNTAwIiBoZWlnaHQ9IjUwMCI+Cjx0ZXh0IHggPSAiMCIgeSA9ICIxNSIgZmlsbCA9ICJyZWQiPkhpISBZb3VyIGJyb3dzZXIgZGVjb2RlZCB0aGlzCiAgICAKPC90ZXh0PgogICAgCjwvc3ZnPg==";
    string memory svg = '<svg xmlns="http://www.w3.org/2000/svg" width= "500" height="500"><text x = "0" y = "15" fill = "red">Hi! Your browser decoded this</text></svg>';
    string memory actualUri = deployMoodNft.svgToImageURI(svg);

    console.log(expectedUri);
    console.log(actualUri);
    //assert(keccak256(abi.encodePacked(expectedUri)) == keccak256(abi.encodePacked(actualUri)));
  }
}