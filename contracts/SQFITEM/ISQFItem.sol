// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISQFItem {
    function safeMint(
        address to,
        string memory tokenURI_
    ) external returns (uint256);

    function burn(uint256 tokenId) external;

    // function paragonInfo(uint256 tokenId)
    //     external
    //     returns (
    //         address owner,
    //         bytes32 originalArt,
    //         bytes32 rawHashed,
    //         bytes32 runesList,
    //         uint8 status
    //     );
    function itemInfo(uint256 tokenId) 
    external
    returns(
            address owner,
            uint8 status,
            string calldata tokenURI
    );
}