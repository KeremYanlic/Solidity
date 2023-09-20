//SPDX-License-Identifier: MIT
pragma solidity^0.8.18;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Base64} from "lib/openzeppelin-contracts/contracts/utils/Base64.sol";
contract MoodNft is ERC721 {

    error MoodNft_CantFlipMoodIfNotOwner();
    
    mapping (uint256 => string) s_tokenIdToURI;
    uint256 private s_tokenCounter;
    string private s_sadSvgImageUri;
    string private s_happySvgImageUri;

    enum Mood{
        HAPPY,
        SAD
    }


    mapping(uint256 => Mood) private s_tokenIdToMood;

    constructor(string memory sadSvgImageUri,string memory happySvgImageUri) ERC721("Mood Nft","MN"){
        s_tokenCounter = 0;
        
        s_sadSvgImageUri = sadSvgImageUri;
        s_happySvgImageUri = happySvgImageUri;
    }
    function mintNft() public {
        _safeMint(msg.sender,s_tokenCounter);
        s_tokenIdToMood[s_tokenCounter] =  Mood.HAPPY;
        s_tokenCounter++;
    }
    function flipMood(uint256 tokenId) public {
        //only want the NFT owner to be able to change the mood\
        if(!_isApprovedOrOwner(msg.sender,tokenId)){
            revert MoodNft_CantFlipMoodIfNotOwner();
        }
        s_tokenIdToMood[tokenId] = s_tokenIdToMood[tokenId] == Mood.HAPPY ? Mood.SAD : Mood.HAPPY;

    }  


    function _baseURI() internal pure override returns (string memory){
        return "data:application/json;base64,";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory imageURI;

        imageURI = s_tokenIdToMood[tokenId] == Mood.HAPPY ? s_happySvgImageUri : s_sadSvgImageUri;

    
         return
            string(
                abi.encodePacked(
                    _baseURI(),
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name(), // You can add whatever name here
                                '", "description":"An NFT that reflects the mood of the owner, 100% on Chain!", ',
                                '"attributes": [{"trait_type": "moodiness", "value": 100}], "image":"',
                                imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    
}