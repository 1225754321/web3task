// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyERC721 is ERC721 {

    /**
     * @dev Emitted when mintNFT.
     */
    event MintNFTURI(address indexed from, uint256 indexed tokenId, string  uri);

    uint256 constant MAX_APES = 10000;
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev 无法根据该tokenId找到对应Uri
     * @param tokenId 无法根据该tokenId找到对应Uri 或者 对应uri为空
     */
    error TokenURINotFount(uint256 tokenId);

    constructor() ERC721("MyNFT", "MNFT") {}

    function mintNFT(
        address to,
        uint256 tokenId,
        string calldata tokenUri
    ) external returns (bool) {
        require(tokenId >= 0 && tokenId < MAX_APES, "tokenId out of range");
        require(bytes(tokenUri).length > 0, "tokenUri is empty");
        _safeMint(to, tokenId);
        _tokenURIs[tokenId] = tokenUri;
        emit MintNFTURI(to, tokenId, tokenUri);
        return true;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireOwned(tokenId);
        string memory uri = _tokenURIs[tokenId];
        if ( bytes(uri).length == 0 ) revert TokenURINotFount(tokenId);
        return uri;
    }
}

