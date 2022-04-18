// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTAuction is ERC721Enumerable, Ownable {
    constructor() ERC721("NFTAuction", "NFTA") {}
    
    mapping(uint256 => string) mapUri;


    function mint(address _to, string calldata _uri) external returns(uint256 id) {
        _mint(_to, totalSupply() + 1);
        id = totalSupply();
        mapUri[id] = _uri;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        
        return mapUri[tokenId];
    }
}
