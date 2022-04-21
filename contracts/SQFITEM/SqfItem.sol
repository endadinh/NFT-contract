//V2
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./ERC721.sol";
import "./ERC721Enumerable.sol";
import "./ERC721URIStorage.sol";
import "./Pausable.sol";
import "./AccessControl.sol";
import "./Counters.sol";
import "./IERC20.sol";
import "./SafeMath.sol";

contract SQFItem is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    AccessControl
{
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    struct SQFI {
        uint8 status;
    }

    mapping(uint256 => SQFI) public SQFItemDetail;
    mapping(uint256 => string) public _tokenURIs;

    string private _URI;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant HYDRA_ROLE = keccak256("HYDRA_ROLE");

    event ActiveItem(uint256[] tokenId, uint8[] status);

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("SQFITEM", "SQFI") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(HYDRA_ROLE,msg.sender);
    }

    function _baseURI() internal view override returns (string memory) {
        return _URI;
    }
    function changeBaseURI(string memory _newURI)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _URI = _newURI;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function itemInfo(uint256 tokenId)
        public
        view
        returns (
            address owner,
            uint8 status,
            string memory tokenURI_
        )
    {
        SQFI memory item = SQFItemDetail[tokenId];
        return (
            ownerOf(tokenId),
            item.status,
            tokenURI(tokenId)
        );
    }
    
    function setMinter( address to) 
    public onlyRole(DEFAULT_ADMIN_ROLE) { 
        _setupRole(MINTER_ROLE, to);
    }

    function safeMint(
        address to,
        string memory tokenURI_
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        _safeMint(to, _tokenIdCounter.current());
        SQFItemDetail[_tokenIdCounter.current()] = SQFI(
            0
        );
        super._setTokenURI(_tokenIdCounter.current(), tokenURI_);
        _tokenIdCounter.increment();
        return _tokenIdCounter.current() - 1;
    }

    function activeItem(uint256[] memory tokenId, uint8[] memory status)
        public
        onlyRole(HYDRA_ROLE)
    {
        for (uint256 i = 0; i < tokenId.length; i++) {
            require(status[i] != 0, "Can not set to processing");
            SQFItemDetail[tokenId[i]].status = status[i];
        }
        emit ActiveItem(tokenId, status);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        if (from != address(0x0)) {
            require(SQFItemDetail[tokenId].status == 1, "Item must be active");
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function burn(uint256 tokenId) public onlyRole(MINTER_ROLE) {
        _burn(tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}