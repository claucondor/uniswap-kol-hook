// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/utils/Pausable.sol";

contract ReferralRegistry is 
    ERC721, 
    ERC721Enumerable, 
    ERC721URIStorage, 
    AccessControl, 
    Pausable 
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    
    uint256 private _tokenIds;
    
    // Mappings principales
    mapping(uint256 => ReferralInfo) public referralInfo;
    mapping(address => uint256[]) public kolTokens;
    mapping(address => uint256) public userReferralToken;
    mapping(string => uint256) public codeToTokenId;
    
    struct ReferralInfo {
        string referralCode;
        address kol;
        uint256 totalTVL;
        uint256 uniqueUsers;
        uint256 createdAt;
        bool isActive;
        string socialHandle; // Twitter, Discord, etc.
        string metadata; // IPFS hash for additional data
    }
    
    // Events
    event ReferralMinted(
        uint256 indexed tokenId,
        address indexed kol,
        string referralCode,
        string socialHandle
    );
    
    event UserReferred(
        address indexed user,
        uint256 indexed tokenId,
        address indexed kol
    );
    
    event ReferralDeactivated(uint256 indexed tokenId);
    event TVLUpdated(uint256 indexed tokenId, uint256 newTVL);
    
    constructor() ERC721("KOL Referral NFT", "KOLREF") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPDATER_ROLE, msg.sender);
    }
    
    function mintReferral(
        address kol,
        string memory referralCode,
        string memory socialHandle,
        string memory metadataURI
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        require(codeToTokenId[referralCode] == 0, "Code already exists");
        require(kol != address(0), "Invalid KOL address");
        require(bytes(referralCode).length > 0, "Empty referral code");
        
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        
        _safeMint(kol, newTokenId);
        if (bytes(metadataURI).length > 0) {
            _setTokenURI(newTokenId, metadataURI);
        }
        
        referralInfo[newTokenId] = ReferralInfo({
            referralCode: referralCode,
            kol: kol,
            totalTVL: 0,
            uniqueUsers: 0,
            createdAt: block.timestamp,
            isActive: true,
            socialHandle: socialHandle,
            metadata: metadataURI
        });
        
        codeToTokenId[referralCode] = newTokenId;
        kolTokens[kol].push(newTokenId);
        
        emit ReferralMinted(newTokenId, kol, referralCode, socialHandle);
        
        return newTokenId;
    }
    
    function setUserReferral(
        address user,
        string memory referralCode
    ) external returns (uint256 tokenId, address kol) {
        require(user != address(0), "Invalid user address");
        require(userReferralToken[user] == 0, "User already referred");
        require(bytes(referralCode).length > 0, "Empty referral code");
        
        tokenId = codeToTokenId[referralCode];
        require(tokenId != 0, "Invalid referral code");
        require(referralInfo[tokenId].isActive, "Referral inactive");
        
        userReferralToken[user] = tokenId;
        referralInfo[tokenId].uniqueUsers++;
        kol = referralInfo[tokenId].kol;
        
        emit UserReferred(user, tokenId, kol);
    }
    
    function getUserReferralInfo(address user) 
        external 
        view 
        returns (uint256 tokenId, address kol, string memory referralCode) 
    {
        tokenId = userReferralToken[user];
        if (tokenId == 0) return (0, address(0), "");
        
        ReferralInfo memory info = referralInfo[tokenId];
        return (tokenId, info.kol, info.referralCode);
    }
    
    function updateTVL(uint256 tokenId, uint256 newTVL) external onlyRole(UPDATER_ROLE) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        referralInfo[tokenId].totalTVL = newTVL;
        emit TVLUpdated(tokenId, newTVL);
    }
    
    function deactivateReferral(uint256 tokenId) external {
        require(
            ownerOf(tokenId) == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        
        referralInfo[tokenId].isActive = false;
        emit ReferralDeactivated(tokenId);
    }
    
    function activateReferral(uint256 tokenId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        referralInfo[tokenId].isActive = true;
    }
    
    function getKOLTokens(address kol) external view returns (uint256[] memory) {
        return kolTokens[kol];
    }
    
    function getReferralByCode(string memory referralCode) 
        external 
        view 
        returns (uint256 tokenId, ReferralInfo memory info) 
    {
        tokenId = codeToTokenId[referralCode];
        if (tokenId != 0) {
            info = referralInfo[tokenId];
        }
    }
    
    function isValidReferralCode(string memory referralCode) external view returns (bool) {
        uint256 tokenId = codeToTokenId[referralCode];
        return tokenId != 0 && referralInfo[tokenId].isActive;
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    // Override functions required by Solidity for OpenZeppelin v5
    function _update(address to, uint256 tokenId, address auth) 
        internal 
        override(ERC721, ERC721Enumerable) 
        whenNotPaused 
        returns (address) 
    {
        address from = _ownerOf(tokenId);
        address previousOwner = super._update(to, tokenId, auth);
        
        // Update KOL mappings on transfer
        if (from != address(0) && to != address(0) && from != to) {
            // Remove from old owner
            uint256[] storage fromTokens = kolTokens[from];
            for (uint i = 0; i < fromTokens.length; i++) {
                if (fromTokens[i] == tokenId) {
                    fromTokens[i] = fromTokens[fromTokens.length - 1];
                    fromTokens.pop();
                    break;
                }
            }
            
            // Add to new owner
            kolTokens[to].push(tokenId);
            
            // Update referral info
            referralInfo[tokenId].kol = to;
        }
        
        return previousOwner;
    }
    
    function _increaseBalance(address account, uint128 value) 
        internal 
        override(ERC721, ERC721Enumerable) 
    {
        super._increaseBalance(account, value);
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
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
} 