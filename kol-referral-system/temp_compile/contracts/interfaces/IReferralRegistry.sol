// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IReferralRegistry {
    struct ReferralInfo {
        string referralCode;
        address kol;
        uint256 totalTVL;
        uint256 uniqueUsers;
        uint256 createdAt;
        bool isActive;
        string socialHandle;
        string metadata;
    }
    
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
    
    function getUserReferralInfo(address user) 
        external 
        view 
        returns (uint256 tokenId, address kol, string memory referralCode);
    
    function updateTVL(uint256 tokenId, uint256 newTVL) external;
    
    function referralInfo(uint256 tokenId) 
        external 
        view 
        returns (ReferralInfo memory);
    
    function setUserReferral(address user, string memory referralCode) 
        external 
        returns (uint256 tokenId, address kol);
        
    function hasRole(bytes32 role, address account) external view returns (bool);
    
    function grantRole(bytes32 role, address account) external;
    
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function mintReferral(
        address kol,
        string memory referralCode,
        string memory socialHandle,
        string memory metadataURI
    ) external returns (uint256);
} 